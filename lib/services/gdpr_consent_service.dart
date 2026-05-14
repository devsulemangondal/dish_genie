import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR / AdMob UMP consent via [google_mobile_ads] (Android + iOS).
///
/// **Debug / iOS:** Google only applies [DebugGeography.debugGeographyEea] on
/// *registered test devices*. Pass your hashed ID from the Xcode console, e.g.:
/// `flutter run --dart-define=UMP_TEST_DEVICE_IDS=YOUR_HASH_HERE`
/// (comma-separated for multiple devices). Without this, UMP often reports
/// `notRequired` and `canRequestAds=true` with **no UI** even in debug.
///
/// Also publish a **Privacy & messaging** message in AdMob for this app ID,
/// or no form asset exists to show.
class GdprConsentService {
  static bool _didGather = false;
  static bool _canRequestAds = true;

  static bool get canRequestAds => _canRequestAds;

  static bool get _isMobile =>
      Platform.isAndroid || Platform.isIOS;

  /// Comma-separated UMP test device hashes (from Xcode / logcat).
  static const String _umpTestDeviceIdsFromEnv = String.fromEnvironment(
    'UMP_TEST_DEVICE_IDS',
    defaultValue: '',
  );

  static List<String> _parsedEnvTestDeviceIds() {
    if (_umpTestDeviceIdsFromEnv.isEmpty) return const [];
    return _umpTestDeviceIdsFromEnv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Google’s sample hashed id for the **Android** emulator (UMP docs).
  static const String _androidEmulatorUmpSampleId =
      'B3EEABB8EE11C2BE770B684D95219EFB';

  static ConsentRequestParameters _consentRequestParameters() {
    if (!kDebugMode || !_isMobile) {
      return ConsentRequestParameters();
    }

    final fromEnv = _parsedEnvTestDeviceIds();
    final List<String> testIds;
    if (fromEnv.isNotEmpty) {
      testIds = List<String>.from(fromEnv);
    } else if (Platform.isAndroid) {
      testIds = const [_androidEmulatorUmpSampleId];
    } else {
      testIds = const [];
      debugPrint(
        '[GDPR] iOS debug: set --dart-define=UMP_TEST_DEVICE_IDS=<hash from '
        'Xcode logs> or forced EEA/debug may be ignored and no form will show.',
      );
    }

    final ConsentDebugSettings debugSettings = testIds.isEmpty
        ? ConsentDebugSettings(
            debugGeography: DebugGeography.debugGeographyEea,
          )
        : ConsentDebugSettings(
            debugGeography: DebugGeography.debugGeographyEea,
            testIdentifiers: testIds,
          );

    return ConsentRequestParameters(consentDebugSettings: debugSettings);
  }

  static Future<void> _logUmpState(String phase) async {
    if (!kDebugMode || !_isMobile) return;
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      final avail = await ConsentInformation.instance.isConsentFormAvailable();
      final privacy =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      final can = await ConsentInformation.instance.canRequestAds();
      debugPrint(
        '[GDPR] $phase status=$status formAvailable=$avail '
        'privacy=$privacy canRequestAds=$can',
      );
    } catch (e) {
      debugPrint('[GDPR] $phase diag error: $e');
    }
  }

  /// Second chance on iOS debug: present a loaded form if the SDK has one.
  static Future<void> _maybePresentExplicitIosDebugForm() async {
    if (!kDebugMode || !Platform.isIOS) return;
    try {
      final available =
          await ConsentInformation.instance.isConsentFormAvailable();
      if (!available) return;

      final done = Completer<void>();
      ConsentForm.loadConsentForm(
        (ConsentForm form) {
          form.show((FormError? err) {
            if (err != null) {
              debugPrint('[GDPR] explicit form: ${err.message}');
            }
            if (!done.isCompleted) done.complete();
          });
        },
        (FormError err) {
          debugPrint('[GDPR] loadConsentForm: ${err.message}');
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 60), onTimeout: () {
        debugPrint('[GDPR] explicit form wait timed out');
      });
    } catch (e) {
      debugPrint('[GDPR] explicit iOS form: $e');
    }
  }

  /// Gathers consent (UMP). Safe to call multiple times.
  /// Returns whether ads can be requested afterward.
  static Future<bool> gatherConsentIfRequired() async {
    if (!_isMobile) return true;
    if (_didGather) return _canRequestAds;

    try {
      if (Platform.isIOS) {
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      if (kDebugMode) {
        await _logUmpState('before requestConsentInfoUpdate');
      }

      final params = _consentRequestParameters();
      final done = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          } finally {
            if (!done.isCompleted) done.complete();
          }
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );

      await done.future;

      if (kDebugMode) {
        await _logUmpState('after loadAndShowConsentFormIfRequired');
      }

      if (kDebugMode && Platform.isIOS) {
        await _maybePresentExplicitIosDebugForm();
        await _logUmpState('after explicit iOS debug form attempt');
      }

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
