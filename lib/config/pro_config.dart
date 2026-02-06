/// Pro / IAP screen visibility configuration.
///
/// [showProOnIos]: When false, users on iOS cannot see the Pro (IAP) screen.
/// Set to true to show the Pro screen on iOS.
class ProConfig {
  ProConfig._();

  /// When false: Pro (IAP) screen is hidden on iOS. When true: Pro screen is shown on iOS.
  /// Android always shows the Pro screen regardless of this value.
  static const bool showProOnIos = false;
}
