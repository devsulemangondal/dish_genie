import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_store_config.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/localization/language_config.dart';
import '../../core/theme/colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/premium_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/rtl_icon.dart';
import '../../widgets/common/sticky_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Kept for when "Clear all data" section is uncommented
  // ignore: unused_element
  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('settings.clear.data.confirm')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('settings.clear.data.warning')),
            const SizedBox(height: 12),
            Text('• ${context.t('settings.saved.recipes')}'),
            Text('• ${context.t('settings.meal.plans')}'),
            Text('• ${context.t('settings.grocery.lists')}'),
            Text('• ${context.t('settings.chat.history')}'),
            Text('• ${context.t('settings.preferences.settings')}'),
            const SizedBox(height: 12),
            Text(
              context.t('settings.cannot.undo'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.destructive,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Provider.of<MealPlanProvider>(
        context,
        listen: false,
      ).clearMealPlan();
      await Provider.of<GroceryProvider>(context, listen: false).clearList();
      Provider.of<ChatProvider>(context, listen: false).clearMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('settings.data.cleared')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  /// Open email app directly with feedback address (like web app).
  /// No dialog - just launches mailto:support@dishgenie.app.
  Future<void> _openFeedbackEmail() async {
    const email = 'support@dishgenie.app';
    const subject = 'Smart Chef Feedback';
    // Use %20 for spaces so Gmail shows "Smart Chef Feedback" instead of "Smart Chef+Feedback"
    final emailUri = Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent(subject)}',
    );

    try {
      // Try externalApplication first (opens default email client)
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('settings.feedback.sent')),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }
    } catch (_) {}

    // Fallback: try without explicit mode (platform default)
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('settings.feedback.sent')),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email app not available. Please send feedback to $email',
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('settings.faq.title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFAQItem(
                context,
                context.t('settings.faq1.q'),
                context.t('settings.faq1.a'),
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                context,
                context.t('settings.faq2.q'),
                context.t('settings.faq2.a'),
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                context,
                context.t('settings.faq3.q'),
                context.t('settings.faq3.a'),
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                context,
                context.t('settings.faq4.q'),
                context.t('settings.faq4.a'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(answer, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Future<void> _shareApp() async {
    try {
      final size = MediaQuery.of(context).size;
      // Use platform-specific store link: Play Store on Android, App Store on iOS
      final appLink = Platform.isAndroid
          ? 'https://play.google.com/store/apps/details?id=com.dishgenie.recipeapp'
          : (AppStoreConfig.appStoreUrl ??
                'https://apps.apple.com/search?term=Dish+Genie+AI');
      await Share.share(
        'Check out Smart Chef AI - Your magical kitchen assistant! $appLink',
        subject: 'Smart Chef AI',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('commonErrorMessage', {'error': e.toString()}),
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('commonCouldNotOpenUrl', {'url': url})),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _rateApp() async {
    try {
      String url;
      if (Platform.isAndroid) {
        // Try to open Play Store directly
        url = 'market://details?id=com.dishgenie.recipeapp';
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        // Fallback to web URL if market:// doesn't work
        url =
            'https://play.google.com/store/apps/details?id=com.dishgenie.recipeapp';
      } else if (Platform.isIOS) {
        // Use direct App Store link if appStoreId is set in AppStoreConfig
        url =
            AppStoreConfig.appStoreUrl ??
            'https://apps.apple.com/search?term=Dish+Genie+AI';
      } else {
        // For other platforms, show a message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rating is only available on mobile devices'),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('commonCouldNotOpenUrl', {'url': url})),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('commonErrorMessage', {'error': e.toString()}),
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _showRateUsDialog() async {
    var rating = 5;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        const gradientA = Color(0xFF40CFB2);
        const gradientB = Color(0xFF57A2F3);
        const textBody = Color(0xFF3E484D);
        const maybeLaterColor = Color(0xFF6E797D);
        const starOn = Color(0xFFFFC107);
        const starOff = Color(0xFFD6D6D6);

        TextStyle titleStyle() => GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.1,
        );
        TextStyle subtitleStyle() => GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: Colors.white.withOpacity(0.95),
          height: 1.2,
        );
        TextStyle bodyStyle() => GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textBody,
          height: 1.25,
        );

        Future<void> handlePrimary(int currentRating) async {
          Navigator.of(ctx).pop();
          if (currentRating <= 3) {
            if (kDebugMode) {
              debugPrint(
                '[Settings] Rate dialog -> feedback rating=$currentRating',
              );
            }
            await _openFeedbackEmail();
          } else {
            if (kDebugMode) {
              debugPrint(
                '[Settings] Rate dialog -> store rating=$currentRating',
              );
            }
            await _rateApp();
          }
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            final primaryText = rating <= 3
                ? ctx.t('rate.dialog.feedback')
                : ctx.t('rate.dialog.rate.now');
            final screenW = MediaQuery.sizeOf(ctx).width;
            final dialogInsetH = screenW < 360 ? 12.0 : 24.0;
            final starIconSize = screenW < 340 ? 30.0 : 38.0;
            final starSplash = starIconSize * 0.55;

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: dialogInsetH,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (screenW - dialogInsetH * 2).clamp(0.0, 420),
                  ),
                  child: Container(
                    color: isDark ? theme.cardColor : Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [gradientA, gradientB],
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ctx.t('rate.dialog.title'),
                                style: titleStyle(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ctx.t('rate.dialog.subtitle'),
                                style: subtitleStyle(),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: Column(
                            children: [
                              Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (i) {
                                      final idx = i + 1;
                                      final active = idx <= rating;
                                      return IconButton(
                                        onPressed: () =>
                                            setLocal(() => rating = idx),
                                        splashRadius: starSplash,
                                        constraints: BoxConstraints.tightFor(
                                          width: starIconSize + 18,
                                          height: starIconSize + 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          active
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: active ? starOn : starOff,
                                          size: starIconSize,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ctx.t('rate.dialog.body'),
                                style: bodyStyle(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [gradientA, gradientB],
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(28),
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => handlePrimary(rating),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        primaryText,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(
                                  ctx.t('rate.dialog.maybe.later'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: maybeLaterColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.gradientHeroDark
                  : AppColors.gradientHero,
            ),
          ),
          Column(
            children: [
              StickyHeader(
                title: context.t('settings.title'),
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                backgroundColor: Colors.transparent,
                statusBarColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1F35)
                    : AppColors.genieBlush,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 0,
                    right: 0,
                    top: 12,
                    bottom: 12 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    // Premium Card (only if remote config enables it and user is not premium)
                    if (!context.watch<PremiumProvider>().isPremium &&
                        (Platform.isIOS
                            ? RemoteConfigService.subCardIos
                            : RemoteConfigService.subCard)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const PremiumCard(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Favorites / Favourite (navigate to saved items screen)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.favorite_border,
                        title: context.t('common.favorites'),
                        subtitle: context.t('favorites.subtitle'),
                        onTap: () => context.push('/favorites'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Language Section (first)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        context,
                        context.t('settings.language'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) {
                          final currentLanguageCode =
                              languageProvider.locale.languageCode;
                          final currentLanguage =
                              LanguageConfig.getLanguageByCode(
                                currentLanguageCode,
                              );
                          final languageName =
                              currentLanguage?.name ?? 'English';

                          return _buildSettingsItem(
                            context,
                            icon: Icons.language,
                            title: context.t('settings.language'),
                            subtitle: languageName,
                            onTap: () => context.push('/language-picker'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Appearance Section (second)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        context,
                        context.t('settingsAppearance'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildThemeOptionCard(
                                context,
                                themeMode: ThemeMode.light,
                                label: context.t('settingsThemeLight'),
                                icon: Icons.light_mode,
                                isSelected:
                                    themeProvider.themeMode == ThemeMode.light,
                                onTap: () =>
                                    themeProvider.setThemeMode(ThemeMode.light),
                              ),
                              const SizedBox(height: 8),
                              _buildThemeOptionCard(
                                context,
                                themeMode: ThemeMode.dark,
                                label: context.t('settingsThemeDark'),
                                icon: Icons.dark_mode,
                                isSelected:
                                    themeProvider.themeMode == ThemeMode.dark,
                                onTap: () =>
                                    themeProvider.setThemeMode(ThemeMode.dark),
                              ),
                              const SizedBox(height: 8),
                              _buildThemeOptionCard(
                                context,
                                themeMode: ThemeMode.system,
                                label: context.t('settingsThemeSystem'),
                                icon: Icons.brightness_auto,
                                isSelected:
                                    themeProvider.themeMode == ThemeMode.system,
                                onTap: () => themeProvider.setThemeMode(
                                  ThemeMode.system,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Support Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        context,
                        context.t('settings.support'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.feedback,
                        title: context.t('settings.feedback'),
                        subtitle: context.t('settings.feedback.subtitle'),
                        onTap: _openFeedbackEmail,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.star,
                        title: context.t('settings.rate.us'),
                        subtitle: context.t('settings.rate.us.subtitle'),
                        onTap: _showRateUsDialog,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.share,
                        title: context.t('settings.share.app'),
                        subtitle: context.t('settings.share.app.subtitle'),
                        onTap: _shareApp,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.help_outline,
                        title: context.t('settings.help.support'),
                        subtitle: context.t('settings.help.support.subtitle'),
                        onTap: _showHelpDialog,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Legal Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        context,
                        context.t('settings.legal'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.privacy_tip,
                        title: context.t('settings.privacy.policy'),
                        onTap: () => _launchURL(
                          'https://sites.google.com/view/dodishgenie/home',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.description,
                        title: context.t('settings.terms.conditions'),
                        onTap: () => _launchURL(
                          'https://sites.google.com/view/dodishgenieterms/home',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Clear all data section - commented out for now
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 16),
                    //   child: _buildSectionHeader(
                    //     context,
                    //     context.t('settings.data'),
                    //   ),
                    // ),
                    // const SizedBox(height: 6),
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 16),
                    //   child: _buildSettingsItem(
                    //     context,
                    //     icon: Icons.delete_forever,
                    //     title: context.t('settings.clear.all.data'),
                    //     subtitle: context.t('settings.clear.data.subtitle'),
                    //     onTap: _clearAllData,
                    //     isDestructive: true,
                    //   ),
                    // ),
                    // const SizedBox(height: 16),
                    // App Version
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${context.t('common.version')} 1.0.0',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildThemeOptionCard(
    BuildContext context, {
    required ThemeMode themeMode,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textDirection: Directionality.of(context),
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? rightElement,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isDestructive
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textDirection: Directionality.of(context),
                      ),
                    ],
                  ],
                ),
              ),
              rightElement ??
                  RtlChevronRight(
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
