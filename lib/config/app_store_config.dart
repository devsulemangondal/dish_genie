/// App Store / Play Store configuration for Rate Us and store links.
class AppStoreConfig {
  AppStoreConfig._();

  /// iOS App Store ID (numeric, e.g. 1234567890).
  /// Find it in App Store Connect → Your App → App Information.
  /// When set, Rate Us opens the direct app page instead of search.
  static const String? appStoreId = '6757077403';

  /// Direct App Store URL when appStoreId is set. Null otherwise.
  static String? get appStoreUrl => appStoreId != null
      ? 'https://apps.apple.com/app/id$appStoreId'
      : null;
}
