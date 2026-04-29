import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/pro_button.dart';
import '../../widgets/common/quick_action_card.dart';
import '../../widgets/common/saved_meal_plan_card.dart';
import '../../widgets/common/search_bar.dart' as custom;
import '../../widgets/common/weekly_plan_preview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isExitSheetOpen = false;

  bool get _shouldShowProButton => Platform.isIOS
      ? RemoteConfigService.subProButtonIos
      : RemoteConfigService.subProButton;

  Future<void> _showExitConfirmation() async {
    if (!mounted) return;
    if (_isExitSheetOpen) return;

    _isExitSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    ctx.t('exit.dialog.title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ctx.t('exit.dialog.message'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.dividerColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            ctx.t('exit.dialog.cancel'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await RemoteConfigService.initialize();
                              await RemoteConfigService.fetchAndActivate();
                            } catch (_) {}
                            final shouldShowExitAd = Platform.isIOS
                                ? RemoteConfigService.exitInterIos
                                : RemoteConfigService.exitInter;

                            if (shouldShowExitAd) {
                              try {
                                if (ctx.mounted) {
                                  await AdService.showInterstitialAdForType(
                                    adType: 'exit',
                                    context: ctx,
                                    loadAdFunction: () =>
                                        AdService.loadExitInterstitialAd(),
                                    onAdDismissed: () {
                                      // App closes ONLY after user dismisses the ad
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      SystemNavigator.pop();
                                    },
                                    onAdFailedToShow: (_) {
                                      // Ad failed to load/show - exit without waiting
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      SystemNavigator.pop();
                                    },
                                  );
                                  return; // Do NOT fall through - exit happens in callbacks only
                                }
                              } catch (_) {}
                            }

                            // No ad shown - close sheet and exit
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            SystemNavigator.pop();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            ctx.t('exit.dialog.exit'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        _isExitSheetOpen = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (_isExitSheetOpen) {
            Navigator.of(context, rootNavigator: true).maybePop();
            return;
          }
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        bottomNavigationBar: const BottomNav(activeTab: 'home'),
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.getGradientHero(context),
              ),
            ),
            // Floating sparkles
            const FloatingSparkles(),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Fixed top section with Pro button and settings (unscrollable)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Pro button on the left (only if remote config enables it)
                        if (_shouldShowProButton) const ProButton(),
                        // Settings button on the right
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () => context.push('/settings'),
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          // Hero section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    children: [
                                      WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) => AppColors
                                              .gradientPrimary
                                              .createShader(bounds),
                                          child: Text(
                                            context.t('home.greeting'),
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  height: 1.0,
                                                ),
                                          ),
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' ${context.t('home.greeting.end')}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                              height: 1.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const GenieMascot(size: GenieMascotSize.md),
                                const SizedBox(height: 12),
                                Text(
                                  context.t('home.subtitle'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                custom.SearchBar(
                                  placeholder: context.t(
                                    'home.search.placeholder',
                                  ),
                                  onSearch: (query) {
                                    context.push(
                                      '/recipes?search=${Uri.encodeComponent(query)}',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Quick Actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('home.quick.actions'),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final screenWidth = constraints.maxWidth;
                                    final crossAxisCount = screenWidth > 600
                                        ? 4
                                        : 2;
                                    // Slightly taller cards only on very small screens (< 360px)
                                    final childAspectRatio = screenWidth < 360
                                        ? 1.1
                                        : 1.4;
                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: childAspectRatio,
                                      children: [
                                        QuickActionCard(
                                          title: context.t(
                                            'home.generate.recipe',
                                          ),
                                          description: context.t(
                                            'home.ai.creates',
                                          ),
                                          icon: Icons.restaurant_menu,
                                          iconGradient: [
                                            AppColors.geniePink,
                                            AppColors.geniePurple,
                                          ],
                                          delay: 100,
                                          onTap: () => context.push('/recipes'),
                                        ),
                                        QuickActionCard(
                                          title: context.t('home.meal.planner'),
                                          description: context.t(
                                            'home.plan.week',
                                          ),
                                          icon: Icons.calendar_today,
                                          iconGradient: [
                                            AppColors.geniePurple,
                                            AppColors.genieLavender,
                                          ],
                                          delay: 200,
                                          onTap: () => context.push('/planner'),
                                        ),
                                        QuickActionCard(
                                          title: context.t(
                                            'home.smart.grocery',
                                          ),
                                          description: context.t(
                                            'home.shopping.lists',
                                          ),
                                          icon: Icons.shopping_cart,
                                          iconGradient: [
                                            AppColors.genieLavender,
                                            AppColors.geniePink,
                                          ],
                                          delay: 300,
                                          onTap: () => context.push('/grocery'),
                                        ),
                                        QuickActionCard(
                                          title: context.t('home.ai.chef.chat'),
                                          description: context.t(
                                            'home.ask.questions',
                                          ),
                                          icon: Icons.chat,
                                          iconGradient: [
                                            AppColors.genieGold,
                                            AppColors.geniePink,
                                          ],
                                          delay: 400,
                                          onTap: () => context.push('/chat'),
                                        ),
                                        QuickActionCard(
                                          title: context.t('common.favorites'),
                                          description: context.t(
                                            'favorites.subtitle',
                                          ),
                                          icon: Icons.favorite,
                                          iconGradient: [
                                            AppColors.geniePink,
                                            Colors.red.shade400,
                                          ],
                                          delay: 500,
                                          onTap: () =>
                                              context.push('/favorites'),
                                        ),
                                      ],
                                    ); // GridView.count closes here
                                  }, // builder function closes
                                ), // LayoutBuilder closes
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Saved Meal Plan Card
                          const SavedMealPlanCard(),

                          // Weekly Plan Preview
                          const WeeklyPlanPreview(delay: 400),
                        ],
                      ),
                    ),
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
