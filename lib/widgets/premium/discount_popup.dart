import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Discount popup shown when user exits Pro screen (controlled by Remote Config).
/// Uses outer card (popup.png) and inner card (popupinner.png) images with overlaid text.
///
/// Pops with true when user taps Subscribe, false when dismissed.
class DiscountPopup extends StatelessWidget {
  const DiscountPopup({super.key});

  static const double _designWidth = 375;

  /// Scale value based on screen width (design base: 375)
  static double _r(BuildContext context, double value) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / _designWidth).clamp(0.75, 1.15);
    return value * scale;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: _r(context, 24)),
      child: Center(
        child: SizedBox(
          width: _r(context, 340),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              /// OUTER BACKGROUND CARD
              Image.asset(
                "assets/popup.png",
                width: double.infinity,
                fit: BoxFit.contain,
              ),

              /// CONTENT
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _r(context, 20),
                    _r(context, 8),
                    _r(context, 20),
                    _r(context, 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// CLOSE BUTTON - same style as Pro screen
                      Align(
                        alignment: Alignment.topRight,
                        child: SizedBox(
                          width: _r(context, 24),
                          height: _r(context, 24),
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 0,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, false),
                              customBorder: const CircleBorder(),
                              child: Center(
                                child: Icon(
                                  Icons.close,
                                  size: _r(context, 14),
                                  color: const Color(0xFF43233A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -_r(context, 4)),
                        child: Text(
                          "🔥 Unlock Your\nDish Genie PRO",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poetsenOne(
                            fontSize: _r(context, 30),
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(height: _r(context, 5)),

                      /// INNER CARD - image with price, btn, links inside
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Image.asset(
                            "assets/popupinner.png",
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                _r(context, 16),
                                0,
                                _r(context, 16),
                                _r(context, 16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "\$19.99",
                                    style: GoogleFonts.poppins(
                                      fontSize: _r(context, 20),
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(0, -_r(context, 6)),
                                    child: Text(
                                      "\$12.99",
                                      style: GoogleFonts.poetsenOne(
                                        fontSize: _r(context, 44),
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFFFFA500),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: _r(context, 2)),
                                  Text(
                                    "Per Month",
                                    style: GoogleFonts.poppins(
                                      fontSize: _r(context, 16),
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: _r(context, 12)),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(
                                      _r(context, 30),
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(true),
                                    child: Container(
                                      height: _r(context, 50),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          _r(context, 30),
                                        ),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6A11CB),
                                            Color(0xFFB54DE2),
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.bolt,
                                            color: Colors.white,
                                            size: _r(context, 20),
                                          ),
                                          SizedBox(width: _r(context, 8)),
                                          Text(
                                            "Subscribe Now",
                                            style: GoogleFonts.poppins(
                                              fontSize: _r(context, 16),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: _r(context, 12)),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _link(
                                        context,
                                        "Privacy Policy",
                                        "https://sites.google.com/view/dodishgenie/home",
                                      ),
                                      _link(
                                        context,
                                        "Cancel Anytime",
                                        "https://play.google.com/store/account/subscriptions",
                                      ),
                                      _link(
                                        context,
                                        "Terms of Use",
                                        "https://sites.google.com/view/dodishgenieterms/home",
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(BuildContext context, String text, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: _r(context, 9),
          decoration: TextDecoration.underline,
          color: Colors.black87,
        ),
      ),
    );
  }
}
