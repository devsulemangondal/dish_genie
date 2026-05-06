import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/recipe_provider.dart';
import 'back_button_handler.dart';
import 'bottom_nav.dart';

/// Hosts the five main tabs with a single persistent bottom bar + banner ([GlobalKey] on banner).
///
/// [PopScope] lives here (inside the shell [ModalRoute]) so the system back button
/// is handled correctly. Ancestor-only handlers (e.g. wrapping [MaterialApp.router]'s
/// `child`) do **not** receive pops for routes inside the [Navigator].
class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell> {
  /// Keeps [BottomBannerAdWidget] state (and one [AdWidget]) across tab index changes.
  final GlobalKey _bottomBannerKey = GlobalKey();

  /// Measures [BottomNav] height so the exit sheet clears tab + banner controls.
  final GlobalKey _bottomNavBarMeasureKey = GlobalKey();

  bool _isExitSheetOpen = false;

  double _measuredBottomNavOverlap() {
    final box =
        _bottomNavBarMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.size.height;
    }
    return kExitSheetBottomNavOverlapFallback;
  }

  Future<void> _showExitConfirmation() async {
    if (!mounted) return;
    if (_isExitSheetOpen) return;

    _isExitSheetOpen = true;
    try {
      final bottomOverlap = _measuredBottomNavOverlap();
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: false,
        useRootNavigator: true,
        builder: (ctx) => ExitConfirmationBottomSheet(
          bottomNavOverlap: bottomOverlap,
        ),
      );
    } catch (e) {
      debugPrint('Error showing exit confirmation: $e');
    } finally {
      if (mounted) {
        _isExitSheetOpen = false;
      }
    }
  }

  void _handleShellPop(bool didPop) {
    if (didPop) return;

    if (_isExitSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      });
      return;
    }

    final shell = widget.navigationShell;
    // Tabs 1–4: the shell route can receive system back before the branch
    // [Navigator] forwards it. Explicitly delegate so tab screens (e.g. meal
    // planner cancel-while-loading) get [PopScope] / [Navigator.maybePop].
    if (shell.currentIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final branch = shell.route.branches[shell.currentIndex];
        branch.navigatorKey.currentState?.maybePop();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final recipeProvider = context.read<RecipeProvider>();
        if (recipeProvider.isLoading) {
          // Same as tabs 1–4: forward pop to the branch [Navigator] so
          // [RecipeGeneratorScreen]'s [PopScope] can show cancel-generation.
          final branch = shell.route.branches[shell.currentIndex];
          branch.navigatorKey.currentState?.maybePop();
          return;
        }
      } catch (_) {}
      _showExitConfirmation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        _handleShellPop(didPop);
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: BottomNav(
          navigationShell: widget.navigationShell,
          bannerKey: _bottomBannerKey,
          bottomBarMeasureKey: _bottomNavBarMeasureKey,
        ),
      ),
    );
  }
}
