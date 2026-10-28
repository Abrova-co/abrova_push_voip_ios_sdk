Pod::Spec.new do |s|
  s.name             = 'AbrovaPushVoip'
  s.version          = '0.1.2'
  s.summary          = 'Abrova Push VoIP SDK for iOS with CallKit support'
  s.description      = <<-DESC
    Abrova Push VoIP SDK provides native incoming call UI for iOS using CallKit.
    Features:
    - Native CallKit integration
    - PushKit VoIP push handling
    - Customizable caller info display
    - Background call handling
    - China/restricted region fallback
  DESC

  s.homepage         = 'https://abrova.ir/cloud/abrova-push'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Abrova' => 'support@abrova.ir' }
  s.source           = { :git => 'https://github.com/Abrova-co/abrova_push_voip_ios_sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'Sources/**/*.swift'

  s.frameworks = 'UIKit', 'PushKit', 'CallKit', 'AVFoundation', 'UserNotifications'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
