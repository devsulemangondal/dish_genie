import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../data/models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../services/interstitial_ad_helper.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/standard_back_button.dart';
import '../../widgets/recipe/recipe_image_widget.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String slug;

  /// When set (e.g. from /ai-recipe), use this recipe instead of loading by slug.
  final Recipe? initialRecipe;

  const RecipeDetailScreen({super.key, required this.slug, this.initialRecipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLoading = true;
  bool _recipeBackInProgress = false;

  // Consistent spacing for the detail content
  static const double _pad = 24;
  static const double _space = 16;
  static const double _spaceSmall = 12;

  void _popOrGoRecipes() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/recipes');
    }
  }

  /// Default placeholder: appetizing food variety that fits all cuisines.
  static const String _defaultFoodPlaceholderUrl =
      'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=800';
  static const Map<String, String> _keywordPlaceholderUrls = {
    'pasta': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=800',
    'spaghetti': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=800',
    'noodle': 'https://images.unsplash.com/photo-1569718212165-3a285ed4c94f?auto=format&fit=crop&w=800',
    'pizza': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800',
    'burger': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800',
    'sandwich': 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=800',
    'salad': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800',
    'soup': 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=800',
    'curry': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=800',
    'rice': 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800',
    'chicken': 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?auto=format&fit=crop&w=800',
    'fish': 'https://images.unsplash.com/photo-1519708227418-8e0c04ed96d6?auto=format&fit=crop&w=800',
    'meat': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?auto=format&fit=crop&w=800',
    'steak': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=800',
    'bread': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800',
    'cake': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=800',
    'dessert': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=800',
    'breakfast': 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=800',
    'egg': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800',
    'vegetable': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800',
    'vegan': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800',
    'smoothie': 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=800',
  };

  static String _getPlaceholderUrlForRecipe(Recipe recipe) {
    final text = '${recipe.title} ${recipe.tags.join(' ')} ${recipe.cuisine} ${recipe.description}'
        .toLowerCase();
    for (final entry in _keywordPlaceholderUrls.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return _defaultFoodPlaceholderUrl;
  }

  Widget _buildRecipeImagePlaceholder(BuildContext context, Recipe? recipe) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = recipe != null
        ? _getPlaceholderUrlForRecipe(recipe)
        : _defaultFoodPlaceholderUrl;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest,
              (theme.brightness == Brightness.dark
                      ? AppColors.geniePurple
                      : AppColors.genieLavender)
                  .withOpacity(0.2),
            ],
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest,
              (theme.brightness == Brightness.dark
                      ? AppColors.geniePurple
                      : AppColors.genieLavender)
                  .withOpacity(0.15),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipe != null) {
      _recipe = widget.initialRecipe;
      _isLoading = false;
    } else {
      _loadRecipe();
    }
    _loadFavorites();
    _trackCardOpen();
  }

  /// Track card open (ads removed - reserved for future ad plan)
  Future<void> _trackCardOpen() async {}

  /// System back, PopScope, or app bar — optional interstitial then pop.
  Future<void> _handleBack() async {
    if (!mounted || _recipeBackInProgress) return;
    _recipeBackInProgress = true;
    await InterstitialAdHelper.showRecipeDetailBackInterstitial(
      context: context,
      onLeave: () {
        if (!mounted) {
          _recipeBackInProgress = false;
          return;
        }
        _recipeBackInProgress = false;
        _popOrGoRecipes();
      },
    );
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

  /// Returns recipe with fallback image URL if original is empty (for storage).
  Recipe _recipeWithFallbackImageIfNeeded(Recipe recipe) {
    if (recipe.image.trim().isEmpty) {
      return recipe.copyWith(image: _getPlaceholderUrlForRecipe(recipe));
    }
    return recipe;
  }

  Future<void> _toggleLike() async {
    if (_recipe == null) return;
    final favorites = await StorageService.getFavorites();
    if (_isLiked) {
      favorites.remove(widget.slug);
      await StorageService.removeRecipeDataForSlug(widget.slug);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('common.remove')),
          backgroundColor: AppColors.destructive,
        ),
      );
    } else {
      favorites.add(widget.slug);
      await StorageService.saveRecipeDataForSlug(
        widget.slug,
        _recipeWithFallbackImageIfNeeded(_recipe!),
      );
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
    if (_recipe == null) return;
    final saved = await StorageService.getSavedRecipes();
    if (_isSaved) {
      saved.remove(widget.slug);
      await StorageService.removeRecipeDataForSlug(widget.slug);
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
      await StorageService.saveRecipeDataForSlug(
        widget.slug,
        _recipeWithFallbackImageIfNeeded(_recipe!),
      );
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
      final size = MediaQuery.of(context).size;
      await Share.share(
        '$shareText\n$shareUrl',
        subject: _recipe!.title,
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height),
      );
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
                    placeholder: _buildRecipeImagePlaceholder(context, recipe),
                    errorWidget: _buildRecipeImagePlaceholder(context, recipe),
                  ),
                  // Gradient overlay for better text visibility if needed
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(
                            0.3,
                          ), // Darker at top for status bar
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
                    // Spacer so bottom sheet peeks enough to show full ad on first open
                    SizedBox(height: MediaQuery.of(context).size.height * 0.36),

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
                            padding: const EdgeInsets.all(_pad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Center Handle (Optional, but nice for sheet look)
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colorScheme.onSurface.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: _pad),

                                // Tags
                                Wrap(
                                  spacing: _spaceSmall,
                                  runSpacing: _spaceSmall,
                                  children: recipe.tags.take(3).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: _spaceSmall,
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
                                const SizedBox(height: _space),

                                // Cuisine & Difficulty
                                Wrap(
                                  spacing: _spaceSmall,
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
                                        color: colorScheme.onSurface
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    Text(
                                      recipe.difficulty,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: _spaceSmall),

                                // Title
                                Text(
                                  recipe.title,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                ),
                                const SizedBox(height: _spaceSmall),

                                // Description
                                Text(
                                  recipe.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: _pad),

                                // Stats
                                Wrap(
                                  spacing: _spaceSmall,
                                  runSpacing: _spaceSmall,
                                  children: [
                                    _StatChip(
                                      icon: Icons.access_time,
                                      iconColor: AppColors.geniePurple,
                                      label: recipe.time,
                                    ),
                                    _StatChip(
                                      icon: Icons.people_outline,
                                      iconColor: AppColors.geniePink,
                                      label:
                                          '${recipe.servings} ${context.t('recipe.detail.servings')}',
                                    ),
                                    _StatChip(
                                      icon:
                                          Icons.local_fire_department_outlined,
                                      iconColor: AppColors.genieGold,
                                      label:
                                          '${recipe.calories} ${context.t('recipe.detail.cal')}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Nutrition Section
                          Padding(
                            padding: const EdgeInsets.all(_pad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t(
                                    'recipe.detail.nutrition.per.serving',
                                  ),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: _space),
                                Wrap(
                                  spacing: _spaceSmall,
                                  runSpacing: _spaceSmall,
                                  children: [
                                    _NutritionItem(
                                      value: '${recipe.nutrition.calories}',
                                      label: context.t(
                                        'recipe.detail.calories',
                                      ),
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
                            padding: const EdgeInsets.all(_pad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('recipe.detail.ingredients'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: _space),
                                ...recipe.ingredients.map((ingredient) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: _space,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withOpacity(0.5),
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
                                        const SizedBox(width: _spaceSmall),
                                        Expanded(
                                          child: Text(
                                            '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          // Instructions
                          Padding(
                            padding: const EdgeInsets.all(_pad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('recipe.detail.instructions'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: _space),
                                ...recipe.instructions.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final step = entry.value;
                                  final isLast =
                                      index == recipe.instructions.length - 1;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: isLast ? 0 : _space,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            gradient: AppColors.gradientPrimary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withOpacity(0.3),
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
                                        const SizedBox(width: _space),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                step.text,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(height: 1.5),
                                              ),
                                              if (step.timeMinutes != null) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme
                                                        .surfaceContainerHighest
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.timer_outlined,
                                                        size: 14,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withOpacity(0.7),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${step.timeMinutes} ${context.t('recipe.detail.min')}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colorScheme
                                                              .onSurface
                                                              .withOpacity(0.7),
                                                          fontWeight:
                                                              FontWeight.w500,
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
                              padding: const EdgeInsets.fromLTRB(
                                _pad,
                                0,
                                _pad,
                                _pad,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(_pad),
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
                                        const SizedBox(width: _spaceSmall),
                                        Text(
                                          context.t('recipe.detail.chefs.tip'),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.genieGold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _spaceSmall),
                                    Text(
                                      recipe.tips!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withOpacity(0.8),
                                            height: 1.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Start Cooking Button
                          Padding(
                            padding: const EdgeInsets.all(_pad),
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
                                          color: AppColors.primary.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final r = _recipe;
                                          if (r == null) return;
                                          // Use go (not push): /chat lives under the shell navigator while
                                          // recipe detail is on the root. Pushing stacks both and can trigger
                                          // Navigator keyReservation / HeroControllerScope assertions.
                                          // Unique `cook` query forces the shell chat route to rebuild with a
                                          // fresh [ChatAssistantScreen] state so "Start cooking" works every time.
                                          final uri = Uri(
                                            path: '/chat',
                                            queryParameters: {
                                              'cook':
                                                  '${DateTime.now().microsecondsSinceEpoch}',
                                            },
                                          );
                                          context.go(uri.toString(), extra: r);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.restaurant_menu,
                                                size: 24,
                                                color: colorScheme.onPrimary,
                                              ),
                                              const SizedBox(
                                                width: _spaceSmall,
                                              ),
                                              Text(
                                                context.t(
                                                  'recipe.detail.start.cooking.a.i',
                                                ),
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
                                const SizedBox(height: _pad),
                                // Genie Helper
                                Container(
                                  padding: const EdgeInsets.all(_space),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const GenieMascot(
                                        size: GenieMascotSize.sm,
                                      ),
                                      const SizedBox(width: _spaceSmall),
                                      Expanded(
                                        child: Text(
                                          context.t('recipe.detail.genie.help'),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.7),
                                                height: 1.4,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: _pad), // Bottom padding
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                        backgroundColor: _isLiked
                            ? AppColors.geniePink
                            : Colors.white,
                        iconColor: _isLiked ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 12),
                      _CircleButton(
                        icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        onTap: _toggleSave,
                        backgroundColor: Colors.white,
                        iconColor: _isSaved
                            ? AppColors.geniePurple
                            : Colors.black,
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
          child: Center(child: Icon(icon, size: 20, color: iconColor)),
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
    final bg =
        theme.chipTheme.backgroundColor ?? colorScheme.surfaceContainerHighest;

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
    final bg =
        theme.chipTheme.backgroundColor ?? colorScheme.surfaceContainerHighest;

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
