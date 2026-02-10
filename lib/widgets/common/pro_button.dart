import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../providers/premium_provider.dart';

/// Pro button widget - gradient badge. Shown everywhere inside the app; tap opens Pro screen.
class ProButton extends StatelessWidget {
  const ProButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return GestureDetector(
      onTap: () => ProNavigation.tryOpen(context, replace: true),
      child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: isPremium
                  ? AppColors.gradientPinkToPurple
                  : LinearGradient(
                      colors: [
                        AppColors.geniePink.withOpacity(0.9),
                        AppColors.geniePurple.withOpacity(0.9),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium ? Icons.star : Icons.auto_awesome,
                  color: AppColors.primaryForeground,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  context.t('premium.pro'),
                  style: TextStyle(
                    color: AppColors.primaryForeground,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
