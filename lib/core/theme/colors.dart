import 'package:flutter/material.dart';

class AppColors {
  // Genie brand colors (HSL converted to RGB)
  // --genie-pink: 170 80% 45%
  static const Color geniePink = Color(0xFF3DD5A8);
  
  // --genie-purple: 220 90% 56%
  static const Color geniePurple = Color(0xFF5B9AFF);
  
  // --genie-lavender: 185 70% 65%
  static const Color genieLavender = Color(0xFF7FC6D8);
  
  // --genie-blush: 180 50% 96%
  static const Color genieBlush = Color(0xFFF4FAFB);
  
  // --genie-cream: 180 40% 98%
  static const Color genieCream = Color(0xFFFAFCFD);
  
  // --genie-gold: 160 85% 40%
  static const Color genieGold = Color(0xFF0FA87A);
  
  // Semantic colors
  // --background: 180 30% 99%
  static const Color background = Color(0xFFFAFDFE);
  
  // --foreground: 220 60% 18%
  static const Color foreground = Color(0xFF1A2B4A);
  
  // --card: 0 0% 100%
  static const Color card = Color(0xFFFFFFFF);
  
  // --card-foreground: 220 60% 18%
  static const Color cardForeground = Color(0xFF1A2B4A);
  
  // --primary: 220 90% 56%
  static const Color primary = geniePurple;
  
  // --primary-foreground: 0 0% 100%
  static const Color primaryForeground = Color(0xFFFFFFFF);
  
  // --secondary: 170 80% 45%
  static const Color secondary = geniePink;
  
  // --secondary-foreground: 0 0% 100%
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  
  // --muted: 180 25% 94%
  static const Color muted = Color(0xFFEFF5F7);
  
  // --muted-foreground: 220 25% 45%
  static const Color mutedForeground = Color(0xFF5A6B7D);
  
  // --accent: 185 70% 65%
  static const Color accent = genieLavender;
  
  // --accent-foreground: 220 60% 18%
  static const Color accentForeground = foreground;
  
  // --destructive: 0 84.2% 60.2%
  static const Color destructive = Color(0xFFF87171);
  
  // --destructive-foreground: 210 40% 98%
  static const Color destructiveForeground = Color(0xFFF5F7FA);
  
  // --border: 180 20% 88%
  static const Color border = Color(0xFFDFE8EB);
  
  // --input: 180 20% 92%
  static const Color input = Color(0xFFEBF2F5);
  
  // --ring: 220 90% 56%
  static const Color ring = geniePurple;
  
  // Gradients
  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [geniePink, geniePurple],
  );
  
  static const LinearGradient gradientPinkToPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [geniePink, geniePurple],
  );
  
  static const LinearGradient gradientPurpleToLavender = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [geniePurple, genieLavender],
  );
  
  static const LinearGradient gradientLavenderToPink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [genieLavender, geniePink],
  );
  
  static const LinearGradient gradientGoldToPink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [genieGold, geniePink],
  );
  
  static const LinearGradient gradientHero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [genieBlush, background],
  );

  // Dark mode colors (matching web app)
  // --background-dark: 220 25% 8%
  static const Color backgroundDark = Color(0xFF0D1117);

  // --foreground-dark: 0 0% 98%
  static const Color foregroundDark = Color(0xFFFAFAFA);

  // --card-dark: 220 22% 15% (lighter for better contrast with background)
  static const Color cardDark = Color(0xFF242936);

  // --card-foreground-dark: 0 0% 98%
  static const Color cardForegroundDark = Color(0xFFFAFAFA);

  // --primary-dark: 220 90% 56% (same as light, but can be adjusted)
  static const Color primaryDark = geniePurple;

  // --primary-foreground-dark: 0 0% 100%
  static const Color primaryForegroundDark = Color(0xFFFFFFFF);

  // --secondary-dark: 170 80% 45%
  static const Color secondaryDark = geniePink;

  // --secondary-foreground-dark: 0 0% 100%
  static const Color secondaryForegroundDark = Color(0xFFFFFFFF);

  // --muted-dark: 220 18% 18% (matching web app)
  static const Color mutedDark = Color(0xFF262932);

  // --muted-foreground-dark: 180 20% 65% (matching web app)
  static const Color mutedForegroundDark = Color(0xFF9DA8B8);

  // --accent-dark: 185 70% 65%
  static const Color accentDark = genieLavender;

  // --accent-foreground-dark: 220 40% 8%
  static const Color accentForegroundDark = backgroundDark;

  // --destructive-dark: 0 84.2% 60.2%
  static const Color destructiveDark = Color(0xFFF87171);

  // --destructive-foreground-dark: 0 0% 98%
  static const Color destructiveForegroundDark = foregroundDark;

  // --border-dark: 220 18% 22% (matching web app)
  static const Color borderDark = Color(0xFF2F3541);

  // --input-dark: 220 18% 22% (matching web app)
  static const Color inputDark = Color(0xFF2F3541);

  // --ring-dark: 220 90% 56%
  static const Color ringDark = geniePurple;

  // Dark mode gradients
  static const LinearGradient gradientHeroDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1F35), backgroundDark],
  );

  // Theme-aware gradient helpers
  static LinearGradient getGradientPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? gradientPrimary // Same gradient works for dark mode
        : gradientPrimary;
  }

  static LinearGradient getGradientHero(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? gradientHeroDark
        : gradientHero;
  }

  // Theme-aware card shadow helper with blue shadows for both modes
  static List<BoxShadow> getCardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? primary.withOpacity(0.4)
            : primary.withOpacity(0.4),
        blurRadius: isDark ? 24 : 28,
        spreadRadius: isDark ? 0 : -2,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
