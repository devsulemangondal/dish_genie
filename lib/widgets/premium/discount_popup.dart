import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/l10n_extension.dart';
import '../../services/billing_service.dart';

/// Discount popup shown when user exits Pro screen (controlled by Remote Config).
/// Uses outer card (popup.png) and inner card (popupinner.png) images with overlaid text.
/// Loads product by [productId] and shows real price and 30% higher discount (crossed out).
///
/// Pops with true when user taps Subscribe, false when dismissed.
class DiscountPopup extends StatelessWidget {
  DiscountPopup({
    super.key,
    String? productId,
  }) : productId = productId ?? BillingService.yearlySubscriptionId;

  /// Product ID to load and display. Defaults to platform yearly ID from [BillingService].
  final String productId;

  static const double _designWidth = 375;

  /// Scale value based on screen width (design base: 375)
  static double _r(BuildContext context, double value) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / _designWidth).clamp(0.75, 1.15);
    return value * scale;
  }

  /// Formats yearly price + 30% as the discount (crossed-out) price.
  static String _formatDiscountPrice(ProductDetails product) {
    final discountPrice = product.rawPrice * 1.30;
    final symbol = product.currencySymbol.isNotEmpty
        ? product.currencySymbol
        : _currencySymbol(product.currencyCode);
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: symbol,
      decimalDigits: 2,
    ).format(discountPrice);
  }

  static String _currencySymbol(String code) {
    const symbols = {
      'USD': r'$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'INR': '₹',
    };
    return symbols[code] ?? '$code ';
  }

  @override
  Widget build(BuildContext context) {
    final product = BillingService.getProduct(productId);
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
                          context.t('discount.popup.title'),
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
                                    product != null
                                        ? _formatDiscountPrice(product)
                                        : r'$19.99',
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
                                      product?.price ?? r'$12.99',
                                      style: GoogleFonts.poetsenOne(
                                        fontSize: _r(context, 44),
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFFFFA500),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: _r(context, 2)),
                                  Text(
                                    context.t('premium.per.year'),
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
                                            context.t('premium.subscribe.now'),
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
                                      Expanded(
                                        child: _link(
                                          context,
                                          context.t('premium.privacy.policy'),
                                          "https://sites.google.com/view/dodishgenie/home",
                                        ),
                                      ),
                                      SizedBox(width: _r(context, 8)),
                                      Expanded(
                                        child: _link(
                                          context,
                                          context.t('premium.cancel.any.time'),
                                          "https://play.google.com/store/account/subscriptions",
                                        ),
                                      ),
                                      SizedBox(width: _r(context, 8)),
                                      Expanded(
                                        child: _link(
                                          context,
                                          context.t('premium.terms.of.use'),
                                          "https://sites.google.com/view/dodishgenieterms/home",
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}
