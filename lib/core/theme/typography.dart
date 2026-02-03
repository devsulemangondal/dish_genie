import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamily = 'Nunito';
  
  static TextTheme textTheme(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.3);
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth < 360 ? 0.9 : (screenWidth > 600 ? 1.1 : 1.0);
    
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: (32 * scaleFactor * textScaleFactor).clamp(24.0, 40.0),
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: (28 * scaleFactor * textScaleFactor).clamp(22.0, 36.0),
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: (24 * scaleFactor * textScaleFactor).clamp(20.0, 32.0),
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: (22 * scaleFactor * textScaleFactor).clamp(18.0, 28.0),
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: (20 * scaleFactor * textScaleFactor).clamp(16.0, 26.0),
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: (18 * scaleFactor * textScaleFactor).clamp(16.0, 24.0),
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: (18 * scaleFactor * textScaleFactor).clamp(16.0, 24.0),
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: (16 * scaleFactor * textScaleFactor).clamp(14.0, 20.0),
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: (14 * scaleFactor * textScaleFactor).clamp(12.0, 18.0),
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: (16 * scaleFactor * textScaleFactor).clamp(14.0, 20.0),
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: (14 * scaleFactor * textScaleFactor).clamp(12.0, 18.0),
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: (12 * scaleFactor * textScaleFactor).clamp(10.0, 16.0),
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: (14 * scaleFactor * textScaleFactor).clamp(12.0, 18.0),
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: (12 * scaleFactor * textScaleFactor).clamp(10.0, 16.0),
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: (10 * scaleFactor * textScaleFactor).clamp(8.0, 14.0),
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    );
  }
}
