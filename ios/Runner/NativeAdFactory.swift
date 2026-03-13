import UIKit
import GoogleMobileAds
import google_mobile_ads

/// Native ad factory for both mediumAd and smallAd layouts.
/// Uses the same view for both - container size is controlled by Flutter.
class NativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> GADNativeAdView? {
    guard let objects = Bundle.main.loadNibNamed(
      "NativeAdView",
      owner: nil,
      options: nil
    ) as? [Any],
          let adView = objects.first(where: { $0 is GADNativeAdView }) as? GADNativeAdView else {
      return nil
    }

    adView.headlineView = adView.viewWithTag(1)
    adView.bodyView = adView.viewWithTag(2)
    adView.mediaView = adView.viewWithTag(3) as? GADMediaView
    adView.callToActionView = adView.viewWithTag(4)
    adView.iconView = adView.viewWithTag(5)

    (adView.headlineView as? UILabel)?.text = nativeAd.headline

    if let bodyView = adView.bodyView as? UILabel {
      bodyView.text = nativeAd.body
      bodyView.isHidden = nativeAd.body == nil || nativeAd.body?.isEmpty == true
    }

    if let ctaView = adView.callToActionView as? UIButton {
      ctaView.setTitle(nativeAd.callToAction, for: .normal)
      ctaView.isHidden = nativeAd.callToAction == nil || nativeAd.callToAction?.isEmpty == true
      ctaView.isUserInteractionEnabled = false
    }

    if let iconView = adView.iconView as? UIImageView, let icon = nativeAd.icon {
      iconView.image = icon.image
      iconView.isHidden = false
    } else {
      adView.iconView?.isHidden = true
    }

    adView.nativeAd = nativeAd
    return adView
  }
}
