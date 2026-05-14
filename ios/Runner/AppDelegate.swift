import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let nativeAdFactory = NativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "mediumAd",
      nativeAdFactory: nativeAdFactory
    )
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "smallAd",
      nativeAdFactory: nativeAdFactory
    )

    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // google_mobile_ads UMP presents using FlutterAppDelegate.window; keep it
    // in sync with the key window from the active scene (avoids nil root on some iOS versions).
    if window == nil {
      if #available(iOS 13.0, *) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
          if let w = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            window = w
            break
          }
        }
      }
    }
    return ok
  }
}
