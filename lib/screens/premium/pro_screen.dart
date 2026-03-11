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
              _showDiscountDialogAfterClose(navContext, () async {
                if (!kDebugMode) {
                  await StorageService.setDiscountPopupShownNow();
                }
              });
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
    Future<void> Function() onDismiss,
  ) async {
    final result = await showDialog<bool>(
      context: navContext,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => const DiscountPopup(),
    );
    if (!navContext.mounted) return;
    // If user tapped Subscribe, start weekly purchase in place (no navigation)
    if (result == true) {
      if (navContext.mounted) {
        _purchaseWeeklyInPlace(navContext);
      }
    } else {
      await onDismiss();
    }
  }

  /// Initiates weekly subscription purchase from current screen (e.g. discount popup).
  /// Shows success/error dialogs in place without navigating to Pro.
  static void _purchaseWeeklyInPlace(BuildContext context) async {
    StreamSubscription? sub;
    try {
      await BillingService.initialize();
      await BillingService.loadProducts();
      final products = BillingService.products;
      ProductDetails? weeklyProduct;
      try {
        weeklyProduct = products.firstWhere(
          (p) => p.id == BillingService.weeklySubscriptionId,
        );
      } catch (_) {
        if (products.isNotEmpty) weeklyProduct = products.first;
      }
      if (weeklyProduct == null) {
        if (context.mounted) {
          _showPurchaseErrorDialog(context, context.t('premium.failed.to.initiate.purchase'));
        }
        return;
      }
      final ok = await BillingService.purchaseProduct(weeklyProduct);
      if (!ok && context.mounted) {
        _showPurchaseErrorDialog(context, context.t('premium.failed.to.initiate.purchase'));
        return;
      }
      sub = BillingService.purchaseStream.listen((purchase) {
        if (purchase.productID != BillingService.weeklySubscriptionId) return;
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
        _showPurchaseErrorDialog(context, context.t('premium.error', {'error': e.toString()}));
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Main scrollable content
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final contentWidth = screenWidth - 32;

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderWithClose(screenWidth),
                          if (isPremium) ...[
                            _buildPremiumBadge(),
                            const SizedBox(height: 16),
                          ],
                          _buildTitleSection(screenWidth),
                          const SizedBox(height: 16),
                          _buildPlanCards(
                            contentWidth,
                            annualProduct,
                            weeklyProduct,
                          ),
                          const SizedBox(height: 20),
                          _buildWhyGoPremium(contentWidth),
                          const SizedBox(height: 20),
                          _buildTrustedBySection(contentWidth),
                          const SizedBox(height: 20),
                          _buildSocialStats(contentWidth),
                          const SizedBox(height: 24),
                          if (!isPremium) ...[
                            _buildSubscribeButton(
                              _selectedPlanId == 'annual'
                                  ? annualProduct
                                  : weeklyProduct,
                            ),
                            const SizedBox(height: 12),
                            _buildContinueWithAdButton(),
                          ],
                          const SizedBox(height: 20),
                          _buildPaymentDisclaimer(),
                          const SizedBox(height: 12),
                          _buildCancelTermsPrivacyLine(screenWidth),
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Close button - circle bg #726B7D, cross #43233A, 24x24
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: SizedBox(
                width: 30,
                height: 30,
                child: Material(
                  color: const Color(0xFFDDDEE7),
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: Opacity(
                    opacity: _canExitProScreen ? 1.0 : 0.4,
                    child: InkWell(
                      onTap: _canExitProScreen
                          ? () async => _exitProFlow()
                          : null,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF43233A),
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

  Widget _buildHeaderWithClose(double contentWidth) {
    final headerHeight = (contentWidth * _headerAspectRatio).clamp(
      120.0,
      280.0,
    );
    return SizedBox(
      width: contentWidth,
      height: headerHeight,
      child: Image.asset('assets/pro_header.png', fit: BoxFit.cover),
    );
  }

  Widget _buildTitleSection(double screenWidth) {
    final scaleFactor = (screenWidth / 360).clamp(0.8, 1.2);
    final titleSize = _titleBaseSize * scaleFactor;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.poetsenOne(
          fontSize: titleSize,
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
        children: [
          const TextSpan(text: 'Cook Smarter with\n'),
          TextSpan(
            text: 'Dish Genie Premium.',
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
  static const Color _selectedBg = Color(0xFFF4F0FF);
  static const Color _selectedBorder = Color(0xFF6F3FF5);
  static const Color _unselectedBorder = Color(0xFFC0BEBE);

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
                        ? 'See less plans'
                        : 'See more plans',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
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
                        color: Colors.black,
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
    return Container(
      width: double.infinity,
      height: _planCardHeight,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? _selectedBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? _selectedBorder : _unselectedBorder,
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
              width: 116,
              height: 28,
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
                'Most Popular',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
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
                        'Annual Plan',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$140.99/year',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B1EE4),
                          decoration: TextDecoration.lineThrough,
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
                    '\$124.99',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '/year',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
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
    return Container(
      width: double.infinity,
      height: _planCardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? _selectedBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? _selectedBorder : _unselectedBorder,
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
                  'Weekly Plan',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3 Days Free Trial',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B1EE4),
                  ),
                ),
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
                  color: Colors.black,
                ),
              ),
              Text(
                context.t('premium.per.week'),
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
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
                '🔥 Why Go Premium?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
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
                '⭐ Trusted by Food\nLovers',
                style: GoogleFonts.poetsenOne(
                  fontSize: 26.4,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
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
              border: Border.all(color: const Color(0xFFC0BEBE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade300,
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
                        'Imogen Davies',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Home Cook in weeks',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"I stopped wasting time searching recipes online. DishGenie instantly creates meals from what I have in my fridge."',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📊 Social Stats',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⭐ 4.8 Average Rating',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              Text(
                '🌎 200K+ Home Cooks',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '👨‍🍳 1000+ Recipes Generated',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
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
            height: 56,
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
                        context.t('premium.subscribe.now'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Payment will be charged to your Google Account at purchase. Subscription renews automatically unless canceled before the billing period ends.',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF726B7D),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static const double _checkSize = 18.75;
  static const double _proCheckSize =
      20.0; // slightly larger, bolder appearance
  static const Color _basicCheckColor = Color(0xFF43233A);

  static const double _rowHeight = 42;
  static const double _headerHeight = 40;

  Widget _buildFeaturesListCompact(
    double contentWidth,
    double availableHeight,
  ) {
    final features = _FeatureComparison._getFeatures(context);
    final columnWidth = (contentWidth * 0.18).clamp(55.0, 75.0);

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
                            color: _basicCheckColor,
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
                      color: Colors.black,
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
                            color: _basicCheckColor,
                            size: _checkSize,
                          )
                        : Icon(
                            Icons.remove,
                            color: Colors.grey.shade600,
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
                    'PRO',
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
                    color: const Color(0xFFF9EEFF),
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
                                    color: Colors.grey.shade400,
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
  /// Responsive: uses Wrap so links flow to multiple lines in long languages.
  Widget _buildCancelTermsPrivacyLine(double screenWidth) {
    final style = GoogleFonts.poppins(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: Colors.black,
      decoration: TextDecoration.underline,
      decorationColor: Colors.black,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LinkText(
            text: context.t('premium.privacy.policy'),
            style: style,
            textAlign: TextAlign.start,
            onTap: () =>
                _launchURL('https://sites.google.com/view/dodishgenie/home'),
            maxLines: 2,
            softWrap: true,
          ),
          _LinkText(
            text: context.t('premium.cancel.any.time'),
            style: style,
            textAlign: TextAlign.center,
            onTap: () => _launchURL(
              'https://play.google.com/store/account/subscriptions',
            ),
            maxLines: 2,
            softWrap: true,
          ),
          _LinkText(
            text: context.t('premium.terms.of.use'),
            style: style,
            textAlign: TextAlign.end,
            onTap: () => _launchURL(
              'https://sites.google.com/view/dodishgenieterms/home',
            ),
            maxLines: 2,
            softWrap: true,
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
