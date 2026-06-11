import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/premium_provider.dart';

/// Navigation helper for Pro screen.
/// From inside the app, user can always go to Pro (no checks).
class ProNavigation {
  /// Opens the Pro screen.
  ///
  /// [context] - BuildContext for navigation
  /// [replace] - If true, replaces current route; if false, pushes new route
  /// Returns true if navigation succeeded, false otherwise
  static Future<bool> tryOpen(
    BuildContext context, {
    bool replace = false,
  }) async {
    try {
      if (!context.mounted) return false;

      if (context.read<PremiumProvider>().isPremium) return false;

      if (replace) {
        context.go('/pro');
      } else {
        context.push('/pro');
      }

      return true;
    } catch (e) {
      debugPrint('Error navigating to Pro screen: $e');
      return false;
    }
  }
}
