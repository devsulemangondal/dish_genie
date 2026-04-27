import 'dart:async';
import 'dart:io';

// ignore_for_file: unused_element

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
  String _selectedPlanId = 'yearly';

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
    final bg = isDark ? AppColors.backgroundDark : const Color(0xFFF9F6F1);

    final selectedProduct = _selectedPlanId == 'yearly'
        ? annualProduct
        : weeklyProduct;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Match the provided reference layout exactly, while keeping it
            // non-scrollable by scaling down on short devices.
            const designW = 360.0;
            const designH = 800.0;
            final scaleW = constraints.maxWidth / designW;
            final scaleH = constraints.maxHeight / designH;
            final scale = (scaleW < scaleH ? scaleW : scaleH).clamp(0.78, 1.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? bg : null,
                      gradient: isDark
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFF5FAFF), Color(0xFFFFFFFF)],
                            ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: designW,
                        height: designH,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              _buildTopHeroImage(),
                              const SizedBox(height: 14),
                              _buildScreenshotTitle(),
                              const SizedBox(height: 14),
                              _buildScreenshotFeatures(),
                              const SizedBox(height: 18),
                              if (!isPremium) ...[
                                _buildCtaWithSubtitle(
                                  selectedProduct,
                                  weeklyProduct,
                                ),
                                const SizedBox(height: 26),
                              ],
                              _buildScreenshotPlanCards(
                                isDark: isDark,
                                annualProduct: annualProduct,
                                weeklyProduct: weeklyProduct,
                              ),
                              const SizedBox(height: 18),
                              _buildCancelTermsPrivacyLine(designW),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 14,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: _canExitProScreen ? 1.0 : 0.4,
                        child: InkWell(
                          onTap: _canExitProScreen ? _exitProFlow : null,
                          customBorder: const CircleBorder(),
                          child: const Center(child: _ScreenshotCloseButton()),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Figma: 17x17, stroke 2.5, color #BC571980
  static const Color _kCloseColor = Color(0x80BC5719);
  static const double _kCloseStroke = 2.5;
  static const double _kCloseSize = 17;

  Widget _buildTopHeroImage() {
    // Screenshot shows a large character image on a light background, not cropped.
    return SizedBox(
      height: 238,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF5FAFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Image.asset(
            'assets/pro_top_new.png',
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }

  Widget _buildScreenshotTitle() {
    final titleColor = const Color(0xFF2B2B2B);

    return Text(
      'Cook Smarter with AI',
      style: GoogleFonts.hahmlet(
        fontSize: 18.5,
        fontWeight: FontWeight.w700,
        color: titleColor,
        height: 1.15,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildScreenshotFeatures() {
    final textColor = const Color(0xFF6B6B6B);
    const iconColor = Color(0xFF2F80ED);

    Widget row(String asset, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SvgPicture.asset(
            asset,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          row('assets/icons/ai.svg', 'Daily AI recipe suggestions'),
          row('assets/icons/scan.svg', 'Ingredient-based cooking'),
          row('assets/icons/calender.svg', 'Smart meal planning'),
          row('assets/icons/stat.svg', 'Nutrition Insights'),
        ],
      ),
    );
  }

  Widget _buildCtaWithSubtitle(
    ProductDetails? selectedProduct,
    ProductDetails? weeklyProduct,
  ) {
    final isWeeklySelected = _selectedPlanId == 'weekly';
    final weeklyPrice = weeklyProduct?.price ?? 'Rs 2,250';
    final subtitle = isWeeklySelected
        ? 'Try 3 days for free, then $weeklyPrice/week'
        : null;

    return _ScreenshotCtaButton(
      enabled: selectedProduct != null && !_isLoading,
      isLoading: _isLoadingProducts || (_isLoading && selectedProduct != null),
      title: isWeeklySelected ? 'Start Free Trial' : 'Subscribe',
      subtitle: subtitle,
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
                  final targetId = _selectedPlanId == 'yearly'
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
    );
  }

  Widget _buildScreenshotPlanCards({
    required bool isDark,
    required ProductDetails? annualProduct,
    required ProductDetails? weeklyProduct,
  }) {
    return Column(
      children: [
        _ScreenshotPlanCard.yearly(
          title: 'Yearly',
          leftSubtitle: 'Just Rs 7,200.00 per year',
          rightPrice: annualProduct?.price ?? 'Rs 139.00',
          rightSuffix: 'per year',
          isSelected: _selectedPlanId == 'yearly',
          onTap: () => setState(() => _selectedPlanId = 'yearly'),
        ),
        const SizedBox(height: 14),
        _ScreenshotPlanCard.weekly(
          title: 'Weekly',
          leftSubtitle: 'Full Access Included',
          rightPrice: weeklyProduct?.price ?? 'Rs 2,250',
          rightSuffix: 'per week',
          isSelected: _selectedPlanId == 'weekly',
          onTap: () => setState(() => _selectedPlanId = 'weekly'),
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF313132);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/search.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            context.t('premium.cook.smarter.with.ai'),
            style: GoogleFonts.hahmlet(
              fontSize: 18,
              height: 1.0,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildGeniusPlanCard({required bool isDark}) {
    final cardBg = isDark ? AppColors.cardDark : const Color(0xFFFAEDDC);
    final borderColor = isDark ? AppColors.borderDark : const Color(0x80DBEAFE);
    final tileBg = isDark ? const Color(0xFF2A2F3A) : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Base width from Figma (outer card width). Use available width so it
        // scales on all devices while keeping the same proportions.
        final scale = (constraints.maxWidth / 494.111083984375).clamp(
          0.75,
          1.35,
        );
        double r(double v) => v * scale;

        // Snap to physical pixels to avoid tiny RenderFlex overflows due to
        // fractional rounding (e.g. 0.24px).
        final dpr = MediaQuery.devicePixelRatioOf(context);
        double snap(double v) => (v * dpr).floorToDouble() / dpr;

        final padX = snap(r(30.04));
        final padY = snap(r(30.04));
        final tileGap = snap(r(18));
        const tileAspect = 199.61636352539062 / 142.3677215576172;
        // Allow tiles slightly wider than original to fit text better.
        const designTileW = 215.0;
        final maxGridWidth = r(designTileW) * 2 + tileGap;
        final contentW = (constraints.maxWidth - (padX * 2)).clamp(0.0, 1e9);
        final gridMaxW = maxGridWidth.clamp(0.0, contentW);
        // Compute a grid width first (snapped), then derive tile widths from it
        // so `tileWidth + gap + tileWidth` can never exceed the parent.
        final desiredGridW = snap(gridMaxW);
        final rawTileW = ((desiredGridW - tileGap) / 2).clamp(
          0.0,
          r(designTileW),
        );
        var tileWidth = snap(rawTileW);
        var gridW = snap((tileWidth * 2 + tileGap).clamp(0.0, desiredGridW));

        // Safety: if rounding still makes us exceed, shrink tiles by 1px.
        if (tileWidth * 2 + tileGap > gridW) {
          tileWidth = snap((tileWidth - (1 / dpr)).clamp(0.0, tileWidth));
          gridW = snap((tileWidth * 2 + tileGap).clamp(0.0, desiredGridW));
        }

        return Container(
          // Make bottom padding same as top padding (requested).
          padding: EdgeInsets.fromLTRB(padX, padY, padX, padY),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(r(36.38)),
            border: Border.all(width: r(1.66), color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: r(48.487178802490234),
                    height: r(48.487178802490234),
                    padding: EdgeInsets.symmetric(horizontal: r(10.61)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBC5719),
                      borderRadius: BorderRadius.circular(r(55831364)),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/ai.svg',
                      width: r(22),
                      height: r(22),
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  SizedBox(width: r(10)),
                  Expanded(
                    child: Text(
                      context.t('premium.genius.cooking.plan'),
                      style: GoogleFonts.inter(
                        fontSize: r(27.29),
                        height: 42.45 / 27.29,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF101828),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r(30.31)),
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: gridW == 0 ? null : gridW,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: tileAspect,
                              child: _FeatureTile(
                                scale: scale,
                                background: tileBg,
                                svgAsset: 'assets/icons/ai.svg',
                                text: context.t(
                                  'premium.feature.daily.ai.recipe.suggestions',
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: tileGap),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: tileAspect,
                              child: _FeatureTile(
                                scale: scale,
                                background: tileBg,
                                svgAsset: 'assets/icons/scan.svg',
                                text: context.t(
                                  'premium.feature.ingredient.based.cooking',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tileGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: tileAspect,
                              child: _FeatureTile(
                                scale: scale,
                                background: tileBg,
                                svgAsset: 'assets/icons/calender.svg',
                                text: context.t(
                                  'premium.feature.smart.meal.planning',
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: tileGap),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: tileAspect,
                              child: _FeatureTile(
                                scale: scale,
                                background: tileBg,
                                svgAsset: 'assets/icons/stat.svg',
                                text: context.t(
                                  'premium.feature.nutrition.insights',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChoosePlanHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF313132);
    final pillTextColor = isDark
        ? AppColors.mutedForegroundDark
        : const Color(0xFF6E6A64);
    return Column(
      children: [
        Text(
          context.t('premium.choose.your.plan'),
          style: GoogleFonts.inter(
            fontSize: 20,
            // height: 1.0,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFAEDDC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: pillTextColor,
              ),
              children: [
                TextSpan(text: context.t('premium.unlimited.recipes')),
                TextSpan(
                  text: context.t('premium.best.value'),
                  style: const TextStyle(color: Color(0xFFE07B67)),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanRow({
    required bool isDark,
    required ProductDetails? annualProduct,
    required ProductDetails? weeklyProduct,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        double snap(double v) => (v * dpr).floorToDouble() / dpr;
        final gap = 12.0;
        final cardW = (constraints.maxWidth - gap) / 2;
        final scale = (cardW / 180).clamp(0.85, 1.15);
        final cardH = snap(96 * scale);

        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: cardH,
                child: _PlanCard(
                  scale: scale,
                  title: context.t('premium.plan.weekly'),
                  price: weeklyProduct?.price ?? '\$9.99',
                  suffix: '/week',
                  isSelected: _selectedPlanId == 'weekly',
                  isBestValue: false,
                  isDark: isDark,
                  centerTitle: true,
                  onTap: () => setState(() => _selectedPlanId = 'weekly'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: cardH,
                child: _PlanCard(
                  scale: scale,
                  title: context.t('premium.plan.yearly'),
                  price: annualProduct?.price ?? '\$9.99',
                  suffix: '/year',
                  isSelected: _selectedPlanId == 'yearly',
                  isBestValue: true,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedPlanId = 'yearly'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrialLine(ProductDetails? weeklyProduct) {
    final weeklyText = weeklyProduct?.price != null
        ? '${weeklyProduct!.price}/week'
        : '\$9.99/week';

    return Text(
      context.t('premium.start.free.trial', {'price': weeklyText}),
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.0,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.mutedForegroundDark
            : const Color(0xFF707070),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildGreenCtaButton(ProductDetails? selectedProduct) {
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: (selectedProduct != null && !_isLoading)
              ? () => _purchaseProduct(selectedProduct)
              : _isLoadingProducts
              ? null
              : () async {
                  setState(() => _isLoadingProducts = true);
                  try {
                    final ok = await BillingService.loadProducts(retry: true);
                    if (mounted && ok) {
                      final p = BillingService.products;
                      final targetId = _selectedPlanId == 'yearly'
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2AA948),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
          child: _isLoadingProducts || (_isLoading && selectedProduct != null)
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  context.t('premium.unlock.unlimited.recipes.now'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
  /// Keep it on a single line (scale down if needed).
  Widget _buildCancelTermsPrivacyLine(double screenWidth) {
    final linkColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.mutedForegroundDark
        : const Color(0xFF707070);
    final style = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: linkColor,
      decoration: TextDecoration.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LinkText(
                text: context.t('premium.terms.of.use'),
                style: style,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                onTap: () => _launchURL(
                  'https://sites.google.com/view/dodishgenieterms/home',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('|', style: style),
              ),
              _LinkText(
                text: context.t('premium.cancel.any.time'),
                style: style,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                onTap: () => _launchURL(
                  'https://play.google.com/store/account/subscriptions',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('|', style: style),
              ),
              _LinkText(
                text: context.t('premium.privacy.policy'),
                style: style,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                onTap: () => _launchURL(
                  'https://sites.google.com/view/dodishgenie/home',
                ),
              ),
            ],
          ),
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

class _FeatureTile extends StatelessWidget {
  final double scale;
  final Color background;
  final String svgAsset;
  final String text;

  const _FeatureTile({
    required this.scale,
    required this.background,
    required this.svgAsset,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    // Figma inner tile:
    // 199.62 x 142.37, radius 24.26, top border 1.66 #FFFFFF99
    // shadows:
    //   0 1.52 3.03 -1.52 #0000001A
    //   0 1.52 4.55 0    #0000001A
    double r(double v) => v * scale;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF364153);

    return Container(
      padding: EdgeInsets.all(r(16)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(r(24.26)),
        border: Border(
          top: BorderSide(width: r(1.66), color: const Color(0x99FFFFFF)),
        ),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 1.52),
            blurRadius: 3.03,
            spreadRadius: -1.52,
            color: Color(0x1A000000),
          ),
          BoxShadow(
            offset: Offset(0, 1.52),
            blurRadius: 4.55,
            spreadRadius: 0,
            color: Color(0x1A000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 0), // keeps layout stable across fonts
          SvgPicture.asset(
            svgAsset,
            width: r(22),
            height: r(22),
            colorFilter: const ColorFilter.mode(
              Color(0xFFE07B67),
              BlendMode.srcIn,
            ),
          ),
          SizedBox(height: r(12)),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: r(19.71),
              height: 27.1 / 19.71,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final double scale;
  final String title;
  final String price;
  final String suffix;
  final bool isSelected;
  final bool isBestValue;
  final bool isDark;
  final bool centerTitle;
  final VoidCallback onTap;

  const _PlanCard({
    required this.scale,
    required this.title,
    required this.price,
    required this.suffix,
    required this.isSelected,
    required this.isBestValue,
    required this.isDark,
    this.centerTitle = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.cardDark : Colors.white;
    const accent = Color(0xFFC46E3D);
    final borderColor = isSelected ? accent : const Color(0xFFDBD8D5);
    final onSurface = isDark ? Colors.white : const Color(0xFF111827);
    final suffixColor = isDark ? Colors.white70 : const Color(0xFF7A7A7A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22 * scale),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1.25),
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (isBestValue)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11 * scale,
                    vertical: 6 * scale,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFE28121), Color(0xFFA53E15)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(26),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.t('premium.best.value.ribbon'),
                    style: GoogleFonts.inter(
                      fontSize: 9.5 * scale,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14 * scale,
                12 * scale,
                14 * scale,
                10 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  centerTitle
                      ? Center(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 15.5 * scale,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15.5 * scale,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  SizedBox(height: 8 * scale),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: GoogleFonts.inter(
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Padding(
                        padding: EdgeInsets.only(bottom: 2 * scale),
                        child: Text(
                          suffix,
                          style: GoogleFonts.inter(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            color: suffixColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseXIcon extends StatelessWidget {
  const _CloseXIcon();

  @override
  Widget build(BuildContext context) {
    // Uses constants from _ProScreenState for exact Figma match.
    return CustomPaint(
      size: const Size(
        _ProScreenState._kCloseSize,
        _ProScreenState._kCloseSize,
      ),
      painter: _CloseXPainter(
        color: _ProScreenState._kCloseColor,
        strokeWidth: _ProScreenState._kCloseStroke,
      ),
    );
  }
}

class _CloseXPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CloseXPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inset = strokeWidth / 2;
    final p1 = Offset(inset, inset);
    final p2 = Offset(size.width - inset, size.height - inset);
    final p3 = Offset(size.width - inset, inset);
    final p4 = Offset(inset, size.height - inset);

    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p3, p4, paint);
  }

  @override
  bool shouldRepaint(covariant _CloseXPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _ScreenshotCloseButton extends StatelessWidget {
  const _ScreenshotCloseButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFD4D4D4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Center(
        child: Icon(Icons.close, size: 16, color: Colors.white),
      ),
    );
  }
}

class _ScreenshotCtaButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;

  const _ScreenshotCtaButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? const Color(0xFF2AA948) : const Color(0xFF93D5A2);
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        color: Colors.white.withOpacity(0.92),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ScreenshotPlanCard extends StatelessWidget {
  final String title;
  final String leftSubtitle;
  final String rightPrice;
  final String? rightSuffix;
  final String? actionText;
  final bool isSelected;
  final bool isYearly;
  final VoidCallback onTap;

  const _ScreenshotPlanCard._({
    required this.title,
    required this.leftSubtitle,
    required this.rightPrice,
    required this.isSelected,
    required this.onTap,
    required this.isYearly,
    this.rightSuffix,
    this.actionText,
  });

  factory _ScreenshotPlanCard.yearly({
    required String title,
    required String leftSubtitle,
    required String rightPrice,
    required String rightSuffix,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _ScreenshotPlanCard._(
      title: title,
      leftSubtitle: leftSubtitle,
      rightPrice: rightPrice,
      rightSuffix: rightSuffix,
      actionText: null,
      isSelected: isSelected,
      onTap: onTap,
      isYearly: true,
    );
  }

  factory _ScreenshotPlanCard.lifetimeStyle({
    required String title,
    required String leftSubtitle,
    required String rightPrice,
    required String actionText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _ScreenshotPlanCard._(
      title: title,
      leftSubtitle: leftSubtitle,
      rightPrice: rightPrice,
      rightSuffix: null,
      actionText: actionText,
      isSelected: isSelected,
      onTap: onTap,
      isYearly: false,
    );
  }

  factory _ScreenshotPlanCard.weekly({
    required String title,
    required String leftSubtitle,
    required String rightPrice,
    required String rightSuffix,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _ScreenshotPlanCard._(
      title: title,
      leftSubtitle: leftSubtitle,
      rightPrice: rightPrice,
      rightSuffix: rightSuffix,
      actionText: null,
      isSelected: isSelected,
      onTap: onTap,
      isYearly: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const selectedBg = Color(0xFFD0E3FF);
    const selectedBorder = Color(0xFF5A98FD);
    const unselectedBg = Colors.white;
    const unselectedBorder = Color(0xFFBFCFE3);

    final border = isSelected ? selectedBorder : unselectedBorder;
    final bg = isSelected ? selectedBg : unselectedBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: isSelected ? 1.6 : 1),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isYearly)
              Positioned(
                // Screenshot: badge overlaps the border line and is pulled
                // inward from the top-right corner.
                top: -16,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFFD5C17), Color(0xFFFFB301)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Best Offer',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          leftSubtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rightPrice,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        actionText ?? (rightSuffix ?? ''),
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
