import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../config/ad_config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/premium_provider.dart';
import '../../services/ad_service.dart';

/// Small native strip when the bottom anchored banner fails.
/// Android: `bottomNativeAd` factory + `custom_bottom_native_ad` (Ummah Pro bottom_native).
/// iOS: Flutter small template, same 74px clip and chrome as the Android bar.
class BottomNativeFallbackAdWidget extends StatefulWidget {
  const BottomNativeFallbackAdWidget({super.key});

  @override
  State<BottomNativeFallbackAdWidget> createState() =>
      _BottomNativeFallbackAdWidgetState();
}

class _BottomNativeFallbackAdWidgetState
    extends State<BottomNativeFallbackAdWidget> {
  static const double _adHeight = 74.0;
  static const EdgeInsets _containerMargin = EdgeInsets.only(top: 2);

  NativeAd? _nativeAd;
  bool _isLoading = true;
  bool _shouldShow = true;
  String? _adResponseId;
  int _adInstanceId = 0;
  Timer? _timeoutWatchdog;

  static int get _loadTimeoutSeconds => kReleaseMode ? 20 : 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  @override
  void dispose() {
    _timeoutWatchdog?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    if (_nativeAd != null) return;

    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      if (mounted) {
        setState(() {
          _shouldShow = false;
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    bool isPremium = false;
    try {
      isPremium =
          Provider.of<PremiumProvider>(context, listen: false).isPremium;
    } catch (_) {
      isPremium = false;
    }
    if (isPremium) {
      if (mounted) {
        setState(() {
          _shouldShow = false;
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    await AdService.initialize();

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final completer = Completer<void>();
    var settled = false;
    NativeAd? created;

    bool markSettled() {
      if (settled) return false;
      settled = true;
      return true;
    }

    _timeoutWatchdog?.cancel();
    _timeoutWatchdog = Timer(Duration(seconds: _loadTimeoutSeconds), () {
      if (!markSettled()) return;
      created?.dispose();
      if (!completer.isCompleted) completer.complete();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shouldShow = false;
        });
      }
    });

    try {
      if (Platform.isAndroid) {
        created = NativeAd(
          adUnitId: AdService.bottomNativeAdUnitId,
          factoryId: 'bottomNativeAd',
          request: const AdRequest(),
          nativeAdOptions: NativeAdOptions(
            videoOptions: VideoOptions(
              startMuted: true,
              clickToExpandRequested: false,
            ),
            adChoicesPlacement: AdChoicesPlacement.topRightCorner,
            mediaAspectRatio: MediaAspectRatio.any,
          ),
          listener: NativeAdListener(
            onAdLoaded: (ad) {
              _timeoutWatchdog?.cancel();
              if (!markSettled()) {
                ad.dispose();
                return;
              }
              if (!completer.isCompleted) completer.complete();
              if (mounted) {
                setState(() {
                  _nativeAd?.dispose();
                  _nativeAd = ad as NativeAd;
                  _adResponseId = ad.responseInfo?.responseId ?? 'loaded';
                  _adInstanceId++;
                  _isLoading = false;
                  _shouldShow = true;
                });
              }
            },
            onAdFailedToLoad: (ad, error) {
              _timeoutWatchdog?.cancel();
              if (kDebugMode) {
                debugPrint(
                  '❌ [BottomNativeFallback] failed: ${error.code} ${error.message}',
                );
              }
              ad.dispose();
              if (markSettled() && !completer.isCompleted) {
                completer.complete();
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _shouldShow = false;
                });
              }
            },
          ),
        );
      } else {
        created = NativeAd(
          adUnitId: AdService.bottomNativeAdUnitId,
          request: const AdRequest(),
          nativeTemplateStyle: NativeTemplateStyle(
            templateType: TemplateType.small,
            mainBackgroundColor: Colors.transparent,
            cornerRadius: 0.0,
            callToActionTextStyle: NativeTemplateTextStyle(
              textColor: Colors.white,
              backgroundColor: const Color(0xFF10B981),
              size: 13.0,
              style: NativeTemplateFontStyle.bold,
            ),
            primaryTextStyle: NativeTemplateTextStyle(
              textColor: isDark ? Colors.grey.shade200 : Colors.black87,
              backgroundColor: Colors.transparent,
              size: 15.0,
              style: NativeTemplateFontStyle.bold,
            ),
            secondaryTextStyle: NativeTemplateTextStyle(
              textColor: isDark ? Colors.grey.shade400 : Colors.black54,
              backgroundColor: Colors.transparent,
              size: 12.0,
              style: NativeTemplateFontStyle.normal,
            ),
            tertiaryTextStyle: NativeTemplateTextStyle(
              textColor: isDark ? Colors.grey.shade500 : Colors.black45,
              backgroundColor: Colors.transparent,
              size: 11.0,
              style: NativeTemplateFontStyle.normal,
            ),
          ),
          nativeAdOptions: NativeAdOptions(
            videoOptions: VideoOptions(
              startMuted: true,
              clickToExpandRequested: false,
            ),
            adChoicesPlacement: AdChoicesPlacement.topRightCorner,
            mediaAspectRatio: MediaAspectRatio.any,
          ),
          listener: NativeAdListener(
            onAdLoaded: (ad) {
              _timeoutWatchdog?.cancel();
              if (!markSettled()) {
                ad.dispose();
                return;
              }
              if (!completer.isCompleted) completer.complete();
              if (mounted) {
                setState(() {
                  _nativeAd?.dispose();
                  _nativeAd = ad as NativeAd;
                  _adResponseId = ad.responseInfo?.responseId ?? 'loaded';
                  _adInstanceId++;
                  _isLoading = false;
                  _shouldShow = true;
                });
              }
            },
            onAdFailedToLoad: (ad, error) {
              _timeoutWatchdog?.cancel();
              if (kDebugMode) {
                debugPrint(
                  '❌ [BottomNativeFallback] iOS failed: ${error.code} ${error.message}',
                );
              }
              ad.dispose();
              if (markSettled() && !completer.isCompleted) {
                completer.complete();
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _shouldShow = false;
                });
              }
            },
          ),
        );
      }

      created.load();
      await completer.future;
    } catch (e, st) {
      _timeoutWatchdog?.cancel();
      if (kDebugMode) {
        debugPrint('❌ [BottomNativeFallback] exception: $e\n$st');
      }
      if (markSettled()) {
        created?.dispose();
      }
      if (!completer.isCompleted) completer.complete();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shouldShow = false;
        });
      }
    }
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? theme.colorScheme.surface : Colors.white;
    final loadingText =
        AppLocalizations.of(context)?.adLoading ?? 'Ad Loading...';

    return Container(
      width: double.infinity,
      height: _adHeight,
      margin: _containerMargin,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.22),
            width: 1.6,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          loadingText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildAdChrome(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? theme.colorScheme.surface : Colors.white;

    return Container(
      width: double.infinity,
      margin: _containerMargin,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.22),
            width: 1.6,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRect(
        child: SizedBox(
          height: _adHeight,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return _buildSkeletonLoader(context);
    }

    if (_nativeAd == null) {
      return const SizedBox.shrink();
    }

    final stableKey = _adResponseId ?? 'unknown';
    final uniqueKey =
        'bottom_native_${Platform.operatingSystem}_${stableKey}_$_adInstanceId';

    return _buildAdChrome(
      context,
      SizedBox.expand(
        child: AdWidget(ad: _nativeAd!, key: ValueKey(uniqueKey)),
      ),
    );
  }
}
