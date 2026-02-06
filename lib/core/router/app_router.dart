import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../screens/splash/splash_screen.dart';
import '../../providers/premium_provider.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/language/language_selection_screen.dart';
import '../../screens/language/language_picker_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/recipes/recipe_generator_screen.dart';
import '../../screens/recipes/recipe_detail_screen.dart';
// import '../../screens/recipes/ai_recipe_detail_screen.dart';
import '../../screens/meal_planner/meal_planner_screen.dart';
import '../../screens/grocery/grocery_list_screen.dart';
import '../../screens/grocery/saved_list_detail_screen.dart';
import '../../screens/chat/chat_assistant_screen.dart';
import '../../screens/chat/chat_history_screen.dart';
import '../../screens/scanner/ingredient_scanner_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/not_found/not_found_screen.dart';
import '../../screens/landing/landing_screen.dart';
import '../../screens/premium/pro_screen.dart';
import '../../screens/app_open_ad_loader_screen.dart';
import '../../providers/language_provider.dart';
import '../../data/models/recipe.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Get the root navigator key for accessing navigator context
  static GlobalKey<NavigatorState>? getNavigatorKey() {
    return _rootNavigatorKey;
  }

  static GoRouter createRouter(LanguageProvider languageProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      errorBuilder: (context, state) => const NotFoundScreen(),
      redirect: (context, state) {
        try {
          final path = state.matchedLocation;

          // Skip guard for these routes
          if (path == '/splash' ||
              path == '/pro' ||
              path == '/language-selection' ||
              path == '/language-picker' ||
              path == '/onboarding' ||
              path == '/landing' ||
              path == '/app-open-ad-loader') {
            return null;
          }

          // Check language selection
          if (!languageProvider.isLanguageSelected) {
            return '/language-selection';
          }

          // Check premium status for pro screen
          if (path == '/pro') {
            try {
              // Use context.mounted check and safe provider access
              if (context.mounted) {
                final premiumProvider = Provider.of<PremiumProvider>(
                  context,
                  listen: false,
                );
                if (premiumProvider.isPremium) {
                  // Premium users should skip pro screen
                  return '/';
                }
              }
            } catch (e) {
              // If provider not available, continue to pro screen
              // Silently handle the error to prevent red screen
            }
          }

          // Check onboarding
          // Note: Check async in screen itself
          return null;
        } catch (e) {
          // If any error occurs during redirect, allow navigation to proceed
          // This prevents red screens during navigation
          return null;
        }
      },
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/language-selection',
          name: 'language-selection',
          builder: (context, state) => const LanguageSelectionScreen(),
        ),
        GoRoute(
          path: '/language-picker',
          name: 'language-picker',
          builder: (context, state) => const LanguagePickerScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth',
          name: 'auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/recipes',
          name: 'recipes',
          builder: (context, state) {
            final search = state.uri.queryParameters['search'];
            final category = state.uri.queryParameters['category'];
            return RecipeGeneratorScreen(
              searchQuery: search,
              category: category,
            );
          },
        ),
        GoRoute(
          path: '/recipe/:slug',
          name: 'recipe-detail',
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return RecipeDetailScreen(slug: slug);
          },
        ),
        GoRoute(
          path: '/ai-recipe',
          name: 'ai-recipe-detail',
          builder: (context, state) {
            final recipe = state.extra as Recipe?;
            if (recipe == null) {
              return const NotFoundScreen();
            }
            return RecipeDetailScreen(
              slug: recipe.slug ?? recipe.id,
              initialRecipe: recipe,
            );
          },
        ),
        GoRoute(
          path: '/planner',
          name: 'planner',
          builder: (context, state) => const MealPlannerScreen(),
        ),
        GoRoute(
          path: '/grocery',
          name: 'grocery',
          builder: (context, state) {
            final fromPlan = state.uri.queryParameters['fromPlan'] == 'true';
            return GroceryListScreen(fromPlan: fromPlan);
          },
        ),
        GoRoute(
          path: '/grocery/:id',
          name: 'saved-list-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return SavedListDetailScreen(listId: id);
          },
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const ChatAssistantScreen(),
        ),
        GoRoute(
          path: '/chat-history',
          name: 'chat-history',
          builder: (context, state) => const ChatHistoryScreen(),
        ),
        GoRoute(
          path: '/scan',
          name: 'scan',
          builder: (context, state) => const IngredientScannerScreen(),
        ),
        GoRoute(
          path: '/favorites',
          name: 'favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/pro',
          name: 'pro',
          builder: (context, state) => const ProScreen(),
        ),
        GoRoute(
          path: '/landing',
          name: 'landing',
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(
          path: '/app-open-ad-loader',
          name: 'app-open-ad-loader',
          builder: (context, state) => const AppOpenAdLoaderScreen(),
        ),
        GoRoute(
          path: '/:pathMatch(.*)*',
          name: 'not-found',
          builder: (context, state) => const NotFoundScreen(),
        ),
      ],
    );
  }
}
