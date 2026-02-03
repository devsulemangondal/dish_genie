import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/localization/l10n_extension.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import '../../services/ad_service.dart';
import '../../services/billing_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/floating_sparkles.dart';
import 'dart:async';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  StreamSubscription? _purchaseSubscription;
  StreamSubscription? _billingErrorSubscription;
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  ProductDetails? _selectedProduct;

  String _getOpenSource() {
    // Prefer GoRouterState if available, otherwise parse from router location.
    try {
      final src = GoRouterState.of(context).uri.queryParameters['src'];
      if (src != null && src.isNotEmpty) return src;
    } catch (_) {}
    return 'manual';
  }

  @override
  void initState() {
    super.initState();
    _initializeBilling();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // If user is already premium, mark first launch as complete
    // This handles edge cases where premium users might reach this screen
    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );
    if (premiumProvider.isPremium) {
      await StorageService.setFirstLaunchComplete();
    }
  }

  Future<void> _initializeBilling() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      await BillingService.initialize();
      await BillingService.loadProducts();
    } catch (e) {
      // Error will be handled when user tries to purchase
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }

    // Listen to billing errors (for future use if needed)
    _billingErrorSubscription = BillingService.errorStream.listen((error) {
      // Error will be shown via snackbar when user tries to purchase
    });

    // Listen to purchase updates
    _purchaseSubscription = BillingService.purchaseStream.listen((purchase) {
      // Check if this purchase is for the selected product
      final isSelectedProduct = _selectedProduct != null && 
          purchase.productID == _selectedProduct!.id;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Keep loading state true while purchase is pending
          if (isSelectedProduct && mounted) {
            setState(() {
              _isLoading = true;
            });
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Clear loading and show success
          if (isSelectedProduct && mounted) {
            setState(() {
              _isLoading = false;
              _selectedProduct = null;
            });
            context.read<PremiumProvider>().setPremium(true);
            _showSuccessDialog();
          }
          break;
        case PurchaseStatus.error:
          // Clear loading and show error
          if (isSelectedProduct && mounted) {
            setState(() {
              _isLoading = false;
              _selectedProduct = null;
            });
            _showErrorDialog(
              purchase.error?.message ?? context.t('premiumPurchaseFailed'),
            );
          }
          break;
        case PurchaseStatus.canceled:
          // Clear loading when user cancels
          if (isSelectedProduct && mounted) {
            setState(() {
              _isLoading = false;
              _selectedProduct = null;
            });
          }
          break;
      }
    });

    if (mounted) {
      setState(() {});
    }
  }


  Future<void> _exitProFlow() async {
    // If user entered via push() (e.g., from settings), just pop back
    if (context.canPop()) {
      context.pop();
      return;
    }

    // Don't mark first launch complete here - it will be marked in language selection screen
    // This ensures the first launch flow completes: splash → pro → inter ad → language

    // Only show this "after Pro" interstitial for the splash funnel (first launch).
    final source = _getOpenSource();
    if (source != 'splash') {
      // For non-splash sources (e.g., from home, settings), just go back to home
      if (mounted) {
        context.go('/');
      }
      return;
    }

    // First launch flow: splash → pro → inter ad → language
    // Decide where to go after Pro (only for first launch)
    final isLanguageSelected = await StorageService.isLanguageSelected();
    if (!mounted) return;
    final nextRoute = isLanguageSelected ? '/' : '/language-selection';

    // Premium users never see ads; go directly.
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (isPremium) {
      if (mounted) {
        context.go(nextRoute);
      }
      return;
    }

    // Show interstitial (using existing "splash" interstitial placement) then navigate.
    try {
      await RemoteConfigService.initialize();
      final shouldShow =
          RemoteConfigService.showAds && RemoteConfigService.splashInter;
      if (!shouldShow) {
        if (mounted) {
          context.go(nextRoute);
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        context.go(nextRoute);
      }
      return;
    }

    // Show ad first, then navigate in callbacks
    bool hasNavigated = false;
    await AdService.showInterstitialAdForType(
      adType: 'splash',
      context: context,
      loadAdFunction: () => AdService.loadSplashInterstitialAd(),
      onAdDismissed: () {
        if (!hasNavigated && mounted) {
          hasNavigated = true;
          context.go(nextRoute);
        }
      },
      onAdFailedToShow: (ad) {
        if (!hasNavigated && mounted) {
          hasNavigated = true;
          context.go(nextRoute);
        }
      },
    );

    // Fallback: don't get stuck if ad never shows.
    Future.delayed(const Duration(seconds: 3), () {
      if (!hasNavigated && mounted) {
        hasNavigated = true;
        context.go(nextRoute);
      }
    });
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _billingErrorSubscription?.cancel();
    super.dispose();
  }

  void _showSuccessDialog() async {
    // Mark first launch as complete
    await StorageService.setFirstLaunchComplete();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          context.t('premium.success'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          context.t('premium.welcome.message'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (context.mounted) {
                context.go('/');
              }
            },
            child: Text(context.t('common.done')),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          context.t('common.error'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseProduct(ProductDetails product) async {
    if (_isLoading) return; // Prevent multiple simultaneous purchases

    setState(() {
      _isLoading = true;
      _selectedProduct = product;
    });

    try {
      final success = await BillingService.purchaseProduct(product);
      if (!success && mounted) {
        // Only clear loading if purchase initiation failed
        // If successful, loading will be cleared by purchase stream listener
        setState(() {
          _isLoading = false;
          _selectedProduct = null;
        });
        _showErrorDialog(context.t('premium.failed.to.initiate.purchase'));
      }
      // Don't clear loading here - wait for purchase stream to handle it
      // The purchase flow is asynchronous and handled via purchase stream
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedProduct = null;
        });
        _showErrorDialog(context.t('premium.error', {'error': e.toString()}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final products = BillingService.products;
    ProductDetails? weeklyProduct;

    // Get weekly subscription product from Play Store
    try {
      weeklyProduct = products.firstWhere(
        (p) => p.id == BillingService.weeklySubscriptionId,
      );
    } catch (e) {
      if (products.isNotEmpty) {
        // Fallback to first product if weekly not found
        weeklyProduct = products.first;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.getGradientHero(context),
            ),
          ),
          // Floating sparkles (matching other screens)
          const FloatingSparkles(),
          // Main content - Fixed layout, no scrolling
          Column(
            children: [
              // Top bar with cross button
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () async {
                          await _exitProFlow();
                        },
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenHeight = constraints.maxHeight;
                      final screenWidth = constraints.maxWidth;
                      final isSmallScreen = screenHeight < 700;
                      final availableHeight = screenHeight;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.05,
                          vertical: screenHeight * 0.015,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPremium) ...[
                              _buildPremiumBadge(),
                              SizedBox(height: availableHeight * 0.015),
                            ],
                            _buildHeroSection(screenWidth, availableHeight),
                            SizedBox(height: availableHeight * 0.015),
                            Expanded(
                              flex: isPremium ? 2 : 3,
                              child: _buildFeaturesListCompact(
                                screenWidth,
                                availableHeight,
                              ),
                            ),
                            SizedBox(height: availableHeight * 0.015),
                            if (!isPremium) ...[
                              // Price text with highlighted price
                              RichText(
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: isSmallScreen ? 13 : 15,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                  children: [
                                    TextSpan(
                                      text: weeklyProduct != null
                                          ? '${weeklyProduct.price}${context.t('premium.per.week')}'
                                          : '\$1.99${context.t('premium.per.week')}',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' ${context.t('premium.full.access')}',
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: availableHeight * 0.015),
                              if (weeklyProduct != null) ...[
                                _buildPurchaseButton(
                                  weeklyProduct,
                                  isPopular: true,
                                  screenHeight: availableHeight,
                                ),
                              ] else ...[
                                _buildDummyPurchaseButton(availableHeight),
                              ],
                            ],
                            SizedBox(height: availableHeight * 0.01),
                            _buildTermsAndPrivacyCompact(screenWidth),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPinkToPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: AppColors.primaryForeground,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Flexible(
            child: Text(
              context.t('premium.you.are.pro'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primaryForeground,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 16 : 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(double screenWidth, double availableHeight) {
    // Make crown larger and more responsive - use both dimensions
    final minDimension = screenWidth < availableHeight
        ? screenWidth
        : availableHeight;
    // Increase size to be more prominent and responsive
    final iconSize = (minDimension * 0.35).clamp(100.0, 150.0);
    final iconInnerSize = iconSize * 0.4;
    final titleSize = (availableHeight * 0.03).clamp(18.0, 22.0);
    final subtitleSize = (availableHeight * 0.02).clamp(12.0, 14.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: AppColors.gradientPinkToPurple,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(iconSize * 0.15),
            child: SvgPicture.asset(
              'assets/icons/material-symbols_crown-rounded.svg',
              width: iconInnerSize,
              height: iconInnerSize,
              colorFilter: ColorFilter.mode(
                AppColors.primaryForeground,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        SizedBox(height: availableHeight * 0.015),
        Text(
          context.t('premium.unlock.title'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: titleSize,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: availableHeight * 0.008),
        Text(
          context.t('premium.subtitle'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: subtitleSize,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFeaturesListCompact(double screenWidth, double availableHeight) {
    final features = _FeatureComparison._getFeatures(context);
    final isSmallScreen = screenWidth < 360;
    final isShortScreen = availableHeight < 700;
    final columnWidth = (screenWidth * 0.15).clamp(50.0, 70.0);
    final headerPadding = isSmallScreen ? 10.0 : (isShortScreen ? 12.0 : 14.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : (isShortScreen ? 12 : 14),
            vertical: headerPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t('premium.feature'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: isSmallScreen ? 10 : (isShortScreen ? 11 : 12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: columnWidth,
                child: Text(
                  context.t('premium.pro'),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: isSmallScreen ? 11 : (isShortScreen ? 12 : 13),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: columnWidth,
                child: Text(
                  context.t('premium.basic'),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: isSmallScreen ? 11 : (isShortScreen ? 12 : 13),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        // Features list - use Flexible to allow shrinking
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: features.length,
            itemBuilder: (context, index) {
              return _buildFeatureComparisonRow(
                features[index],
                index,
                features.length,
                screenWidth,
                columnWidth,
                availableHeight,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureComparisonRow(
    _FeatureComparison feature,
    int index,
    int totalFeatures,
    double screenWidth,
    double columnWidth,
    double availableHeight,
  ) {
    final isSmallScreen = screenWidth < 360;
    final isShortScreen = availableHeight < 700;
    final iconSize = isSmallScreen ? 26.0 : (isShortScreen ? 28.0 : 30.0);
    final iconInnerSize = isSmallScreen ? 14.0 : (isShortScreen ? 16.0 : 18.0);
    final checkSize = isSmallScreen ? 16.0 : (isShortScreen ? 18.0 : 20.0);
    final fontSize = isSmallScreen ? 12.0 : (isShortScreen ? 13.0 : 14.0);
    final rowPadding = isSmallScreen ? 8.0 : (isShortScreen ? 10.0 : 12.0);
    final isFirstRow = index == 0;
    final isLastRow = index == totalFeatures - 1;

    return Padding(
      padding: EdgeInsets.only(
        left: isSmallScreen ? 10 : (isShortScreen ? 12 : 14),
        right: isSmallScreen ? 10 : (isShortScreen ? 12 : 14),
        top: isFirstRow ? 0 : rowPadding,
        bottom: isLastRow ? 0 : rowPadding,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all((iconSize - iconInnerSize) / 2),
            child: SvgPicture.asset(
              feature.iconPath,
              width: iconInnerSize,
              height: iconInnerSize,
              colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : (isShortScreen ? 10 : 12)),
          // Feature name
          Expanded(
            child: Text(
              feature.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: fontSize,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // PRO indicator
          SizedBox(
            width: columnWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: feature.availableInPro
                  ? Icon(Icons.check, color: AppColors.primary, size: checkSize)
                  : Icon(
                      Icons.remove,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.3),
                      size: checkSize,
                    ),
            ),
          ),
          // Basic indicator
          SizedBox(
            width: columnWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: feature.availableInBasic
                  ? Icon(Icons.check, color: AppColors.primary, size: checkSize)
                  : Icon(
                      Icons.remove,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.3),
                      size: checkSize,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(
    ProductDetails product, {
    bool isPopular = false,
    required double screenHeight,
  }) {
    final isLoading = _isLoading && _selectedProduct?.id == product.id;
    final isSmallScreen = screenHeight < 700;
    final buttonPadding = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final fontSize = isSmallScreen ? 15.0 : 16.0;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _purchaseProduct(product),
        style:
            ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: buttonPadding),
                  backgroundColor: isPopular ? null : AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                )
                .copyWith(
                  backgroundColor: isPopular
                      ? MaterialStateProperty.all<Color>(Colors.transparent)
                      : null,
                )
                .copyWith(
                  overlayColor: MaterialStateProperty.all<Color>(
                    AppColors.primary.withOpacity(0.1),
                  ),
                ),
        child: isPopular
            ? Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPinkToPurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.symmetric(vertical: buttonPadding),
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryForeground,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            color: AppColors.primaryForeground,
                            size: iconSize,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.t('premium.subscribe.now'),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.primaryForeground,
                                    fontWeight: FontWeight.bold,
                                    fontSize: fontSize,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              )
            : isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryForeground,
                  ),
                ),
              )
            : Text(
                context.t('premium.subscribe.now'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('common.could.not.open.url', {'url': url})),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Widget _buildDummyPurchaseButton(double screenHeight) {
    final isSmallScreen = screenHeight < 700;
    final buttonPadding = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final fontSize = isSmallScreen ? 15.0 : 16.0;

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientPinkToPurple,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: () async {
            // Try to load products first
            setState(() {
              _isLoadingProducts = true;
            });

            final success = await BillingService.loadProducts(retry: true);
            
            if (mounted) {
              setState(() {
                _isLoadingProducts = false;
              });

              if (!success) {
                // Show snackbar with error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      BillingService.lastError ?? context.t('premium.subscription.loading'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    backgroundColor: Theme.of(context).cardColor,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else {
                // Products loaded successfully, try to get the product and purchase
                final products = BillingService.products;
                ProductDetails? weeklyProduct;
                
                try {
                  weeklyProduct = products.firstWhere(
                    (p) => p.id == BillingService.weeklySubscriptionId,
                  );
                } catch (e) {
                  if (products.isNotEmpty) {
                    weeklyProduct = products.first;
                  }
                }

                if (weeklyProduct != null && mounted) {
                  // Trigger purchase with the loaded product
                  await _purchaseProduct(weeklyProduct);
                } else if (mounted) {
                  // Still no product available
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t('premium.subscription.loading'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      backgroundColor: Theme.of(context).cardColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: buttonPadding),
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.primaryForeground,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoadingProducts
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryForeground,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      color: AppColors.primaryForeground,
                      size: iconSize,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.t('premium.subscribe.now'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.primaryForeground,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTermsAndPrivacyCompact(double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final fontSize = isSmallScreen ? 10.0 : 12.0;
    final horizontalPadding = isSmallScreen ? 4.0 : 8.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () =>
                _launchURL('https://sites.google.com/view/dodishgenie/home'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.t('premium.privacy.policy'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: fontSize,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _launchURL(
              'https://sites.google.com/view/dodishgenieterms/home',
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.t('premium.terms.of.use'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _FeatureComparison {
  final String iconPath;
  final String title;
  final bool availableInBasic;
  final bool availableInPro;

  _FeatureComparison({
    required this.iconPath,
    required this.title,
    required this.availableInBasic,
    required this.availableInPro,
  });

  static List<_FeatureComparison> _getFeatures(BuildContext context) => [
    _FeatureComparison(
      iconPath: 'assets/icons/si_ai-line.svg',
      title: context.t('premium.feature.unlimited.recipes'),
      availableInBasic: false,
      availableInPro: true,
    ),
    _FeatureComparison(
      iconPath: 'assets/icons/lucide_brain.svg',
      title: context.t('premium.feature.nutrition.analytics'),
      availableInBasic: true,
      availableInPro: true,
    ),
    _FeatureComparison(
      iconPath: 'assets/icons/icon-park-twotone_voice.svg',
      title: context.t('premium.feature.voice.assistant'),
      availableInBasic: true,
      availableInPro: true,
    ),
    _FeatureComparison(
      iconPath: 'assets/icons/f7_camera.svg',
      title: context.t('premium.feature.image.analysis'),
      availableInBasic: true,
      availableInPro: true,
    ),
    _FeatureComparison(
      iconPath: 'assets/icons/ic_outline-local-grocery-store.svg',
      title: context.t('premium.feature.grocery.list'),
      availableInBasic: true,
      availableInPro: true,
    ),
    _FeatureComparison(
      iconPath: 'assets/icons/ad-blocker.svg',
      title: context.t('premium.feature.ad.free'),
      availableInBasic: false,
      availableInPro: true,
    ),
  ];
}
