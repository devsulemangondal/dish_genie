import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../data/models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../services/storage_service.dart';
import '../../services/card_ad_tracker.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/standard_back_button.dart';
import '../../widgets/ads/screen_native_ad_widget.dart';
import '../../widgets/ads/custom_native_ad_widget.dart';
import '../../widgets/recipe/recipe_image_widget.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String slug;

  const RecipeDetailScreen({super.key, required this.slug});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLoading = true;

  void _popOrGoRecipes() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/recipes');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecipe();
    _loadFavorites();
    _trackCardOpen();
  }

  /// Track card open and show ad if configured
  Future<void> _trackCardOpen() async {
    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(
      context,
      listen: false,
    );
    if (premiumProvider.isPremium) return;

    // Track the open action
    final openCount = await CardAdTracker.trackCardOpen();

    // Get the card_inter configuration (single value like "open5" or "back5" or "off")
    final cardInterConfig = RemoteConfigService.cardInter.trim().toLowerCase();

    // Check if card_inter is "off" - if so, don't show ad
    if (cardInterConfig != 'off' && cardInterConfig.isNotEmpty) {
      // Check if config starts with "open"
      if (cardInterConfig.startsWith('open')) {
        try {
          // Extract number after "open"
          final numStr = cardInterConfig.substring(4); // "open" is 4 characters
          final threshold = int.parse(numStr);
          if (threshold > 0) {
            // Show ad when counter >= threshold
            final shouldShowAd = openCount >= threshold;

            if (shouldShowAd) {
              // Show after a small delay to ensure screen is loaded
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (mounted) {
                  await AdService.showInterstitialAdForType(
                    adType: 'card',
                    context: context,
                    loadAdFunction: () => AdService.loadCardInterstitialAd(),
                    onAdDismissed: () {
                      // Reset counter after ad is shown
                      CardAdTracker.resetCardOpenCount();
                    },
                    onAdFailedToShow: (ad) {
                      // Reset counter even if ad fails to show
                      CardAdTracker.resetCardOpenCount();
                    },
                  );
                }
              });
            }
          }
        } catch (e) {
          // If parsing fails, don't show ad
        }
      }
    }
  }

  /// Handle back button press and track card back
  Future<void> _handleBack() async {
    try {
      // Check if user is premium (premium users don't see ads)
      final premiumProvider = Provider.of<PremiumProvider>(
        context,
        listen: false,
      );

      if (!premiumProvider.isPremium) {
        // Track the back action
        final backCount = await CardAdTracker.trackCardBack();

        // Get the card_inter configuration (single value like "open5" or "back5" or "off")
        final cardInterConfig = RemoteConfigService.cardInter
            .trim()
            .toLowerCase();

        // Check if card_inter is "off" - if so, don't show ad
        if (cardInterConfig != 'off' && cardInterConfig.isNotEmpty) {
          // Check if config starts with "back"
          if (cardInterConfig.startsWith('back')) {
            try {
              // Extract number after "back"
              final numStr = cardInterConfig.substring(
                4,
              ); // "back" is 4 characters
              final threshold = int.parse(numStr);
              if (threshold > 0) {
                // Show ad when counter >= threshold
                final shouldShowAd = backCount >= threshold;

                if (shouldShowAd) {
                  // Show ad with loader (loader is handled in AdService)
                  await AdService.showInterstitialAdForType(
                    adType: 'card',
                    context: context,
                    loadAdFunction: () => AdService.loadCardInterstitialAd(),
                    onAdDismissed: () {
                      // Reset counter after ad is shown
                      CardAdTracker.resetCardBackCount();
                      _popOrGoRecipes();
                    },
                    onAdFailedToShow: (ad) {
                      // Reset counter even if ad fails to show
                      CardAdTracker.resetCardBackCount();
                      _popOrGoRecipes();
                    },
                  );
                  // Don't pop immediately, wait for ad callback
                  return;
                }
              }
            } catch (e) {
              // If parsing fails, continue to pop normally
            }
          }
        }
      }

      // If no ad should be shown, pop normally
      _popOrGoRecipes();
    } catch (e) {
      // Ensure we always pop even if there's an error
      _popOrGoRecipes();
    }
  }

  void _loadRecipe() {
    // Find recipe by slug using RecipeProvider
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final recipe = recipeProvider.getRecipeBySlug(widget.slug);
    setState(() {
      _recipe = recipe;
      _isLoading = false;
    });
  }

  Future<void> _loadFavorites() async {
    final favorites = await StorageService.getFavorites();
    final saved = await StorageService.getSavedRecipes();
    setState(() {
      _isLiked = favorites.contains(widget.slug);
      _isSaved = saved.contains(widget.slug);
    });
  }

  Future<void> _toggleLike() async {
    final favorites = await StorageService.getFavorites();
    if (_isLiked) {
      favorites.remove(widget.slug);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('common.remove')),
          backgroundColor: AppColors.destructive,
        ),
      );
    } else {
      favorites.add(widget.slug);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.t('common.add')} ${context.t('common.favorites')}! ❤️',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
    await StorageService.saveFavorites(favorites);
    setState(() => _isLiked = !_isLiked);
  }

  Future<void> _toggleSave() async {
    final saved = await StorageService.getSavedRecipes();
    if (_isSaved) {
      saved.remove(widget.slug);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.t('common.remove')} ${context.t('common.favorites')}',
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
    } else {
      saved.add(widget.slug);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('common.save')}! 📌'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
    await StorageService.saveSavedRecipes(saved);
    setState(() => _isSaved = !_isSaved);
  }

  Future<void> _shareRecipe() async {
    if (_recipe == null) return;

    final shareText =
        '${context.t('recipe.detail.ingredients')}: ${_recipe!.title} - ${_recipe!.description}';
    final shareUrl = 'https://dishgenie.app/recipe/${widget.slug}';

    try {
      await Share.share('$shareText\n$shareUrl', subject: _recipe!.title);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('common.error')}: ${e.toString()}'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (!didPop) {
            await _handleBack();
          }
        },
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_recipe == null) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (!didPop) {
            await _handleBack();
          }
        },
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.getGradientHero(context),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GenieMascot(size: GenieMascotSize.lg),
                      const SizedBox(height: 24),
                      Text(
                        context.t('recipe.detail.recipe.not.found'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('recipe.detail.generate.custom'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/recipes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 20),
                            const SizedBox(width: 8),
                            Text(context.t('recipes.generate.recipe')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final recipe = _recipe!;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Hero Image (Fixed at top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipeImageWidget(
                    image: recipe.image,
                    fit: BoxFit.cover,
                    placeholder: Container(color: colorScheme.surfaceVariant),
                    errorWidget: Container(
                      color: colorScheme.surfaceVariant,
                      child: const Icon(Icons.error),
                    ),
                  ),
                  // Gradient overlay for better text visibility if needed
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3), // Darker at top for status bar
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Spacer to show image
                    SizedBox(height: MediaQuery.of(context).size.height * 0.45),

                    // Main Content Card
                    Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Center Handle (Optional, but nice for sheet look)
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colorScheme.onSurface.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Tags
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: recipe.tags.take(3).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                
                                // Cuisine & Difficulty
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      recipe.cuisine.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.geniePurple,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withOpacity(0.4),
                                      ),
                                    ),
                                    Text(
                                      recipe.difficulty,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Title
                                Text(
                                  recipe.title,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Description
                                Text(
                                  recipe.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Stats
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _StatChip(
                                      icon: Icons.access_time,
                                      iconColor: AppColors.geniePurple,
                                      label: recipe.time,
                                    ),
                                    _StatChip(
                                      icon: Icons.people_outline,
                                      iconColor: AppColors.geniePink,
                                      label: '${recipe.servings} ${context.t('recipe.detail.servings')}',
                                    ),
                                    _StatChip(
                                      icon: Icons.local_fire_department_outlined,
                                      iconColor: AppColors.genieGold,
                                      label: '${recipe.calories} ${context.t('recipe.detail.cal')}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const Divider(height: 1),
                          
                          // Nutrition Section
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('recipe.detail.nutrition.per.serving'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _NutritionItem(
                                      value: '${recipe.nutrition.calories}',
                                      label: context.t('recipe.detail.calories'),
                                      color: AppColors.primary,
                                    ),
                                    _NutritionItem(
                                      value: '${recipe.nutrition.protein}g',
                                      label: context.t('recipe.detail.protein'),
                                      color: AppColors.geniePurple,
                                    ),
                                    _NutritionItem(
                                      value: '${recipe.nutrition.carbs}g',
                                      label: context.t('recipe.detail.carbs'),
                                      color: AppColors.geniePink,
                                    ),
                                    _NutritionItem(
                                      value: '${recipe.nutrition.fat}g',
                                      label: context.t('recipe.detail.fat'),
                                      color: AppColors.genieGold,
                                    ),
                                    _NutritionItem(
                                      value: '${recipe.nutrition.fiber}g',
                                      label: context.t('recipe.detail.fiber'),
                                      color: AppColors.genieLavender,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Ingredients Section
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('recipe.detail.ingredients'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...recipe.ingredients.map((ingredient) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.primary.withOpacity(0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              height: 1.4,
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

                          // Ad
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final fullWidth = MediaQuery.of(context).size.width;
                              return SizedBox(
                                width: fullWidth,
                                child: const ScreenNativeAdWidget(
                                  screenKey: 'recipeDetail',
                                  size: CustomNativeAdSize.medium,
                                ),
                              );
                            },
                          ),

                          // Instructions
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('recipe.detail.instructions'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...recipe.instructions.map((step) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            gradient: AppColors.gradientPrimary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${step.step}',
                                              style: TextStyle(
                                                color: colorScheme.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                step.text,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  height: 1.5,
                                                ),
                                              ),
                                              if (step.timeMinutes != null) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.timer_outlined,
                                                        size: 14,
                                                        color: colorScheme.onSurface.withOpacity(0.7),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${step.timeMinutes} ${context.t('recipe.detail.min')}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colorScheme.onSurface.withOpacity(0.7),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          if (recipe.tips != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.genieGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.genieGold.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          color: AppColors.genieGold,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          context.t('recipe.detail.chefs.tip'),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.genieGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      recipe.tips!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.8),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Start Cooking Button
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.gradientPrimary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => context.go('/chat'),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.restaurant_menu,
                                                size: 24,
                                                color: colorScheme.onPrimary,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                context.t('recipe.detail.start.cooking.a.i'),
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Genie Helper
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const GenieMascot(size: GenieMascotSize.sm),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          context.t('recipe.detail.genie.help'),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24), // Bottom padding
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Top Navigation Bar (Floating)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      StandardBackButton(
                        onTap: _handleBack,
                        backgroundColor: Colors.white,
                        iconColor: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      const Spacer(),
                      _CircleButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        onTap: _toggleLike,
                        backgroundColor: _isLiked ? AppColors.geniePink : Colors.white,
                        iconColor: _isLiked ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 12),
                      _CircleButton(
                        icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        onTap: _toggleSave,
                        backgroundColor: Colors.white,
                        iconColor: _isSaved ? AppColors.geniePurple : Colors.black,
                      ),
                      const SizedBox(width: 12),
                      _CircleButton(
                        icon: Icons.share_outlined,
                        onTap: _shareRecipe,
                        backgroundColor: Colors.white,
                        iconColor: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor = Colors.white,
    this.iconColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = theme.chipTheme.backgroundColor ?? colorScheme.surfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.85),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _NutritionItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = theme.chipTheme.backgroundColor ?? colorScheme.surfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
