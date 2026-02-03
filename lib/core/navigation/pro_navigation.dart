import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation helper for Pro screen
class ProNavigation {
  /// Try to open the Pro screen
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
