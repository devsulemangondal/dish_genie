import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/language_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/theme_provider.dart';
import 'services/app_open_ad_manager.dart';
import 'widgets/common/back_button_handler.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final AppOpenAdManager _adManager = AppOpenAdManager.instance;
  GoRouter? _router;
  AppLifecycleState? _lastLifecycleState;

  /// True after we've been paused (user backgrounded app); used so that when we get
  /// resumed from inactive (e.g. paused->inactive->resumed), we still show app-open ad.
  bool _wasPausedBeforeInactive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize ad manager
    _adManager.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adManager.dispose();
    _router?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      print('🔄 [App] Lifecycle state changed: $state');
    }
    switch (state) {
      case AppLifecycleState.resumed:
        // Show app-open ad when returning from background: either paused->resumed or
        // paused->inactive->resumed. Skip when we went resumed->inactive->resumed (e.g. permission
        // dialog) so we don't show an ad after a dialog.
        final fromPaused = _lastLifecycleState == AppLifecycleState.paused;
        final fromInactiveAfterPause =
            (_lastLifecycleState == AppLifecycleState.inactive ||
                _lastLifecycleState == AppLifecycleState.hidden) &&
            _wasPausedBeforeInactive;
        if (fromPaused || fromInactiveAfterPause) {
          if (kDebugMode) {
            print(
              '📱 [App] App resumed from background, calling ad manager resume()',
            );
          }
          _adManager.resume();
          _wasPausedBeforeInactive = false;
        } else {
          if (kDebugMode) {
            print(
              '🛑 [App] Resumed from $_lastLifecycleState, skipping app-open ad',
            );
          }
        }
        break;
      case AppLifecycleState.paused:
        _wasPausedBeforeInactive = true;
        if (kDebugMode) {
          print('⏸️ [App] App paused, calling ad manager pause()');
        }
        _adManager.pause();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
    _lastLifecycleState = state;
  }

  GoRouter _getOrCreateRouter(LanguageProvider languageProvider) {
    // Only create router once - it accesses language provider dynamically via context
    // The router's redirect function accesses the language provider from context,
    // so it will always use the current locale without needing to be recreated
    if (_router == null) {
      _router = AppRouter.createRouter(languageProvider);

      // Store router in ad manager for direct access
      _adManager.setRouter(_router!);
      if (kDebugMode) {
        print('✅ [App] Router created and set in ad manager');
      }
    }

    return _router!;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GroceryProvider()),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => MealPlanProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, _) {
          final router = _getOrCreateRouter(languageProvider);

          return MaterialApp.router(
            title: 'DishGenie',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) {
              // Store context for ad manager
              Future.microtask(() {
                if (context.mounted) {
                  _adManager.setAppContext(context);
                  if (kDebugMode) {
                    print('✅ [App] Stored app context for ad manager');
                  }
                }
              });

              // Get the current theme brightness
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;

              final statusBarColor = theme.scaffoldBackgroundColor;
              final statusBarIconBrightness = isDark
                  ? Brightness.light
                  : Brightness.dark;

              // Wrap child in error boundary to prevent red screens
              Widget wrappedChild = child ?? const SizedBox.shrink();

              // Get text direction from language provider
              final textDirection = languageProvider.textDirection;

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  // Default for the app: match the app/header (solid surface).
                  // Specific screens (e.g. Home) can override to transparent.
                  statusBarColor: statusBarColor,
                  statusBarIconBrightness: statusBarIconBrightness,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  // Prevent Android from applying a contrast "scrim" that can make the
                  // status bar look different than the intended app/header color.
                  systemStatusBarContrastEnforced: false,
                ),
                child: BackButtonHandler(
                  homeRoutes: const ['/'],
                  child: Directionality(
                    textDirection: textDirection,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: MediaQuery.of(context).textScaler),
                      child: wrappedChild,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
