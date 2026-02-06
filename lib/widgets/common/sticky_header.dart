import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'standard_back_button.dart';

class StickyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? rightContent;
  final Color? backgroundColor;
  final Color? statusBarColor;

  const StickyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.rightContent,
    this.backgroundColor,
    this.statusBarColor,
  });

  bool _isAndroid() {
    return Platform.isAndroid;
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    // Always respect the real safe-area inset (status bar). Only fall back to a
    // small padding if the inset is unexpectedly 0 (some fullscreen cases).
    final topPadding = safeAreaTop > 0
        ? safeAreaTop
        : (_isAndroid() ? 8.0 : 0.0);

    final theme = Theme.of(context);
    // If backgroundColor is provided, use it; otherwise make it transparent to show gradient
    final bg = backgroundColor ?? Colors.transparent;

    // For status bar color, use the provided statusBarColor, or fall back to backgroundColor,
    // or finally to scaffoldBackgroundColor
    final effectiveStatusBarColor =
        statusBarColor ?? (backgroundColor ?? theme.scaffoldBackgroundColor);

    final iconBrightness = effectiveStatusBarColor.computeLuminance() > 0.5
        ? Brightness.dark
        : Brightness.light;
    final iosStatusBarBrightness = iconBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: effectiveStatusBarColor,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: iosStatusBarBrightness,
        // Avoid Android adding a contrast scrim that changes the perceived color.
        systemStatusBarContrastEnforced: false,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          boxShadow: bg != Colors.transparent
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.only(top: topPadding),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Builder(
            builder: (context) {
              // Use Directionality from context for reliable RTL detection
              final textDirection = Directionality.of(context);

              return Row(
                textDirection: textDirection,
                children: [
                  // Back button - appears on start side (left for LTR, right for RTL)
                  if (showBack) StandardBackButton(onTap: onBack),
                  if (showBack) const SizedBox(width: 8),
                  // Title in the middle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: textDirection,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.85
                                    : 0.6,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: textDirection,
                          ),
                      ],
                    ),
                  ),
                  // Right content - appears on end side (right for LTR, left for RTL)
                  if (rightContent != null) ...[
                    const SizedBox(width: 8),
                    rightContent!,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
