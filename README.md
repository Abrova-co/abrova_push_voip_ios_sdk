# AbrovaPush VoIP SDK for iOS

Native incoming call UI for iOS using CallKit and PushKit. Add real-time calling to your app with Abrova Push.

## Features

- Native CallKit incoming call screen
- PushKit VoIP push handling (wakes app even when killed)
- Customizable caller info (name, avatar, call type)
- Audio and video call support
- Flexible payload parsing (supports nested data, snake_case and camelCase keys)
- Call timeout handling
- China/restricted region fallback (local notification instead of CallKit)
- Custom ringtone support
- Cold start handling (app launched from incoming call)

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode capabilities: Push Notifications, Background Modes (Voice over IP, Remote notifications)

## Installation

The SDK is published on [Abrova Center](https://center.abrova.ir).

### CocoaPods

```ruby
pod 'AbrovaPushVoip', :git => 'https://center.abrova.ir/abrova/abrova-push-voip-ios-sdk.git', :tag => '0.1.2'
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://center.abrova.ir/abrova/abrova-push-voip-ios-sdk.git", from: "0.1.2")
]
```

## Quick Start

### 1. Configure

```swift
import AbrovaPushVoip

let config = VoipConfig(
    appName: "MyApp",
    supportsVideo: true,
    callTimeout: 30
)

AbrovaPushVoip.shared.initialize(config: config)
AbrovaPushVoip.shared.delegate = self
```

### 2. Register for VoIP Pushes

```swift
AbrovaPushVoip.shared.registerForVoIPPushes()
```

### 3. Handle PushKit in AppDelegate

```swift
import PushKit
import AbrovaPushVoip

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // Send VoIP token to your server
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        sendTokenToServer(token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                       for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }

        // SDK handles payload parsing and CallKit reporting
        AbrovaPushVoip.shared.handlePushPayload(payload.dictionaryPayload)
        completion()
    }
}
```

### 4. Handle Callbacks

```swift
extension AppDelegate: AbrovaPushVoipDelegate {
    func voip(_ voip: AbrovaPushVoip, didAcceptCall callData: VoipCallData) {
        // User accepted — connect to your calling service (Jitsi, WebRTC, etc.)
    }

    func voip(_ voip: AbrovaPushVoip, didDeclineCall callData: VoipCallData) {
        // User declined
    }

    func voip(_ voip: AbrovaPushVoip, didTimeoutCall callData: VoipCallData) {
        // Call timed out (no answer)
    }

    func voip(_ voip: AbrovaPushVoip, didReceiveIncomingCall callData: VoipCallData) {
        // CallKit unavailable (e.g., China) — show your own call UI
    }

    func voip(_ voip: AbrovaPushVoip, didFailWithError error: String) {
        print("VoIP error: \(error)")
    }
}
```

### 5. Manage Calls

```swift
// Report call as connected (after WebRTC/Jitsi connects)
AbrovaPushVoip.shared.reportCallConnected(callId: "call_123")

// End call
AbrovaPushVoip.shared.endCall(callId: "call_123")
```

## Configuration

```swift
let config = VoipConfig(
    appName: "MyApp",              // App name shown in CallKit UI
    vibrate: true,                  // Enable vibration on incoming call
    callTimeout: 30,                // Seconds before call times out
    supportsVideo: true,            // Enable video call support
    ringtoneName: "custom_ring",    // Custom ringtone file name (optional)
    iconTemplateName: "CallIcon",   // CallKit icon template (optional)
    disableCallKit: false,          // Force disable CallKit
    callIdKey: "call_id",           // Push payload key for call ID
    callerNameKey: "caller_name",   // Push payload key for caller name
    callerIdKey: "caller_id",       // Push payload key for caller ID
    callerAvatarKey: "caller_avatar", // Push payload key for avatar URL
    callTypeKey: "call_type"        // Push payload key for call type
)
```

## Push Payload

The SDK supports flexible payload formats. All of the following work:

**Flat payload (snake_case):**
```json
{
    "call_id": "unique_call_id",
    "caller_name": "John Doe",
    "call_type": "video"
}
```

**Flat payload (camelCase):**
```json
{
    "callId": "unique_call_id",
    "callerName": "John Doe",
    "callType": "video"
}
```

**Nested payload (from Abrova Push server):**
```json
{
    "title": "Incoming Call",
    "body": "John Doe is calling",
    "data": {
        "type": "voip_call",
        "callerName": "John Doe",
        "callerId": "user_456",
        "callType": "video"
    }
}
```

The `call_id` field is optional — a UUID is generated automatically if not provided. Payload keys are configurable via `VoipConfig`.

## Cold Start Handling

```swift
// Check if app was launched from a VoIP call
if let initialCall = AbrovaPushVoip.shared.getInitialCall() {
    showCallScreen(callData: initialCall)
    AbrovaPushVoip.shared.clearInitialCall()
}
```

## China/Restricted Regions

CallKit is restricted in China. The SDK automatically detects this and falls back to a local notification with Accept/Decline actions. Handle this in:

```swift
func voip(_ voip: AbrovaPushVoip, didReceiveIncomingCall callData: VoipCallData) {
    // Show your own incoming call UI (CallKit not available)
}
```

## Used With

This SDK works alongside [AbrovaPush SDK](https://github.com/Abrova-co/abrova_push_ios_sdk) for push delivery. To trigger a VoIP call, send a push with `data.type = "voip_call"` — the server routes it via PushKit instead of regular APNs.

## Links

- [Abrova Push](https://abrova.ir/cloud/abrova-push) - Learn more about Abrova Push
- [Documentation](https://abrova.ir/cloud/abrova-push/docs/voip) - VoIP documentation
- [Abrova Console](https://console.abrova.ir) - Manage your push notifications

## License

MIT License - see [LICENSE](LICENSE) for details.
