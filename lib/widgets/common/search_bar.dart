import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../services/voice_service.dart';
import '../../providers/grocery_provider.dart';
import 'rtl_helper.dart';

class SearchBar extends StatefulWidget {
  final Function(String)? onSearch;
  final String? placeholder;

  const SearchBar({
    super.key,
    this.onSearch,
    this.placeholder,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  bool _isListening = false;
  bool _showSuggestions = false;
  int _selectedIndex = -1;
  OverlayEntry? _overlayEntry;
  late AnimationController _placeholderController;
  int _currentPhraseIndex = 0;

  // Magic phrases for animated placeholder - will be localized in build
  List<String> _getMagicPhrases(BuildContext context) {
    return [
      context.t('search.placeholder1'),
      context.t('search.placeholder2'),
      context.t('search.placeholder3'),
      context.t('search.placeholder4'),
      context.t('search.placeholder5'),
    ];
  }

  // Food terms for auto-suggestions
  final List<String> _foodTerms = [
    'Mutton', 'Mince', 'Meat', 'Masala', 'Mixed vegetables', 'Mango', 'Milk', 'Mushroom',
    'Chicken', 'Chapati', 'Cheese', 'Curry', 'Cauliflower', 'Carrot', 'Coriander',
    'Biryani', 'Butter', 'Beef', 'Beans', 'Bread', 'Broccoli', 'Banana',
    'Rice', 'Roti', 'Raita', 'Radish',
    'Potato', 'Paratha', 'Paneer', 'Pasta', 'Pepper', 'Peas',
    'Tomato', 'Tikka', 'Tandoori', 'Tofu', 'Turkey',
    'Onion', 'Olive oil', 'Orange',
    'Egg', 'Eggplant',
    'Fish', 'Flour',
    'Garlic', 'Ginger', 'Ghee', 'Grapes',
    'Honey', 'Halal',
    'Ice cream',
    'Jalapeño',
    'Kebab', 'Kale', 'Ketchup',
    'Lemon', 'Lentils', 'Lamb', 'Lettuce',
    'Naan', 'Nuts',
    'Spinach', 'Samosa', 'Salad', 'Salmon', 'Shrimp', 'Soy sauce',
    'Yogurt',
    'Zucchini',
    'Aloo', 'Apple', 'Avocado',
    'Daal', 'Dahi',
    'Vegetable', 'Vinegar',
    'Water', 'Watermelon', 'Wheat',
  ];

  // Grocery command patterns
  final List<RegExp> _groceryPatterns = [
    RegExp(r'^add\s+(.+?)(?:\s+to\s+(?:the\s+)?(?:grocery|shopping)\s*(?:list)?)?$', caseSensitive: false),
    RegExp(r'^(?:put|get|buy|need|i need|we need)\s+(.+?)(?:\s+(?:to|on)\s+(?:the\s+)?(?:grocery|shopping)\s*(?:list)?)?$', caseSensitive: false),
    RegExp(r'^grocery\s+(?:add\s+)?(.+)$', caseSensitive: false),
    RegExp(r'^shopping\s+list\s+(?:add\s+)?(.+)$', caseSensitive: false),
  ];

  List<String> get _suggestions {
    if (_controller.text.trim().isEmpty) return [];
    final query = _controller.text.toLowerCase();
    return _foodTerms
        .where((term) => term.toLowerCase().contains(query))
        .take(6)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    VoiceService.initialize();
    _placeholderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startPlaceholderAnimation();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _startPlaceholderAnimation() {
    if (!_focusNode.hasFocus && _controller.text.isEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_focusNode.hasFocus && _controller.text.isEmpty) {
          _placeholderController.forward().then((_) {
            if (mounted) {
              setState(() {
                final phrases = _getMagicPhrases(context);
              _currentPhraseIndex = (_currentPhraseIndex + 1) % phrases.length;
              });
              _placeholderController.reset();
              _startPlaceholderAnimation();
            }
          });
        }
      });
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _showSuggestions = _focusNode.hasFocus && _suggestions.isNotEmpty;
        _selectedIndex = -1;
      });
      _updateOverlay();
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _showSuggestions = _focusNode.hasFocus && _suggestions.isNotEmpty;
      });
      if (_focusNode.hasFocus) {
        _updateOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  List<String>? _extractGroceryItems(String text) {
    for (final pattern in _groceryPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final itemsText = match.group(1) ?? '';
        return itemsText
            .split(RegExp(r',|\sand\s|\s&\s'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .map((item) => item.isEmpty
                ? item
                : item[0].toUpperCase() + item.substring(1).toLowerCase())
            .toList();
      }
    }
    return null;
  }

  void _updateOverlay() {
    _removeOverlay();
    if (_showSuggestions && _suggestions.isNotEmpty) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 8,
        width: size.width,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.98),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final isSelected = index == _selectedIndex;
                return InkWell(
                  onTap: () => _handleSuggestionClick(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      border: index < _suggestions.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor.withOpacity(0.3),
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleSuggestionClick(String suggestion) {
    _controller.text = suggestion;
    _removeOverlay();
    _focusNode.unfocus();
    _handleSubmit(suggestion);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await VoiceService.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      setState(() {
        _isListening = true;
      });

      await VoiceService.listen(
        onResult: (text) {
          setState(() {
            _controller.text = text;
            _isListening = false;
          });

          // Check if this is a grocery command
          final groceryItems = _extractGroceryItems(text);
          if (groceryItems != null && groceryItems.isNotEmpty) {
            final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
            groceryProvider.addItemsByName(groceryItems);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 20, color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('grocery.added.items', {'count': '${groceryItems.length}'}),
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  _controller.text = '';
                });
              }
            });
          } else {
            _handleSubmit(text);
          }
        },
        onPartialResult: (text) {
          // Partial results can be used for live transcription if needed
        },
        onDone: () {
          setState(() {
            _isListening = false;
          });
        },
        onError: (error) {
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.t('common.error')}: $error'),
            ),
          );
        },
      );
    }
  }

  void _handleSubmit(String value) {
    if (value.trim().isNotEmpty) {
      widget.onSearch?.call(value);
      context.go('/recipes?search=${Uri.encodeComponent(value)}&generate=true');
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _placeholderController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    VoiceService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magicPhrases = _getMagicPhrases(context);
    final currentPlaceholder = widget.placeholder ??
        (widget.placeholder == null && !_focusNode.hasFocus && _controller.text.isEmpty
            ? magicPhrases[_currentPhraseIndex]
            : context.t('home.search.placeholder'));

    return CompositedTransformTarget(
      link: _layerLink,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Search icon with orange dot
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        size: 20,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35), // Orange color
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onSubmitted: _handleSubmit,
                    onTap: () {},
                    decoration: InputDecoration(
                      hintText: currentPlaceholder,
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
                // Mic button
                GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.destructive
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: _isListening
                          ? Theme.of(context).colorScheme.onError
                          : AppColors.genieLavender, // Light blue
                      size: 18,
                    ),
                  ),
                ),
                // AI/Search button with blue-to-green gradient
                Container(
                  width: 40,
                  height: 40,
                  margin: RtlEdgeInsets.only(context: context, right: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.geniePurple, AppColors.genieLavender], // Blue to green
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.geniePurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleSubmit(_controller.text),
                      borderRadius: BorderRadius.circular(12),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
