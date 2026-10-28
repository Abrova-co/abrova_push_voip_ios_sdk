import Foundation

/// Configuration for AbrovaPushVoip SDK
public struct VoipConfig {
    /// App name shown in CallKit UI
    public let appName: String
    /// Enable vibration (default: true)
    public let vibrate: Bool
    /// Call timeout in seconds (default: 30)
    public let callTimeout: Int
    /// Supports video calls (default: false)
    public let supportsVideo: Bool
    /// Custom ringtone name (optional)
    public let ringtoneName: String?
    /// Icon template image name for CallKit (optional)
    public let iconTemplateName: String?
    /// Manually disable CallKit (e.g. for China where CallKit is banned)
    public let disableCallKit: Bool

    // Payload keys for extracting call data from push
    public let callIdKey: String
    public let callerNameKey: String
    public let callerIdKey: String
    public let callerAvatarKey: String
    public let callTypeKey: String

    /// Whether CallKit should be used based on config and region
    public var shouldUseCallKit: Bool {
        if disableCallKit { return false }
        if VoipConfig.isCallKitRestricted() { return false }
        return true
    }

    /// Auto-detect if the current region restricts CallKit (China)
    public static func isCallKitRestricted() -> Bool {
        if let regionCode = Locale.current.regionCode {
            return regionCode == "CN"
        }
        return false
    }

    public init(
        appName: String = "App",
        vibrate: Bool = true,
        callTimeout: Int = 30,
        supportsVideo: Bool = false,
        ringtoneName: String? = nil,
        iconTemplateName: String? = nil,
        disableCallKit: Bool = false,
        callIdKey: String = "call_id",
        callerNameKey: String = "caller_name",
        callerIdKey: String = "caller_id",
        callerAvatarKey: String = "caller_avatar",
        callTypeKey: String = "call_type"
    ) {
        self.appName = appName
        self.vibrate = vibrate
        self.callTimeout = callTimeout
        self.supportsVideo = supportsVideo
        self.ringtoneName = ringtoneName
        self.iconTemplateName = iconTemplateName
        self.disableCallKit = disableCallKit
        self.callIdKey = callIdKey
        self.callerNameKey = callerNameKey
        self.callerIdKey = callerIdKey
        self.callerAvatarKey = callerAvatarKey
        self.callTypeKey = callTypeKey
    }

    /// Create config from dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> VoipConfig {
        return VoipConfig(
            appName: dict["appName"] as? String ?? "App",
            vibrate: dict["vibrate"] as? Bool ?? true,
            callTimeout: dict["callTimeout"] as? Int ?? 30,
            supportsVideo: dict["supportsVideo"] as? Bool ?? false,
            ringtoneName: dict["ringtoneName"] as? String,
            iconTemplateName: dict["iconTemplateName"] as? String,
            disableCallKit: dict["disableCallKit"] as? Bool ?? false,
            callIdKey: dict["callIdKey"] as? String ?? "call_id",
            callerNameKey: dict["callerNameKey"] as? String ?? "caller_name",
            callerIdKey: dict["callerIdKey"] as? String ?? "caller_id",
            callerAvatarKey: dict["callerAvatarKey"] as? String ?? "caller_avatar",
            callTypeKey: dict["callTypeKey"] as? String ?? "call_type"
        )
    }
}
