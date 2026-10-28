import Foundation

/// Delegate protocol for AbrovaPushVoip SDK callbacks
public protocol AbrovaPushVoipDelegate: AnyObject {
    /// Called when user accepts an incoming call
    func voip(_ voip: AbrovaPushVoip, didAcceptCall callData: VoipCallData)

    /// Called when user declines an incoming call
    func voip(_ voip: AbrovaPushVoip, didDeclineCall callData: VoipCallData)

    /// Called when call times out (not answered)
    func voip(_ voip: AbrovaPushVoip, didTimeoutCall callData: VoipCallData)

    /// Called when an error occurs
    func voip(_ voip: AbrovaPushVoip, didFailWithError error: String)

    /// Called when an incoming call is received but CallKit is unavailable (e.g. China).
    /// The app should show its own custom incoming call UI.
    func voip(_ voip: AbrovaPushVoip, didReceiveIncomingCall callData: VoipCallData)
}

// Default implementations (optional methods)
public extension AbrovaPushVoipDelegate {
    func voip(_ voip: AbrovaPushVoip, didDeclineCall callData: VoipCallData) {}
    func voip(_ voip: AbrovaPushVoip, didTimeoutCall callData: VoipCallData) {}
    func voip(_ voip: AbrovaPushVoip, didFailWithError error: String) {}
    func voip(_ voip: AbrovaPushVoip, didReceiveIncomingCall callData: VoipCallData) {}
}
