import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Central service for Firebase Analytics. Use it to log screen views and custom events
/// so they appear in the Firebase Console (Analytics).
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Use this instance for observers (e.g. [FirebaseAnalyticsObserver]).
  static FirebaseAnalytics get instance => _analytics;

  /// Log a screen view. Shown in Firebase Analytics > Events > screen_view.
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      if (kDebugMode) {
        print('📊 [Analytics] screen_view sent: screenName=$screenName screenClass=$screenClass');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('📊 [Analytics] screen_view FAILED: $e');
        print('   $st');
      }
    }
  }

  /// Log a custom event. Shown in Firebase Analytics > Events.
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (kDebugMode) {
        print('📊 [Analytics] event sent: name=$name parameters=$parameters');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('📊 [Analytics] event FAILED: name=$name error=$e');
        print('   $st');
      }
    }
  }

  /// Log that the user signed in (optional; use if you add auth).
  static Future<void> logLogin({String? loginMethod}) async {
    try {
      await _analytics.logLogin(loginMethod: loginMethod);
      if (kDebugMode) {
        print('📊 [Analytics] log_login sent: loginMethod=$loginMethod');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('📊 [Analytics] log_login FAILED: $e');
        print('   $st');
      }
    }
  }

  /// Set whether analytics collection is enabled (e.g. respect user privacy).
  static Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }
}
