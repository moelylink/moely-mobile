import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "link.moely.mobile/app_info",
                                              binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getStorageSpace" {
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()) {
          let totalSpace = attrs[.systemSize] as? Int64 ?? 0
          let freeSpace = attrs[.systemFreeSize] as? Int64 ?? 0
          result([
            "totalSpace": totalSpace,
            "freeSpace": freeSpace
          ])
        } else {
          result(FlutterError(code: "ERROR", message: "Failed to get disk space attributes", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
