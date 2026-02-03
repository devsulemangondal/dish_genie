import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/recipe/recipe_image_widget.dart';
import '../../services/storage_service.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../data/models/recipe.dart';
import '../../data/models/meal_plan.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _favorites = [];
  List<String> _saved = [];
  List<MealPlan> _mealPlans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final favorites = await StorageService.getFavorites();
    final saved = await StorageService.getSavedRecipes();

    // Load meal plans
    final mealPlanProvider = context.read<MealPlanProvider>();
    final currentPlan = mealPlanProvider.currentMealPlan;
    if (currentPlan != null) {
      _mealPlans = [currentPlan];
    }

    setState(() {
      _favorites = favorites;
      _saved = saved;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // If Favorites was opened via push(), pop back. Otherwise fall back to Home.
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.gradientHeroDark
                    : AppColors.gradientHero,
              ),
            ),
            const FloatingSparkles(),
            Column(
              children: [
                StickyHeader(
                  title: context.t('favorites.title'),
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
                ),
                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final isSmallScreen = screenWidth < 360;
                      final isVerySmallScreen = screenWidth < 320;
                      final showText = screenWidth >= 320;
                      
                      return TabBar(
                        isScrollable: false,
                        tabAlignment: TabAlignment.fill,
                        padding: EdgeInsets.all(isSmallScreen ? 2.0 : 4.0),
                        controller: _tabController,
                        labelColor: Theme.of(context).colorScheme.onPrimary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                        indicator: BoxDecoration(
                          gradient: AppColors.getGradientPrimary(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: TextStyle(
                          fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                                  ),
                                  if (showText) ...[
                                    SizedBox(width: isVerySmallScreen ? 2 : 4),
                                    Text(
                                      '${_favorites.length}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bookmark,
                                    size: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                                  ),
                                  if (showText) ...[
                                    SizedBox(width: isVerySmallScreen ? 2 : 4),
                                    Text(
                                      '${_saved.length}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                                  ),
                                  if (showText) ...[
                                    SizedBox(width: isVerySmallScreen ? 2 : 4),
                                    Text(
                                      context.t('favorites.plans'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shopping_cart,
                                    size: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                                  ),
                                  if (showText) ...[
                                    SizedBox(width: isVerySmallScreen ? 2 : 4),
                                    Text(
                                      context.t('common.shop'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 11 : 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFavoritesTab(context),
                            _buildSavedTab(context),
                            _buildMealPlansTab(context),
                            _buildGroceryListsTab(context),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFromFavorites(String slug) async {
    final favorites = await StorageService.getFavorites();
    favorites.remove(slug);
    await StorageService.saveFavorites(favorites);
    await _loadData();
  }

  Future<void> _removeFromSaved(String slug) async {
    final saved = await StorageService.getSavedRecipes();
    saved.remove(slug);
    await StorageService.saveSavedRecipes(saved);
    await _loadData();
  }

  Widget _buildFavoritesTab(BuildContext context) {
    if (_favorites.isEmpty) {
      return _buildEmptyState(
        context,
        context.t('favorites.no.favorites'),
        context.t('favorites.no.favorites.hint'),
        Icons.favorite_border,
        () => context.go('/recipes'),
        context.t('favorites.browse.recipes'),
      );
    }

    final recipeProvider = context.read<RecipeProvider>();
    final recipes = _favorites
        .map((slug) => recipeProvider.getRecipeBySlug(slug))
        .where((recipe) => recipe != null)
        .cast<Recipe>()
        .toList();

    return _buildRecipesList(context, recipes, _removeFromFavorites);
  }

  Widget _buildSavedTab(BuildContext context) {
    if (_saved.isEmpty) {
      return _buildEmptyState(
        context,
        context.t('favorites.no.saved'),
        context.t('favorites.no.saved.hint'),
        Icons.bookmark_border,
        () => context.go('/recipes'),
        context.t('favorites.browse.recipes'),
      );
    }

    final recipeProvider = context.read<RecipeProvider>();
    final recipes = _saved
        .map((slug) => recipeProvider.getRecipeBySlug(slug))
        .where((recipe) => recipe != null)
        .cast<Recipe>()
        .toList();

    return _buildRecipesList(context, recipes, _removeFromSaved);
  }

  Widget _buildMealPlansTab(BuildContext context) {
    if (_mealPlans.isEmpty) {
      return _buildEmptyState(
        context,
        context.t('favorites.no.meal.plans'),
        context.t('favorites.no.meal.plans.hint'),
        Icons.calendar_today_outlined,
        () => context.go('/planner'),
        context.t('favorites.create.meal.plan'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mealPlans.length,
      itemBuilder: (context, index) {
        final plan = _mealPlans[index];
        return _buildMealPlanCard(context, plan);
      },
    );
  }

  Widget _buildGroceryListsTab(BuildContext context) {
    final groceryProvider = context.watch<GroceryProvider>();
    final groceryList = groceryProvider.groceryList;

    if (groceryList == null || groceryList.items.isEmpty) {
      return _buildEmptyState(
        context,
        context.t('favorites.no.grocery'),
        context.t('favorites.no.grocery.hint'),
        Icons.shopping_cart_outlined,
        () => context.go('/grocery'),
        context.t('favorites.go.to.grocery'),
      );
    }

    final checkedItems = groceryList.items.where((i) => i.checked).length;
    final totalItems = groceryList.items.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.genieGold, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    color: Theme.of(context).cardColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groceryList.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$checkedItems/$totalItems ${context.t('favorites.checked.items')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Est. ${groceryList.estimatedCost}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalItems ${context.t('grocery.items')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // If the list has an ID, navigate to saved list detail screen
                          // Otherwise, navigate to main grocery screen
                          if (groceryList.id != null &&
                              groceryList.id!.isNotEmpty) {
                            context.go('/grocery/${groceryList.id}');
                          } else {
                            context.go('/grocery');
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              context.t('grocery.view.list'),
                              style: TextStyle(
                                color: Theme.of(context).cardColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    groceryProvider.clearList();
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: BorderSide(
                      color: AppColors.destructive.withOpacity(0.3),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesList(
    BuildContext context,
    List<Recipe> recipes,
    Function(String) onRemove,
  ) {
    if (recipes.isEmpty) {
      return _buildEmptyState(
        context,
        context.t('favorites.no.favorites'),
        context.t('favorites.no.favorites.hint'),
        Icons.restaurant_menu_outlined,
        () => context.go('/recipes'),
        context.t('favorites.browse.recipes'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _buildRecipeCard(
          context,
          recipe,
          () => onRemove(recipe.slug ?? recipe.id),
        );
      },
    );
  }

  Widget _buildRecipeCard(
    BuildContext context,
    Recipe recipe,
    VoidCallback onRemove,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/recipe/${recipe.slug ?? recipe.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120, // Reduced from 128 to save space
                  width: double.infinity,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: RecipeImageWidget(
                          image: recipe.image,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            height: 120,
                            color: AppColors.muted,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: Container(
                            height: 120,
                            color: AppColors.muted,
                            child: const Icon(Icons.restaurant_menu),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.foreground.withOpacity(0.4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${recipe.time} • ${recipe.calories} cal',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRemove,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: BorderSide(
                    color: AppColors.destructive.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      context.t('common.remove'),
                      style: const TextStyle(fontSize: 11),
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

  Widget _buildMealPlanCard(BuildContext context, MealPlan plan) {
    final days = plan.endDate.difference(plan.startDate).inDays + 1;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).cardColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('favorites.created.recently'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${plan.dailyCalories} ${context.t('favorites.cal.per.day')}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$days ${context.t('meal.planner.days')}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${plan.meals.length} meals',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        context.read<MealPlanProvider>().setMealPlan(plan);
                        context.go('/planner');
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            context.t('favorites.view.plan'),
                            style: TextStyle(
                              color: Theme.of(context).cardColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  // TODO: Implement delete meal plan
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: BorderSide(
                    color: AppColors.destructive.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                child: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String hint,
    IconData icon,
    VoidCallback onTap,
    String buttonText,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GenieMascot(size: GenieMascotSize.md),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          buttonText,
                          style: TextStyle(
                            color: Theme.of(context).cardColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
}
