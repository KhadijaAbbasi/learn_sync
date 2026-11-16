import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "learnsync/live_lockdown",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "enable":
        UIApplication.shared.isIdleTimerDisabled = true
        result([
          "keepScreenOn": true,
          "secure": false,
          "screenPinning": false,
          "dnd": false,
          "needsDndPermission": false,
          "platform": "ios",
          "note":
            "iOS cannot pin this app, silence calls, or block notifications "
            + "from a normal App Store app. Keep-screen-on is enabled. For a "
            + "stronger lockdown, the student can turn on Guided Access "
            + "(Settings > Accessibility > Guided Access) while attending.",
        ])
      case "disable":
        UIApplication.shared.isIdleTimerDisabled = false
        result(nil)
      case "openNotificationPolicySettings":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
