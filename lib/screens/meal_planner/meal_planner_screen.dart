import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/loading_genie.dart';
import '../../widgets/ads/screen_native_ad_widget.dart';
import '../../widgets/ads/custom_native_ad_widget.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/premium_provider.dart';
import '../../services/card_ad_tracker.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../data/models/meal_plan.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  int _days = 7;
  int _dailyCalories = 2000;
  int _familySize = 1;
  String? _selectedDiet;
  String? _selectedGoal;
  String? _selectedBudget = 'moderate'; // Default to Moderate
  String? _selectedSkill = 'intermediate'; // Default to Intermediate
  String? _selectedFasting;
  List<String> _allergies = [];
  final TextEditingController _allergiesController = TextEditingController();
  late final TextEditingController _caloriesController;
  bool _showForm = true;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController(text: '$_dailyCalories');
    // Check if there's a saved meal plan - if so, show the plan view instead of form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mealPlanProvider = context.read<MealPlanProvider>();
        final mealPlan = mealPlanProvider.currentMealPlan;
        if (mealPlan != null) {
          setState(() {
            _showForm = false;
          });
          // Initialize selected day to today or the start date
          final today = DateTime.now();
          final selectedDate = (today.isAfter(mealPlan.startDate) && today.isBefore(mealPlan.endDate.add(const Duration(days: 1))))
              ? today
              : mealPlan.startDate;
          mealPlanProvider.setSelectedDay(selectedDate);
        }
      }
    });
    _trackCardScreenOpen();
  }

  /// Track when card screen is opened
  Future<void> _trackCardScreenOpen() async {
    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(context, listen: false);
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
    _allergiesController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(context, listen: false);
    
    if (!premiumProvider.isPremium) {
      // Track the back action
      final backCount = await CardAdTracker.trackCardBack();
      
      // Get the card_inter configuration (single value like "open5" or "back5" or "off")
      final cardInterConfig = RemoteConfigService.cardInter.trim().toLowerCase();
      
      // Check if card_inter is "off" - if so, don't show ad
      if (cardInterConfig != 'off' && cardInterConfig.isNotEmpty) {
        // Check if config starts with "back"
        if (cardInterConfig.startsWith('back')) {
          try {
            // Extract number after "back"
            final numStr = cardInterConfig.substring(4); // "back" is 4 characters
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
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  Future<void> _generatePlan() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if user is premium (premium users don't see ads)
    final premiumProvider = Provider.of<PremiumProvider>(context, listen: false);
    final shouldShowAd = !premiumProvider.isPremium;
    
    bool shouldProceed = true;

    if (shouldShowAd) {
      // Track the generate plan tap
      final generateCount = await CardAdTracker.trackGeneratePlan();
      
      // Get the generateplan_inter configuration (single integer string or "off")
      final generatePlanConfig = RemoteConfigService.generatePlanInter.trim().toLowerCase();
      
      // Check if generateplan_inter is "off" - if so, don't show ad
      if (generatePlanConfig != 'off' && generatePlanConfig.isNotEmpty) {
        // Parse the threshold value (single integer string)
        bool meetsThreshold = false;
        try {
          final threshold = int.parse(generatePlanConfig);
          if (threshold > 0) {
            // Show ad when counter >= threshold
            meetsThreshold = generateCount >= threshold;
          }
        } catch (e) {
          // If parsing fails, don't show ad
          meetsThreshold = false;
        }
        
        if (meetsThreshold) {
          shouldProceed = false;
          
          // Show ad with loader (loader is handled in AdService)
          await AdService.showInterstitialAdForType(
            adType: 'generatePlan',
            context: context,
            loadAdFunction: () => AdService.loadGeneratePlanInterstitialAd(),
            onAdDismissed: () {
              // Reset counter after ad is shown
              CardAdTracker.resetGeneratePlanCount();
              // Proceed with plan generation after ad is dismissed
              _executePlanGeneration();
            },
            onAdFailedToShow: (ad) {
              // Reset counter even if ad fails to show
              CardAdTracker.resetGeneratePlanCount();
              // Proceed even if ad fails
              _executePlanGeneration();
            },
          );
        }
      }
    }

    if (shouldProceed) {
      _executePlanGeneration();
    }
  }

  Future<void> _executePlanGeneration() async {
    if (!mounted) return;
    
    final provider = context.read<MealPlanProvider>();
    
    try {
      final plan = await provider.generateMealPlan(
        days: _days,
        dietType: _selectedDiet,
        healthGoal: _selectedGoal,
        dailyCalories: _dailyCalories,
        allergies: _allergies.isEmpty ? null : _allergies,
        budget: _selectedBudget,
        fastingSchedule: _selectedFasting,
        skillLevel: _selectedSkill,
      );

      if (plan != null && mounted) {
        setState(() {
          _showForm = false;
          _selectedDayIndex = 0;
        });
        // Set selected day to today or start date
        final today = DateTime.now();
        final selectedDate = (today.isAfter(plan.startDate) && today.isBefore(plan.endDate.add(const Duration(days: 1))))
            ? today
            : plan.startDate;
        provider.setSelectedDay(selectedDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('meal.planner.creating.plan')),
            backgroundColor: AppColors.primary,
          ),
        );
      } else if (mounted) {
        // Show error message if generation failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('meal.planner.generation.failed'),
            ),
            backgroundColor: AppColors.destructive,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Extract user-friendly error message
        String errorMessage = e.toString();
        // Remove "Exception: " prefix if present
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isNotEmpty 
                  ? errorMessage 
                  : context.t('meal.planner.generation.failed'),
            ),
            backgroundColor: AppColors.destructive,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final mealPlan = mealPlanProvider.currentMealPlan;
    final isLoading = mealPlanProvider.isLoading;

    // If meal plan is loaded and we're still showing form, switch to plan view
    // This handles the case where meal plan loads after initState
    if (mealPlan != null && _showForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showForm = false;
          });
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        bottomNavigationBar: const BottomNav(activeTab: 'planner'),
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
                  title: context.t('meal.planner.title'),
                  onBack: _handleBack,
                  backgroundColor: Colors.transparent,
                  statusBarColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1F35)
                      : AppColors.genieBlush,
                ),
                Expanded(
                  child: isLoading
                      ? const LoadingGenie(message: 'Creating Your Plan...')
                      : mealPlan != null && !_showForm
                          ? _buildMealPlanView(context, mealPlan, mealPlanProvider)
                          : _buildFormView(context),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
            // Your Profile Section
            _buildSection(
              context,
              title: context.t('meal.planner.your.profile'),
              icon: Icons.show_chart,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final availableWidth = constraints.maxWidth;
                  
                  // Use column layout on small screens (< 360px) to prevent overflow
                  // Also check available width in case of padding constraints
                  final useColumnLayout = screenWidth < 360 || availableWidth < 280;
                  
                  // Adaptive spacing and sizing based on screen width
                  final horizontalSpacing = screenWidth < 400 ? 12.0 : 16.0;
                  final buttonPadding = screenWidth < 360 ? 6.0 : 8.0;
                  final numberBoxWidth = screenWidth < 360 ? 45.0 : 50.0;
                  final fontSize = screenWidth < 360 ? 16.0 : 18.0;
                  final buttonFontSize = screenWidth < 360 ? 18.0 : 20.0;
                  
                  // Build Family Size widget
                  Widget buildFamilySize() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('meal.planner.family.size'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (_familySize > 1) {
                                    setState(() => _familySize--);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.all(buttonPadding),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: numberBoxWidth,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_familySize',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (_familySize < 8) {
                                    setState(() => _familySize++);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.all(buttonPadding),
                                  child: Text(
                                    '+',
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  
                  // Build Daily Calories widget
                  Widget buildDailyCalories() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('meal.planner.daily.calories'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.local_fire_department,
                              size: screenWidth < 360 ? 18 : 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenWidth < 360 ? 12 : 16,
                              vertical: screenWidth < 360 ? 10 : 12,
                            ),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            final calories = int.tryParse(value);
                            if (calories != null && calories >= 1000 && calories <= 5000) {
                              setState(() => _dailyCalories = calories);
                            }
                          },
                        ),
                      ],
                    );
                  }
                  
                  if (useColumnLayout) {
                    // Column layout for small screens
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildFamilySize(),
                        SizedBox(height: horizontalSpacing),
                        buildDailyCalories(),
                      ],
                    );
                  }
                  
                  // Row layout for larger screens
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: 1,
                        child: buildFamilySize(),
                      ),
                      SizedBox(width: horizontalSpacing),
                      Flexible(
                        flex: 1,
                        child: buildDailyCalories(),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Plan Duration
            _buildSection(
              context,
              title: context.t('meal.planner.plan.duration'),
              icon: Icons.calendar_today,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDurationChip('7', 7),
                  _buildDurationChip('14', 14),
                  _buildDurationChip('30', 30),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Health Goal
            _buildSection(
              context,
              title: context.t('meal.planner.health.goal'),
              icon: Icons.balance,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context.t('meal.planner.lose.weight'),
                    _selectedGoal == 'lose_weight',
                    () => setState(() => _selectedGoal = 'lose_weight'),
                  ),
                  _buildChip(
                    context.t('meal.planner.build.muscle'),
                    _selectedGoal == 'build_muscle',
                    () => setState(() => _selectedGoal = 'build_muscle'),
                  ),
                  _buildChip(
                    context.t('meal.planner.stay.healthy'),
                    _selectedGoal == 'stay_healthy',
                    () => setState(() => _selectedGoal = 'stay_healthy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Diet Type
            _buildSection(
              context,
              title: context.t('meal.planner.diet.type'),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context.t('meal.planner.balanced'),
                    _selectedDiet == 'balanced',
                    () => setState(() => _selectedDiet = 'balanced'),
                  ),
                  _buildChip(
                    context.t('meal.planner.keto'),
                    _selectedDiet == 'keto',
                    () => setState(() => _selectedDiet = 'keto'),
                  ),
                  _buildChip(
                    context.t('meal.planner.vegan'),
                    _selectedDiet == 'vegan',
                    () => setState(() => _selectedDiet = 'vegan'),
                  ),
                  _buildChip(
                    context.t('meal.planner.halal'),
                    _selectedDiet == 'halal',
                    () => setState(() => _selectedDiet = 'halal'),
                  ),
                  _buildChip(
                    context.t('meal.planner.high.protein'),
                    _selectedDiet == 'high_protein',
                    () => setState(() => _selectedDiet = 'high_protein'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Budget
            _buildSection(
              context,
              title: '\$ ${context.t('meal.planner.budget')}',
              icon: Icons.attach_money,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context.t('meal.planner.budget'),
                    _selectedBudget == 'budget',
                    () => setState(() => _selectedBudget = 'budget'),
                  ),
                  _buildChip(
                    context.t('meal.planner.moderate'),
                    _selectedBudget == 'moderate',
                    () => setState(() => _selectedBudget = 'moderate'),
                  ),
                  _buildChip(
                    context.t('meal.planner.premium'),
                    _selectedBudget == 'premium',
                    () => setState(() => _selectedBudget = 'premium'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Skill Level
            _buildSection(
              context,
              title: context.t('meal.planner.skill'),
              icon: Icons.restaurant_menu,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context.t('meal.planner.beginner'),
                    _selectedSkill == 'beginner',
                    () => setState(() => _selectedSkill = 'beginner'),
                  ),
                  _buildChip(
                    context.t('meal.planner.intermediate'),
                    _selectedSkill == 'intermediate',
                    () => setState(() => _selectedSkill = 'intermediate'),
                  ),
                  _buildChip(
                    context.t('meal.planner.advanced'),
                    _selectedSkill == 'advanced',
                    () => setState(() => _selectedSkill = 'advanced'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Intermittent Fasting
            _buildSection(
              context,
              title: context.t('meal.planner.intermittent.fasting'),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context.t('meal.planner.none'),
                    _selectedFasting == null || _selectedFasting == 'none',
                    () => setState(() => _selectedFasting = 'none'),
                  ),
                  _buildChip(
                    '16:8',
                    _selectedFasting == '16:8',
                    () => setState(() => _selectedFasting = '16:8'),
                  ),
                  _buildChip(
                    '18:6',
                    _selectedFasting == '18:6',
                    () => setState(() => _selectedFasting = '18:6'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Allergies
            _buildSection(
              context,
              title: context.t('meal.planner.allergies'),
              child: TextField(
                controller: _allergiesController,
                decoration: InputDecoration(
                  hintText: context.t('meal.planner.allergies.placeholder'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  _allergies = value
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                },
              ),
            ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generatePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      context.t('meal.planner.generate.plan'),
                      style: const TextStyle(
                        fontSize: 18,
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
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required Widget child, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDurationChip(String label, int days) {
    final isSelected = _days == days;
    return GestureDetector(
      onTap: () => setState(() => _days = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.gradientPrimary : null,
          color: isSelected ? null : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: AppColors.border.withOpacity(0.8),
                  width: 1,
                ),
        ),
        child: Text(
          '$label ${context.t('meal.planner.days')}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.gradientPrimary : null,
          color: isSelected ? null : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: AppColors.border.withOpacity(0.8),
                  width: 1,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildMealPlanView(
      BuildContext context, MealPlan plan, MealPlanProvider provider) {
    final days = plan.endDate.difference(plan.startDate).inDays + 1;
    final mealsByDay = <int, Map<String, MealPlanMeal>>{};
    final snacksByDay = <int, List<MealPlanMeal>>{};

    for (var meal in plan.meals) {
      final dayIndex = meal.date.difference(plan.startDate).inDays;
      if (meal.mealType == 'snack') {
        snacksByDay.putIfAbsent(dayIndex, () => <MealPlanMeal>[]).add(meal);
      } else {
        if (!mealsByDay.containsKey(dayIndex)) {
          mealsByDay[dayIndex] = {};
        }
        mealsByDay[dayIndex]![meal.mealType] = meal;
      }
    }

    // Ensure selected day index is within bounds
    if (_selectedDayIndex >= days) {
      _selectedDayIndex = 0;
    }

    final selectedDayDate = plan.startDate.add(Duration(days: _selectedDayIndex));
    final selectedDayMeals = mealsByDay[_selectedDayIndex] ?? {};
    final selectedSnacks = snacksByDay[_selectedDayIndex] ?? const <MealPlanMeal>[];
    final dayTotals = _calculateDayTotals(selectedDayMeals, selectedSnacks);


    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Plan Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.genieLavender.withOpacity(0.2),
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
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (plan.description != null && plan.description!.isNotEmpty)
                  Text(
                    plan.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  )
                else
                  Text(
                    'A ${days}-day meal plan designed for individuals following a halal diet and aiming to maintain overall health with balanced nutrition.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 18, color: AppColors.geniePink),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.dailyCalories} ${context.t('meal.planner.cal')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.geniePurple),
                        const SizedBox(width: 4),
                        Text(
                          '$days ${context.t('meal.planner.days')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Grocery List Button
          Row(
            children: [
              Expanded(
                child: Container(
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
                  child: ElevatedButton(
                    onPressed: () async {
                      final mealPlan = provider.currentMealPlan;
                      if (mealPlan == null || mealPlan.meals.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('grocery.create.meal.plan.first')),
                            backgroundColor: AppColors.destructive,
                          ),
                        );
                        return;
                      }
                      
                      // Navigate immediately - generation will happen in grocery screen
                      // This matches web app pattern for better UX
                      if (mounted) {
                        context.go('/grocery?fromPlan=true');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t('meal.planner.grocery.list'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('meal_planner_refresh'),
                    onTap: () async {
                      try {
                        await provider.clearMealPlan();
                        if (!mounted) return;
                        setState(() {
                          _showForm = true;
                          _days = 7;
                          _dailyCalories = 2000;
                          _familySize = 1;
                          _selectedDiet = null;
                          _selectedGoal = null;
                          _selectedBudget = 'moderate';
                          _selectedSkill = 'intermediate';
                          _selectedFasting = null;
                          _allergies = [];
                          _allergiesController.clear();
                          _caloriesController.text = '2000';
                          _selectedDayIndex = 0;
                        });
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('meal.planner.generation.failed')),
                            backgroundColor: AppColors.destructive,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Icon(
                        Icons.refresh,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Day Navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _selectedDayIndex > 0
                      ? () {
                          setState(() => _selectedDayIndex--);
                          context.read<MealPlanProvider>().setSelectedDay(
                            plan.startDate.add(Duration(days: _selectedDayIndex)),
                          );
                        }
                      : null,
                ),
                Text(
                  _getDayName(selectedDayDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedDayIndex < days - 1
                      ? () {
                          setState(() => _selectedDayIndex++);
                          context.read<MealPlanProvider>().setSelectedDay(
                            plan.startDate.add(Duration(days: _selectedDayIndex)),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Plan Native Ad (Medium)
          const ScreenNativeAdWidget(
            screenKey: 'plan',
            size: CustomNativeAdSize.medium,
          ),
          const SizedBox(height: 16),
          // Breakfast Card
          if (selectedDayMeals['breakfast'] != null)
            _buildMealCard(
              context,
              context.t('meal.planner.breakfast'),
              selectedDayMeals['breakfast']!,
              _selectedDayIndex,
              'breakfast',
              provider,
            ),
          if (selectedDayMeals['breakfast'] != null) const SizedBox(height: 12),
          // Lunch Card
          if (selectedDayMeals['lunch'] != null)
            _buildMealCard(
              context,
              context.t('meal.planner.lunch'),
              selectedDayMeals['lunch']!,
              _selectedDayIndex,
              'lunch',
              provider,
            ),
          if (selectedDayMeals['lunch'] != null) const SizedBox(height: 12),
          // Dinner Card
          if (selectedDayMeals['dinner'] != null)
            _buildMealCard(
              context,
              context.t('meal.planner.dinner'),
              selectedDayMeals['dinner']!,
              _selectedDayIndex,
              'dinner',
              provider,
            ),
          const SizedBox(height: 16),

          // Snacks (matches screenshot section)
          _buildSnacksSection(context, selectedSnacks),
          const SizedBox(height: 12),

          // Daily Total (matches screenshot card)
          _buildDailyTotalCard(context, dayTotals),
          const SizedBox(height: 12),

          // Meal Prep Tips (matches screenshot section)
          _buildMealPrepTipsCard(context, plan),
          const SizedBox(height: 16),

          // Create New Plan CTA (matches screenshot bottom button)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await provider.clearMealPlan();
                  if (!mounted) return;
                  setState(() {
                    _showForm = true;
                    _days = 7;
                    _dailyCalories = 2000;
                    _familySize = 1;
                    _selectedDiet = null;
                    _selectedGoal = null;
                    _selectedBudget = 'moderate';
                    _selectedSkill = 'intermediate';
                    _selectedFasting = null;
                    _allergies = [];
                    _allergiesController.clear();
                    _caloriesController.text = '2000';
                    _selectedDayIndex = 0;
                  });
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('meal.planner.generation.failed')),
                      backgroundColor: AppColors.destructive,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: Text(
                    context.t('meal.planner.create.new.plan'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  ({int calories, int protein, int carbs, int fat}) _calculateDayTotals(
    Map<String, MealPlanMeal> meals,
    List<MealPlanMeal> snacks,
  ) {
    int sumInt(int? v) => v ?? 0;

    final allMeals = <MealPlanMeal>[...meals.values, ...snacks];
    final calories = allMeals.fold<int>(0, (s, m) => s + sumInt(m.calories));
    final protein = allMeals.fold<int>(0, (s, m) => s + sumInt(m.protein));
    final carbs = allMeals.fold<int>(0, (s, m) => s + sumInt(m.carbs));
    final fat = allMeals.fold<int>(0, (s, m) => s + sumInt(m.fat));

    return (calories: calories, protein: protein, carbs: carbs, fat: fat);
  }

  Widget _buildSnacksSection(BuildContext context, List<MealPlanMeal> snacks) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(Icons.restaurant, size: 18, color: AppColors.genieGold),
              const SizedBox(width: 8),
              Text(
                context.t('meal.planner.snacks'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (snacks.isEmpty)
            Text(
              '—',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            )
          else
            ...snacks.map((snack) {
              final calories = snack.calories ?? 0;
              return InkWell(
                onTap: () {
                  // Navigate to recipe detail screen
                  final slug = _createSlug(snack.recipeTitle);
                  context.push('/recipe/$slug');
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          snack.recipeTitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$calories ${context.t('meal.planner.cal')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDailyTotalCard(
    BuildContext context,
    ({int calories, int protein, int carbs, int fat}) totals,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.55), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('meal.planner.daily.total'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDailyTotalStat(context, '${totals.calories}', context.t('meal.planner.cal'), AppColors.geniePink),
              _buildDailyTotalStat(context, '${totals.protein}g', context.t('meal.planner.protein'), AppColors.geniePurple),
              _buildDailyTotalStat(context, '${totals.carbs}g', context.t('meal.planner.carbs'), AppColors.genieGold),
              _buildDailyTotalStat(context, '${totals.fat}g', context.t('meal.planner.fat'), AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTotalStat(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildMealPrepTipsCard(BuildContext context, MealPlan plan) {
    final tips = (plan.mealPrepTips != null && plan.mealPrepTips!.isNotEmpty)
        ? plan.mealPrepTips!
        : const [
            'Meal prep on Sunday: Cook a batch of rice, chop vegetables, and pre-portion snacks to save time during the week.',
            'Stay hydrated: Drink plenty of water throughout the day, aiming for at least 8 glasses.',
            "Listen to your body: Adjust portion sizes based on your hunger and energy levels. These are guidelines, not strict rules.",
            "Don’t be afraid to substitute: If you don’t like a particular ingredient, swap it for a similar nutritious alternative.",
            'Add variety to snacks: Rotate with options like fruit, veggies with hummus, or a small handful of nuts.',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.genieGold.withOpacity(0.55), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('meal.planner.meal.prep.tips'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: AppColors.genieGold,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return context.t('meal.planner.today');
    }
    
    // Use localized day name
    final locale = Localizations.localeOf(context);
    return DateFormat('EEEE', locale.toString()).format(date);
  }


  String _createSlug(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  Widget _buildMealCard(
    BuildContext context,
    String mealType,
    MealPlanMeal meal,
    int dayIndex,
    String mealTypeKey,
    MealPlanProvider provider,
  ) {
    return InkWell(
      onTap: () {
        // Navigate to recipe detail screen
        final slug = _createSlug(meal.recipeTitle);
        context.push('/recipe/$slug');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        padding: const EdgeInsets.all(16),
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
            // Header Row: Meal Type Label and Swap Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal Type Label (left side)
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mealType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              // Swap Button (right side, top aligned)
              TextButton.icon(
                onPressed: provider.swappingMealType == mealTypeKey
                    ? null
                    : () => provider.swapMeal(dayIndex, mealTypeKey),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                icon: provider.swappingMealType == mealTypeKey
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.refresh,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                label: Text(
                  provider.swappingMealType == mealTypeKey
                      ? context.t('meal.planner.swapping')
                      : context.t('meal.planner.swap'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              ],
            ),
            const SizedBox(height: 12),
            // Meal Title
            Text(
              meal.recipeTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Meal Description (full text, no truncation)
            if (meal.description != null && meal.description!.isNotEmpty)
              Text(
                meal.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 12),
            // Bottom Row: Nutritional Info (horizontal layout)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (meal.calories != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: AppColors.geniePink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meal.calories}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                if (meal.protein != null)
                  Text(
                    '${context.t('meal.planner.protein.short')}: ${meal.protein}g',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (meal.carbs != null)
                  Text(
                    '${context.t('meal.planner.carbs.short')}: ${meal.carbs}g',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (meal.prepTime != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.geniePurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meal.prepTime}m',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
