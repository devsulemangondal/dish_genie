import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/analytics_service.dart';
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
import '../../screens/scanner/custom_camera_screen.dart';
import '../../screens/scanner/crop_image_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/not_found/not_found_screen.dart';
import '../../screens/landing/landing_screen.dart';
import '../../screens/premium/pro_screen.dart';
import '../../screens/app_open_ad_loader_screen.dart';
import '../../providers/language_provider.dart';
import '../../data/models/recipe.dart';
import '../../widgets/common/main_tab_shell.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Route observer for screens that need to react when becoming visible again
  /// (e.g. FavoritesScreen to reload data after user returns from recipe detail)
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  /// Get the root navigator key for accessing navigator context
  static GlobalKey<NavigatorState>? getNavigatorKey() {
    return _rootNavigatorKey;
  }

  static GoRouter createRouter(LanguageProvider languageProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      observers: [
        _SafeAnalyticsRouteObserver(),
        routeObserver,
      ],
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainTabShell(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/',
                  name: 'home',
                  builder: (context, state) => const RecipeGeneratorScreen(
                    initialTabIndex: 1,
                    lockToAiGenerateTab: true,
                    showAsHomeTab: true,
                    isBottomTabRoot: true,
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/recipes',
                  name: 'recipes',
                  builder: (context, state) {
                    final search = state.uri.queryParameters['search'];
                    final category = state.uri.queryParameters['category'];
                    return RecipeGeneratorScreen(
                      searchQuery: search,
                      category: category,
                      isBottomTabRoot: true,
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/planner',
                  name: 'planner',
                  builder: (context, state) => const MealPlannerScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/grocery',
                  name: 'grocery',
                  builder: (context, state) {
                    final fromPlan =
                        state.uri.queryParameters['fromPlan'] == 'true';
                    return GroceryListScreen(fromPlan: fromPlan);
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/chat',
                  name: 'chat',
                  builder: (context, state) {
                    final extra = state.extra;
                    final recipe = extra is Recipe ? extra : null;
                    final cookLaunch = state.uri.queryParameters['cook'];
                    return ChatAssistantScreen(
                      initialRecipe: recipe,
                      cookLaunchId: cookLaunch,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/home',
          name: 'home-old',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/recipe/:slug',
          name: 'recipe-detail',
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return RecipeDetailScreen(slug: slug);
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
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
          parentNavigatorKey: _rootNavigatorKey,
          path: '/grocery/:id',
          name: 'saved-list-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return SavedListDetailScreen(listId: id);
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/chat-history',
          name: 'chat-history',
          builder: (context, state) => const ChatHistoryScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/scan-camera',
          name: 'scan-camera',
          builder: (context, state) => const CustomCameraScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/scan-crop',
          name: 'scan-crop',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is! XFile) return const NotFoundScreen();
            return CropImageScreen(image: extra);
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/scan',
          name: 'scan',
          builder: (context, state) {
            final extra = state.extra;
            return IngredientScannerScreen(
              initialImage: extra is XFile ? extra : null,
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/favorites',
          name: 'favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/pro',
          name: 'pro',
          builder: (context, state) => const ProScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/landing',
          name: 'landing',
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/app-open-ad-loader',
          name: 'app-open-ad-loader',
          builder: (context, state) => const AppOpenAdLoaderScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/:pathMatch(.*)*',
          name: 'not-found',
          builder: (context, state) => const NotFoundScreen(),
        ),
      ],
    );
  }
}

/// Logs screen views to Firebase Analytics without using Firebase's observer,
/// so analytics works even if the native observer would crash (e.g. with GoRouter).
class _SafeAnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _logRoute(newRoute);
  }

  void _logRoute(Route<dynamic> route) {
    try {
      final name = route.settings.name ?? route.settings.toString();
      if (name.isNotEmpty) {
        final screenName = name.startsWith('/') ? name : '/$name';
        if (kDebugMode) {
          print('📊 [Analytics] triggering screen_view for route: $screenName');
        }
        AnalyticsService.logScreenView(
          screenName: screenName,
          screenClass: route.runtimeType.toString(),
        );
      }
    } catch (e, st) {
      // Never let analytics crash the app
      if (kDebugMode) {
        print('📊 [Analytics] _logRoute error (ignored): $e');
        print('   $st');
      }
    }
  }
}
