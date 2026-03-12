import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../providers/premium_provider.dart';

/// Pro button widget - gradient badge. Shown everywhere inside the app; tap opens Pro screen.
/// Dimensions: 86x27, gradient 7B4DFF→A66BFF, radius 28, Poppins 12 semi-bold white.
class ProButton extends StatelessWidget {
  const ProButton({super.key});

  static const double _width = 86;
  static const double _height = 27;
  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return GestureDetector(
      onTap: () => ProNavigation.tryOpen(context, replace: false),
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          gradient: isPremium
              ? AppColors.gradientPinkToPurple
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF7B4DFF),
                    Color(0xFFA66BFF),
                  ],
                ),
          borderRadius: BorderRadius.circular(_radius),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/si_ai-line.svg',
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.t('premium.card.get.plus'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
