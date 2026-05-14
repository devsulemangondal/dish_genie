import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../config/ad_config.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import 'bottom_native_fallback_ad_widget.dart';

/// Compile-time: `flutter run --dart-define=FORCE_BOTTOM_BANNER_FAIL=true`
const bool _kForceBottomBannerFailFromDefine = bool.fromEnvironment(
  'FORCE_BOTTOM_BANNER_FAIL',
  defaultValue: false,
);

/// Bottom banner ad above the tab row. Use a stable [GlobalKey] on the main tab shell
/// so one [BannerAd] / [AdWidget] instance persists across tab switches (no reuse error).
class BottomBannerAdWidget extends StatefulWidget {
  const BottomBannerAdWidget({super.key});

  /// **Debug only** (ignored in release): set to `true` to skip loading the real banner
  /// and show the bottom native fallback immediately (Remote Config `bottom_native` is
  /// not required for this path). Flip back to `false` before shipping.
  ///
  /// Alternatively (debug): `flutter run --dart-define=FORCE_BOTTOM_BANNER_FAIL=true`.
  static const bool debugForceBannerFailShowNative = false;

  @override
  State<BottomBannerAdWidget> createState() => _BottomBannerAdWidgetState();
}

class _BottomBannerAdWidgetState extends State<BottomBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShow = false;
  bool _isLoading = false;
  bool _premiumListenerAttached = false;
  bool _useNativeFallback = false;
  bool _fallbackResolveInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<PremiumProvider>().addListener(_onPremiumChanged);
        _premiumListenerAttached = true;
      } catch (_) {}
      _checkAndLoad();
    });
  }

  @override
  void dispose() {
    if (_premiumListenerAttached) {
      try {
        context.read<PremiumProvider>().removeListener(_onPremiumChanged);
      } catch (_) {}
    }
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  void _onPremiumChanged() {
    final premium = context.read<PremiumProvider>().isPremium;
    if (premium) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      _shouldShow = false;
      _isLoading = false;
      _useNativeFallback = false;
    } else {
      _checkAndLoad();
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkAndLoad() async {
    if (_isLoading) return;

    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      if (mounted) {
        setState(() {
          _shouldShow = false;
        });
      }
      return;
    }

    if (!mounted) return;
    bool isPremium = false;
    try {
      isPremium = Provider.of<PremiumProvider>(
        context,
        listen: false,
      ).isPremium;
    } catch (_) {
      isPremium = false;
    }

    if (isPremium) return;

    try {
      await RemoteConfigService.initialize();
      _shouldShow = Platform.isIOS
          ? RemoteConfigService.bottomBannerIos
          : RemoteConfigService.bottomBanner;
    } catch (_) {
      _shouldShow = false;
    }

    if (!_shouldShow) return;

    if (!mounted) return;

    setState(() {
      _useNativeFallback = false;
      _isLoading = true;
    });

    if (kDebugMode &&
        (BottomBannerAdWidget.debugForceBannerFailShowNative ||
            _kForceBottomBannerFailFromDefine)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      await _tryNativeFallbackAfterBannerFail(force: true);
      return;
    }

    await _loadBanner();
  }

  Future<void> _tryNativeFallbackAfterBannerFail({bool force = false}) async {
    if (_fallbackResolveInFlight || _useNativeFallback) return;
    _fallbackResolveInFlight = true;
    try {
      if (!force) {
        try {
          await RemoteConfigService.fetchAndActivate();
        } catch (_) {}
      }
      if (!mounted) return;
      final allowNative = force ||
          (Platform.isIOS
              ? RemoteConfigService.bottomNativeIos
              : RemoteConfigService.bottomNative);
      if (!allowNative) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _useNativeFallback = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _bannerAd?.dispose();
          _bannerAd = null;
          _isLoaded = false;
          _isLoading = false;
          _useNativeFallback = true;
        });
      }
    } finally {
      _fallbackResolveInFlight = false;
    }
  }

  Future<void> _loadBanner() async {
    if (!mounted) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );

    if (size == null || !mounted) {
      await _tryNativeFallbackAfterBannerFail();
      return;
    }

    final banner = BannerAd(
      adUnitId: AdService.bottomBannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _bannerAd?.dispose();
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
              _isLoading = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          if (kDebugMode) {
            debugPrint(
              '❌ [BottomBannerAd] failed to load: ${err.code} ${err.message}',
            );
          }
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isLoaded = false;
            });
          }
          _tryNativeFallbackAfterBannerFail();
        },
      ),
    );

    banner.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_useNativeFallback) return;
    if (!_shouldShow || !_isLoaded || _bannerAd == null) return;
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (_bannerAd!.size.width.truncate() != w) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      _isLoading = false;
      _checkAndLoad();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    if (_useNativeFallback) {
      return const BottomNativeFallbackAdWidget();
    }

    if (_isLoading) {
      return _buildLoadingPlaceholder(context);
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }
}
