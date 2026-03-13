import UIKit
import GoogleMobileAds
import google_mobile_ads

/// Native ad factory for both mediumAd and smallAd layouts.
/// Creates view programmatically to avoid XIB loading issues.
class NativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = UIColor.systemBackground

    let mediaSize: CGFloat = 80
    let padding: CGFloat = 12

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.backgroundColor = UIColor.secondarySystemBackground
    adView.addSubview(mediaView)

    let headlineLabel = UILabel()
    headlineLabel.translatesAutoresizingMaskIntoConstraints = false
    headlineLabel.font = UIFont.boldSystemFont(ofSize: 16)
    headlineLabel.textColor = UIColor.label
    headlineLabel.numberOfLines = 1
    headlineLabel.lineBreakMode = .byTruncatingTail
    headlineLabel.text = nativeAd.headline
    adView.addSubview(headlineLabel)

    let bodyLabel = UILabel()
    bodyLabel.translatesAutoresizingMaskIntoConstraints = false
    bodyLabel.font = UIFont.systemFont(ofSize: 13)
    bodyLabel.textColor = UIColor.secondaryLabel
    bodyLabel.numberOfLines = 2
    bodyLabel.lineBreakMode = .byTruncatingTail
    bodyLabel.text = nativeAd.body ?? ""
    bodyLabel.isHidden = (nativeAd.body == nil || nativeAd.body?.isEmpty == true)
    adView.addSubview(bodyLabel)

    let ctaButton = UIButton(type: .system)
    ctaButton.translatesAutoresizingMaskIntoConstraints = false
    ctaButton.setTitle(nativeAd.callToAction ?? "Learn More", for: .normal)
    ctaButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
    ctaButton.backgroundColor = UIColor.systemBlue
    ctaButton.setTitleColor(.white, for: .normal)
    ctaButton.layer.cornerRadius = 8
    ctaButton.isUserInteractionEnabled = false
    ctaButton.isHidden = (nativeAd.callToAction == nil || nativeAd.callToAction?.isEmpty == true)
    adView.addSubview(ctaButton)

    adView.headlineView = headlineLabel
    adView.bodyView = bodyLabel
    adView.mediaView = mediaView
    adView.callToActionView = ctaButton
    if let icon = nativeAd.icon {
      let iconView = UIImageView(image: icon.image)
      iconView.translatesAutoresizingMaskIntoConstraints = false
      iconView.contentMode = .scaleAspectFit
      adView.addSubview(iconView)
      adView.iconView = iconView
      NSLayoutConstraint.activate([
        iconView.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
        iconView.centerYAnchor.constraint(equalTo: headlineLabel.centerYAnchor),
        iconView.widthAnchor.constraint(equalToConstant: 20),
        iconView.heightAnchor.constraint(equalToConstant: 20),
      ])
    }

    NSLayoutConstraint.activate([
      mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: padding),
      mediaView.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
      mediaView.widthAnchor.constraint(equalToConstant: mediaSize),
      mediaView.heightAnchor.constraint(equalToConstant: mediaSize),

      headlineLabel.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 12),
      headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -padding),
      headlineLabel.topAnchor.constraint(equalTo: mediaView.topAnchor),

      bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
      bodyLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
      bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),

      ctaButton.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
      ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 8),
      ctaButton.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor, constant: -padding),
      ctaButton.heightAnchor.constraint(equalToConstant: 36),
      ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
    ])

    adView.nativeAd = nativeAd
    return adView
  }
}
