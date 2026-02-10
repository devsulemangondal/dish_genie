import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/localization/language_config.dart';
import '../../core/theme/colors.dart';
import '../../providers/language_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/ads/custom_native_ad_widget.dart';
import '../../widgets/ads/screen_native_ad_widget.dart';
import '../../widgets/common/sticky_header.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;
  String? _tempSelectedLanguage;
  bool _showBackButton = true;

  @override
  void initState() {
    super.initState();
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    _selectedLanguage = languageProvider.locale.languageCode;
    _tempSelectedLanguage = _selectedLanguage;
    // Hide back button if language was not already selected (first time users)
    _showBackButton = languageProvider.isLanguageSelected;
  }

  void _selectLanguage(String languageCode) {
    setState(() {
      _tempSelectedLanguage = languageCode;
    });
  }

  Future<void> _saveLanguage() async {
    if (_tempSelectedLanguage == null) return;

    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    // Capture navigation state BEFORE any async work so we don't use context
    // after locale change (notifyListeners can trigger rebuild and invalidate context on iOS)
    final wasLanguageAlreadySelected = languageProvider.isLanguageSelected;
    final canPop = context.canPop();

    setState(() {
      _selectedLanguage = _tempSelectedLanguage;
    });

    await languageProvider.changeLanguage(_tempSelectedLanguage!);

    // Only set language as selected if this is the first launch
    if (!wasLanguageAlreadySelected) {
      await languageProvider.setLanguageSelected();
      await StorageService.setFirstLaunchComplete();
    }

    // Defer navigation to next frame to avoid using context during/after rebuild (fixes iOS crash)
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (wasLanguageAlreadySelected) {
        if (canPop) {
          context.pop();
        } else {
          context.go('/settings');
        }
        return;
      }
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languages = LanguageConfig.languages;

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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: StickyHeader(
                  title: context.t('settings.language'),
                  showBack: _showBackButton,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/settings');
                    }
                  },
                  backgroundColor: Colors.transparent,
                  statusBarColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1F35)
                      : AppColors.genieBlush,
                  rightContent: OutlinedButton(
                    onPressed: _tempSelectedLanguage != null
                        ? _saveLanguage
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: _tempSelectedLanguage != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface
                                  .withOpacity(isDark ? 0.3 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      context.t('common.done'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _tempSelectedLanguage != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface
                                  .withOpacity(isDark ? 0.5 : 0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // Scrollable language list
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // All languages in a single scrollable list
                      ...languages.map(
                        (language) =>
                            _buildLanguageOption(context, language, isDark),
                      ),

                      // Bottom padding to account for the fixed ad
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Fixed ad at the bottom (non-scrollable) with safe area
              SafeArea(
                top: false,
                child: const ScreenNativeAdWidget(
                  screenKey: 'language',
                  size: CustomNativeAdSize.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    Language language,
    bool isDark,
  ) {
    final isSelected = _tempSelectedLanguage == language.code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _selectLanguage(language.code);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(isDark ? 0.25 : 0.15)
                  : isDark
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.6)
                  : Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : isDark && !isSelected
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                      width: 1,
                    )
                  : null,
              boxShadow: AppColors.getCardShadow(context),
            ),
            child: Row(
              children: [
                // Flag with better styling
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary
                                  .withOpacity(isDark ? 0.4 : 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.network(
                      LanguageConfig.getFlagUrl(language.code),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                        ),
                        child: Icon(
                          Icons.flag,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurface
                              .withOpacity(isDark ? 0.7 : 0.6),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Language Name with Native Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (language.nativeName != language.name &&
                          language.nativeName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          language.nativeName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: isSelected
                                ? (isDark
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.black.withOpacity(0.8))
                                : Theme.of(context).colorScheme.onSurface
                                      .withOpacity(isDark ? 0.7 : 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Check Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 18,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
