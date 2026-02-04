import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/localization/language_config.dart';
import '../../core/theme/colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/rtl_icon.dart';
import '../../widgets/common/sticky_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

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
      await Provider.of<MealPlanProvider>(context, listen: false).clearMealPlan();
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
    const subject = 'DishGenie Feedback';
    final emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        'subject': subject,
      },
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
      await Share.share(
        'Check out DishGenie AI - Your magical kitchen assistant! https://dishgenie.app',
        subject: 'DishGenie AI',
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
        url = 'https://play.google.com/store/apps/details?id=com.dishgenie.recipeapp';
      } else if (Platform.isIOS) {
        // For iOS, we need the App Store ID
        // TODO: Replace <APP_STORE_ID> with your actual App Store ID when the app is published
        // You can find it in App Store Connect or use: https://apps.apple.com/app/id<APP_STORE_ID>
        // For now, using a search URL as fallback
        url = 'https://apps.apple.com/search?term=dishgenie';
        // Once you have the App Store ID, use:
        // url = 'itms-apps://itunes.apple.com/app/id<APP_STORE_ID>';
        // Or web version: url = 'https://apps.apple.com/app/id<APP_STORE_ID>';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNav(activeTab: 'settings'),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 12,
                  ),
                  children: [
                    // Premium Card
                    const PremiumCard(),
                    const SizedBox(height: 8),
                    // Appearance Section
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
                          // Determine if dark mode is active (considering system mode)
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          String themeText;
                          if (themeProvider.isSystemMode) {
                            themeText = context.t('settingsThemeSystem');
                          } else if (themeProvider.isDarkMode) {
                            themeText = context.t('settingsThemeDark');
                          } else {
                            themeText = context.t('settingsThemeLight');
                          }

                          return _buildSettingsItem(
                            context,
                            icon: isDark ? Icons.dark_mode : Icons.light_mode,
                            title: context.t('settingsTheme'),
                            subtitle: themeText,
                            onTap: () async {
                              final mode = await showDialog<ThemeMode>(
                                context: context,
                                builder: (ctx) => SimpleDialog(
                                  title: Text(context.t('settingsChooseTheme')),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(ctx, ThemeMode.system),
                                      child: Text(
                                          context.t('settingsThemeSystem')),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(ctx, ThemeMode.light),
                                      child: Text(
                                          context.t('settingsThemeLight')),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(ctx, ThemeMode.dark),
                                      child: Text(
                                          context.t('settingsThemeDark')),
                                    ),
                                  ],
                                ),
                              );
                              if (mode != null) {
                                await themeProvider.setThemeMode(mode);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Language Section
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
                        onTap: _rateApp,
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
                    // Data Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        context,
                        context.t('settings.data'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSettingsItem(
                        context,
                        icon: Icons.delete_forever,
                        title: context.t('settings.clear.all.data'),
                        subtitle: context.t('settings.clear.data.subtitle'),
                        onTap: _clearAllData,
                        isDestructive: true,
                      ),
                    ),
                    const SizedBox(height: 16),
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
