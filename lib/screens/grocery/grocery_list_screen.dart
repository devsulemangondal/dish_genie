import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/loading_genie.dart';
import '../../widgets/ads/screen_native_ad_widget.dart';
import '../../widgets/ads/custom_native_ad_widget.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../data/models/grocery_item.dart';
import '../../data/models/grocery_list.dart';
import '../../services/voice_service.dart';
import '../../services/grocery_service.dart';
import '../../providers/premium_provider.dart';
import '../../services/card_ad_tracker.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import 'widgets/grocery_quick_actions.dart';

class GroceryListScreen extends StatefulWidget {
  final bool fromPlan;

  const GroceryListScreen({super.key, this.fromPlan = false});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  String _searchQuery = '';
  bool _isBudgetMode = false;
  bool _isShoppingMode = false;
  bool _isVoiceListening = false;
  String? _selectedCategory;
  int _selectedTab = 0; // 0: Home, 1: List, 2: Add
  final TextEditingController _quickAddController = TextEditingController();
  bool _isCategoryGridView = true;
  final Map<String, bool> _expandedCategories = {};
  final Set<String> _dismissedSmartSuggestions = {};

  bool _hasLoadedSavedLists = false;

  @override
  void initState() {
    super.initState();
    // If coming from meal plan, start on the List tab to show the generated items
    if (widget.fromPlan) {
      _selectedTab = 1;
    }
    // Defer heavy operations to after first frame to improve initial load time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only check for meal plan if needed (don't block UI)
      _checkForMealPlan();
      // Defer non-critical operations to improve initial load
      // Voice service and ad tracking can happen after UI is shown
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          VoiceService.initialize();
          _trackCardScreenOpen();
        }
      });
    });
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
    _searchController.dispose();
    _itemNameController.dispose();
    _quantityController.dispose();
    _budgetController.dispose();
    _quickAddController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _handleBack() async {
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
                    if (mounted) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    }
                  },
                  onAdFailedToShow: (ad) {
                    // Reset counter even if ad fails to show
                    CardAdTracker.resetCardBackCount();
                    if (mounted) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    }
                  },
                );
                // Don't pop immediately, wait for ad callback
                return;
              }
            }
          } catch (e) {
            // If parsing fails, just pop
          }
        }
      }
    }

    // If no ad should be shown, pop normally
    // Use pop() if possible to properly remove from stack and let BackButtonHandler work
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        // Navigate to home - BackButtonHandler will handle exit confirmation on next back press
        context.go('/');
      }
    }
  }

  Future<void> _checkForMealPlan() async {
    // Only check if coming from meal plan or if no list exists
    // Skip if we already have a list to avoid unnecessary API calls
    final groceryProvider = context.read<GroceryProvider>();

    // Wait a bit for storage to load first (non-blocking)
    // This allows UI to show immediately with cached data
    await Future.delayed(const Duration(milliseconds: 100));

    // If we have a list and not coming from plan, skip
    if (!widget.fromPlan && groceryProvider.groceryList != null) {
      return;
    }

    final mealPlanProvider = context.read<MealPlanProvider>();
    final mealPlan = mealPlanProvider.currentMealPlan;

    // Match web app: send mealPlan object directly
    if (mealPlan != null && mealPlan.meals.isNotEmpty) {
      // If coming from meal planner (fromPlan=true), always regenerate the list
      // Otherwise, only generate if list doesn't exist
      if (widget.fromPlan) {
        // Always regenerate when coming from meal plan to ensure fresh list
        await groceryProvider.generateGroceryList(
          mealPlan: mealPlan,
          pantryItems: [],
          budgetMode: _isBudgetMode,
          budget: _isBudgetMode && _budgetController.text.isNotEmpty
              ? _budgetController.text
              : null,
        );
      } else if (groceryProvider.groceryList == null) {
        // Only generate if no list exists and not from plan
        await groceryProvider.generateGroceryList(
          mealPlan: mealPlan,
          pantryItems: [],
          budgetMode: _isBudgetMode,
          budget: _isBudgetMode && _budgetController.text.isNotEmpty
              ? _budgetController.text
              : null,
        );
      }
    }
  }

  Future<void> _handleQuickGenerate() async {
    final mealPlanProvider = context.read<MealPlanProvider>();
    final mealPlan = mealPlanProvider.currentMealPlan;
    final groceryProvider = context.read<GroceryProvider>();

    if (mealPlan != null && mealPlan.meals.isNotEmpty) {
      // If meal plan exists, use it
      await groceryProvider.generateGroceryList(
        mealPlan: mealPlan,
        pantryItems: [],
        budgetMode: _isBudgetMode,
        budget: _isBudgetMode && _budgetController.text.isNotEmpty
            ? _budgetController.text
            : null,
      );
    } else {
      // Generate demo list with sample recipes (matching web app)
      await groceryProvider.generateGroceryList(
        recipes: [
          {
            'title': context.t('grocery.demo.recipe.chicken.biryani'),
            'ingredients': [
              'basmati rice',
              'chicken',
              'yogurt',
              'onions',
              'tomatoes',
              'ginger',
              'garlic',
              'biryani spices',
              'saffron',
              'ghee',
            ],
          },
          {
            'title': context.t('grocery.demo.recipe.dal.makhani'),
            'ingredients': [
              'black lentils',
              'kidney beans',
              'butter',
              'cream',
              'tomatoes',
              'onions',
              'ginger',
              'garlic',
              'cumin',
              'garam masala',
            ],
          },
          {
            'title': context.t('grocery.demo.recipe.aloo.paratha'),
            'ingredients': [
              'whole wheat flour',
              'potatoes',
              'green chilies',
              'coriander',
              'cumin seeds',
              'ghee',
              'salt',
            ],
          },
        ],
        pantryItems: [],
        budgetMode: _isBudgetMode,
        budget: _isBudgetMode && _budgetController.text.isNotEmpty
            ? _budgetController.text
            : null,
      );
    }
    // Switch to list tab after generating (matching web app)
    if (mounted) {
      setState(() => _selectedTab = 1);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isVoiceListening) {
      await VoiceService.stop();
      setState(() {
        _isVoiceListening = false;
      });
    } else {
      setState(() {
        _isVoiceListening = true;
      });

      await VoiceService.listen(
        onResult: (text) {
          final items = text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          final provider = context.read<GroceryProvider>();
          provider.addItemsByName(items);
          setState(() {
            _isVoiceListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${items.length} ${context.t('grocery.added')}'),
              backgroundColor: AppColors.primary,
            ),
          );
        },
        onDone: () {
          setState(() {
            _isVoiceListening = false;
          });
        },
        onError: (error) {
          setState(() {
            _isVoiceListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.t('common.error')}: $error'),
              backgroundColor: AppColors.destructive,
            ),
          );
        },
      );
    }
  }

  Future<void> _shareList(BuildContext context, GroceryList list) async {
    if (list.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('grocery.no.items.to.share')),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    try {
      final listText = list.items
          .map(
            (item) =>
                '${item.checked ? '✓' : '○'} ${item.name}${item.quantity.isNotEmpty ? ' (${item.quantity})' : ''}',
          )
          .join('\n');
      final shareText =
          '🛒 ${context.t('grocery.my.grocery.list')}\n\n$listText\n\n${context.t('grocery.total')}: ${list.items.length} ${context.t('grocery.items')}';

      await Share.share(
        shareText,
        subject: context.t('grocery.my.grocery.list'),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('grocery.list.shared')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t('common.error')}: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _saveList(BuildContext context, GroceryList list) async {
    if (list.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('grocery.no.items.to.save')),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    try {
      final provider = context.read<GroceryProvider>();
      final dateStr = DateTime.now().toLocal().toString().split(' ')[0];
      await provider.saveCurrentList('${context.t('grocery.saved')} $dateStr');

      // Reload saved lists to ensure UI is updated
      await provider.loadSavedLists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('grocery.list.saved')),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Provide user-friendly error message
        final errorMessage = e.toString().contains('No grocery list')
            ? context.t('grocery.no.items.to.save')
            : '${context.t('common.error')}: Failed to save list. Please try again.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.destructive,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAddItemDialog() {
    _itemNameController.clear();
    _quantityController.clear();
    _selectedCategory = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('grocery.add.item')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(
                  labelText: context.t('grocery.item.name'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: context.t('grocery.quantity'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: context.t('grocery.category'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items:
                    [
                          context.t('grocery.produce'),
                          context.t('grocery.protein'),
                          context.t('grocery.dairy'),
                          context.t('grocery.pantry'),
                          context.t('grocery.frozen'),
                          context.t('grocery.grains'),
                          context.t('grocery.other'),
                        ]
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_itemNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t('grocery.item.required')),
                    backgroundColor: AppColors.destructive,
                  ),
                );
                return;
              }

              final provider = context.read<GroceryProvider>();
              if (provider.groceryList == null) {
                // Create new list
                await provider.setGroceryList(
                  GroceryList(
                    name: context.t('grocery.list'),
                    estimatedCost: '\$0',
                    items: [],
                    categoriesSummary: {},
                    budgetTips: [],
                    mealPrepOrder: [],
                  ),
                );
              }

              final item = GroceryItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _itemNameController.text.trim(),
                quantity: _quantityController.text.trim().isEmpty
                    ? '1'
                    : _quantityController.text.trim(),
                unit: '',
                category:
                    _selectedCategory ??
                    GroceryService.detectCategory(
                      _itemNameController.text.trim(),
                    ),
                checked: false,
              );

              await provider.addItem(item);
              if (context.mounted) {
                Navigator.pop(context);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.t('grocery.item.added')),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: Text(context.t('grocery.add.to.list')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groceryProvider = context.watch<GroceryProvider>();
    final groceryList = groceryProvider.groceryList;
    final isLoading = groceryProvider.isLoading;
    final cartCount = groceryList?.items.length ?? 0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Check if we're actually on the grocery route before handling
          // This prevents interference when navigating away
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            String? currentPath;
            try {
              final routerState = GoRouterState.of(context);
              currentPath = routerState.uri.path;
            } catch (_) {
              try {
                currentPath =
                    router.routerDelegate.currentConfiguration.uri.path;
              } catch (_) {
                currentPath = null;
              }
            }

            // Only handle back if we're actually on a grocery route
            if (currentPath != null && currentPath.startsWith('/grocery')) {
              await _handleBack();
            }
            // If not on grocery route, let BackButtonHandler handle it
          } else {
            // If no router, handle it anyway (fallback)
            await _handleBack();
          }
        }
      },
      child: Scaffold(
        bottomNavigationBar: const BottomNav(activeTab: 'grocery'),
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
            SafeArea(
              child: Column(
                children: [
                  StickyHeader(
                    title: context.t('grocery.title'),
                    onBack: _handleBack,
                    rightContent: _buildCartBadge(context, cartCount),
                    backgroundColor: Colors.transparent,
                    statusBarColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1F35)
                        : AppColors.genieBlush,
                  ),
                  // Tab Navigation
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: EdgeInsets.all(4),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.getCardShadow(context),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            context,
                            context.t('grocery.home'),
                            0,
                            null,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            context,
                            cartCount > 0
                                ? '${context.t('grocery.list')} ($cartCount)'
                                : context.t('grocery.list'),
                            1,
                            null,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            context,
                            context.t('grocery.add'),
                            2,
                            null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildHomeTab(
                          context,
                          groceryProvider,
                          groceryList,
                          isLoading,
                        ),
                        _buildListTab(
                          context,
                          groceryProvider,
                          groceryList,
                          isLoading,
                        ),
                        _buildAddTab(context, groceryProvider),
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

  Widget _buildCartBadge(BuildContext context, int count) {
    return GestureDetector(
      onTap: () {
        if (_selectedTab != 1) {
          setState(() {
            _selectedTab = 1;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, GroceryProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              context.t('grocery.no.items.yet'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t('grocery.no.items.hint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showAddItemDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add),
                  const SizedBox(width: 8),
                  Text(context.t('grocery.add.item')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroceryList(
    BuildContext context,
    GroceryList list,
    GroceryProvider provider,
  ) {
    final itemsByCategory = provider.getItemsByCategory();

    // Filter out checked items when shop mode is enabled
    Map<String, List<GroceryItem>> shopModeFiltered = itemsByCategory;
    if (_isShoppingMode) {
      shopModeFiltered = <String, List<GroceryItem>>{};
      for (final entry in itemsByCategory.entries) {
        final uncheckedItems = entry.value
            .where((item) => !item.checked)
            .toList();
        if (uncheckedItems.isNotEmpty) {
          shopModeFiltered[entry.key] = uncheckedItems;
        }
      }
    }

    final filteredItems = _searchQuery.isEmpty
        ? shopModeFiltered
        : _filterItemsBySearch(shopModeFiltered);
    final checkedCount = list.items.where((i) => i.checked).length;
    final totalCount = list.items.length;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Mode Card (matches webapp design)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: MediaQuery.of(context).size.width < 360 ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.getCardShadow(context),
            ),
            child: Row(
              children: [
                // Shop Mode Button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          setState(() => _isShoppingMode = !_isShoppingMode),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: _isShoppingMode
                              ? AppColors.gradientPrimary
                              : null,
                          color: _isShoppingMode ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: _isShoppingMode
                              ? null
                              : Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              size: 16,
                              color: _isShoppingMode
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isShoppingMode
                                  ? context.t('grocery.shopping.mode')
                                  : context.t('grocery.shop.mode'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isShoppingMode
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Share and Save icons
                IconButton(
                  icon: Icon(Icons.share_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _shareList(context, list),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.bookmark_border, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _saveList(context, list),
                ),
              ],
            ),
          ),
          // Progress Bar
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$checkedCount/$totalCount ${context.t('grocery.items')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          // Budget Mode Card (matches webapp design)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: MediaQuery.of(context).size.width < 360 ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.getCardShadow(context),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      color: AppColors.genieGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.t('grocery.budget.mode'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Toggle button showing ON/OFF
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _isBudgetMode = !_isBudgetMode),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: _isBudgetMode
                                ? AppColors.gradientPrimary
                                : null,
                            color: _isBudgetMode ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: _isBudgetMode
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _isBudgetMode
                                ? context.t('grocery.on')
                                : context.t('grocery.off'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isBudgetMode
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Budget input field when enabled
                if (_isBudgetMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: context.t('grocery.budget.placeholder'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: AppColors.genieGold,
                        size: 20,
                      ),
                    ),
                  ),
                ],
                // Budget Tips
                if (_isBudgetMode && list.budgetTips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...list.budgetTips.map(
                    (tip) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.genieGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.genieGold.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.genieGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Add Item Input Field
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickAddController,
                    decoration: InputDecoration(
                      hintText: context.t('grocery.add.item.hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        provider.addItemsByName([value.trim()]);
                        _quickAddController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (_quickAddController.text.trim().isNotEmpty) {
                          provider.addItemsByName([
                            _quickAddController.text.trim(),
                          ]);
                          _quickAddController.clear();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Shop Native Ad (Small)
          const ScreenNativeAdWidget(
            screenKey: 'shop',
            size: CustomNativeAdSize.small,
          ),
          const SizedBox(height: 16),
          // Empty state for shop mode when all items are checked
          if (_isShoppingMode && filteredItems.isEmpty && _searchQuery.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppColors.primary.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All items checked!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ve checked off all items. Great job!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          // Categories
          else if (filteredItems.isNotEmpty)
            ...filteredItems.entries.map((entry) {
              return _buildCategorySection(
                context,
                entry.key,
                entry.value,
                provider,
              );
            }),
          if (filteredItems.isEmpty && _searchQuery.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '${context.t('grocery.no.items.found')} "$_searchQuery"',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Estimated Total Card
          if (list.items.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: MediaQuery.of(context).size.width < 360 ? 12 : 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.genieGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.genieGold.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.t('grocery.estimated.total'),
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360
                          ? 14
                          : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    list.estimatedCost,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360
                          ? 16
                          : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.genieGold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<GroceryItem>> _filterItemsBySearch(
    Map<String, List<GroceryItem>> itemsByCategory,
  ) {
    final filtered = <String, List<GroceryItem>>{};
    final query = _searchQuery.toLowerCase();

    for (final entry in itemsByCategory.entries) {
      final matchingItems = entry.value
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
      if (matchingItems.isNotEmpty) {
        filtered[entry.key] = matchingItems;
      }
    }

    return filtered;
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<GroceryItem> items,
    GroceryProvider provider,
  ) {
    final checkedCount = items.where((i) => i.checked).length;
    final totalCount = items.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isExpanded = _expandedCategories[category] ?? true;

    // Get category icon
    IconData categoryIcon = _getCategoryIcon(category);
    Color categoryColor = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategories[category] = !isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  Icon(
                    categoryIcon,
                    color: categoryColor,
                    size: isSmallScreen ? 18 : 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalizeCategory(category),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$checkedCount/$totalCount ${context.t('grocery.items')}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$checkedCount/$totalCount',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Column(
                children: items
                    .map(
                      (item) =>
                          _buildGroceryItemInCategory(context, item, provider),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('produce') ||
        cat.contains('vegetable') ||
        cat.contains('fruit')) {
      return '🥬';
    } else if (cat.contains('protein') ||
        cat.contains('meat') ||
        cat.contains('chicken')) {
      return '🍖';
    } else if (cat.contains('dairy')) {
      return '🥛';
    } else if (cat.contains('frozen')) {
      return '❄️';
    } else if (cat.contains('pantry')) {
      return '🥫';
    } else {
      return '🛒';
    }
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('produce') ||
        cat.contains('vegetable') ||
        cat.contains('fruit')) {
      return Icons.local_florist;
    } else if (cat.contains('protein') ||
        cat.contains('meat') ||
        cat.contains('chicken')) {
      return Icons.set_meal;
    } else if (cat.contains('dairy')) {
      return Icons.local_drink;
    } else if (cat.contains('frozen')) {
      return Icons.ac_unit;
    } else if (cat.contains('pantry')) {
      return Icons.kitchen;
    } else {
      return Icons.shopping_cart;
    }
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('produce') ||
        cat.contains('vegetable') ||
        cat.contains('fruit')) {
      return Colors.green;
    } else if (cat.contains('protein') ||
        cat.contains('meat') ||
        cat.contains('chicken')) {
      return Colors.red;
    } else if (cat.contains('dairy')) {
      return Colors.blue;
    } else if (cat.contains('frozen')) {
      return Colors.cyan;
    } else if (cat.contains('pantry')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildGroceryItemInCategory(
    BuildContext context,
    GroceryItem item,
    GroceryProvider provider,
  ) {
    return _buildGroceryItemCard(
      context,
      item,
      provider,
      hasHorizontalMargin: false,
    );
  }

  Widget _buildGroceryItemCard(
    BuildContext context,
    GroceryItem item,
    GroceryProvider provider, {
    required bool hasHorizontalMargin,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    // Generate price range if not present
    String priceRange = item.estimatedPrice ?? _generatePriceRange(item.name);

    return Container(
      // Use a border instead of card styling to avoid nested cards
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: item.checked,
            onChanged: (value) => provider.toggleItem(item.id),
            activeColor: AppColors.primary,
            shape: const CircleBorder(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: item.checked
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${item.quantity} • $priceRange',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.destructive.withOpacity(0.7),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              provider.removeItem(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} ${context.t('common.remove')}'),
                  backgroundColor: AppColors.destructive,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _capitalizeCategory(String category) {
    if (category.isEmpty) return category;
    // Capitalize first letter and handle multi-word categories
    final words = category.split(' ');
    return words
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _generatePriceRange(String itemName) {
    // Simple price estimation based on item name
    final name = itemName.toLowerCase();
    if (name.contains('chicken') ||
        name.contains('meat') ||
        name.contains('beef')) {
      return '\$2-5';
    } else if (name.contains('milk') ||
        name.contains('cheese') ||
        name.contains('yogurt')) {
      return '\$3-6';
    } else if (name.contains('bread') ||
        name.contains('rice') ||
        name.contains('pasta')) {
      return '\$1-3';
    } else if (name.contains('vegetable') ||
        name.contains('fruit') ||
        name.contains('produce')) {
      return '\$1-4';
    } else {
      return '\$2-5';
    }
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    int index,
    IconData? icon,
  ) {
    final isSelected = _selectedTab == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = isSmallScreen ? 12.0 : 14.0;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.gradientPrimary : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    GroceryProvider provider,
    GroceryList? list,
    bool isLoading,
  ) {
    // Lazy load saved lists only when Home tab is viewed
    if (!_hasLoadedSavedLists) {
      _hasLoadedSavedLists = true;
      // Load saved lists asynchronously without blocking UI
      Future.microtask(() => provider.loadSavedLists());
    }

    // Only show loading for API calls, not storage loads
    if (isLoading) {
      return const LoadingGenie();
    }

    final itemsByCategory = provider.getItemsByCategory();
    final currentItems = list?.items ?? const <GroceryItem>[];

    int countFor(String categoryKey) {
      final lower = categoryKey.toLowerCase();
      return itemsByCategory.entries
          .where((e) => e.key.toLowerCase().contains(lower))
          .fold<int>(0, (sum, e) => sum + e.value.length);
    }

    bool hasItemNamed(String name) {
      final n = name.trim().toLowerCase();
      return currentItems.any((i) => i.name.trim().toLowerCase() == n);
    }

    Future<void> addSuggestion(String itemName) async {
      provider.addItemsByName([itemName]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$itemName ${context.t('grocery.added')}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() {});
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          GroceryQuickActions(
            onAddTap: () => setState(() => _selectedTab = 2),
            onWeeklyListTap: _handleQuickGenerate,
          ),
          const SizedBox(height: 24),

          // Voice Assistant
          _buildVoiceAssistantCard(context),
          const SizedBox(height: 24),

          // Categories Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('grocery.categories'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              // View Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _buildViewToggleOption(
                      context,
                      icon: Icons.grid_view_rounded,
                      isSelected: _isCategoryGridView,
                      onTap: () => setState(() => _isCategoryGridView = true),
                    ),
                    const SizedBox(width: 4),
                    _buildViewToggleOption(
                      context,
                      icon: Icons.view_list_rounded,
                      isSelected: !_isCategoryGridView,
                      onTap: () => setState(() => _isCategoryGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Categories
          if (_isCategoryGridView)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount:
                  3, // Changed to 3 to better match typical mobile design and allow bigger cards
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildCategoryCard(
                  context,
                  emoji: _getCategoryEmoji('produce'),
                  label: context.t('grocery.produce'),
                  badgeCount: countFor('produce'),
                  onTap: () => setState(() {
                    _selectedCategory = 'produce';
                    _selectedTab = 2;
                  }),
                ),
                _buildCategoryCard(
                  context,
                  emoji: _getCategoryEmoji('protein'),
                  label: context.t('grocery.protein'),
                  badgeCount: countFor('protein'),
                  onTap: () => setState(() {
                    _selectedCategory = 'protein';
                    _selectedTab = 2;
                  }),
                ),
                _buildCategoryCard(
                  context,
                  emoji: _getCategoryEmoji('dairy'),
                  label: context.t('grocery.dairy'),
                  badgeCount: countFor('dairy'),
                  onTap: () => setState(() {
                    _selectedCategory = 'dairy';
                    _selectedTab = 2;
                  }),
                ),
                _buildCategoryCard(
                  context,
                  emoji: _getCategoryEmoji('pantry'),
                  label: context.t('grocery.pantry'),
                  badgeCount: countFor('pantry'),
                  onTap: () => setState(() {
                    _selectedCategory = 'pantry';
                    _selectedTab = 2;
                  }),
                ),
                _buildCategoryCard(
                  context,
                  emoji: _getCategoryEmoji('frozen'),
                  label: context.t('grocery.frozen'),
                  badgeCount: countFor('frozen'),
                  onTap: () => setState(() {
                    _selectedCategory = 'frozen';
                    _selectedTab = 2;
                  }),
                ),
                _buildCategoryCard(
                  context,
                  emoji: _getCategoryEmoji('other'),
                  label: context.t('grocery.other'),
                  badgeCount: countFor('other'),
                  onTap: () => setState(() {
                    _selectedCategory = 'other';
                    _selectedTab = 2;
                  }),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildCategoryListTile(
                  context,
                  emoji: _getCategoryEmoji('produce'),
                  label: context.t('grocery.produce'),
                  badgeCount: countFor('produce'),
                  onTap: () => setState(() {
                    _selectedCategory = 'produce';
                    _selectedTab = 2;
                  }),
                  color: _getCategoryColor('produce'),
                ),
                const SizedBox(height: 8),
                _buildCategoryListTile(
                  context,
                  emoji: _getCategoryEmoji('protein'),
                  label: context.t('grocery.protein'),
                  badgeCount: countFor('protein'),
                  onTap: () => setState(() {
                    _selectedCategory = 'protein';
                    _selectedTab = 2;
                  }),
                  color: _getCategoryColor('protein'),
                ),
                const SizedBox(height: 8),
                _buildCategoryListTile(
                  context,
                  emoji: _getCategoryEmoji('dairy'),
                  label: context.t('grocery.dairy'),
                  badgeCount: countFor('dairy'),
                  onTap: () => setState(() {
                    _selectedCategory = 'dairy';
                    _selectedTab = 2;
                  }),
                  color: _getCategoryColor('dairy'),
                ),
                const SizedBox(height: 8),
                _buildCategoryListTile(
                  context,
                  emoji: _getCategoryEmoji('pantry'),
                  label: context.t('grocery.pantry'),
                  badgeCount: countFor('pantry'),
                  onTap: () => setState(() {
                    _selectedCategory = 'pantry';
                    _selectedTab = 2;
                  }),
                  color: _getCategoryColor('pantry'),
                ),
                const SizedBox(height: 8),
                _buildCategoryListTile(
                  context,
                  emoji: _getCategoryEmoji('frozen'),
                  label: context.t('grocery.frozen'),
                  badgeCount: countFor('frozen'),
                  onTap: () => setState(() {
                    _selectedCategory = 'frozen';
                    _selectedTab = 2;
                  }),
                  color: _getCategoryColor('frozen'),
                ),
                const SizedBox(height: 8),
                _buildCategoryListTile(
                  context,
                  emoji: _getCategoryEmoji('other'),
                  label: context.t('grocery.other'),
                  badgeCount: countFor('other'),
                  onTap: () => setState(() {
                    _selectedCategory = 'other';
                    _selectedTab = 2;
                  }),
                  color: _getCategoryColor('other'),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Smart Suggestions (screenshot-style)
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.genieGold, size: 20),
              const SizedBox(width: 8),
              Text(
                context.t('grocery.smart.suggestions'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSmartSuggestionTile(
            context,
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.genieGold,
            text: context.t('groceryLowStock'),
            isAdded: hasItemNamed(context.t('ingredient.onions')),
            onAdd: () => addSuggestion(context.t('ingredient.onions')),
          ),
          const SizedBox(height: 10),
          _buildSmartSuggestionTile(
            context,
            icon: Icons.calendar_today,
            iconColor: AppColors.geniePurple,
            text: context.t('groceryRecipeNeed'),
            isAdded: hasItemNamed(context.t('ingredient.yogurt')),
            onAdd: () => addSuggestion(context.t('ingredient.yogurt')),
          ),
          const SizedBox(height: 10),
          _buildSmartSuggestionTile(
            context,
            icon: Icons.refresh,
            iconColor: AppColors.geniePink,
            text: context.t('groceryFrequentItem'),
            isAdded: hasItemNamed(context.t('ingredient.rice')),
            onAdd: () => addSuggestion(context.t('ingredient.rice')),
          ),
          const SizedBox(height: 10),
          _buildSmartSuggestionTile(
            context,
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.destructive,
            text: context.t('groceryExpiringItem'),
            isAdded: hasItemNamed(context.t('ingredient.milk')),
            onAdd: () => addSuggestion(context.t('ingredient.milk')),
          ),
          const SizedBox(height: 24),

          // Saved Lists
          Text(
            context.t('grocery.saved.lists'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
              scrollDirection: Axis.horizontal,
              itemCount: provider.savedLists.isNotEmpty
                  ? provider.savedLists.length
                  : 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (provider.savedLists.isEmpty) {
                  final placeholders = [
                    {
                      'name': context.t('grocery.placeholder.weekly.grocery'),
                      'items': const <dynamic>[],
                    },
                    {
                      'name': context.t('grocery.placeholder.monthly.stock'),
                      'items': const <dynamic>[],
                    },
                    {
                      'name': context.t(
                        'grocery.placeholder.high.protein.diet',
                      ),
                      'items': const <dynamic>[],
                    },
                  ];
                  final data = placeholders[index];
                  return _buildSavedListCard(
                    context,
                    title: data['name'] as String,
                    itemCount: 0,
                    onTap: null,
                  );
                }

                final saved = provider.savedLists[index];
                final id = saved['id']?.toString();
                final name =
                    saved['name']?.toString() ?? context.t('grocery.list');
                final items = (saved['items'] as List?) ?? const <dynamic>[];
                return _buildSavedListCard(
                  context,
                  title: name,
                  itemCount: items.length,
                  onTap: id == null ? null : () => context.go('/grocery/$id'),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Current List summary
          _buildCurrentListCard(context, list),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVoiceAssistantCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8), // More horizontal padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.getCardShadow(context),
        border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.mic, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('grocery.voice.assistant'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('grocery.voice.hint.example'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleVoiceInput,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(12),
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
                child: Icon(
                  _isVoiceListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleOption(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryListTile(
    BuildContext context, {
    required String emoji,
    required String label,
    required int badgeCount,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.getCardShadow(context),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.genieGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String emoji,
    required String label,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.getCardShadow(context),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.genieGold,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartSuggestionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isAdded,
    required VoidCallback onAdd,
  }) {
    if (_dismissedSmartSuggestions.contains(text)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (isAdded)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 18, color: AppColors.genieGold),
                const SizedBox(width: 6),
                Text(
                  context.t('grocery.added.status'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.genieGold,
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.t('common.add')),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedListCard(
    BuildContext context, {
    required String title,
    required int itemCount,
    required VoidCallback? onTap,
  }) {
    // Determine icon/emoji based on title
    String emoji = '📝';
    if (title.toLowerCase().contains('weekly')) {
      emoji = '🛒';
    } else if (title.toLowerCase().contains('monthly') ||
        title.toLowerCase().contains('stock')) {
      emoji = '📦';
    } else if (title.toLowerCase().contains('protein') ||
        title.toLowerCase().contains('diet')) {
      emoji = '💪';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                '$itemCount ${context.t('grocery.items')}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentListCard(BuildContext context, GroceryList? list) {
    final total = list?.items.length ?? 0;
    final bought = list?.items.where((i) => i.checked).length ?? 0;
    final est = list?.estimatedCost ?? '\$0';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                context.t('grocery.current.list'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _selectedTab = 1),
                style:
                    TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ).copyWith(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),
                    ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      context.t('grocery.view.list'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat(
                context,
                value: '$total',
                label: context.t('grocery.total'),
              ),
              _buildMiniStat(
                context,
                value: '$bought',
                label: context.t('grocery.bought'),
                valueColor: AppColors.genieGold,
              ),
              _buildMiniStat(
                context,
                value: est,
                label: context.t('grocery.est.cost'),
                valueColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildListTab(
    BuildContext context,
    GroceryProvider provider,
    GroceryList? list,
    bool isLoading,
  ) {
    // Show loading only if actively generating a new list via API, not when loading from storage
    // Storage loads happen in background and don't block UI
    if (isLoading) {
      return const LoadingGenie();
    }

    // If list is null, show empty state (will update when storage loads in background)
    // This allows UI to render immediately without waiting for storage
    if (list == null || list.items.isEmpty) {
      return _buildEmptyState(context, provider);
    }

    return _buildGroceryList(context, list, provider);
  }

  Widget _buildAddTab(BuildContext context, GroceryProvider provider) {
    final groceryList = provider.groceryList;
    final allCurrentItems = groceryList?.items ?? [];
    final allQuickAddItems = [
      context.t('ingredient.onions'),
      context.t('ingredient.tomatoes'),
      context.t('ingredient.potatoes'),
      context.t('ingredient.milk'),
      context.t('ingredient.eggs'),
      context.t('ingredient.bread'),
      context.t('ingredient.rice'),
      context.t('ingredient.oil'),
    ];

    // Helper function to check if item already exists in list
    bool hasItemNamed(String name) {
      final n = name.trim().toLowerCase();
      return allCurrentItems.any((i) => i.name.trim().toLowerCase() == n);
    }

    // Filter items based on search query
    final query = _searchQuery.toLowerCase();
    final currentItems = query.isEmpty
        ? allCurrentItems
        : allCurrentItems
              .where((item) => item.name.toLowerCase().contains(query))
              .toList();
    final quickAddItems = query.isEmpty
        ? allQuickAddItems
        : allQuickAddItems
              .where((item) => item.toLowerCase().contains(query))
              .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.getCardShadow(context),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.t('grocery.search.items'),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ],
            ),
          ),
          // Add Item Section
          Text(
            context.t('grocery.add.item'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.getCardShadow(context),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemNameController,
                        decoration: InputDecoration(
                          hintText: context.t('grocery.item.name'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          hintText: context.t('grocery.quantity'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryChip(
                      context,
                      Icons.eco,
                      context.t('grocery.produce'),
                      'produce',
                    ),
                    _buildCategoryChip(
                      context,
                      Icons.set_meal,
                      context.t('grocery.protein'),
                      'protein',
                    ),
                    _buildCategoryChip(
                      context,
                      Icons.local_drink,
                      context.t('grocery.dairy'),
                      'dairy',
                    ),
                    _buildCategoryChip(
                      context,
                      Icons.kitchen,
                      context.t('grocery.pantry'),
                      'pantry',
                    ),
                    _buildCategoryChip(
                      context,
                      Icons.ac_unit,
                      context.t('grocery.frozen'),
                      'frozen',
                    ),
                    _buildCategoryChip(
                      context,
                      Icons.shopping_cart,
                      context.t('grocery.other'),
                      'other',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_itemNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.t('grocery.item.required'),
                                ),
                                backgroundColor: AppColors.destructive,
                              ),
                            );
                            return;
                          }
                          final item = GroceryItem(
                            id: const Uuid().v4(),
                            name: _itemNameController.text.trim(),
                            quantity: _quantityController.text.trim().isEmpty
                                ? '1'
                                : _quantityController.text.trim(),
                            unit: '',
                            category:
                                _selectedCategory ??
                                GroceryService.detectCategory(
                                  _itemNameController.text.trim(),
                                ),
                            checked: false,
                          );
                          provider.addItem(item);
                          _itemNameController.clear();
                          _quantityController.clear();
                          _selectedCategory = null;
                          setState(() => _selectedTab = 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.t('grocery.item.added')),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, size: 20),
                            const SizedBox(width: 8),
                            Text(context.t('grocery.add.to.list')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _isVoiceListening
                            ? null
                            : AppColors.gradientPrimary,
                        color: _isVoiceListening ? AppColors.destructive : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleVoiceInput,
                          borderRadius: BorderRadius.circular(12),
                          child: Icon(
                            _isVoiceListening ? Icons.mic_off : Icons.mic,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Your Items Section
          if (allCurrentItems.isNotEmpty) ...[
            Text(
              '${context.t('grocery.your.items')} (${currentItems.length}${query.isNotEmpty ? '/${allCurrentItems.length}' : ''})',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (currentItems.isEmpty && query.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${context.t('grocery.no.items.found')} "$_searchQuery"',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...currentItems
                  .take(5)
                  .map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: item.checked,
                            onChanged: (value) => provider.toggleItem(item.id),
                            activeColor: AppColors.primary,
                          ),
                          Text(
                            _getCategoryEmoji(item.category),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                          Text(
                            item.quantity,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: AppColors.destructive,
                            ),
                            onPressed: () => provider.removeItem(item.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
          ],
          // Quick Add Section
          Text(
            context.t('grocery.quick.add'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (quickAddItems.isEmpty && query.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${context.t('grocery.no.items.found')} "$_searchQuery"',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickAddItems.map((itemName) {
                final isAlreadyAdded = hasItemNamed(itemName);
                return ElevatedButton(
                  onPressed: () {
                    provider.addItemsByName([itemName]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$itemName ${context.t('grocery.added')}',
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    setState(() {}); // Refresh to update button state
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAlreadyAdded
                        ? AppColors.primary.withOpacity(0.2)
                        : Theme.of(context).cardColor,
                    foregroundColor: isAlreadyAdded
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isAlreadyAdded
                            ? AppColors.primary
                            : AppColors.border,
                        width: isAlreadyAdded ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAlreadyAdded) ...[
                        Icon(Icons.check, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                      ] else
                        Text('+ '),
                      Text(itemName),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    IconData icon,
    String label,
    String category,
  ) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () =>
          setState(() => _selectedCategory = isSelected ? null : category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
