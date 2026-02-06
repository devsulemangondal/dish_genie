/// Ad display configuration.
///
/// [showAdsOnIos]: When false, ads are not shown on iOS (Android always shows ads).
/// Set to true to enable ads on iOS.
class AdConfig {
  AdConfig._();

  /// When false: no ads on iOS. When true: show ads on iOS.
  /// Android always shows ads regardless of this value.
  static const bool showAdsOnIos = false;
}
