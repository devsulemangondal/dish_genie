import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/theme/colors.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';

/// Consistent horizontal padding for native ads throughout the app
const double _kNativeAdHorizontalPadding = 16.0;

/// Custom styled native ad widget that matches app design
/// Similar to XML-based native ads in Ummah pro
enum CustomNativeAdSize {
  small, // Compact card design
  medium, // Larger card with more details
}

class CustomNativeAdWidget extends StatefulWidget {
  final CustomNativeAdSize size;
  final String screenKey; // Required: 'home', 'recipe', 'plan', etc.
  final double? width;
  final double? height;

  const CustomNativeAdWidget({
    super.key,
    required this.size,
    required this.screenKey,
    this.width,
    this.height,
  });

  const CustomNativeAdWidget.small({
    super.key,
    required this.screenKey,
    this.width,
    this.height,
  }) : size = CustomNativeAdSize.small;

  const CustomNativeAdWidget.medium({
    super.key,
    required this.screenKey,
    this.width,
    this.height,
  }) : size = CustomNativeAdSize.medium;

  @override
  State<CustomNativeAdWidget> createState() => _CustomNativeAdWidgetState();
}

class _CustomNativeAdWidgetState extends State<CustomNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _isInternetAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAd();
  }

  Future<void> _checkAndLoadAd() async {
    // Check specific remote config for this screen FIRST (before any loading)
    try {
      await RemoteConfigService.initialize();
      bool shouldShow = false;
      
      switch (widget.screenKey) {
        case 'language':
          shouldShow = RemoteConfigService.languageNative;
          break;
        case 'home':
          shouldShow = RemoteConfigService.homeNative;
          break;
        case 'recipe':
          shouldShow = RemoteConfigService.recipeNative;
          break;
        case 'plan':
          shouldShow = RemoteConfigService.planNative;
          break;
        case 'shop':
          shouldShow = RemoteConfigService.shopNative;
          break;
        case 'chat':
          shouldShow = RemoteConfigService.chatNative;
          break;
        case 'recipeDetail':
          shouldShow = RemoteConfigService.recipeDetailNative;
          break;
        case 'camera':
          shouldShow = RemoteConfigService.cameraNative;
          break;
        default:
          shouldShow = RemoteConfigService.showAds;
      }
      
      // If config says no ads, don't load or show loading
      if (!shouldShow) {
        return;
      }
    } catch (e) {
      // If remote config fails, don't show ads (fail safe)
      return;
    }

    // Check internet connectivity (simple check via try-catch)
    _isInternetAvailable = true; // Will be handled by ad loading

    if (_isInternetAvailable) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

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
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAdLoaded = false;
                });
              }
            },
          );
          break;
        default:
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAdLoaded = false;
            });
          }
          return;
      }

      if (ad != null && mounted && !_isAdLoaded) {
        setState(() {
          _nativeAd = ad;
        });
      }
    } catch (e) {
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
    // Note: Don't dispose here as the ad might be reused
    // AdService manages the lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if ads should be shown
    if (!AdService.showAds || !_isInternetAvailable) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return _buildLoadingPlaceholder();
    }

    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Use custom template style for Android (like XML layout)
    if (Platform.isAndroid) {
      return _buildAndroidNativeAd();
    } else {
      // For iOS, use default style wrapped in custom container
      return _buildIOSNativeAd();
    }
  }

  Widget _buildAndroidNativeAd() {
    // For Android, wrap AdWidget in styled container matching app design
    // The AdWidget will use Google's default template styled by our container
    final adSize = widget.size == CustomNativeAdSize.small
        ? AdSize(width: 300, height: 90)
        : AdSize(width: 300, height: 160);

    final screenWidth = MediaQuery.of(context).size.width;
    final defaultWidth = screenWidth - (_kNativeAdHorizontalPadding * 2);

    return Container(
      width: widget.width ?? defaultWidth,
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
          width: widget.width ?? adSize.width.toDouble(),
          height: widget.height ?? adSize.height.toDouble(),
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }

  Widget _buildIOSNativeAd() {
    // For iOS, wrap default AdWidget in custom container matching app design
    final adSize = widget.size == CustomNativeAdSize.small
        ? AdSize(width: 300, height: 90)
        : AdSize(width: 300, height: 160);

    final screenWidth = MediaQuery.of(context).size.width;
    final defaultWidth = screenWidth - (_kNativeAdHorizontalPadding * 2);

    return Container(
      width: widget.width ?? defaultWidth,
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
          width: widget.width ?? adSize.width.toDouble(),
          height: widget.height ?? adSize.height.toDouble(),
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    if (!_isInternetAvailable) {
      return const SizedBox.shrink();
    }

    final height = widget.height ?? 
        (widget.size == CustomNativeAdSize.small ? 90.0 : 160.0);

    final screenWidth = MediaQuery.of(context).size.width;
    final defaultWidth = screenWidth - (_kNativeAdHorizontalPadding * 2);

    return Container(
      width: widget.width ?? defaultWidth,
      height: height,
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
