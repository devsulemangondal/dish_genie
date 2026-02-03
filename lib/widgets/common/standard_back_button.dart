import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import 'rtl_icon.dart';

/// Standard, reusable back button used across the app.
///
/// - Uses `RtlBackIcon` so it automatically mirrors in RTL locales.
/// - Can be styled with custom background and icon colors.
/// - Defaults are chosen to work on both light and dark backgrounds.
class StandardBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const StandardBackButton({
    super.key,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.cardColor.withOpacity(0.9);
    final iconFg = iconColor ?? theme.colorScheme.onSurface.withOpacity(0.9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: RtlBackIcon(size: 20, color: iconFg),
        ),
      ),
    );
  }
}
