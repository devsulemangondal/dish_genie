import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/models/meal_plan.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';

class MealPlanProvider with ChangeNotifier {
  MealPlan? _currentMealPlan;
  bool _isLoading = false;
  String? _swappingMealType;
  DateTime? _selectedDay;

  MealPlan? get currentMealPlan => _currentMealPlan;
  bool get isLoading => _isLoading;
  String? get swappingMealType => _swappingMealType;
  DateTime? get selectedDay => _selectedDay;

  MealPlanProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final stored = await StorageService.getMealPlan();
      if (stored != null) {
        _currentMealPlan = MealPlan.fromJson(json.decode(stored));
        notifyListeners();
      }
    } catch (e) {
      print('Error loading meal plan: $e');
    }
  }

  Future<MealPlan?> generateMealPlan({
    required int days,
    String? dietType,
    String? healthGoal,
    required int dailyCalories,
    List<String>? allergies,
    String? budget,
    String? fastingSchedule,
    String? skillLevel,
  }) async {
    _isLoading = true;
    _currentMealPlan = null;
    notifyListeners();

    try {
      if (!SupabaseService.isInitialized) {
        throw Exception(
          'Meal plan service is not configured. Set supabase_url and supabase_anon_key in Firebase Remote Config, or in lib/config/supabase_config.dart (use your Supabase project URL and anon key from the Dashboard).',
        );
      }

      final supabaseUrl = SupabaseService.url;
      final supabaseKey = SupabaseService.anonKey;

      if (supabaseUrl == null || supabaseKey == null) {
        throw Exception(
          'Supabase credentials are missing. Add supabase_anon_key in Firebase Remote Config or in lib/config/supabase_config.dart.',
        );
      }

      // Get current language (matching web app pattern)
      final currentLanguage = await StorageService.getLanguage() ?? 'en';

      // Use direct HTTP call (matching web app pattern)
      final functionUrl = '$supabaseUrl/functions/v1/generate-meal-plan';

      final requestBody = {
        'days': days,
        if (dietType != null) 'dietType': dietType, // Match web app: camelCase
        if (healthGoal != null)
          'healthGoal': healthGoal, // Match web app: camelCase
        'dailyCalories': dailyCalories, // Match web app: camelCase
        if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
        if (budget != null) 'budget': budget,
        if (fastingSchedule != null && fastingSchedule != 'none')
          'fastingSchedule': fastingSchedule, // Match web app: camelCase
        if (skillLevel != null)
          'skillLevel': skillLevel, // Match web app: camelCase
        'language': currentLanguage, // Match web app: include language
      };

      if (kDebugMode) {
        print('📤 [MealPlan] Request URL: $functionUrl');
        print('📤 [MealPlan] Request body: ${json.encode(requestBody)}');
      }

      final httpResponse = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey, // Required by Supabase Edge Functions
        },
        body: json.encode(requestBody),
      );

      if (kDebugMode) {
        print('📥 [MealPlan] Response status: ${httpResponse.statusCode}');
        print('📥 [MealPlan] Response body: ${httpResponse.body}');
      }

      if (httpResponse.statusCode != 200) {
        String errorMessage = 'Request failed';
        try {
          final errorBody =
              json.decode(httpResponse.body) as Map<String, dynamic>?;
          errorMessage =
              errorBody?['error']?.toString() ??
              errorBody?['message']?.toString() ??
              'Request failed with status ${httpResponse.statusCode}';
        } catch (e) {
          // If response body is not JSON, use the raw body or status code
          errorMessage = httpResponse.body.isNotEmpty
              ? httpResponse.body
              : 'Request failed with status ${httpResponse.statusCode}';
        }
        throw Exception(errorMessage);
      }

      final responseData =
          json.decode(httpResponse.body) as Map<String, dynamic>;

      // Check if there's an error message in the response
      if (responseData['error'] != null) {
        throw Exception(responseData['error'].toString());
      }

      if (responseData['mealPlan'] == null) {
        throw Exception('Invalid response format: mealPlan not found');
      }

      final planData = responseData['mealPlan'] as Map<String, dynamic>;

      // Convert to MealPlan model
      final meals = <MealPlanMeal>[];
      if (planData['meals'] != null) {
        final mealsList = planData['meals'] as List;
        for (var mealData in mealsList) {
          final mealMap = mealData as Map<String, dynamic>;
          final date = DateTime.now().add(
            Duration(days: mealMap['day'] as int? ?? 0),
          );

          ({int? calories, int? protein, int? carbs, int? fat, int? prepTime})
          extractNutrition(Map<String, dynamic> meal) {
            int? calories;
            int? protein;
            int? carbs;
            int? fat;
            int? prepTime;

            if (meal['nutrition'] != null) {
              final nutrition = meal['nutrition'] as Map<String, dynamic>;
              calories = nutrition['calories'] as int?;
              protein = nutrition['protein'] as int?;
              carbs = nutrition['carbs'] as int?;
              fat = nutrition['fat'] as int?;
            } else {
              // Try flat structure
              calories = meal['calories'] as int?;
              protein = meal['protein'] as int?;
              carbs = meal['carbs'] as int?;
              fat = meal['fat'] as int?;
            }

            // Extract prep time (can be in minutes or as time string)
            if (meal['prepTime'] != null) {
              prepTime = meal['prepTime'] as int?;
            } else if (meal['prep_time'] != null) {
              prepTime = meal['prep_time'] as int?;
            } else if (meal['time'] != null) {
              // If time is a string like "30m", parse it
              final timeStr = meal['time'].toString();
              if (timeStr.contains('m')) {
                prepTime = int.tryParse(timeStr.replaceAll('m', '').trim());
              }
            }

            return (
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
              prepTime: prepTime,
            );
          }

          // Add breakfast, lunch, dinner
          for (var mealType in ['breakfast', 'lunch', 'dinner']) {
            if (mealMap[mealType] != null) {
              final meal = mealMap[mealType] as Map<String, dynamic>;
              final n = extractNutrition(meal);

              meals.add(
                MealPlanMeal(
                  id: '${mealType}_${mealMap['day']}',
                  recipeId: (meal['id'] ?? '').toString(),
                  recipeTitle: (meal['title'] ?? '').toString(),
                  recipeImage: meal['image']?.toString(),
                  description: meal['description'] as String?,
                  mealType: mealType,
                  date: date,
                  servings: meal['servings'] as int? ?? 1,
                  calories: n.calories,
                  protein: n.protein,
                  carbs: n.carbs,
                  fat: n.fat,
                  prepTime: n.prepTime,
                ),
              );
            }
          }

          // Add snacks (if provided by edge function)
          final snacksData = mealMap['snacks'] ?? mealMap['snack'];
          if (snacksData is List) {
            for (var i = 0; i < snacksData.length; i++) {
              final snack = snacksData[i];
              if (snack is! Map<String, dynamic>) continue;
              final n = extractNutrition(snack);
              meals.add(
                MealPlanMeal(
                  id: 'snack_${mealMap['day']}_$i',
                  recipeId: (snack['id'] ?? '').toString(),
                  recipeTitle: (snack['title'] ?? snack['name'] ?? '')
                      .toString(),
                  recipeImage: snack['image']?.toString(),
                  description: snack['description']?.toString(),
                  mealType: 'snack',
                  date: date,
                  servings: snack['servings'] as int? ?? 1,
                  calories: n.calories,
                  protein: n.protein,
                  carbs: n.carbs,
                  fat: n.fat,
                  prepTime: n.prepTime,
                ),
              );
            }
          }
        }
      }

      if (meals.isEmpty) {
        throw Exception('Generated meal plan contains no meals');
      }

      // Extract macros if available
      Map<String, int>? macros;
      if (planData['macros'] != null) {
        final macrosData = planData['macros'] as Map<String, dynamic>;
        macros = {
          'protein': macrosData['protein'] as int? ?? 0,
          'carbs': macrosData['carbs'] as int? ?? 0,
          'fat': macrosData['fat'] as int? ?? 0,
        };
      }

      // Extract meal prep tips if available
      List<String>? mealPrepTips;
      final tipsData =
          planData['meal_prep_tips'] ??
          planData['mealPrepTips'] ??
          planData['mealPrepTips'.toLowerCase()];
      if (tipsData is List) {
        mealPrepTips = tipsData
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }

      final plan = MealPlan(
        id: planData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: planData['name'] ?? 'My Meal Plan',
        description: planData['description'] as String?,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: days)),
        dailyCalories:
            planData['daily_calories'] ??
            planData['dailyCalories'] ??
            dailyCalories,
        meals: meals,
        macros: macros,
        mealPrepTips: mealPrepTips,
        budget: budget ?? planData['budget'] as String?,
        skillLevel: skillLevel ?? planData['skillLevel'] as String?,
        createdAt: DateTime.now(),
      );

      _currentMealPlan = plan;
      await _saveToStorage(plan);
      _isLoading = false;
      notifyListeners();
      return plan;
    } catch (e, stackTrace) {
      print('Error generating meal plan: $e');
      print('Stack trace: $stackTrace');
      _isLoading = false;
      notifyListeners();

      // Extract meaningful error message
      String errorMessage;

      if (e is Exception) {
        final errorString = e.toString();
        // Check for HTTP errors
        if (errorString.contains('404') || errorString.contains('NOT_FOUND')) {
          errorMessage =
              'The meal planning service is not available. Please try again later or contact support.';
        } else if (errorString.contains('429') ||
            errorString.contains('rate limit')) {
          errorMessage = 'Rate limit exceeded. Please try again later.';
        } else {
          errorMessage = errorString.replaceFirst('Exception: ', '');
        }
      } else {
        errorMessage = e.toString();
      }

      // Ensure we have a meaningful message
      if (errorMessage.isEmpty || errorMessage == 'null') {
        errorMessage =
            'Failed to generate meal plan. Please check your connection and try again.';
      }

      // Re-throw with meaningful error message
      throw Exception(errorMessage);
    }
  }

  Future<void> swapMeal(int dayIndex, String mealType) async {
    if (_currentMealPlan == null) return;

    _swappingMealType = mealType;
    notifyListeners();

    try {
      // Get Supabase URL and key
      final supabaseUrl = SupabaseService.url;
      final supabaseKey = SupabaseService.anonKey;

      if (supabaseUrl == null || supabaseKey == null) {
        return;
      }

      // Get current language (matching web app pattern)
      final currentLanguage = await StorageService.getLanguage() ?? 'en';

      // Use direct HTTP call (matching web app pattern)
      final functionUrl = '$supabaseUrl/functions/v1/generate-meal-plan';

      final requestBody = {
        'days': 1,
        'dailyCalories':
            _currentMealPlan!.dailyCalories, // Match web app: camelCase
        'swapOnly': true, // Match web app: camelCase
        'mealType': mealType, // Match web app: camelCase
        'language': currentLanguage, // Match web app: include language
      };

      final httpResponse = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey, // Required by Supabase Edge Functions
        },
        body: json.encode(requestBody),
      );

      if (httpResponse.statusCode != 200) {
        if (kDebugMode) {
          print('❌ [MealPlan] Swap meal failed: ${httpResponse.statusCode}');
          print('❌ [MealPlan] Response: ${httpResponse.body}');
        }
        return;
      }

      final responseData =
          json.decode(httpResponse.body) as Map<String, dynamic>;

      if (responseData['mealPlan'] != null) {
        final planData = responseData['mealPlan'] as Map<String, dynamic>;
        final newMealData = planData['meals']?[0]?[mealType];

        if (newMealData != null) {
          final date = _currentMealPlan!.startDate.add(
            Duration(days: dayIndex),
          );
          final updatedMeals = List<MealPlanMeal>.from(_currentMealPlan!.meals);

          // Remove old meal of this type for this day
          updatedMeals.removeWhere(
            (m) =>
                m.date.year == date.year &&
                m.date.month == date.month &&
                m.date.day == date.day &&
                m.mealType == mealType,
          );

          // Extract nutrition data from swapped meal
          int? calories;
          int? protein;
          int? carbs;
          int? fat;
          int? prepTime;

          if (newMealData['nutrition'] != null) {
            final nutrition = newMealData['nutrition'] as Map<String, dynamic>;
            calories = nutrition['calories'] as int?;
            protein = nutrition['protein'] as int?;
            carbs = nutrition['carbs'] as int?;
            fat = nutrition['fat'] as int?;
          } else {
            calories = newMealData['calories'] as int?;
            protein = newMealData['protein'] as int?;
            carbs = newMealData['carbs'] as int?;
            fat = newMealData['fat'] as int?;
          }

          if (newMealData['prepTime'] != null) {
            prepTime = newMealData['prepTime'] as int?;
          } else if (newMealData['prep_time'] != null) {
            prepTime = newMealData['prep_time'] as int?;
          } else if (newMealData['time'] != null) {
            final timeStr = newMealData['time'].toString();
            if (timeStr.contains('m')) {
              prepTime = int.tryParse(timeStr.replaceAll('m', '').trim());
            }
          }

          // Add new meal
          updatedMeals.add(
            MealPlanMeal(
              id: '${mealType}_${dayIndex}_${DateTime.now().millisecondsSinceEpoch}',
              recipeId: newMealData['id'] ?? '',
              recipeTitle: newMealData['title'] ?? '',
              recipeImage: newMealData['image'],
              description: newMealData['description'] as String?,
              mealType: mealType,
              date: date,
              servings: newMealData['servings'] as int? ?? 1,
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
              prepTime: prepTime,
            ),
          );

          _currentMealPlan = _currentMealPlan!.copyWith(meals: updatedMeals);
          await _saveToStorage(_currentMealPlan!);
        }
      }
    } catch (e) {
      print('Error swapping meal: $e');
    } finally {
      _swappingMealType = null;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage(MealPlan plan) async {
    try {
      await StorageService.saveMealPlan(json.encode(plan.toJson()));
    } catch (e) {
      print('Error saving meal plan: $e');
    }
  }

  void setMealPlan(MealPlan? plan) {
    _currentMealPlan = plan;
    if (plan != null) {
      _saveToStorage(plan);
    }
    notifyListeners();
  }

  Future<void> clearMealPlan() async {
    _currentMealPlan = null;
    notifyListeners();
    try {
      await StorageService.clearMealPlan();
    } catch (e) {
      print('Error clearing meal plan storage: $e');
    }
    // Note: Grocery list clearing should be handled by the caller
    // to avoid circular dependencies between providers
  }

  void setSelectedDay(DateTime? day) {
    _selectedDay = day;
    notifyListeners();
  }
}
