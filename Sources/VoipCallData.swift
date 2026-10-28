import Foundation

/// Represents an incoming VoIP call
public struct VoipCallData {
    /// Unique call identifier
    public let callId: String
    /// Name of the caller
    public let callerName: String
    /// Caller's user ID (optional)
    public let callerId: String?
    /// Avatar URL of the caller (optional)
    public let callerAvatar: String?
    /// Type of call: "audio" or "video"
    public let callType: String
    /// Additional data from push payload
    public let payload: [String: Any]?
    /// Timestamp when call was received (milliseconds)
    public let timestamp: TimeInterval

    public init(
        callId: String,
        callerName: String,
        callerId: String? = nil,
        callerAvatar: String? = nil,
        callType: String = "audio",
        payload: [String: Any]? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970 * 1000
    ) {
        self.callId = callId
        self.callerName = callerName
        self.callerId = callerId
        self.callerAvatar = callerAvatar
        self.callType = callType
        self.payload = payload
        self.timestamp = timestamp
    }

    /// Create from push payload dictionary
    public static func fromPayload(_ payload: [AnyHashable: Any], config: VoipConfig) -> VoipCallData? {
        // Try top-level first, then check nested "data" dictionary
        let effectivePayload: [AnyHashable: Any]
        if payload[config.callIdKey] != nil || payload[config.callerNameKey] != nil {
            effectivePayload = payload
        } else if let nested = payload["data"] as? [AnyHashable: Any] {
            effectivePayload = nested
        } else {
            effectivePayload = payload
        }

        let callId = effectivePayload[config.callIdKey] as? String
            ?? effectivePayload["callId"] as? String
            ?? UUID().uuidString
        let callerName = effectivePayload[config.callerNameKey] as? String
            ?? effectivePayload["callerName"] as? String
            ?? "Unknown"
        let callerId = effectivePayload[config.callerIdKey] as? String
            ?? effectivePayload["callerId"] as? String
        let callerAvatar = effectivePayload[config.callerAvatarKey] as? String
            ?? effectivePayload["callerAvatar"] as? String
        let callType = effectivePayload[config.callTypeKey] as? String
            ?? effectivePayload["callType"] as? String
            ?? "audio"

        // Convert payload to [String: Any]
        var payloadDict: [String: Any] = [:]
        for (key, value) in payload {
            if let keyStr = key as? String {
                payloadDict[keyStr] = value
            }
        }

        return VoipCallData(
            callId: callId,
            callerName: callerName,
            callerId: callerId,
            callerAvatar: callerAvatar,
            callType: callType,
            payload: payloadDict
        )
    }

    /// Convert to dictionary for bridge communication
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "callId": callId,
            "callerName": callerName,
            "callType": callType,
            "timestamp": timestamp
        ]
        if let callerId = callerId {
            dict["callerId"] = callerId
        }
        if let callerAvatar = callerAvatar {
            dict["callerAvatar"] = callerAvatar
        }
        if let payload = payload {
            dict["payload"] = payload
        }
        return dict
    }
}
