import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/loading_genie.dart';
import '../../providers/grocery_provider.dart';
import '../../data/models/grocery_list.dart';
import '../../data/models/grocery_item.dart';
import '../../services/storage_service.dart';
import 'dart:convert';

class SavedListDetailScreen extends StatefulWidget {
  final String listId;

  const SavedListDetailScreen({super.key, required this.listId});

  @override
  State<SavedListDetailScreen> createState() => _SavedListDetailScreenState();
}

class _SavedListDetailScreenState extends State<SavedListDetailScreen> {
  GroceryList? _groceryList;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadList();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);

    try {
      // Try to load from saved lists
      final savedListsJson = await StorageService.getSavedGroceryLists();
      if (savedListsJson != null) {
        final List<dynamic> savedLists = json.decode(savedListsJson);
        final listData = savedLists.firstWhere(
          (list) => (list as Map<String, dynamic>)['id'] == widget.listId,
          orElse: () => null,
        );

        if (listData != null) {
          final data = listData as Map<String, dynamic>;
          // Handle both old format (partial) and new format (complete GroceryList)
          // Ensure all required fields are present
          if (!data.containsKey('categories_summary')) {
            data['categories_summary'] = <String, dynamic>{};
          }
          if (!data.containsKey('budget_tips')) {
            data['budget_tips'] = <dynamic>[];
          }
          if (!data.containsKey('meal_prep_order')) {
            data['meal_prep_order'] = <dynamic>[];
          }

          _groceryList = GroceryList.fromJson(data);
        }
      }

      // If not found, try current list
      if (_groceryList == null) {
        final currentListJson = await StorageService.getGroceryList();
        if (currentListJson != null) {
          final listData = json.decode(currentListJson) as Map<String, dynamic>;
          if (listData['id'] == widget.listId) {
            _groceryList = GroceryList.fromJson(listData);
          }
        }
      }
    } catch (e) {
      print('Error loading grocery list: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading saved list: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _addToCurrentList() async {
    if (_groceryList == null) return;

    final provider = context.read<GroceryProvider>();
    for (final item in _groceryList!.items) {
      provider.addItem(item);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_groceryList!.items.length} ${context.t('saved.list.items.added')}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/grocery');
    }
  }

  Future<void> _regenerateWithAI() async {
    if (_groceryList == null) return;

    final provider = context.read<GroceryProvider>();
    final recipeIds = _groceryList!.items
        .map((item) => item.name)
        .toList(); // Simplified - in production, map to recipe IDs

    final newList = await provider.generateGroceryList(
      recipeIds: recipeIds,
      budget: _groceryList!.estimatedCost,
    );

    if (newList != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('saved.list.optimized.with.a.i')),
          backgroundColor: AppColors.primary,
        ),
      );
      setState(() => _groceryList = newList);
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${context.t('saved.list.delete.confirm')} "${_groceryList?.name}"?',
        ),
        content: Text(context.t('saved.list.cannot.undo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete from saved lists
      try {
        final savedListsJson = await StorageService.getSavedGroceryLists();
        if (savedListsJson != null) {
          final List<dynamic> savedLists = json.decode(savedListsJson);
          savedLists.removeWhere(
            (list) => (list as Map<String, dynamic>)['id'] == widget.listId,
          );
          await StorageService.saveSavedGroceryLists(json.encode(savedLists));
        }
      } catch (e) {
        print('Error deleting list: $e');
      }

      if (mounted) {
        context.go('/grocery');
      }
    }
  }

  Future<void> _shareList() async {
    if (_groceryList == null || _groceryList!.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('grocery.no.items.to.share')),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    final itemsText = _groceryList!.items
        .map((item) => '${item.name} - ${item.quantity} ${item.unit}'.trim())
        .join('\n');

    final shareText =
        '${_groceryList!.name}\n\n$itemsText\n\n${context.t('grocery.est.cost')}: ${_groceryList!.estimatedCost}';

    try {
      await Share.share(shareText, subject: _groceryList!.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('commonErrorMessage', {'error': e.toString()}),
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  List<GroceryItem> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _groceryList?.items ?? [];
    }
    return _groceryList?.items
            .where((item) => item.name.toLowerCase().contains(_searchQuery))
            .toList() ??
        [];
  }

  Map<String, List<GroceryItem>> get _itemsByCategory {
    final filtered = _filteredItems;
    final Map<String, List<GroceryItem>> grouped = {};
    for (final item in filtered) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                title:
                    _groceryList?.name ??
                    context.t('saved.list.list.not.found'),
                onBack: () => context.go('/grocery'),
                backgroundColor: Colors.transparent,
                statusBarColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1F35)
                    : AppColors.genieBlush,
                rightContent: _groceryList != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: _shareList,
                            tooltip: context.t('common.share'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _deleteList,
                            tooltip: context.t('common.delete'),
                          ),
                        ],
                      )
                    : null,
              ),
              if (_groceryList != null) ...[
                // Search Bar
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.t('grocery.search.items'),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                // Summary Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_groceryList!.items.length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Text(
                            context.t('grocery.items'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_groceryList!.items.where((i) => i.checked).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Text(
                            context.t('grocery.bought'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            _groceryList!.estimatedCost,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Text(
                            context.t('grocery.est.cost'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: _isLoading
                    ? const LoadingGenie()
                    : _groceryList == null
                    ? _buildNotFoundState(context)
                    : _buildListContent(context),
              ),
              if (_groceryList != null) ...[
                // Action Buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.95),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _addToCurrentList,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              context.t('saved.list.add.to.current.list'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _regenerateWithAI,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              context.t('saved.list.regenerate.with.a.i'),
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
        ],
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              context.t('saved.list.list.not.found'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t('saved.list.list.not.found.hint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/grocery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(context.t('saved.list.go.back')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent(BuildContext context) {
    final itemsByCategory = _itemsByCategory;

    if (itemsByCategory.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? '${context.t('grocery.no.items.found')} "$_searchQuery"'
              : context.t('grocery.no.items.yet'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...itemsByCategory.entries.map((entry) {
            return _buildCategorySection(context, entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<GroceryItem> items,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((item) => _buildGroceryItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildGroceryItem(BuildContext context, GroceryItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.checked
            ? Theme.of(context).colorScheme.surfaceVariant
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.checked,
            onChanged: null, // Read-only in saved list
            activeColor: AppColors.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: item.checked
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (item.quantity.isNotEmpty || item.unit.isNotEmpty)
                  Text(
                    '${item.quantity} ${item.unit}'.trim(),
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
          if (item.estimatedPrice != null)
            Text(
              item.estimatedPrice!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.genieGold,
              ),
            ),
        ],
      ),
    );
  }
}
