import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../config/ad_config.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import 'custom_native_ad_widget.dart';

/// Consistent horizontal padding for native ads throughout the app
/// Note: Set to 0 as parent containers now handle padding
const double _kNativeAdHorizontalPadding = 0.0;

/// Native ad widget that automatically loads the correct ad based on screen
/// and checks remote config before showing
class ScreenNativeAdWidget extends StatefulWidget {
  final String screenKey; // 'home', 'recipe', 'plan', etc.
  final CustomNativeAdSize size; // small or medium

  const ScreenNativeAdWidget({
    super.key,
    required this.screenKey,
    required this.size,
  });

  @override
  State<ScreenNativeAdWidget> createState() => _ScreenNativeAdWidgetState();
}

class _ScreenNativeAdWidgetState extends State<ScreenNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _shouldShowAd = false;

  @override
  void initState() {
    super.initState();
    _checkConfigAndLoadAd();
  }

  Future<void> _checkConfigAndLoadAd() async {
    // Don't load ads on iOS if ads are disabled
    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      _shouldShowAd = false;
      return;
    }

    // Check premium status first - premium users don't see ads
    // Use a microtask to ensure context is ready
    bool isPremium = false;
    await Future.microtask(() {
      try {
        final premiumProvider = Provider.of<PremiumProvider>(context, listen: false);
        isPremium = premiumProvider.isPremium;
      } catch (e) {
        // Provider might not be available yet, will check in build()
        // For now, assume not premium and proceed
        isPremium = false;
      }
    });

    if (isPremium) {
      _shouldShowAd = false;
      return;
    }

    // Check remote config
    try {
      await RemoteConfigService.initialize();
      _shouldShowAd = _getConfigValue();
    } catch (e) {
      _shouldShowAd = RemoteConfigService.showAds; // Fallback
    }

    if (!_shouldShowAd) {
      return;
    }

    _loadAd();
  }

  bool _getConfigValue() {
    switch (widget.screenKey) {
      case 'language':
        return RemoteConfigService.languageNative;
      case 'home':
        return RemoteConfigService.homeNative;
      case 'recipe':
        return RemoteConfigService.recipeNative;
      case 'plan':
        return RemoteConfigService.planNative;
      case 'shop':
        return RemoteConfigService.shopNative;
      case 'chat':
        return RemoteConfigService.chatNative;
      case 'recipeDetail':
        return RemoteConfigService.recipeDetailNative;
      case 'camera':
        return RemoteConfigService.cameraNative;
      default:
        return RemoteConfigService.showAds;
    }
  }

  Future<void> _loadAd() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isAdLoaded = false;
    });

    try {
      NativeAd? ad;
      
      // Load ad based on screen key
      switch (widget.screenKey) {
        case 'language':
          ad = await AdService.loadLanguageNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'home':
          ad = await AdService.loadHomeNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'recipe':
          ad = await AdService.loadRecipeNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'plan':
          ad = await AdService.loadPlanNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'shop':
          ad = await AdService.loadShopNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'chat':
          ad = await AdService.loadChatNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'recipeDetail':
          ad = await AdService.loadRecipeDetailNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        case 'camera':
          ad = await AdService.loadCameraNativeAd(
            onAdLoaded: (ad) {
              if (mounted) {
                setState(() {
                  _nativeAd = ad;
                  _isAdLoaded = true;
                  _isLoading = false;
                });
              }
            },
            onAdFailedToLoad: (error) {
              if (kDebugMode) {
                debugPrint(
                  '❌ [NativeAd:${widget.screenKey}] failed to load: ${error.code} ${error.message}',
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
      }

      if (ad != null && mounted && !_isAdLoaded) {
        setState(() {
          _nativeAd = ad;
        });
      } else if (ad == null && mounted) {
        // If the ad loader returned null (e.g., config/internet/premium gate inside AdService),
        // don't keep showing a loading placeholder forever.
        setState(() {
          _isLoading = false;
          _isAdLoaded = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [NativeAd:${widget.screenKey}] load exception: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAdLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Don't dispose here - AdService manages lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show ads on iOS if ads are disabled
    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      return const SizedBox.shrink();
    }

    // Check premium status - premium users don't see ads
    final premiumProvider = Provider.of<PremiumProvider>(context, listen: false);
    if (premiumProvider.isPremium) {
      return const SizedBox.shrink();
    }

    // Don't show if remote config says no
    if (!_shouldShowAd) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return _buildLoadingPlaceholder();
    }

    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Use the custom native ad widget for styling
    // Width will be constrained by parent padding, so we don't need to calculate it
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _kNativeAdHorizontalPadding,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: double.infinity,
          height: widget.size == CustomNativeAdSize.small ? 90.0 : 160.0,
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: double.infinity,
      height: widget.size == CustomNativeAdSize.small ? 90.0 : 160.0,
      margin: EdgeInsets.symmetric(
        horizontal: _kNativeAdHorizontalPadding,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
