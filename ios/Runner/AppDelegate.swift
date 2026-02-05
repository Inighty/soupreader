import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var originalBrightness: CGFloat?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "soupreader/screen_brightness",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
          return
        }

        switch call.method {
        case "setBrightness":
          if self.originalBrightness == nil {
            self.originalBrightness = UIScreen.main.brightness
          }
          guard
            let args = call.arguments as? [String: Any],
            let value = args["brightness"] as? Double
          else {
            result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing brightness", details: nil))
            return
          }
          let clamped = min(max(value, 0.0), 1.0)
          UIScreen.main.brightness = CGFloat(clamped)
          result(nil)

        case "resetBrightness":
          if let original = self.originalBrightness {
            UIScreen.main.brightness = original
            self.originalBrightness = nil
          }
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
