import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/pro_config.dart';
import 'billing_service.dart';
import 'remote_config_service.dart';
import 'storage_service.dart';

/// After first-launch flow (language + onboarding), optionally open Pro before home when
/// Remote Config [splash_sub] / [splash_sub_ios] is true (and [weekly_sub] / [weekly_sub_ios] / premium / iOS Pro rules allow).
///
/// Returns `/pro?src=splash_sub_first` or `null` to go straight home.
Future<String?> splashSubProRouteBeforeHomeIfNeeded() async {
  try {
    await RemoteConfigService.initialize();
    await RemoteConfigService.fetchAndActivate().timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[SplashSubIapGate] RC fetch: $e');
    }
  }

  if (!(Platform.isIOS
      ? RemoteConfigService.weeklySubIos
      : RemoteConfigService.weeklySub)) {
    return null;
  }

  final gate = Platform.isIOS
      ? RemoteConfigService.splashSubIos
      : RemoteConfigService.splashSub;
  if (!gate) return null;

  if (await StorageService.getIsPremium() ||
      BillingService.hasPremiumEntitlement) {
    return null;
  }

  if (Platform.isIOS && !ProConfig.showProOnIos) return null;

  return '/pro?src=splash_sub_first';
}
