import 'dart:io';
import 'dart:typed_data';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';
import '../../data/models/recipe.dart';
import '../../providers/premium_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/recipe_service.dart';
import '../../services/scanner_service.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/loading_genie.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/recipe/recipe_image_widget.dart';

enum ScannerViewMode { camera, ingredients, recipes, recipeDetail }

class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key, this.initialImage});

  final XFile? initialImage;

  @override
  State<IngredientScannerScreen> createState() =>
      _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen> {
  ScannerViewMode _viewMode = ScannerViewMode.camera;
  bool _isAnalyzing = false;
  XFile? _capturedImage;
  String? _imageBase64;
  ScanResult? _scanResult;
  Recipe? _selectedRecipe;
  List<DetectedIngredient> _editableIngredients = [];

  // Preferences
  String _dietType = 'balanced';
  int _calorieTarget = 500;
  int _cookingTime = 30;

  // Add ingredient dialog state
  String _newIngredientName = '';
  String _newIngredientQuantity = '1';
  String _newIngredientCategory = 'other';

  @override
  void initState() {
    super.initState();
    if (_scanResult != null) {
      _editableIngredients = List.from(_scanResult!.ingredients);
    }

    // If an initial image was passed (from the custom camera flow),
    // just preview it. The user can set preferences and then start scanning.
    final initial = widget.initialImage;
    if (initial != null) {
      _capturedImage = initial;
      _viewMode = ScannerViewMode.camera;
    }
  }

  Future<void> _processImage(XFile image) async {
    // Check if user can use scanner (sub_scancamera limit)
    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.canUseScannerSync()) {
      if (mounted) ProNavigation.tryOpen(context, replace: false);
      return;
    }

    setState(() {
      _capturedImage = image;
      _isAnalyzing = true;
      _viewMode = ScannerViewMode.camera;
    });

    try {
      final Uint8List imageBytes = await image.readAsBytes();
      final String? base64Image = ScannerService.imageToBase64(imageBytes);

      if (base64Image == null) {
        throw Exception('Failed to convert image to base64');
      }

      // Convert to data URI format if needed
      final String imageDataUri = 'data:image/jpeg;base64,$base64Image';

      final result = await ScannerService.analyzeImage(
        imageBase64: imageDataUri,
        dietType: _dietType,
        calorieTarget: _calorieTarget,
        cookingTime: _cookingTime,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (result != null && result.ingredients.isNotEmpty) {
            _scanResult = result;
            _editableIngredients = List.from(result.ingredients);
            // If recipes are available, go to recipes view, otherwise ingredients view
            if (result.recipes.isNotEmpty) {
              _viewMode = ScannerViewMode.recipes;
            } else {
              _viewMode = ScannerViewMode.ingredients;
            }
            _imageBase64 = imageDataUri;
          } else {
            // Reset to camera view if no ingredients detected
            _viewMode = ScannerViewMode.camera;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t('scanner.no.ingredients.detected')),
                backgroundColor: AppColors.destructive,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          // Reset to camera view on error so user can try again or go back
          _viewMode = ScannerViewMode.camera;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.t('common.error')}: ${context.t('scanner.error.analyzing.image', {'error': e.toString()})}',
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _regenerateRecipes() async {
    if (_editableIngredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('scanner.no.ingredients.detected')),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
      return;
    }

    // Check if user can use scanner (sub_scancamera limit)
    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.canUseScannerSync()) {
      if (mounted) {
        final limit = premiumProvider.getScannerLimit();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              limit != null
                  ? context.t('scanner.limit.reached', {
                      'limit': limit.toString(),
                    })
                  : context.t('scanner.ai.disabled'),
            ),
            backgroundColor: AppColors.destructive,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: context.t('premium.upgrade'),
              textColor: Colors.white,
              onPressed: () {
                ProNavigation.tryOpen(context, replace: false);
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Try to use image-based analysis first if available
      if (_imageBase64 != null) {
        final result = await ScannerService.analyzeImage(
          imageBase64: _imageBase64!,
          dietType: _dietType,
          calorieTarget: _calorieTarget,
          cookingTime: _cookingTime,
        );

        if (mounted && result != null && result.recipes.isNotEmpty) {
          setState(() {
            _scanResult = result;
            _isAnalyzing = false;
            _viewMode = ScannerViewMode.recipes;
          });
          return;
        }
      }

      // Fallback: Generate recipe from ingredients list using RecipeService
      // Convert ingredients list to comma-separated string
      final ingredientsString = _editableIngredients
          .map(
            (ing) =>
                '${ing.name}${ing.quantity.isNotEmpty ? " (${ing.quantity})" : ""}',
          )
          .join(', ');

      // Generate a single recipe from ingredients (with image if available - matching web app)
      Recipe? generatedRecipe;
      try {
        generatedRecipe = await RecipeService.generateRecipe(
          ingredients: ingredientsString,
          cookingTime: _cookingTime,
          targetCalories: _calorieTarget,
          dietType: _dietType,
          imageBase64:
              _imageBase64, // Pass image to recipe generation (matching web app behavior)
        );
      } catch (e) {
        print('Error in recipe generation: $e');
        // Error will be handled below
      }

      if (mounted) {
        if (generatedRecipe != null) {
          // Create a ScanResult with the generated recipe
          final newScanResult = ScanResult(
            ingredients: _editableIngredients,
            recipes: [generatedRecipe],
            totalIngredientsDetected: _editableIngredients.length,
            totalRecipesGenerated: 1,
          );

          setState(() {
            _scanResult = newScanResult;
            _isAnalyzing = false;
            _viewMode = ScannerViewMode.recipes;
          });
        } else {
          setState(() {
            _isAnalyzing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.t('common.error')}: ${context.t('scanner.no.recipes.generated')}',
              ),
              backgroundColor: AppColors.destructive,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        print('Error in _regenerateRecipes: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t('common.error')}: ${e.toString()}'),
            backgroundColor: AppColors.destructive,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _editableIngredients.removeAt(index);
    });
  }

  void _addIngredient() {
    if (_newIngredientName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('scanner.enter.ingredient.name')),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() {
      _editableIngredients.add(
        DetectedIngredient(
          name: _newIngredientName.trim(),
          quantity: _newIngredientQuantity.trim().isEmpty
              ? '1'
              : _newIngredientQuantity.trim(),
          category: _newIngredientCategory,
          freshness: 'good',
          confidence: 1.0,
        ),
      );
      // Reset form
      _newIngredientName = '';
      _newIngredientQuantity = '1';
      _newIngredientCategory = 'other';
    });

    Navigator.of(context).pop(); // Close dialog

    final ingredientName = _newIngredientName.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$ingredientName added'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showAddIngredientDialogMethod() {
    setState(() {
      _newIngredientName = '';
      _newIngredientQuantity = '1';
      _newIngredientCategory = 'other';
    });

    showDialog(
      context: context,
      builder: (context) => _buildAddIngredientDialog(),
    );
  }

  void _viewRecipeDetail(Recipe recipe) {
    setState(() {
      _selectedRecipe = recipe;
      _viewMode = ScannerViewMode.recipeDetail;
    });
  }

  void _handleBack() {
    try {
      // Handle navigation based on current view mode
      if (_viewMode == ScannerViewMode.recipeDetail) {
        // From recipe detail, go back to recipes list
        setState(() => _viewMode = ScannerViewMode.recipes);
      } else if (_viewMode == ScannerViewMode.recipes) {
        // From recipes list, go back to ingredients
        setState(() => _viewMode = ScannerViewMode.ingredients);
      } else if (_viewMode == ScannerViewMode.ingredients) {
        // From detected ingredients, go back to camera (previous screen)
        setState(() {
          _viewMode = ScannerViewMode.camera;
          _capturedImage = null;
          _imageBase64 = null;
          _scanResult = null;
          _editableIngredients = [];
        });
      } else {
        // From camera view, exit the screen (pop or go home)
        if (mounted && context.canPop()) {
          context.pop();
        } else if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      // Fallback: try to navigate to home if anything fails
      if (mounted) {
        try {
          context.go('/');
        } catch (_) {
          // Last resort: do nothing if navigation completely fails
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final premiumProvider = context.watch<PremiumProvider>();
    // Use sub_scancamera only - no other remote keys inside scan screen
    final canUseScanner = premiumProvider.canUseScannerSync();
    final scanLimit = premiumProvider.getScannerLimit();
    final scanCount = premiumProvider.scanCount;

    if (_isAnalyzing) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          // Show confirmation before going back during analysis
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(ctx.t('scanner.cancel.analysis.title')),
              content: Text(ctx.t('scanner.cancel.analysis.message')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(ctx.t('common.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(ctx.t('common.confirm')),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            setState(() {
              _isAnalyzing = false;
              _viewMode = ScannerViewMode.camera;
            });
          }
        },
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.gradientHeroDark
                  : AppColors.gradientHero,
            ),
            child: LoadingGenie(message: context.t('scanner.analyzing')),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_viewMode == ScannerViewMode.camera) {
          // If user opens scan directly (e.g. from Home),
          // popping would close the app. Always go to new Home instead.
          if (mounted) context.go('/');
          return;
        }
        _handleBack();
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
                  title: _viewMode == ScannerViewMode.ingredients
                      ? context.t('scanner.detected')
                      : _viewMode == ScannerViewMode.recipes
                      ? context.t('scanner.recipe.suggestions')
                      : _viewMode == ScannerViewMode.recipeDetail
                      ? _selectedRecipe?.title ?? context.t('scanner.recipe')
                      : context.t('scanner.title'),
                  onBack: _handleBack,
                  backgroundColor: Colors.transparent,
                  statusBarColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1F35)
                      : AppColors.genieBlush,
                  rightContent: _viewMode == ScannerViewMode.ingredients
                      ? IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _showAddIngredientDialogMethod,
                        )
                      : _viewMode == ScannerViewMode.recipes
                      ? IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _regenerateRecipes,
                        )
                      : null,
                ),
                Expanded(
                  child: _buildCurrentView(
                    canUseScanner: canUseScanner,
                    scanLimit: scanLimit,
                    scanCount: scanCount,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddIngredientDialog() {
    final categories = [
      'vegetable',
      'fruit',
      'meat',
      'dairy',
      'spice',
      'grain',
      'packaged',
      'other',
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.t('scanner.add.ingredient'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.t('scanner.ingredient.name'),
                  hintText: context.t('scanner.ingredient.name.hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.restaurant),
                ),
                onChanged: (value) {
                  setState(() {
                    _newIngredientName = value;
                  });
                },
                controller: TextEditingController(text: _newIngredientName),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: context.t('scanner.quantity'),
                  hintText: context.t('scanner.quantity.hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.scale),
                ),
                onChanged: (value) {
                  setState(() {
                    _newIngredientQuantity = value;
                  });
                },
                controller: TextEditingController(text: _newIngredientQuantity),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _newIngredientCategory,
                decoration: InputDecoration(
                  labelText: context.t('scanner.category'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category[0].toUpperCase() + category.substring(1),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _newIngredientCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addIngredient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.t('scanner.add.ingredient'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildCurrentView({
    required bool canUseScanner,
    required int? scanLimit,
    required int scanCount,
  }) {
    switch (_viewMode) {
      case ScannerViewMode.camera:
        return _buildCameraView(
          canUseScanner: canUseScanner,
          scanLimit: scanLimit,
          scanCount: scanCount,
        );
      case ScannerViewMode.ingredients:
        return _buildIngredientsView();
      case ScannerViewMode.recipes:
        return _buildRecipesView();
      case ScannerViewMode.recipeDetail:
        return _buildRecipeDetailView();
    }
  }

  Widget _buildCameraView({
    required bool canUseScanner,
    required int? scanLimit,
    required int scanCount,
  }) {
    final premiumProvider = context.read<PremiumProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Ingredient Scanner Header with Mascot
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GenieMascot(size: GenieMascotSize.md),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('scanner.ai.ingredient.scanner'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('scanner.take.photo.description'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          const SizedBox(height: 32),
          // Limit Reached Banner (if scan limit reached - sub_scancamera)
          if (!canUseScanner && !premiumProvider.isPremium)
            _buildLimitReachedBanner(context, scanLimit, scanCount),
          if (!canUseScanner && !premiumProvider.isPremium)
            const SizedBox(height: 16),
          // Preferences Card (before camera section)
          _buildPreferencesCard(context),
          const SizedBox(height: 32),
          // Camera/Upload Section removed.
          // Scan flow starts from Home → custom camera → crop → this screen.
          // Show captured image if available
          if (_capturedImage != null)
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(_capturedImage!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (!_isAnalyzing && _scanResult == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _processImage(_capturedImage!),
                      icon: const Icon(Icons.search),
                      label: Text(
                        context.t('recipes.scan'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          if (_capturedImage == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: Text(context.t('common.home')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context) {
    final dietTypeLabels = {
      'balanced': context.t('scanner.diet.balanced'),
      'high-protein': context.t('scanner.diet.high.protein'),
      'low-carb': context.t('scanner.diet.low.carb'),
      'keto': context.t('scanner.diet.keto'),
      'vegetarian': context.t('scanner.diet.vegetarian'),
      'vegan': context.t('scanner.diet.vegan'),
    };

    final cookingTimeOptions = [15, 30, 45, 60];

    return Container(
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
              Icon(Icons.auto_awesome, color: AppColors.genieGold, size: 20),
              const SizedBox(width: 8),
              Text(
                context.t('scanner.recipe.preferences'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Diet Type Dropdown
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField2<String>(
                  value: _dietType,
                  decoration: InputDecoration(
                    labelText: context.t('scanner.diet.type'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  isExpanded: true,
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 4), // keeps menu close
                  ),
                  items:
                      [
                            'balanced',
                            'high-protein',
                            'low-carb',
                            'keto',
                            'vegetarian',
                            'vegan',
                          ]
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(dietTypeLabels[type] ?? type),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _dietType = value);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: DropdownButtonFormField2<int>(
                  value: _cookingTime,
                  decoration: InputDecoration(
                    labelText: context.t('scanner.cooking.time.label'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  isExpanded: true,
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 4),
                  ),
                  items: cookingTimeOptions
                      .map(
                        (time) => DropdownMenuItem<int>(
                          value: time,
                          child: Text('$time mins'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _cookingTime = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Target Calories with +/- buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('scanner.target.calories.label'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setState(
                        () => _calorieTarget = (_calorieTarget - 100).clamp(
                          200,
                          1500,
                        ),
                      );
                    },
                  ),
                  Text(
                    '$_calorieTarget kcal',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(
                        () => _calorieTarget = (_calorieTarget + 100).clamp(
                          200,
                          1500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsView() {
    final bottomPadding = 24.0 + MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_capturedImage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_capturedImage!.path),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Text(
                  context.t('scanner.detected.ingredients'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...List.generate(_editableIngredients.length, (index) {
                  final ingredient = _editableIngredients[index];
                  return _buildIngredientCard(ingredient, index);
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          child: ElevatedButton(
            onPressed: () {
              if (_scanResult != null && _scanResult!.recipes.isNotEmpty) {
                setState(() => _viewMode = ScannerViewMode.recipes);
              } else {
                _regenerateRecipes();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              // Keep label white in both light/dark modes.
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _scanResult != null && _scanResult!.recipes.isNotEmpty
                  ? context.t('scanner.view.recipe.suggestions', {
                      'count': '${_scanResult!.recipes.length}',
                    })
                  : context.t('scanner.generate.recipes'),
              style:
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ) ??
                  const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientCard(DetectedIngredient ingredient, int index) {
    // Specific ingredient emoji mapping
    String getIngredientEmoji(String name) {
      final lowerName = name.toLowerCase();

      // Specific ingredient mappings
      if (lowerName.contains('potato')) return '🥔';
      if (lowerName.contains('carrot')) return '🥕';
      if (lowerName.contains('tomato')) return '🍅';
      if (lowerName.contains('onion')) return '🧅';
      if (lowerName.contains('garlic')) return '🧄';
      if (lowerName.contains('pepper') || lowerName.contains('bell pepper'))
        return '🫑';
      if (lowerName.contains('broccoli')) return '🥦';
      if (lowerName.contains('cucumber')) return '🥒';
      if (lowerName.contains('corn')) return '🌽';
      if (lowerName.contains('mushroom')) return '🍄';
      if (lowerName.contains('lettuce') || lowerName.contains('salad'))
        return '🥬';
      if (lowerName.contains('spinach')) return '🥬';
      if (lowerName.contains('cabbage')) return '🥬';
      if (lowerName.contains('eggplant') || lowerName.contains('aubergine'))
        return '🍆';
      if (lowerName.contains('avocado')) return '🥑';
      if (lowerName.contains('zucchini') || lowerName.contains('courgette'))
        return '🥒';

      // Fruits
      if (lowerName.contains('apple')) return '🍎';
      if (lowerName.contains('banana')) return '🍌';
      if (lowerName.contains('orange')) return '🍊';
      if (lowerName.contains('strawberry')) return '🍓';
      if (lowerName.contains('grape')) return '🍇';
      if (lowerName.contains('lemon') || lowerName.contains('lime'))
        return '🍋';
      if (lowerName.contains('mango')) return '🥭';
      if (lowerName.contains('pineapple')) return '🍍';
      if (lowerName.contains('watermelon')) return '🍉';
      if (lowerName.contains('cherry')) return '🍒';
      if (lowerName.contains('peach')) return '🍑';

      // Meat & Protein
      if (lowerName.contains('chicken')) return '🍗';
      if (lowerName.contains('beef') || lowerName.contains('steak'))
        return '🥩';
      if (lowerName.contains('pork')) return '🥓';
      if (lowerName.contains('fish') ||
          lowerName.contains('salmon') ||
          lowerName.contains('tuna'))
        return '🐟';
      if (lowerName.contains('egg')) return '🥚';
      if (lowerName.contains('tofu')) return '🧈';

      // Dairy
      if (lowerName.contains('milk')) return '🥛';
      if (lowerName.contains('cheese')) return '🧀';
      if (lowerName.contains('butter')) return '🧈';
      if (lowerName.contains('yogurt') || lowerName.contains('yoghurt'))
        return '🥛';

      // Grains & Bread
      if (lowerName.contains('rice')) return '🍚';
      if (lowerName.contains('bread')) return '🍞';
      if (lowerName.contains('pasta') || lowerName.contains('noodle'))
        return '🍝';
      if (lowerName.contains('wheat') || lowerName.contains('flour'))
        return '🌾';

      // Spices & Herbs
      if (lowerName.contains('pepper') && !lowerName.contains('bell'))
        return '🌶️';
      if (lowerName.contains('chili') || lowerName.contains('chilli'))
        return '🌶️';
      if (lowerName.contains('herb') ||
          lowerName.contains('basil') ||
          lowerName.contains('parsley') ||
          lowerName.contains('cilantro'))
        return '🌿';

      // Fallback to category-based mapping
      final categoryEmojis = {
        'vegetable': '🥕',
        'fruit': '🍎',
        'meat': '🍗',
        'dairy': '🥛',
        'spice': '🌿',
        'grain': '🌾',
        'packaged': '📦',
        'other': '🍽️',
      };
      return categoryEmojis[ingredient.category] ?? '🍽️';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Row(
        children: [
          Text(
            getIngredientEmoji(ingredient.name),
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ingredient.quantity,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ingredient.freshness == 'fresh'
                  ? Colors.green.withOpacity(0.1)
                  : ingredient.freshness == 'expiring_soon'
                  ? Colors.orange.withOpacity(0.1)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ingredient.freshness == 'expiring_soon'
                  ? context.t('scanner.expiring')
                  : ingredient.freshness,
              style: TextStyle(
                fontSize: 10,
                color: ingredient.freshness == 'fresh'
                    ? Colors.green
                    : ingredient.freshness == 'expiring_soon'
                    ? Colors.orange
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.destructive,
            ),
            onPressed: () => _removeIngredient(index),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesView() {
    if (_scanResult == null || _scanResult!.recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('scanner.no.recipes.generated'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _regenerateRecipes,
              child: Text(context.t('scanner.generate.recipes')),
            ),
          ],
        ),
      );
    }

    final bottomPadding = 24.0 + MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      itemCount: _scanResult!.recipes.length,
      itemBuilder: (context, index) {
        final recipe = _scanResult!.recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  // Helper function to get theme-aware tag colors
  ({Color bg, Color fg}) _getTagColors(String tag, BuildContext context) {
    final lowerTag = tag.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;

    if (lowerTag.contains('keto') || lowerTag.contains('low carb')) {
      return (
        bg: colorScheme.primaryContainer,
        fg: colorScheme.onPrimaryContainer,
      );
    } else if (lowerTag.contains('vegetarian') || lowerTag.contains('vegan')) {
      return (
        bg: colorScheme.secondaryContainer,
        fg: colorScheme.onSecondaryContainer,
      );
    } else if (lowerTag.contains('high protein') ||
        lowerTag.contains('protein')) {
      return (
        bg: colorScheme.tertiaryContainer,
        fg: colorScheme.onTertiaryContainer,
      );
    } else if (lowerTag.contains('healthy')) {
      return (
        bg: colorScheme.tertiaryContainer,
        fg: colorScheme.onTertiaryContainer,
      );
    } else if (lowerTag.contains('quick') || lowerTag.contains('fast')) {
      return (bg: colorScheme.errorContainer, fg: colorScheme.onErrorContainer);
    }
    return (
      bg: colorScheme.surfaceContainerHighest,
      fg: colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: InkWell(
        onTap: () => _viewRecipeDetail(recipe),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RecipeImageWidget(
                        image: recipe.image,
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                        placeholder: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Text('🍽️', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.description,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.cookTime} ${context.t('scanner.min')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: Colors.orange,
                  ), // Semantic color for calories
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.calories} ${context.t('scanner.kcal')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              if (recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recipe.tags.take(4).map((tag) {
                    final tagColors = _getTagColors(tag, context);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tagColors.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tagColors.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeDetailView() {
    if (_selectedRecipe == null) {
      return Center(child: Text(context.t('scanner.no.recipe.selected')));
    }

    final recipe = _selectedRecipe!;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RecipeImageWidget(
                image: recipe.image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                placeholder: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                  ),
                  child: const Center(
                    child: Text('🍽️', style: TextStyle(fontSize: 100)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            recipe.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          // Nutrition
          _buildNutritionSection(recipe),
          const SizedBox(height: 16),
          // Ingredients
          _buildIngredientsSection(recipe),
          const SizedBox(height: 16),
          // Instructions
          _buildInstructionsSection(recipe),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<RecipeProvider>().setRecipe(recipe);
              context.push('/recipe/${recipe.slug}');
            },
            icon: const Icon(Icons.visibility),
            label: Text(context.t('scanner.view.full.recipe')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 20,
              ), // Keep orange for calories - semantic color
              const SizedBox(width: 8),
              Text(
                context.t('scanner.nutrition.per.serving'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutritionChip(
                context.t('scanner.calories'),
                '${recipe.nutrition.calories}',
                Colors.orange,
              ), // Semantic color - already correct
              _buildNutritionChip(
                context.t('recipe.detail.protein'),
                '${recipe.nutrition.protein}g',
                Colors.blue,
              ), // Semantic color
              _buildNutritionChip(
                context.t('recipe.detail.carbs'),
                '${recipe.nutrition.carbs}g',
                Colors.amber,
              ), // Semantic color
              _buildNutritionChip(
                context.t('scanner.fats'),
                '${recipe.nutrition.fat}g',
                Colors.green,
              ), // Semantic color
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('scanner.ingredients'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...recipe.ingredients.map((ingredient) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ), // Semantic color for success
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('scanner.instructions'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...recipe.instructions.map((instruction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '${instruction.step}',
                        style: TextStyle(
                          color: Theme.of(context).cardColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      instruction.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLimitReachedBanner(
    BuildContext context,
    int? limit,
    int scanCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                      context.t('scanner.limit.reached.title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (limit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.t('scanner.limit.reached', {
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
                        context.t('scanner.ai.disabled'),
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
                ProNavigation.tryOpen(context, replace: false);
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
              ).copyWith(elevation: WidgetStateProperty.all(0)),
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
        ],
      ),
    );
  }
}
