import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR / AdMob UMP consent via [google_mobile_ads] (Android + iOS).
///
/// In [kDebugMode], consent is requested as if the device were in the EEA so
/// the form is easy to test. Release builds use normal geography.
class GdprConsentService {
  static bool _didGather = false;
  static bool _canRequestAds = true;

  static bool get canRequestAds => _canRequestAds;

  static bool get _isMobile =>
      Platform.isAndroid || Platform.isIOS;

  static ConsentRequestParameters _consentRequestParameters() {
    if (kDebugMode && _isMobile) {
      return ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
        ),
      );
    }
    return ConsentRequestParameters();
  }

  /// Gathers consent (UMP). Safe to call multiple times.
  /// Returns whether ads can be requested afterward.
  static Future<bool> gatherConsentIfRequired() async {
    if (!_isMobile) return true;
    if (_didGather) return _canRequestAds;

    try {
      final params = _consentRequestParameters();
      final done = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          Future.microtask(() async {
            try {
              await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
            } finally {
              if (!done.isCompleted) done.complete();
            }
          });
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );

      await done.future;
      _canRequestAds = await ConsentInformation.instance.canRequestAds();

      if (kDebugMode) {
        debugPrint('[GDPR] gatherConsent done canRequestAds=$_canRequestAds');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GDPR] gatherConsent exception: $e');
      }
      _canRequestAds = false;
    } finally {
      _didGather = true;
    }

    return _canRequestAds;
  }

  /// Opens the UMP privacy options form when supported.
  static Future<void> showPrivacyOptionsForm() async {
    if (!_isMobile) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GDPR] showPrivacyOptionsForm exception: $e');
      }
    }
  }

  /// Resets UMP state. Intended for testing only.
  static Future<void> resetForDebug() async {
    if (!_isMobile) return;
    try {
      await ConsentInformation.instance.reset();
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
