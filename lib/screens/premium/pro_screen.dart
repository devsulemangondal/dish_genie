import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import '../../services/billing_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/premium/discount_popup.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

/// Minimum time to show Pro screen on first launch before allowing navigation away
const Duration _kFirstLaunchMinDisplayDuration = Duration(seconds: 3);

/// Set to true to enable discount popup on Pro screen close (for later releases).
const bool kShowDiscountPopup = false;

class _ProScreenState extends State<ProScreen> with WidgetsBindingObserver {
  StreamSubscription? _purchaseSubscription;
  StreamSubscription? _billingErrorSubscription;
  Timer? _purchaseLoadingTimeout;
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  ProductDetails? _selectedProduct;
  bool _wasInBackgroundForPurchase = false;

  /// On first launch, user must see Pro screen for minimum duration before exiting
  bool _canExitProScreen = true;

  /// Whether "See more plans" dropdown is expanded
  bool _showMorePlansExpanded = false;

  /// Selected plan: 'annual' or 'weekly'
  String _selectedPlanId = 'annual';

  final GlobalKey _scrollContentKey = GlobalKey();

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
    WidgetsBinding.instance.addObserver(this);
    _initializeBilling();
    _checkFirstLaunch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isLoading && _selectedProduct != null) {
        _wasInBackgroundForPurchase = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackgroundForPurchase &&
          _isLoading &&
          _selectedProduct != null) {
        _wasInBackgroundForPurchase = false;
        // User may have closed the Play Store dialog without buying (no cancel event).
        // Wait so a "purchased" result can arrive first, then clear loader if still loading.
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isLoading && _selectedProduct != null) {
            _clearPurchaseLoading();
          }
        });
      } else {
        _wasInBackgroundForPurchase = false;
      }
    }
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
      return;
    }
    // On first launch, enforce minimum display time before user can exit
    final isFirstLaunch = await StorageService.isFirstLaunch();
    if (isFirstLaunch && mounted) {
      setState(() => _canExitProScreen = false);
      Future.delayed(_kFirstLaunchMinDisplayDuration, () {
        if (mounted) {
          setState(() => _canExitProScreen = true);
        }
      });
    }
  }

  Future<void> _initializeBilling() async {
    setState(() {
      _isLoadingProducts = true;
    });

    // Subscribe to errors first so we clear loader when "app not configured for IAP" etc.
    _billingErrorSubscription = BillingService.errorStream.listen((error) {
      if (mounted) {
        _clearPurchaseLoading();
        setState(() {
          _isLoadingProducts = false;
        });
      }
    });

    try {
      await BillingService.initialize();
      await BillingService.loadProducts();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }

    // Listen to purchase updates
    _purchaseSubscription = BillingService.purchaseStream.listen((purchase) {
      // Check if this purchase is for the selected product
      final isSelectedProduct =
          _selectedProduct != null &&
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
            _clearPurchaseLoading();
            context.read<PremiumProvider>().setPremium(true);
            _showSuccessDialog();
          }
          break;
        case PurchaseStatus.error:
          // Always clear loading on error (e.g. "app not configured for IAP")
          if (mounted) {
            _clearPurchaseLoading();
            if (isSelectedProduct) {
              _showErrorDialog(
                purchase.error?.message ?? context.t('premiumPurchaseFailed'),
              );
            }
          }
          break;
        case PurchaseStatus.canceled:
          // Clear loading when user closes subscription popup / cancels
          if (isSelectedProduct && mounted) {
            _clearPurchaseLoading();
          }
          break;
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _exitProFlow() async {
    if (!_canExitProScreen) return;
    final canPop = context.canPop();
    final source = _getOpenSource();

    // Decide where to go after closing (or after ad): pop if came via push, else go to route
    final isLanguageSelected = await StorageService.isLanguageSelected();
    if (!mounted) return;
    final String nextRoute;
    if (canPop) {
      nextRoute = ''; // will use pop() instead
    } else if (source == 'splash') {
      nextRoute = isLanguageSelected ? '/' : '/language-selection';
    } else {
      nextRoute = '/';
    }

    void navigateAway() {
      if (!mounted) return;
      if (canPop) {
        context.pop();
      } else {
        context.go(nextRoute);
      }
    }

    // Do not show discount popup to premium users
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (isPremium) {
      navigateAway();
      return;
    }

    // Discount popup hidden until kShowDiscountPopup is true (for later releases)
    if (!kShowDiscountPopup) {
      navigateAway();
      return;
    }

    // Show discount dialog: debug = every close; release = once per 24h if RC allows
    // Flow: close Pro screen FIRST, THEN show popup on the next screen
    final shouldShowDiscount = kDebugMode
        ? true
        : (Platform.isIOS
              ? RemoteConfigService.discountPopupIos
              : RemoteConfigService.discountPopup);
    if (shouldShowDiscount) {
      if (!kDebugMode) {
        try {
          await RemoteConfigService.initialize();
          await RemoteConfigService.fetchAndActivate();
        } catch (_) {}
      }
      if (!mounted) return;
      final showDiscount = kDebugMode
          ? true
          : (Platform.isIOS
                ? RemoteConfigService.discountPopupIos
                : RemoteConfigService.discountPopup);
      if (showDiscount) {
        final bool canShow;
        if (kDebugMode) {
          canShow = true; // Always show in debug
        } else {
          final lastShown = await StorageService.getDiscountPopupShownAt();
          final now = DateTime.now();
          canShow =
              lastShown == null ||
              now.difference(lastShown) >= const Duration(hours: 24);
        }
        if (canShow && mounted) {
          // 1. Close Pro screen first
          navigateAway();
          // 2. After Pro closes, show discount popup on the new screen
          Future.delayed(const Duration(milliseconds: 350), () {
            final navContext = AppRouter.getNavigatorKey()?.currentContext;
            if (navContext != null && navContext.mounted) {
              _showDiscountDialogAfterClose(
                navContext,
                BillingService.yearlySubscriptionId,
                () async {
                  if (!kDebugMode) {
                    await StorageService.setDiscountPopupShownNow();
                  }
                },
              );
            }
          });
          return;
        }
      }
    }

    navigateAway();
  }

  /// Shows discount popup on the current screen (called after Pro has closed).
  Future<void> _showDiscountDialogAfterClose(
    BuildContext navContext,
    String productId,
    Future<void> Function() onDismiss,
  ) async {
    final result = await showDialog<bool>(
      context: navContext,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => DiscountPopup(productId: productId),
    );
    if (!navContext.mounted) return;
    // If user tapped Subscribe, purchase the popup's product (yearly) in place
    if (result == true) {
      if (navContext.mounted) {
        _purchaseProductInPlace(navContext, productId);
      }
    } else {
      await onDismiss();
    }
  }

  /// Initiates subscription purchase from current screen (e.g. discount popup).
  /// [productId] - e.g. yearly_sub or weekly_sub. Shows success/error dialogs in place.
  static void _purchaseProductInPlace(
    BuildContext context,
    String productId,
  ) async {
    StreamSubscription? sub;
    try {
      await BillingService.initialize();
      await BillingService.loadProducts();
      final product = BillingService.getProduct(productId);
      if (product == null) {
        if (context.mounted) {
          _showPurchaseErrorDialog(
            context,
            context.t('premium.failed.to.initiate.purchase'),
          );
        }
        return;
      }
      final ok = await BillingService.purchaseProduct(product);
      if (!ok && context.mounted) {
        _showPurchaseErrorDialog(
          context,
          context.t('premium.failed.to.initiate.purchase'),
        );
        return;
      }
      sub = BillingService.purchaseStream.listen((purchase) {
        if (purchase.productID != productId) return;
        sub?.cancel();
        sub = null;
        if (!context.mounted) return;
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            context.read<PremiumProvider>().setPremium(true);
            StorageService.setFirstLaunchComplete();
            _showPurchaseSuccessDialog(context);
            break;
          case PurchaseStatus.error:
            _showPurchaseErrorDialog(
              context,
              purchase.error?.message ?? context.t('premiumPurchaseFailed'),
            );
            break;
          case PurchaseStatus.canceled:
          case PurchaseStatus.pending:
            break;
        }
      });
    } catch (e) {
      sub?.cancel();
      if (context.mounted) {
        _showPurchaseErrorDialog(
          context,
          context.t('premium.error', {'error': e.toString()}),
        );
      }
    }
  }

  static void _showPurchaseSuccessDialog(BuildContext context) async {
    await StorageService.setFirstLaunchComplete();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Text(
          context.t('premium.success'),
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        content: Text(
          context.t('premium.welcome.message'),
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (context.mounted) context.go('/');
            },
            child: Text(context.t('common.done')),
          ),
        ],
      ),
    );
  }

  static void _showPurchaseErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Text(
          context.t('common.error'),
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        content: Text(
          message,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
  }

  void _clearPurchaseLoading() {
    _purchaseLoadingTimeout?.cancel();
    _purchaseLoadingTimeout = null;
    if (mounted) {
      setState(() {
        _isLoading = false;
        _selectedProduct = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseLoadingTimeout?.cancel();
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

    _purchaseLoadingTimeout?.cancel();
    setState(() {
      _isLoading = true;
      _selectedProduct = product;
    });
    // If user closes the native subscription popup without buying, the store
    // may not always send PurchaseStatus.canceled. Stop loader after 90s.
    _purchaseLoadingTimeout = Timer(const Duration(seconds: 90), () {
      if (mounted && _isLoading && _selectedProduct?.id == product.id) {
        _clearPurchaseLoading();
      }
    });

    try {
      final success = await BillingService.purchaseProduct(product);
      if (!success && mounted) {
        _clearPurchaseLoading();
        _showErrorDialog(context.t('premium.failed.to.initiate.purchase'));
      }
    } catch (e) {
      if (mounted) {
        _clearPurchaseLoading();
        _showErrorDialog(context.t('premium.error', {'error': e.toString()}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final products = BillingService.products;
    ProductDetails? weeklyProduct;
    ProductDetails? annualProduct;

    // Get subscription products from Play Store
    try {
      weeklyProduct = products.firstWhere(
        (p) => p.id == BillingService.weeklySubscriptionId,
      );
    } catch (e) {
      if (products.isNotEmpty) {
        weeklyProduct = products.first;
      }
    }
    try {
      annualProduct = products.firstWhere(
        (p) => p.id == BillingService.yearlySubscriptionId,
      );
    } catch (e) {
      annualProduct = null;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.background,
        body: Stack(
          children: [
            // Column: scrollable content + sticky bottom bar
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final contentWidth = screenWidth - 32;

                  return Stack(
                    children: [
                      // Scrollable content (extends behind sticky bar)
                      SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                (!isPremium ? 100 : 8) +
                                MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            key: _scrollContentKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderWithGradient(screenWidth),
                              if (isPremium) ...[
                                _buildPremiumBadge(),
                                const SizedBox(height: 16),
                              ],
                              _buildTitleSection(screenWidth),
                              const SizedBox(height: 12),
                              _buildPlanCards(
                                contentWidth,
                                annualProduct,
                                weeklyProduct,
                              ),
                              const SizedBox(height: 8),
                              _buildWhyGoPremium(contentWidth),
                              const SizedBox(height: 8),
                              _buildTrustedBySection(contentWidth),
                              const SizedBox(height: 8),
                              _buildSocialStats(contentWidth),
                              const SizedBox(height: 4),
                              _buildPaymentDisclaimer(),
                              const SizedBox(height: 4),
                              _buildCancelTermsPrivacyLine(screenWidth),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                      // Sticky bottom bar: gradient transparency (top clear → bottom opaque)
                      if (!isPremium)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Gradient bg: only under buttons (transparent top → opaque bottom)
                              IgnorePointer(
                                child: Container(
                                  height:
                                      108 +
                                      MediaQuery.of(context).padding.bottom,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        (isDark
                                                ? AppColors.backgroundDark
                                                : AppColors.background)
                                            .withOpacity(0),
                                        (isDark
                                                ? AppColors.backgroundDark
                                                : AppColors.background)
                                            .withOpacity(0.5),
                                        (isDark
                                            ? AppColors.backgroundDark
                                            : AppColors.background),
                                      ],
                                      stops: const [0, 0, 0.5],
                                    ),
                                  ),
                                ),
                              ),
                              SafeArea(
                                top: false,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: 6,
                                    bottom:
                                        6 +
                                        MediaQuery.of(context).padding.bottom,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSubscribeButton(
                                        _selectedPlanId == 'annual'
                                            ? annualProduct
                                            : weeklyProduct,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildContinueWithAdButton(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // Close button - circle bg, respects dark mode
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: SizedBox(
                width: 30,
                height: 30,
                child: Material(
                  color: isDark ? AppColors.mutedDark : const Color(0xFFDDDEE7),
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: Opacity(
                    opacity: _canExitProScreen ? 1.0 : 0.4,
                    child: InkWell(
                      onTap: _canExitProScreen
                          ? () async => _exitProFlow()
                          : null,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: isDark
                              ? AppColors.foregroundDark
                              : const Color(0xFF43233A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  static const double _headerAspectRatio = 263 / 360;
  static const double _titleBaseSize = 26.4;
  static const premiumPurple = Color(0xFF6E20E3);

  /// Figma gradient EECEFF -> FFFFFF to blend header with body (no harsh divider)
  static const Color _blendGradientTop = Color(0xFFEECEFF);
  static const Color _blendGradientBottom = Color(0xFFFFFFFF);

  /// Header image with gradient overlay to blend with body content
  Widget _buildHeaderWithGradient(double contentWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerHeight = (contentWidth * _headerAspectRatio).clamp(
      120.0,
      280.0,
    );
    final bottomColor = isDark
        ? AppColors.backgroundDark
        : _blendGradientBottom;
    return SizedBox(
      width: contentWidth,
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/pro_header.png', fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Colors.transparent,
                            const Color(0xFF1A1F35).withOpacity(0.5),
                            bottomColor,
                          ]
                        : [
                            Colors.transparent,
                            _blendGradientTop.withOpacity(0.4),
                            bottomColor,
                          ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(double screenWidth) {
    final scaleFactor = (screenWidth / 360).clamp(0.8, 1.2);
    final titleSize = _titleBaseSize * scaleFactor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.poetsenOne(
          fontSize: titleSize,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        children: [
          TextSpan(text: '${context.t('premium.title.line1')}\n'),
          TextSpan(
            text: context.t('premium.title.line2'),
            style: GoogleFonts.poetsenOne(
              fontSize: titleSize,
              fontWeight: FontWeight.w400,
              color: premiumPurple,
            ),
          ),
        ],
      ),
    );
  }

  static const double _planCardHeight = 116;
  static const Color _selectedBgLight = Color(0xFFF4F0FF);
  static const Color _selectedBgDark = Color(0xFF2A1F4A);
  static const Color _selectedBorder = Color(0xFF6F3FF5);
  static const Color _unselectedBorderLight = Color(0xFFC0BEBE);
  static const Color _unselectedBorderDark = Color(0xFF3F4654);

  Widget _buildPlanCards(
    double contentWidth,
    ProductDetails? annualProduct,
    ProductDetails? weeklyProduct,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedPlanId = 'annual'),
            child: _buildAnnualPlanCard(annualProduct),
          ),
          if (_showMorePlansExpanded && weeklyProduct != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _selectedPlanId = 'weekly'),
              child: _buildWeeklyPlanCard(weeklyProduct),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(
              () => _showMorePlansExpanded = !_showMorePlansExpanded,
            ),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showMorePlansExpanded
                        ? context.t('premium.see.less.plans')
                        : context.t('premium.see.more.plans'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _showMorePlansExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualPlanCard(ProductDetails? annualProduct) {
    final isSelected = _selectedPlanId == 'annual';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isSelected
        ? (isDark ? _selectedBgDark : _selectedBgLight)
        : (isDark ? AppColors.cardDark : AppColors.card);
    final unselectedBorder = isDark
        ? _unselectedBorderDark
        : _unselectedBorderLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      height: _planCardHeight,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? _selectedBorder : unselectedBorder,
          width: 1.5,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Most Popular tag
          Positioned(
            top: -6,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              // constraints: const BoxConstraints(
              //   minWidth: 70,
              //   maxWidth: 100,
              //   minHeight: 28,
              // ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF7A18), Color(0xFFFFB347)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                context.t('premium.most.popular'),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.t('premium.annual.plan'),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    annualProduct?.price ?? context.t('premium.annual.price'),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    context.t('premium.per.year'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: onSurface.withOpacity(0.87),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanCard(ProductDetails weeklyProduct) {
    final isSelected = _selectedPlanId == 'weekly';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isSelected
        ? (isDark ? _selectedBgDark : _selectedBgLight)
        : (isDark ? AppColors.cardDark : AppColors.card);
    final unselectedBorder = isDark
        ? _unselectedBorderDark
        : _unselectedBorderLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hasFreeTrial = BillingService.hasFreeTrial(weeklyProduct);
    if (kDebugMode && hasFreeTrial) {
      debugPrint('[ProScreen] Weekly plan: has free trial (from IAP)');
    }
    return Container(
      width: double.infinity,
      height: _planCardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? _selectedBorder : unselectedBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.t('premium.weekly.plan'),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                if (hasFreeTrial) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.t('premium.three.days.free.trial'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : premiumPurple,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                weeklyProduct.price,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              Text(
                context.t('premium.per.week'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: onSurface.withOpacity(0.87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhyGoPremium(double contentWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.t('premium.why.go.premium'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeaturesListCompact(contentWidth - 32, 600),
        ],
      ),
    );
  }

  Widget _buildTrustedBySection(double contentWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFC0BEBE);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('premium.trusted.by.title'),
                style: GoogleFonts.poetsenOne(
                  fontSize: 26.4,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isDark
                      ? AppColors.mutedDark
                      : Colors.grey.shade300,
                  child: ClipOval(
                    child: Image.asset(
                      "assets/profile.png",
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('premium.testimonial.name'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        context.t('premium.testimonial.role'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"${context.t('premium.testimonial.quote')}"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStats(double contentWidth) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('premium.social.stats'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            children: [
              Text(
                context.t('premium.average.rating'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
              ),
              Text(
                context.t('premium.home.cooks'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
              ),
              Text(
                context.t('premium.recipes.generated'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(ProductDetails? selectedProduct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (selectedProduct != null && !_isLoading)
              ? () => _purchaseProduct(selectedProduct)
              : _isLoadingProducts
              ? null
              : () async {
                  setState(() => _isLoadingProducts = true);
                  try {
                    final ok = await BillingService.loadProducts(retry: true);
                    if (mounted && ok) {
                      final p = BillingService.products;
                      final targetId = _selectedPlanId == 'annual'
                          ? BillingService.yearlySubscriptionId
                          : BillingService.weeklySubscriptionId;
                      ProductDetails? product;
                      try {
                        product = p.firstWhere((x) => x.id == targetId);
                      } catch (_) {
                        if (p.isNotEmpty) product = p.first;
                      }
                      if (product != null) await _purchaseProduct(product);
                    }
                  } finally {
                    if (mounted) setState(() => _isLoadingProducts = false);
                  }
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [const Color(0xFF691CE4), const Color(0xFFAF50E0)],
              ),
            ),
            alignment: Alignment.center,
            child: _isLoadingProducts || (_isLoading && selectedProduct != null)
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        context.t('common.continue'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDisclaimer() {
    final mutedColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        context.t('premium.payment.disclaimer'),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: mutedColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static const double _checkSize = 18.75;
  static const double _proCheckSize =
      20.0; // slightly larger, bolder appearance
  static const Color _basicCheckColorLight = Color(0xFF43233A);
  static const Color _basicCheckColorDark = Color(0xFFE8E6E9);

  static const double _rowHeight = 42;
  static const double _headerHeight = 40;

  Widget _buildFeaturesListCompact(
    double contentWidth,
    double availableHeight,
  ) {
    final features = _FeatureComparison._getFeatures(context);
    final columnWidth = (contentWidth * 0.18).clamp(55.0, 75.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final basicCheckColor = isDark
        ? _basicCheckColorDark
        : _basicCheckColorLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final proInnerBg = isDark
        ? const Color(0xFF2A1F4A)
        : const Color(0xFFF9EEFF);
    final greyColor = isDark
        ? AppColors.mutedForegroundDark
        : Colors.grey.shade600;
    final greyPro = isDark
        ? AppColors.mutedForegroundDark
        : Colors.grey.shade400;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// FEATURE LIST
        Expanded(
          child: Column(
            children: [
              SizedBox(height: _headerHeight),
              ...features.map((f) {
                return SizedBox(
                  height: _rowHeight,
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        f.iconPath,
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          premiumPurple,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: basicCheckColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(width: 8),

        /// BASIC COLUMN
        SizedBox(
          width: columnWidth,
          child: Column(
            children: [
              SizedBox(
                height: _headerHeight,
                child: Center(
                  child: Text(
                    context.t('premium.basic'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ),
              ),
              ...features.map((f) {
                return SizedBox(
                  height: _rowHeight,
                  child: Center(
                    child: f.availableInBasic
                        ? Icon(
                            Icons.check,
                            color: basicCheckColor,
                            size: _checkSize,
                          )
                        : Icon(
                            Icons.remove,
                            color: greyColor,
                            size: _checkSize,
                          ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(width: 6),

        /// PRO COLUMN - outer gradient with PRO text (white), inner card #F9EEFF with checks
        Container(
          width: columnWidth + 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: [Color(0xFF691CE4), Color(0xFFAF50E0)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PRO text in outer card (gradient area) - same height as other headers
              SizedBox(
                height: _headerHeight,
                child: Center(
                  child: Text(
                    context.t('premium.pro'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Inner card - checks align with feature rows
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: proInnerBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...features.map((f) {
                        return SizedBox(
                          height: _rowHeight,
                          child: Center(
                            child: f.availableInPro
                                ? Icon(
                                    Icons.check,
                                    color: premiumPurple,
                                    size: _proCheckSize,
                                  )
                                : Icon(
                                    Icons.remove,
                                    color: greyPro,
                                    size: _checkSize,
                                  ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Continue with ad button - same functionality as close (X) button
  Widget _buildContinueWithAdButton() {
    return TextButton(
      onPressed: (_isLoading || !_canExitProScreen)
          ? null
          : () async => await _exitProFlow(),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        context.t('premium.continue.with.ad'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  /// Privacy Policy • Cancel Anytime • Terms of Use (each tappable).
  /// Uses Wrap so links flow to multiple lines when text is long (e.g. RTL/long translations).
  Widget _buildCancelTermsPrivacyLine(double screenWidth) {
    final linkColor = Theme.of(context).colorScheme.onSurface;
    final style = GoogleFonts.poppins(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    final maxLinkWidth = screenWidth - 40;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLinkWidth),
            child: _LinkText(
              text: context.t('premium.privacy.policy'),
              style: style,
              textAlign: TextAlign.center,
              onTap: () =>
                  _launchURL('https://sites.google.com/view/dodishgenie/home'),
              maxLines: 3,
              softWrap: true,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLinkWidth),
            child: _LinkText(
              text: context.t('premium.cancel.any.time'),
              style: style,
              textAlign: TextAlign.center,
              onTap: () => _launchURL(
                'https://play.google.com/store/account/subscriptions',
              ),
              maxLines: 3,
              softWrap: true,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLinkWidth),
            child: _LinkText(
              text: context.t('premium.terms.of.use'),
              style: style,
              textAlign: TextAlign.center,
              onTap: () => _launchURL(
                'https://sites.google.com/view/dodishgenieterms/home',
              ),
              maxLines: 3,
              softWrap: true,
            ),
          ),
        ],
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
}

/// Inline tappable text link (no button chrome).
class _LinkText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onTap;
  final int maxLines;
  final TextAlign textAlign;
  final bool softWrap;

  const _LinkText({
    required this.text,
    required this.style,
    required this.onTap,
    this.maxLines = 1,
    this.textAlign = TextAlign.center,
    this.softWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: TextOverflow.ellipsis,
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
