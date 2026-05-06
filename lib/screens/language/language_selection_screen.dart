import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/language_config.dart';
import '../../core/theme/colors.dart';
import '../../providers/language_provider.dart';
import '../../services/splash_sub_iap_gate.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (wasLanguageAlreadySelected) {
        if (canPop) {
          context.pop();
        } else {
          context.go('/settings');
        }
        return;
      }
      // First-time: onboarding if needed; else home or Pro when splash_sub RC allows
      final onboardingComplete = await StorageService.isOnboardingComplete();
      if (!mounted) return;
      if (!onboardingComplete) {
        context.go('/onboarding');
        return;
      }
      final proRoute = await splashSubProRouteBeforeHomeIfNeeded();
      if (mounted) context.go(proRoute ?? '/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languages = LanguageConfig.languages;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : null,
                gradient: isDark
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF5FAFF),
                          Color(0xFFFFFFFF),
                        ],
                      ),
              ),
            ),
          ),
          if (!isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  // Center vertical "bluish" band (not full width).
                  child: FractionallySizedBox(
                    widthFactor: 0.72,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00EAF4FF),
                            Color(0xFFEAF4FF),
                            Color(0x00EAF4FF),
                          ],
                          stops: [0.0, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: StickyHeader(
                  title: 'Languages',
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
                      : const Color(0xFFF5FAFF),
                  rightContent: _LanguageSaveButton(
                    enabled: _tempSelectedLanguage != null,
                    onTap: _saveLanguage,
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
                      // Bottom padding for fixed ad
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Fixed native ad at bottom (medium)
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

    const selectedFill = Color(0xFFD0E3FF);
    const selectedBorder = Color(0xFF5A98FD);
    const unselectedBorder = Color(0xFFBFCFE3);
    final languageTextColor =
        isDark ? Colors.white : const Color(0xFF111827);
    final nativeLanguageTextColor = isDark
        ? Colors.white.withOpacity(0.65)
        : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _selectLanguage(language.code);
          },
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.65)
                  : (isSelected ? selectedFill : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? selectedBorder : unselectedBorder,
                width: isSelected ? 1.6 : 1.1,
              ),
              boxShadow: isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x14000000),
                        offset: Offset(0, 6),
                        blurRadius: 14,
                      ),
                    ],
            ),
            child: Row(
              children: [
                _FlagBadge(flagCode: language.flagCode),

                const SizedBox(width: 14),

                // Language Name with Native Name
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: language.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: languageTextColor,
                          ),
                        ),
                        if (language.nativeName.isNotEmpty &&
                            language.nativeName != language.name)
                          TextSpan(
                            text: '  (${language.nativeName})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: nativeLanguageTextColor,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  final String flagCode;

  const _FlagBadge({required this.flagCode});

  String _flagEmojiFromCountryCode(String code) {
    final cc = code.trim().toUpperCase();
    if (cc.length != 2) return '🏳️';
    final int base = 0x1F1E6;
    final int a = 'A'.codeUnitAt(0);
    final int first = base + (cc.codeUnitAt(0) - a);
    final int second = base + (cc.codeUnitAt(1) - a);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _flagEmojiFromCountryCode(flagCode);
    return Text(
      emoji,
      style: const TextStyle(fontSize: 26, height: 1.0),
    );
  }
}

class _LanguageSaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _LanguageSaveButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 66,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF5A98FD) : const Color(0xFFBFCFE3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Icon(Icons.check, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
