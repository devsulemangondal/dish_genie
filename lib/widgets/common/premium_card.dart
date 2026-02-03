import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../services/remote_config_service.dart';

/// Premium upgrade card with crown icon and gradient background
class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RemoteConfigService.initialize(),
      builder: (context, snapshot) {
        final enabled = RemoteConfigService.weeklySub;
        if (!enabled) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => ProNavigation.tryOpen(context, replace: false),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.getCardShadow(context),
            ),
            child: Row(
              children: [
                // Crown icon in white circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/material-symbols_crown-rounded.svg',
                      width: 28,
                      height: 28,
                      colorFilter: const ColorFilter.mode(
                        AppColors.genieGold,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main title
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          children: [
                            TextSpan(
                              text: context.t('premium.card.unlock'),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            TextSpan(
                              text: context.t('premium.card.dishgenie.pro'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Subtitle
                      Text(
                        context.t('premium.card.subtitle'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
