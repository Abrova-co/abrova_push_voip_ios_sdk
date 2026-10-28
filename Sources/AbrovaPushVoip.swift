import Foundation
import UIKit
import PushKit
import CallKit
import AVFoundation
import UserNotifications

/// Main AbrovaPushVoip SDK class
public class AbrovaPushVoip: NSObject {

    /// Shared singleton instance
    public static let shared = AbrovaPushVoip()

    /// Delegate for receiving VoIP events
    public weak var delegate: AbrovaPushVoipDelegate?

    /// Current configuration
    private var config: VoipConfig = VoipConfig()

    /// PushKit registry for VoIP pushes
    private var voipRegistry: PKPushRegistry?

    /// CallKit provider for incoming call UI
    private var callProvider: CXProvider?

    /// CallKit call controller
    private let callController = CXCallController()

    /// Currently active call
    private var activeCall: (uuid: UUID, callData: VoipCallData)?

    /// Fallback active call (when CallKit is not available)
    private var fallbackActiveCall: VoipCallData?

    /// Initial call that launched the app
    private var initialCall: VoipCallData?

    /// Call timeout timer
    private var callTimeoutTimer: Timer?

    /// Notification category identifier for incoming call actions
    private static let callNotificationCategory = "ABROVA_PUSH_VOIP_INCOMING_CALL"
    private static let acceptAction = "ABROVA_PUSH_VOIP_ACCEPT"
    private static let declineAction = "ABROVA_PUSH_VOIP_DECLINE"

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Initialize the VoIP SDK with configuration
    public func initialize(config: VoipConfig) {
        self.config = config
        if config.shouldUseCallKit {
            setupCallKit()
        } else {
            setupFallbackNotificationCategory()
        }
        print("[AbrovaPushVoip] Initialized with appName: \(config.appName), callKit: \(config.shouldUseCallKit)")
    }

    /// Update configuration
    public func updateConfig(_ config: VoipConfig) {
        self.config = config
        if config.shouldUseCallKit {
            setupCallKit()
        } else {
            setupFallbackNotificationCategory()
        }
    }

    /// Register for VoIP push notifications
    public func registerForVoIPPushes() {
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
        print("[AbrovaPushVoip] Registering for VoIP pushes")
    }

    /// Get the VoIP push token
    public func getVoIPToken() -> String? {
        guard let credentials = voipRegistry?.pushToken(for: .voIP) else { return nil }
        return credentials.map { String(format: "%02x", $0) }.joined()
    }

    /// Show incoming call UI
    public func showIncomingCall(callData: VoipCallData) {
        if config.shouldUseCallKit {
            let uuid = UUID()
            reportIncomingCall(uuid: uuid, callData: callData)
        } else {
            showFallbackIncomingCall(callData: callData)
        }
    }

    /// End a call
    public func endCall(callId: String) {
        if config.shouldUseCallKit {
            guard let active = activeCall, active.callData.callId == callId else { return }

            let endAction = CXEndCallAction(call: active.uuid)
            let transaction = CXTransaction(action: endAction)

            callController.request(transaction) { [weak self] error in
                if let error = error {
                    print("[AbrovaPushVoip] Failed to end call: \(error)")
                }
                self?.cleanupCall()
            }
        } else {
            guard let active = fallbackActiveCall, active.callId == callId else { return }
            removeFallbackNotification()
            cleanupCall()
        }
    }

    /// Report call as connected
    public func reportCallConnected(callId: String) {
        if config.shouldUseCallKit {
            guard let active = activeCall, active.callData.callId == callId else { return }
            callProvider?.reportOutgoingCall(with: active.uuid, connectedAt: Date())
        }
        // No-op in fallback mode
    }

    /// Accept call from fallback notification (call this from your notification handler)
    public func acceptCallFromNotification(callId: String) {
        guard let active = fallbackActiveCall, active.callId == callId else { return }
        callTimeoutTimer?.invalidate()
        initialCall = active
        delegate?.voip(self, didAcceptCall: active)
        removeFallbackNotification()
        fallbackActiveCall = nil
    }

    /// Decline call from fallback notification (call this from your notification handler)
    public func declineCallFromNotification(callId: String) {
        guard let active = fallbackActiveCall, active.callId == callId else { return }
        callTimeoutTimer?.invalidate()
        delegate?.voip(self, didDeclineCall: active)
        removeFallbackNotification()
        fallbackActiveCall = nil
    }

    /// Handle notification action for fallback mode — call from UNUserNotificationCenterDelegate
    public func handleNotificationAction(actionIdentifier: String, userInfo: [AnyHashable: Any]) -> Bool {
        guard let callId = userInfo["callId"] as? String else { return false }

        switch actionIdentifier {
        case AbrovaPushVoip.acceptAction, UNNotificationDefaultActionIdentifier:
            acceptCallFromNotification(callId: callId)
            return true
        case AbrovaPushVoip.declineAction:
            declineCallFromNotification(callId: callId)
            return true
        default:
            return false
        }
    }

    /// Get initial call that launched the app
    public func getInitialCall() -> VoipCallData? {
        return initialCall
    }

    /// Set initial call (for internal use by wrappers)
    public func setInitialCall(_ callData: VoipCallData) {
        initialCall = callData
    }

    /// Clear initial call after handling
    public func clearInitialCall() {
        initialCall = nil
    }

    /// Handle incoming push payload
    public func handlePushPayload(_ payload: [AnyHashable: Any]) -> Bool {
        guard let callData = VoipCallData.fromPayload(payload, config: config) else {
            print("[AbrovaPushVoip] Invalid push payload - could not parse call data")
            return false
        }

        print("[AbrovaPushVoip] Handling VoIP push - callId: \(callData.callId), caller: \(callData.callerName)")
        showIncomingCall(callData: callData)
        return true
    }

    // MARK: - CallKit Setup (normal regions)

    private func setupCallKit() {
        let providerConfig: CXProviderConfiguration
        if #available(iOS 14.0, *) {
            providerConfig = CXProviderConfiguration()
        } else {
            providerConfig = CXProviderConfiguration(localizedName: config.appName)
        }

        providerConfig.supportsVideo = config.supportsVideo
        providerConfig.maximumCallsPerCallGroup = 1
        providerConfig.supportedHandleTypes = [.generic, .phoneNumber]

        if let ringtoneName = config.ringtoneName {
            providerConfig.ringtoneSound = ringtoneName
        }

        if let iconName = config.iconTemplateName,
           let image = UIImage(named: iconName) {
            providerConfig.iconTemplateImageData = image.pngData()
        }

        callProvider = CXProvider(configuration: providerConfig)
        callProvider?.setDelegate(self, queue: .main)
    }

    private func reportIncomingCall(uuid: UUID, callData: VoipCallData) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callData.callerId ?? callData.callId)
        update.hasVideo = callData.callType == "video"
        update.localizedCallerName = callData.callerName

        activeCall = (uuid, callData)

        callProvider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                print("[AbrovaPushVoip] Failed to report incoming call: \(error)")
                self?.delegate?.voip(AbrovaPushVoip.shared, didFailWithError: error.localizedDescription)
                self?.cleanupCall()
            } else {
                print("[AbrovaPushVoip] Incoming call reported: \(callData.callerName)")
                self?.startCallTimeout()
            }
        }
    }

    // MARK: - Fallback Mode (China / CallKit disabled)

    private func setupFallbackNotificationCategory() {
        let acceptAction = UNNotificationAction(
            identifier: AbrovaPushVoip.acceptAction,
            title: "Accept",
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: AbrovaPushVoip.declineAction,
            title: "Decline",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: AbrovaPushVoip.callNotificationCategory,
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var categories = existing
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    private func showFallbackIncomingCall(callData: VoipCallData) {
        fallbackActiveCall = callData

        // Show local notification with accept/decline actions
        let content = UNMutableNotificationContent()
        content.title = callData.callerName
        content.body = callData.callType == "video" ? "Incoming video call" : "Incoming call"
        content.categoryIdentifier = AbrovaPushVoip.callNotificationCategory
        content.userInfo = ["callId": callData.callId, "callerName": callData.callerName, "callType": callData.callType]

        if let ringtoneName = config.ringtoneName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: ringtoneName))
        } else {
            if #available(iOS 15.2, *) {
                content.sound = .defaultRingtone
            } else {
                content.sound = .defaultCritical
            }
        }

        let request = UNNotificationRequest(
            identifier: "abrova_push_voip_call_\(callData.callId)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("[AbrovaPushVoip] Failed to show fallback notification: \(error)")
                self?.delegate?.voip(AbrovaPushVoip.shared, didFailWithError: error.localizedDescription)
            } else {
                print("[AbrovaPushVoip] Fallback notification shown for: \(callData.callerName)")
            }
        }

        // Notify delegate so app can show custom UI if desired
        delegate?.voip(self, didReceiveIncomingCall: callData)

        startCallTimeout()
    }

    private func removeFallbackNotification() {
        if let callId = fallbackActiveCall?.callId {
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: ["abrova_push_voip_call_\(callId)"]
            )
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["abrova_push_voip_call_\(callId)"]
            )
        }
    }

    // MARK: - Timeout & Cleanup

    private func startCallTimeout() {
        callTimeoutTimer?.invalidate()
        callTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(config.callTimeout),
            repeats: false
        ) { [weak self] _ in
            self?.handleCallTimeout()
        }
    }

    private func handleCallTimeout() {
        if config.shouldUseCallKit {
            guard let active = activeCall else { return }
            print("[AbrovaPushVoip] Call timeout: \(active.callData.callId)")
            callProvider?.reportCall(with: active.uuid, endedAt: Date(), reason: .unanswered)
            delegate?.voip(self, didTimeoutCall: active.callData)
        } else {
            guard let active = fallbackActiveCall else { return }
            print("[AbrovaPushVoip] Call timeout: \(active.callId)")
            removeFallbackNotification()
            delegate?.voip(self, didTimeoutCall: active)
            fallbackActiveCall = nil
        }

        cleanupCall()
    }

    private func cleanupCall() {
        callTimeoutTimer?.invalidate()
        callTimeoutTimer = nil
        activeCall = nil
    }
}

// MARK: - PKPushRegistryDelegate
extension AbrovaPushVoip: PKPushRegistryDelegate {
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }

        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("[AbrovaPushVoip] VoIP token received: \(token)")
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        print("[AbrovaPushVoip] VoIP push received")

        if config.shouldUseCallKit {
            // Must report a call to CallKit (Apple requirement since iOS 13)
            if !handlePushPayload(payload.dictionaryPayload) {
                // If we can't parse the payload, still need to report a call
                // Otherwise Apple will terminate the app
                let uuid = UUID()
                let update = CXCallUpdate()
                update.remoteHandle = CXHandle(type: .generic, value: "Unknown")
                update.localizedCallerName = "Unknown Caller"

                callProvider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
                    // Immediately end this fake call
                    self?.callProvider?.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                    completion()
                }
                return
            }
        } else {
            // Fallback mode: no CallKit needed, just handle the payload
            _ = handlePushPayload(payload.dictionaryPayload)
        }

        completion()
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("[AbrovaPushVoip] VoIP token invalidated")
    }
}

// MARK: - CXProviderDelegate
extension AbrovaPushVoip: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        print("[AbrovaPushVoip] Provider did reset")
        cleanupCall()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[AbrovaPushVoip] Call answered")

        if let active = activeCall {
            callTimeoutTimer?.invalidate()

            // Set as initial call so app can retrieve it
            initialCall = active.callData

            // Notify delegate
            delegate?.voip(self, didAcceptCall: active.callData)
        }

        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[AbrovaPushVoip] Call ended")

        if let active = activeCall {
            // Check if this was a decline (not answered yet) or end
            callTimeoutTimer?.invalidate()

            // Notify delegate of decline
            delegate?.voip(self, didDeclineCall: active.callData)
        }

        cleanupCall()
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[AbrovaPushVoip] Audio session activated")
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[AbrovaPushVoip] Audio session deactivated")
    }
}
