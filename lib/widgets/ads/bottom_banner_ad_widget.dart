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

/// Bottom banner ad shown above the bottom nav on bottom nav screens only.
/// Displays only when Remote Config bottom_banner (Android) or bottom_banner_ios (iOS) is true.
class BottomBannerAdWidget extends StatefulWidget {
  const BottomBannerAdWidget({super.key});

  @override
  State<BottomBannerAdWidget> createState() => _BottomBannerAdWidgetState();
}

class _BottomBannerAdWidgetState extends State<BottomBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShow = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  Future<void> _checkAndLoad() async {
    if (_isLoading) return;

    // Don't load on iOS if ads are disabled
    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      return;
    }

    // Check premium - don't show ads to premium users
    bool isPremium = false;
    await Future.microtask(() {
      try {
        final premiumProvider =
            Provider.of<PremiumProvider>(context, listen: false);
        isPremium = premiumProvider.isPremium;
      } catch (_) {
        isPremium = false;
      }
    });

    if (isPremium) return;

    // Check remote config - show only when key is true
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
      _isLoading = true;
    });

    await _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (!mounted) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );

    if (size == null || !mounted) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        },
      ),
    );

    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return _buildLoadingPlaceholder();
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

  Widget _buildLoadingPlaceholder() {
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
