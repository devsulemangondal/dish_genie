import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/loading_genie.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/recipe/recipe_card.dart';
import '../../widgets/recipe/recipe_grid_card.dart';
import '../../widgets/ads/screen_native_ad_widget.dart';
import '../../widgets/ads/custom_native_ad_widget.dart';
import '../../providers/recipe_provider.dart';
import '../../services/voice_service.dart';
import '../../data/models/recipe.dart';
import '../../providers/premium_provider.dart';
import '../../services/card_ad_tracker.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';

class RecipeGeneratorScreen extends StatefulWidget {
  final String? searchQuery;
  final String? category;

  const RecipeGeneratorScreen({super.key, this.searchQuery, this.category});

  @override
  State<RecipeGeneratorScreen> createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends State<RecipeGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ingredientsController = TextEditingController();
  String? _selectedCuisine;
  String? _selectedDiet;
  String? _selectedGoal;
  String? _selectedMood;
  String? _selectedCategory;
  int _cookingTime = 30;
  int _targetCalories = 500;
  bool _isVoiceListening = false;
  String _voiceTranscript = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.searchQuery != null) {
      _ingredientsController.text = widget.searchQuery!;
      _tabController.animateTo(1);
      // Auto-generate if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          _handleGenerate();
        }
      });
    }
    VoiceService.initialize();
    _trackCardScreenOpen();
  }

  /// Track when card screen is opened
  Future<void> _trackCardScreenOpen() async {
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

  @override
  void dispose() {
    _tabController.dispose();
    _ingredientsController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isVoiceListening) {
      await VoiceService.stop();
      setState(() {
        _isVoiceListening = false;
        _voiceTranscript = '';
      });
    } else {
      setState(() {
        _isVoiceListening = true;
        _voiceTranscript = context.t('grocery.listening.hint');
      });

      await VoiceService.listen(
        onResult: (text) {
          setState(() {
            _ingredientsController.text = _ingredientsController.text.isEmpty
                ? text
                : '${_ingredientsController.text}, $text';
            _isVoiceListening = false;
            _voiceTranscript = '';
          });
        },
        onPartialResult: (text) {
          setState(() {
            _voiceTranscript = text;
          });
        },
        onDone: () {
          setState(() {
            _isVoiceListening = false;
            _voiceTranscript = '';
          });
        },
        onError: (error) {
          setState(() {
            _isVoiceListening = false;
            _voiceTranscript = '';
          });
        },
      );
    }
  }

  Future<void> _handleGenerate() async {
    if (_ingredientsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('recipes.enter.ingredients'))),
      );
      return;
    }

    // Check if user can generate AI recipes based on remote config
    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.isPremium) {
      if (!premiumProvider.canGenerateAiRecipe()) {
        // Don't generate - limit reached message is shown in UI
        return;
      }
    }

    // Get current language code
    final languageCode = Localizations.localeOf(context).languageCode;

    final recipeProvider = context.read<RecipeProvider>();
    final generatedRecipe = await recipeProvider.generateRecipe(
      ingredients: _ingredientsController.text,
      cookingTime: _cookingTime,
      targetCalories: _targetCalories,
      cuisine: _selectedCuisine,
      dietType: _selectedDiet,
      healthGoal: _selectedGoal,
      mood: _selectedMood,
      language: languageCode,
    );

    // Increment AI recipe count for free users after successful generation
    if (generatedRecipe != null && !premiumProvider.isPremium) {
      premiumProvider.incrementAiRecipeCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final premiumProvider = context.watch<PremiumProvider>();
    final recipe = recipeProvider.recipe;
    final isLoading = recipeProvider.isLoading;

    // Check if user can generate AI recipes
    final canGenerateRecipe =
        premiumProvider.isPremium || premiumProvider.canGenerateAiRecipe();
    final aiRecipeLimit = premiumProvider.getAiRecipeLimit();
    final aiRecipeCount = premiumProvider.aiRecipeCount;

    return Scaffold(
      bottomNavigationBar: const BottomNav(activeTab: 'recipes'),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.gradientHeroDark
                  : AppColors.gradientHero,
            ),
          ),
          // Floating elements
          const FloatingSparkles(),
          // Main content with safe area handling
          SafeArea(
            child: Column(
              children: [
                // Sticky Header
                StickyHeader(
                  title: context.t('recipes.title'),
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  backgroundColor: Colors.transparent,
                  statusBarColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1F35)
                      : AppColors.genieBlush,
                  rightContent: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/favorites'),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.t('common.favorites'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.getCardShadow(context),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).colorScheme.onPrimary,
                      unselectedLabelColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [AppColors.geniePurple, AppColors.geniePink],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(text: context.t('recipes.browse')),
                        Tab(text: context.t('recipes.ai.generate')),
                      ],
                    ),
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Browse Tab
                      _buildBrowseTab(context, recipeProvider),
                      // Generate Tab
                      _buildGenerateTab(
                        context,
                        recipeProvider,
                        premiumProvider,
                        isLoading,
                        recipe,
                        canGenerateRecipe,
                        aiRecipeLimit,
                        aiRecipeCount,
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

  Widget _buildBrowseTab(BuildContext context, RecipeProvider recipeProvider) {
    // Filter recipes based on search or category
    List<Recipe> displayRecipes = [];
    if (widget.searchQuery != null) {
      displayRecipes = recipeProvider.searchRecipes(widget.searchQuery!);
    } else if (_selectedCategory != null) {
      displayRecipes = recipeProvider.filterByCategory(_selectedCategory!);
    } else {
      displayRecipes = recipeProvider.authenticRecipes.take(12).toList();
    }

    // Get category counts
    final quickRecipes = recipeProvider.authenticRecipes
        .where(
          (r) =>
              r.tags.any((t) => t.toLowerCase().contains('quick')) ||
              (r.prepTime + r.cookTime) <= 20,
        )
        .toList();
    final proteinRecipes = recipeProvider.authenticRecipes
        .where(
          (r) => r.tags.any((t) => t.toLowerCase().contains('high protein')),
        )
        .toList();
    final chickenRecipes = recipeProvider.authenticRecipes
        .where(
          (r) =>
              r.title.toLowerCase().contains('chicken') ||
              r.ingredients.any(
                (i) => i.name.toLowerCase().contains('chicken'),
              ),
        )
        .toList();
    final fishRecipes = recipeProvider.authenticRecipes
        .where(
          (r) =>
              r.title.toLowerCase().contains('fish') ||
              r.title.toLowerCase().contains('salmon') ||
              r.title.toLowerCase().contains('seafood'),
        )
        .toList();
    final veggieRecipes = recipeProvider.authenticRecipes
        .where(
          (r) => r.tags.any(
            (t) =>
                t.toLowerCase().contains('vegan') ||
                t.toLowerCase().contains('vegetarian') ||
                t.toLowerCase().contains('healthy'),
          ),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Results Header
          if (widget.searchQuery != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: '${context.t('recipes.results.for')} ',
                          ),
                          TextSpan(
                            text: '"${widget.searchQuery}"',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/recipes'),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.muted.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // No Results Message
          if (widget.searchQuery != null && displayRecipes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const GenieMascot(size: GenieMascotSize.md),
                  const SizedBox(height: 16),
                  Text(
                    context.t('recipes.no.results'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.t('recipes.try.other')} "${widget.searchQuery}"',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/recipes'),
                    child: Text(context.t('recipes.clear.search')),
                  ),
                ],
              ),
            ),
          // Category Chips - hide when searching
          if (widget.searchQuery == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3.2,
                children: [
                  _CategoryChip(
                    emoji: '⚡',
                    label: context.t('recipes.quick'),
                    count: quickRecipes.length,
                    isSelected: _selectedCategory == 'quick',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'quick'
                          ? null
                          : 'quick';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '💪',
                    label: context.t('recipes.high.protein'),
                    count: proteinRecipes.length,
                    isSelected: _selectedCategory == 'protein',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'protein'
                          ? null
                          : 'protein';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '🍗',
                    label: context.t('recipes.chicken'),
                    count: chickenRecipes.length,
                    isSelected: _selectedCategory == 'chicken',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'chicken'
                          ? null
                          : 'chicken';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '🐟',
                    label: context.t('recipes.seafood'),
                    count: fishRecipes.length,
                    isSelected: _selectedCategory == 'fish',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'fish'
                          ? null
                          : 'fish';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '🥚',
                    label: context.t('recipes.eggs'),
                    count: recipeProvider.authenticRecipes
                        .where(
                          (r) => r.ingredients.any(
                            (i) => i.name.toLowerCase().contains('egg'),
                          ),
                        )
                        .length,
                    isSelected: _selectedCategory == 'eggs',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'eggs'
                          ? null
                          : 'eggs';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '🥗',
                    label: context.t('recipes.healthy'),
                    count: veggieRecipes.length,
                    isSelected: _selectedCategory == 'veggie',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'veggie'
                          ? null
                          : 'veggie';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '👶',
                    label: context.t('recipes.kids'),
                    count: recipeProvider.authenticRecipes
                        .where(
                          (r) =>
                              r.difficulty == 'Easy' ||
                              r.tags.any(
                                (t) => t.toLowerCase().contains('kid'),
                              ),
                        )
                        .length,
                    isSelected: _selectedCategory == 'kids',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'kids'
                          ? null
                          : 'kids';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '💰',
                    label: context.t('recipes.budget'),
                    count: recipeProvider.authenticRecipes
                        .where(
                          (r) => r.tags.any(
                            (t) => t.toLowerCase().contains('budget'),
                          ),
                        )
                        .length,
                    isSelected: _selectedCategory == 'budget',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'budget'
                          ? null
                          : 'budget';
                    }),
                  ),
                  _CategoryChip(
                    emoji: '🔥',
                    label: context.t('recipes.grilled'),
                    count: recipeProvider.authenticRecipes
                        .where(
                          (r) => r.tags.any(
                            (t) => t.toLowerCase().contains('grill'),
                          ),
                        )
                        .length,
                    isSelected: _selectedCategory == 'grilled',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'grilled'
                          ? null
                          : 'grilled';
                    }),
                  ),
                ],
              ),
            ),
          if (widget.searchQuery == null) const SizedBox(height: 8),
          // Recipe Native Ad (Small) - Full width extending beyond padding
          if (widget.searchQuery == null)
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate full screen width and extend beyond padding
                final fullWidth = MediaQuery.of(context).size.width;
                return SizedBox(
                  width: fullWidth,
                  child: const ScreenNativeAdWidget(
                    screenKey: 'recipe',
                    size: CustomNativeAdSize.small,
                  ),
                );
              },
            ),
          if (widget.searchQuery == null) const SizedBox(height: 8),
          // Recipes Grid
          if (displayRecipes.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final crossAxisCount = screenWidth > 600
                    ? 3
                    : (screenWidth > 400 ? 2 : 2);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: displayRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = displayRecipes[index];
                    return RecipeGridCard(recipe: recipe);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGenerateTab(
    BuildContext context,
    RecipeProvider recipeProvider,
    PremiumProvider premiumProvider,
    bool isLoading,
    Recipe? recipe,
    bool canGenerateRecipe,
    int? aiRecipeLimit,
    int aiRecipeCount,
  ) {
    if (isLoading) {
      return const Center(child: LoadingGenie());
    }

    if (recipe != null) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RecipeCard(
                title: recipe.title,
                image: recipe.image,
                time: recipe.time,
                servings: recipe.servings,
                calories: recipe.calories,
                tags: recipe.tags,
                hideImage: true, // Hide images for AI generated recipes
                onTap: () {
                  // Navigate to AI recipe detail screen
                  context.push('/ai-recipe', extra: recipe);
                },
              ),
            ),
          ),
          // Create New Recipe Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Reset the recipe and form
                    recipeProvider.setRecipe(null);
                    _ingredientsController.clear();
                    setState(() {
                      _selectedCuisine = null;
                      _selectedDiet = null;
                      _selectedGoal = null;
                      _selectedMood = null;
                      _cookingTime = 30;
                      _targetCalories = 500;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.t('recipes.new.recipe'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ingredients Input Card
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.getCardShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and title
                      Row(
                        children: [
                          // Fork and knife icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Expanded(
                            child: Text(
                              context.t('recipes.what.ingredients'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Circular dot in top right
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Large text input field
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.inputDark
                              : AppColors.input,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _ingredientsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: context.t(
                              'recipes.ingredients.placeholder',
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Scan and Voice buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => context.go('/scan'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.camera_alt,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.t('recipes.scan'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleVoiceInput,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isVoiceListening
                                              ? Icons.mic_off
                                              : Icons.mic,
                                          size: 18,
                                          color: _isVoiceListening
                                              ? AppColors.destructive
                                              : AppColors.geniePurple,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.t('recipes.voice'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Voice transcript
                      if (_isVoiceListening && _voiceTranscript.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _voiceTranscript,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Mood Selection
                Text(
                  context.t('recipes.what.craving'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMoodChip(
                      '😋',
                      context.t('recipes.moods.comfortFood'),
                      _selectedMood == 'comfort',
                      () => setState(
                        () => _selectedMood = _selectedMood == 'comfort'
                            ? null
                            : 'comfort',
                      ),
                    ),
                    _buildMoodChip(
                      '🥗',
                      context.t('recipes.moods.lightFresh'),
                      _selectedMood == 'light',
                      () => setState(
                        () => _selectedMood = _selectedMood == 'light'
                            ? null
                            : 'light',
                      ),
                    ),
                    _buildMoodChip(
                      '⚡',
                      context.t('recipes.moods.highEnergy'),
                      _selectedMood == 'energy',
                      () => setState(
                        () => _selectedMood = _selectedMood == 'energy'
                            ? null
                            : 'energy',
                      ),
                    ),
                    _buildMoodChip(
                      '🍰',
                      context.t('recipes.moods.sweetCravings'),
                      _selectedMood == 'sweet',
                      () => setState(
                        () => _selectedMood = _selectedMood == 'sweet'
                            ? null
                            : 'sweet',
                      ),
                    ),
                    _buildMoodChip(
                      '🌶️',
                      context.t('recipes.moods.spicyFix'),
                      _selectedMood == 'spicy',
                      () => setState(
                        () => _selectedMood = _selectedMood == 'spicy'
                            ? null
                            : 'spicy',
                      ),
                    ),
                    _buildMoodChip(
                      '⏱️',
                      context.t('recipes.moods.quickBite'),
                      _selectedMood == 'quick',
                      () => setState(
                        () => _selectedMood = _selectedMood == 'quick'
                            ? null
                            : 'quick',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Time and Calories Sliders Side by Side
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.getCardShadow(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${context.t('recipes.time')}: ${_cookingTime}${context.t('recipes.min')}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _cookingTime.toDouble(),
                              min: 5,
                              max: 120,
                              divisions: 23,
                              onChanged: (value) =>
                                  setState(() => _cookingTime = value.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.getCardShadow(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 16,
                                  color: AppColors.genieGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${context.t('recipes.cal')}: $_targetCalories',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _targetCalories.toDouble(),
                              min: 100,
                              max: 1000,
                              divisions: 18,
                              onChanged: (value) => setState(
                                () => _targetCalories = value.toInt(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Cuisine Section
                Text(
                  context.t('recipes.cuisine'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMoodChip(
                      '🇵🇰',
                      context.t('recipes.cuisines.pakistani'),
                      _selectedCuisine == 'pakistani',
                      () => setState(
                        () => _selectedCuisine = _selectedCuisine == 'pakistani'
                            ? null
                            : 'pakistani',
                      ),
                    ),
                    _buildMoodChip(
                      '🇮🇳',
                      context.t('recipes.cuisines.indian'),
                      _selectedCuisine == 'indian',
                      () => setState(
                        () => _selectedCuisine = _selectedCuisine == 'indian'
                            ? null
                            : 'indian',
                      ),
                    ),
                    _buildMoodChip(
                      '🇮🇹',
                      context.t('recipes.cuisines.italian'),
                      _selectedCuisine == 'italian',
                      () => setState(
                        () => _selectedCuisine = _selectedCuisine == 'italian'
                            ? null
                            : 'italian',
                      ),
                    ),
                    _buildMoodChip(
                      '🥗',
                      context.t('recipes.cuisines.mediterranean'),
                      _selectedCuisine == 'mediterranean',
                      () => setState(
                        () => _selectedCuisine =
                            _selectedCuisine == 'mediterranean'
                            ? null
                            : 'mediterranean',
                      ),
                    ),
                    _buildMoodChip(
                      '🇹🇭',
                      context.t('recipes.cuisines.thai'),
                      _selectedCuisine == 'thai',
                      () => setState(
                        () => _selectedCuisine = _selectedCuisine == 'thai'
                            ? null
                            : 'thai',
                      ),
                    ),
                    _buildMoodChip(
                      '🇰🇷',
                      context.t('recipes.cuisines.korean'),
                      _selectedCuisine == 'korean',
                      () => setState(
                        () => _selectedCuisine = _selectedCuisine == 'korean'
                            ? null
                            : 'korean',
                      ),
                    ),
                    _buildMoodChip(
                      '🌮',
                      context.t('recipes.cuisines.middleEastern'),
                      _selectedCuisine == 'middleEastern',
                      () => setState(
                        () => _selectedCuisine =
                            _selectedCuisine == 'middleEastern'
                            ? null
                            : 'middleEastern',
                      ),
                    ),
                    _buildMoodChip(
                      '🇺🇸',
                      context.t('recipes.cuisines.american'),
                      _selectedCuisine == 'american',
                      () => setState(
                        () => _selectedCuisine = _selectedCuisine == 'american'
                            ? null
                            : 'american',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Diet Type Section
                Text(
                  context.t('recipes.diet.type'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMoodChip(
                      '⚖️',
                      context.t('recipes.diets.balanced'),
                      _selectedDiet == 'balanced',
                      () => setState(
                        () => _selectedDiet = _selectedDiet == 'balanced'
                            ? null
                            : 'balanced',
                      ),
                    ),
                    _buildMoodChip(
                      '🥑',
                      context.t('recipes.diets.keto'),
                      _selectedDiet == 'keto',
                      () => setState(
                        () => _selectedDiet = _selectedDiet == 'keto'
                            ? null
                            : 'keto',
                      ),
                    ),
                    _buildMoodChip(
                      '🌱',
                      context.t('recipes.diets.vegan'),
                      _selectedDiet == 'vegan',
                      () => setState(
                        () => _selectedDiet = _selectedDiet == 'vegan'
                            ? null
                            : 'vegan',
                      ),
                    ),
                    _buildMoodChip(
                      '🥗',
                      context.t('recipes.diets.vegetarian'),
                      _selectedDiet == 'vegetarian',
                      () => setState(
                        () => _selectedDiet = _selectedDiet == 'vegetarian'
                            ? null
                            : 'vegetarian',
                      ),
                    ),
                    _buildMoodChip(
                      '🕌',
                      context.t('recipes.diets.halal'),
                      _selectedDiet == 'halal',
                      () => setState(
                        () => _selectedDiet = _selectedDiet == 'halal'
                            ? null
                            : 'halal',
                      ),
                    ),
                    _buildMoodChip(
                      '🇵🇰',
                      context.t('recipes.diets.desi'),
                      _selectedDiet == 'desi',
                      () => setState(
                        () => _selectedDiet = _selectedDiet == 'desi'
                            ? null
                            : 'desi',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Health Goal Section
                Text(
                  context.t('recipes.health.goal'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMoodChip(
                      '📉',
                      context.t('recipes.goals.weightLoss'),
                      _selectedGoal == 'weightLoss',
                      () => setState(
                        () => _selectedGoal = _selectedGoal == 'weightLoss'
                            ? null
                            : 'weightLoss',
                      ),
                    ),
                    _buildMoodChip(
                      '💪',
                      context.t('recipes.goals.muscle'),
                      _selectedGoal == 'muscle',
                      () => setState(
                        () => _selectedGoal = _selectedGoal == 'muscle'
                            ? null
                            : 'muscle',
                      ),
                    ),
                    _buildMoodChip(
                      '⚖️',
                      context.t('recipes.goals.maintain'),
                      _selectedGoal == 'maintain',
                      () => setState(
                        () => _selectedGoal = _selectedGoal == 'maintain'
                            ? null
                            : 'maintain',
                      ),
                    ),
                    _buildMoodChip(
                      '⚡',
                      context.t('recipes.goals.energy'),
                      _selectedGoal == 'energy',
                      () => setState(
                        () => _selectedGoal = _selectedGoal == 'energy'
                            ? null
                            : 'energy',
                      ),
                    ),
                  ],
                ),
                // Limit Reached Banner (if limit reached)
                if (!canGenerateRecipe && !premiumProvider.isPremium)
                  _buildLimitReachedBanner(
                    context,
                    aiRecipeLimit,
                    aiRecipeCount,
                  ),
              ],
            ),
          ),
        ),
        // Fixed Generate Button (non-scrollable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: canGenerateRecipe && !isLoading
                    ? AppColors.gradientPrimary
                    : null,
                color: canGenerateRecipe && !isLoading
                    ? null
                    : Theme.of(context).cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: canGenerateRecipe && !isLoading
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (canGenerateRecipe && !isLoading)
                      ? _handleGenerate
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          color: (canGenerateRecipe && !isLoading)
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.4),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t('recipes.generate.recipe'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (canGenerateRecipe && !isLoading)
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodChip(
    String emoji,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.8),
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitReachedBanner(
    BuildContext context,
    int? limit,
    int recipeCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.geniePurple.withOpacity(0.15),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('recipes.limitReached') !=
                              'recipes.limitReached'
                          ? context.t('recipes.limitReached')
                          : context.t('scanner.limit.reached.title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (limit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.t('recipes.limit.reached.message', {
                          'limit': limit.toString(),
                        }),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        context.t('recipes.ai.recipe.disabled'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ProNavigation.tryOpen(context, replace: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ).copyWith(elevation: MaterialStateProperty.all(0)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.t('common.upgrade') != 'common.upgrade'
                          ? context.t('common.upgrade')
                          : context.t('common.upgrade'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String? emoji;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    this.emoji,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive font sizes
    final emojiSize = isSmallScreen ? 14.0 : 16.0;
    final labelFontSize = isSmallScreen ? 11.0 : 12.0;
    final countFontSize = isSmallScreen ? 10.0 : 11.0;
    final horizontalPadding = isSmallScreen ? 8.0 : 10.0;
    final verticalPadding = isSmallScreen ? 8.0 : 9.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.geniePurple, AppColors.geniePink],
                )
              : null,
          color: isSelected ? null : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.getCardShadow(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: TextStyle(fontSize: emojiSize)),
              SizedBox(width: isSmallScreen ? 6 : 7),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: isSmallScreen ? 4 : 5),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: countFontSize,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withOpacity(0.7),
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
