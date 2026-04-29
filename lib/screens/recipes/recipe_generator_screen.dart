import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs/app_dialogs.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';
import '../../data/models/recipe.dart';
import '../../providers/premium_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/loading_genie.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/recipe/recipe_card.dart';
import '../../widgets/recipe/recipe_grid_card.dart';
import '../../widgets/voice/voice_input_dialog.dart';

class RecipeGeneratorScreen extends StatefulWidget {
  final String? searchQuery;
  final String? category;
  final int initialTabIndex;
  final bool lockToAiGenerateTab;
  final bool showAsHomeTab;

  const RecipeGeneratorScreen({
    super.key,
    this.searchQuery,
    this.category,
    this.initialTabIndex = 0,
    this.lockToAiGenerateTab = false,
    this.showAsHomeTab = false,
  });

  @override
  State<RecipeGeneratorScreen> createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends State<RecipeGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _searchText = '';
  String? _selectedCategory;
  String? _selectedCuisine;
  String? _selectedDiet;
  String? _selectedGoal;
  String? _selectedMood;
  int _cookingTime = 30;
  int _targetCalories = 500;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _searchText = (widget.searchQuery ?? '').trim();
    _searchController.text = _searchText;
    if (widget.showAsHomeTab && widget.searchQuery != null) {
      _ingredientsController.text = widget.searchQuery!.trim();
    }
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _searchText) return;
      if (!mounted) return;
      setState(() => _searchText = next);
    });
    _trackCardScreenOpen();
  }

  /// Track when card screen is opened
  /// Track card screen open (ads removed - reserved for future ad plan)
  Future<void> _trackCardScreenOpen() async {}

  @override
  void dispose() {
    _searchController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  Future<void> _showVoiceInputDialog() async {
    final text = await showVoiceInputDialog(context);
    if (text != null && text.trim().isNotEmpty && mounted) {
      setState(() {
        final controller = widget.showAsHomeTab
            ? _ingredientsController
            : _searchController;
        controller.text = controller.text.isEmpty
            ? text.trim()
            : '${controller.text}, ${text.trim()}';
      });
    }
  }

  Future<void> _pickScanFromGallery() async {
    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.canUseScannerSync()) {
      ProNavigation.tryOpen(context, replace: false);
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        context.push('/scan-crop', extra: image);
      }
    } catch (_) {}
  }

  Future<void> _handleGenerate() async {
    final ingredients = _ingredientsController.text.trim();
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('recipes.enter.ingredients'))),
      );
      return;
    }

    if (!await ensureConnectedAndShowDialog(context)) return;

    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.isPremium && !premiumProvider.canGenerateAiRecipe()) {
      ProNavigation.tryOpen(context, replace: false);
      return;
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final recipeProvider = context.read<RecipeProvider>();

    final generatedRecipe = await recipeProvider.generateRecipe(
      ingredients: ingredients,
      cookingTime: _cookingTime,
      targetCalories: _targetCalories,
      cuisine: _selectedCuisine,
      dietType: _selectedDiet,
      healthGoal: _selectedGoal,
      mood: _selectedMood,
      language: languageCode,
    );

    if (generatedRecipe != null && !premiumProvider.isPremium) {
      premiumProvider.incrementAiRecipeCount();
    }
  }

  Future<void> _handleBack(BuildContext context) async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final premiumProvider = context.watch<PremiumProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Otherwise, go to Home (bottom nav index 0).
        context.go('/');
      },
      child: Scaffold(
        bottomNavigationBar: BottomNav(
          activeTab: widget.showAsHomeTab ? 'home' : 'recipes',
        ),
        body: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.gradientHeroDark
                    : (widget.showAsHomeTab
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFEAF4FF), Color(0xFFFFFFFF)],
                            )
                          : AppColors.gradientHero),
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
                    title: widget.showAsHomeTab
                        ? context.t('smartChefTitle')
                        : context.t('recipes.title'),
                    titleStyle: widget.showAsHomeTab
                        ? GoogleFonts.inter(
                            fontSize: 26,
                            height: 34 / 26,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1E2945),
                          )
                        : null,
                    showBack: !widget.showAsHomeTab,
                    onBack: widget.showAsHomeTab
                        ? null
                        : () => _handleBack(context),
                    backgroundColor: Colors.transparent,
                    statusBarColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1F35)
                        : const Color(0xFFEAF4FF),
                    rightContent: widget.showAsHomeTab
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => ProNavigation.tryOpen(
                                  context,
                                  replace: false,
                                ),
                                child: SizedBox(
                                  width: 70,
                                  height: 32,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFFFB301),
                                          Color(0xFFFD5C17),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.auto_awesome,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.t('smartChefPro'),
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              height: 1.0,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                onPressed: () => context.push('/settings'),
                                icon: const Icon(Icons.settings),
                                iconSize: 24,
                                color: const Color(0xFF5A6A7C),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                splashRadius: 16,
                              ),
                            ],
                          )
                        : null,
                  ),
                  Expanded(
                    child: widget.showAsHomeTab
                        ? _buildAiHomeTab(
                            context,
                            recipeProvider,
                            premiumProvider,
                          )
                        : _buildBrowseTab(context, recipeProvider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseTab(BuildContext context, RecipeProvider recipeProvider) {
    final searchText = _searchText.trim();

    // Filter recipes based on search or category
    List<Recipe> displayRecipes = [];
    if (searchText.isNotEmpty) {
      displayRecipes = recipeProvider.searchRecipes(searchText);
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
          // Search Bar
          _buildBrowseSearchBar(context),
          const SizedBox(height: 12),
          // Search Results Header
          if (searchText.isNotEmpty)
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
                            text: '"$searchText"',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _searchController.clear();
                        _searchText = '';
                      });
                    },
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
          if (searchText.isNotEmpty && displayRecipes.isEmpty)
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
                    '${context.t('recipes.try.other')} "$searchText"',
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
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _searchController.clear();
                        _searchText = '';
                      });
                    },
                    child: Text(context.t('recipes.clear.search')),
                  ),
                ],
              ),
            ),
          // Category Chips - hide when searching
          if (searchText.isEmpty)
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
          if (searchText.isEmpty) const SizedBox(height: 8),
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

  Widget _buildBrowseSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? AppColors.inputDark : AppColors.input;

    final hint =
        context.t('recipes.search.placeholder') != 'recipes.search.placeholder'
        ? context.t('recipes.search.placeholder')
        : 'Search recipes, ingredients...';

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.25)),
    );

    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fillColor,
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
          color: AppColors.primary,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchText.trim().isNotEmpty)
              IconButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _searchController.clear();
                    _searchText = '';
                  });
                },
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                splashRadius: 18,
                tooltip:
                    context.t('recipes.clear.search') != 'recipes.clear.search'
                    ? context.t('recipes.clear.search')
                    : 'Clear',
              ),
            IconButton(
              onPressed: _showVoiceInputDialog,
              icon: const Icon(Icons.mic, color: AppColors.primary, size: 20),
              splashRadius: 18,
              tooltip: context.t('recipes.voice'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.55)),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildAiHomeTab(
    BuildContext context,
    RecipeProvider recipeProvider,
    PremiumProvider premiumProvider,
  ) {
    final isLoading = recipeProvider.isLoading;
    final recipe = recipeProvider.recipe;
    final canGenerateRecipe =
        premiumProvider.isPremium || premiumProvider.canGenerateAiRecipe();
    final aiRecipeLimit = premiumProvider.getAiRecipeLimit();
    final aiRecipeCount = premiumProvider.aiRecipeCount;

    if (isLoading) {
      return const Center(child: LoadingGenie());
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSmartChefIngredientsCard(context),
                const SizedBox(height: 24),
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
                                  '${context.t('recipes.time')}: $_cookingTime${context.t('recipes.min')}',
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
                      '🌶️',
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
                if (!canGenerateRecipe && !premiumProvider.isPremium)
                  _buildLimitReachedBanner(
                    context,
                    aiRecipeLimit,
                    aiRecipeCount,
                  ),
                const SizedBox(height: 12),
                if (recipe != null)
                  RecipeCard(
                    title: recipe.title,
                    image: recipe.image,
                    time: recipe.time,
                    servings: recipe.servings,
                    calories: recipe.calories,
                    tags: recipe.tags,
                    hideImage: true,
                    onTap: () => context.push('/ai-recipe', extra: recipe),
                  ),
              ],
            ),
          ),
        ),
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
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: canGenerateRecipe ? AppColors.gradientPrimary : null,
                    color: canGenerateRecipe
                        ? null
                        : Theme.of(context).cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: canGenerateRecipe ? _handleGenerate : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              color: canGenerateRecipe
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
                                color: canGenerateRecipe
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

  Widget _buildSmartChefIngredientsCard(BuildContext context) {
    final dir = Directionality.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const rightImageReserve = 147.97;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF111827),
                  Color(0xFF020617),
                ],
              )
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFDFF0FB), Color(0xFFDBEDFF), Color(0xFFD8EEEC)],
                stops: [0.0, 0.45, 1.0],
                transform: GradientRotation(0.954),
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x804994FE), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              left: -70,
              bottom: -90,
              child: IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.6, 0.6),
                        radius: 0.9,
                        colors: [
                          Color(0x664994FE),
                          Color(0x1A8FD3FF),
                          Color(0x004994FE),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/home_corner.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17.46, 27.19, 17.46, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: rightImageReserve),
                    child: SizedBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('smartChefWhatIngredientsLine1'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: dir == TextDirection.rtl
                                ? TextAlign.right
                                : TextAlign.left,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              height: 1.15,
                              letterSpacing: -0.15,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? Colors.white : const Color(0xFF1E1E3A),
                            ),
                          ),
                          Text(
                            context.t('smartChefWhatIngredientsLine2'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: dir == TextDirection.rtl
                                ? TextAlign.right
                                : TextAlign.left,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              height: 1.15,
                              letterSpacing: -0.15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF4290FE),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: rightImageReserve),
                    child: Text(
                      context.t('smartChefSubtitle'),
                      textAlign: dir == TextDirection.rtl
                          ? TextAlign.left
                          : TextAlign.left,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withOpacity(0.75)
                            : const Color(0xFF6264A0),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, right: 9.73),
                    child: SizedBox(
                      height: 96.95,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xB3FFFFFF),
                          borderRadius: BorderRadius.circular(19.55),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              offset: Offset(0, 10),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(19.55),
                          border: Border.all(
                            color: const Color(0xFFB8D7FF),
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19.55),
                          child: TextField(
                            controller: _ingredientsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: context.t('smartChefIngredientsHint'),
                              border: InputBorder.none,
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              disabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              errorBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              focusedErrorBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                onPressed: _showVoiceInputDialog,
                                icon: const Icon(
                                  Icons.mic,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                splashRadius: 18,
                                tooltip: context.t('recipes.voice'),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF8A8FB0),
                              ),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E1E3A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, right: 9.73),
                    child: Row(
                      children: [
                        Expanded(
                          child: _smartChefPillButton(
                            icon: Icons.camera_alt,
                            label: context.t('recipes.scan'),
                            onTap: () => context.push('/scan-camera'),
                            height: 50.69,
                            radius: 25.3431,
                            background: const Color(0xFF4994FE),
                            outlined: false,
                            elevation: 8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _smartChefPillButton(
                            icon: Icons.photo_library_outlined,
                            label: context.t('common.gallery'),
                            onTap: _pickScanFromGallery,
                            height: 50.69,
                            radius: 25.3431,
                            outlined: true,
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
      ),
    );
  }

  Widget _smartChefPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool outlined = false,
    double height = 36,
    double radius = 20,
    Color background = const Color(0xFF5A98FD),
    double elevation = 0,
  }) {
    final bg = outlined ? Colors.white : background;
    final fg = outlined ? background : Colors.white;
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          shadowColor: const Color(0x33000000),
          side: outlined
              ? BorderSide(color: background.withOpacity(0.35), width: 1.2)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.0,
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
              onPressed: () => ProNavigation.tryOpen(context, replace: false),
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
              ).copyWith(elevation: WidgetStateProperty.all(0)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(16),
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
                      context.t('common.upgrade'),
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
          if (limit != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$recipeCount/$limit',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
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
