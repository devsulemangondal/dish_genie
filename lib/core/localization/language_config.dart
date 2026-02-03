class Language {
  final String code;
  final String name;
  final String nativeName;
  final String dir;
  final String flagCode;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.dir,
    required this.flagCode,
  });
}

class LanguageConfig {
  static const List<Language> languages = [
    Language(
      code: 'en',
      name: 'English',
      nativeName: 'English (UK)',
      dir: 'ltr',
      flagCode: 'gb',
    ),
    Language(
      code: 'af',
      name: 'Afrikaans',
      nativeName: 'Afrikaans',
      dir: 'ltr',
      flagCode: 'za',
    ),
    Language(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      dir: 'rtl',
      flagCode: 'sa',
    ),
    Language(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      dir: 'ltr',
      flagCode: 'bd',
    ),
    Language(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      dir: 'ltr',
      flagCode: 'cn',
    ),
    Language(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      dir: 'rtl',
      flagCode: 'pk',
    ),
    Language(
      code: 'nl',
      name: 'Dutch',
      nativeName: 'Nederlands',
      dir: 'ltr',
      flagCode: 'nl',
    ),
    Language(
      code: 'fil',
      name: 'Filipino',
      nativeName: 'Filipino',
      dir: 'ltr',
      flagCode: 'ph',
    ),
    Language(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      dir: 'ltr',
      flagCode: 'fr',
    ),
    Language(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      dir: 'ltr',
      flagCode: 'de',
    ),
    Language(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      dir: 'ltr',
      flagCode: 'in',
    ),
    Language(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      dir: 'ltr',
      flagCode: 'id',
    ),
    Language(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      dir: 'ltr',
      flagCode: 'it',
    ),
    Language(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      dir: 'ltr',
      flagCode: 'jp',
    ),
    Language(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      dir: 'ltr',
      flagCode: 'kr',
    ),
    Language(
      code: 'ms',
      name: 'Malay',
      nativeName: 'Bahasa Melayu',
      dir: 'ltr',
      flagCode: 'my',
    ),
    Language(
      code: 'fa',
      name: 'Persian',
      nativeName: 'فارسی',
      dir: 'rtl',
      flagCode: 'ir',
    ),
    Language(
      code: 'pl',
      name: 'Polish',
      nativeName: 'Polski',
      dir: 'ltr',
      flagCode: 'pl',
    ),
    Language(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      dir: 'ltr',
      flagCode: 'br',
    ),
    Language(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      dir: 'ltr',
      flagCode: 'ru',
    ),
    Language(
      code: 'th',
      name: 'Thai',
      nativeName: 'ไทย',
      dir: 'ltr',
      flagCode: 'th',
    ),
    Language(
      code: 'tr',
      name: 'Turkish',
      nativeName: 'Türkçe',
      dir: 'ltr',
      flagCode: 'tr',
    ),
    Language(
      code: 'uk',
      name: 'Ukrainian',
      nativeName: 'Українська',
      dir: 'ltr',
      flagCode: 'ua',
    ),
    Language(
      code: 'uz',
      name: 'Uzbek',
      nativeName: "O'zbekcha",
      dir: 'ltr',
      flagCode: 'uz',
    ),
    Language(
      code: 'vi',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      dir: 'ltr',
      flagCode: 'vn',
    ),
    Language(
      code: 'kk',
      name: 'Kazakh',
      nativeName: 'Қазақша',
      dir: 'ltr',
      flagCode: 'kz',
    ),
  ];

  static const List<String> rtlLanguages = ['ar', 'fa', 'ur'];

  static bool isRTL(String languageCode) {
    return rtlLanguages.contains(languageCode);
  }

  static Language? getLanguageByCode(String code) {
    try {
      return languages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  static String getFlagUrl(String languageCode) {
    final lang = getLanguageByCode(languageCode);
    if (lang != null) {
      return 'https://flagcdn.com/w160/${lang.flagCode}.png';
    }
    return 'https://flagcdn.com/w160/gb.png';
  }
}
