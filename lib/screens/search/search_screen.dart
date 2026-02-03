import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/sticky_header.dart';
import '../../core/localization/l10n_extension.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // Suggested search terms - will be localized in build method
  List<String> _getSuggestions(BuildContext context) {
    return [
      context.t('search.suggestion.pasta'),
      context.t('search.suggestion.healthy'),
      context.t('search.suggestion.quick'),
      context.t('search.suggestion.chicken'),
      context.t('search.suggestion.dessert'),
    ];
  }

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update UI
    _searchController.addListener(() {
      setState(() {});
    });
    // Auto-focus the search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    if (query.trim().isNotEmpty) {
      context.go('/recipes?search=${Uri.encodeComponent(query)}&generate=true');
    }
  }

  void _handleSuggestionTap(String suggestion, BuildContext context) {
    _searchController.text = suggestion;
    _handleSearch(suggestion);
  }

  void _clearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _focusNode.requestFocus();
    } else {
      // If search is empty, go back
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Blurred background with gradient (matching home screen)
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.getGradientHero(context),
            ),
          ),
          // Blur overlay for depth effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // Sticky Header
              StickyHeader(
                title: context.t('search.title'),
                onBack: () => context.pop(),
              ),
              // White search card overlay
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Search card - takes about 60% of screen
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Magnifying glass icon
                              Icon(
                                Icons.search,
                                color: AppColors.foreground.withOpacity(0.6),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              // Search input
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _focusNode,
                                  onSubmitted: _handleSearch,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: context.t('search.hint'),
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Clear button (X icon) - always visible
                              GestureDetector(
                                onTap: _clearSearch,
                                child: Icon(
                                  Icons.close,
                                  color: AppColors.foreground.withOpacity(0.6),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey[200],
                        ),
                        // Suggestions section
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('search.try.searching'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Suggested search chips
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _getSuggestions(context).map((suggestion) {
                                    return GestureDetector(
                                      onTap: () => _handleSuggestionTap(suggestion, context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          suggestion,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
