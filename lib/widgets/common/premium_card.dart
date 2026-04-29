import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';

/// Premium card for settings screen. Uses asset image as background with
/// overlaid "Try Smart Chef Plus" text and "Get Plus" button.
class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key});

  static const double _designWidth = 375;

  static double _r(BuildContext context, double value) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / _designWidth).clamp(0.75, 1.15);
    return value * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: () => ProNavigation.tryOpen(context, replace: false),
      child: Container(
        // margin: EdgeInsets.symmetric(
        //   horizontal: _r(context, 24),
        //   vertical: _r(context, 12),
        // ),
        height: _r(context, 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_r(context, 20)),
          boxShadow: AppColors.getCardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image (robot, food bowls, purple gradient)
            // Mirror in RTL
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(isRtl ? -1.0 : 1.0, 1.0),
              child: Image.asset(
                'assets/premium.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
            // Content: left in LTR, right in RTL
            Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: SizedBox(
                width: _r(context, 220),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    _r(context, 20),
                    _r(context, 20),
                    _r(context, 20),
                    _r(context, 20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t('premium.card.try.plus'),
                        style: GoogleFonts.poetsenOne(
                          fontSize: _r(context, 16),
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      ),
                      SizedBox(height: _r(context, 12)),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              ProNavigation.tryOpen(context, replace: false),
                          borderRadius: BorderRadius.circular(_r(context, 28)),
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: _r(context, 100),
                              maxWidth: _r(context, 140),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: _r(context, 20),
                              vertical: _r(context, 7),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: const [
                                  Color(0xFF691CE4),
                                  Color(0xFFAF50E0),
                                ],
                                begin: isRtl
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                end: isRtl
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                _r(context, 28),
                              ),
                            ),
                            child: Text(
                              context.t('premium.card.get.plus'),
                              style: GoogleFonts.poppins(
                                fontSize: _r(context, 14),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: isRtl
                                  ? TextAlign.right
                                  : TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
