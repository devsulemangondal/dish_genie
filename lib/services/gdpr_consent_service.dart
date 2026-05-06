import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GdprConsentService {
  static const MethodChannel _channel = MethodChannel(
    'com.dishgenie.recipeapp/gdpr_consent',
  );

  static bool _didGather = false;
  static bool _canRequestAds = true;

  static bool get canRequestAds => _canRequestAds;

  /// Gathers consent (Android UMP). Safe to call multiple times.
  /// Returns whether ads can be requested afterward.
  static Future<bool> gatherConsentIfRequired() async {
    if (!Platform.isAndroid) return true;
    if (_didGather) return _canRequestAds;

    try {
      final res = await _channel.invokeMethod<dynamic>('gatherConsent');
      final map = (res is Map) ? res : const {};
      final can = map['canRequestAds'];
      _canRequestAds = can is bool ? can : true;

      if (kDebugMode) {
        final errCode = map['errorCode'];
        final errMsg = map['errorMessage'];
        debugPrint(
          '[GDPR] gatherConsent done canRequestAds=$_canRequestAds error=$errCode $errMsg',
        );
      }
    } catch (e) {
      // Fail closed: if consent flow is broken, we must not request ads.
      if (kDebugMode) {
        debugPrint('[GDPR] gatherConsent exception: $e');
      }
      _canRequestAds = false;
    } finally {
      _didGather = true;
    }

    return _canRequestAds;
  }

  /// Opens privacy options UI if required (Android UMP).
  static Future<void> showPrivacyOptionsForm() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<dynamic>('showPrivacyOptionsForm');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GDPR] showPrivacyOptionsForm exception: $e');
      }
    }
  }

  /// Resets consent state (Android UMP). Useful for testing in debug mode.
  static Future<void> resetForDebug() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<dynamic>('resetConsent');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GDPR] resetForDebug exception: $e');
      }
    } finally {
      _didGather = false;
      _canRequestAds = true;
    }
  }
}
