import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('en');
  bool _isLanguageSelected = false;

  Locale get locale => _locale;
  bool get isLanguageSelected => _isLanguageSelected;
  
  // RTL languages
  static const List<String> rtlLanguages = ['ar', 'fa', 'ur'];
  
  bool get isRTL => rtlLanguages.contains(_locale.languageCode);
  TextDirection get textDirection => isRTL ? TextDirection.rtl : TextDirection.ltr;

  LanguageProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLanguageSelected = await StorageService.isLanguageSelected();
    final savedLanguage = await StorageService.getLanguage();
    if (savedLanguage != null) {
      _locale = Locale(savedLanguage);
    }
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    await StorageService.setLanguage(languageCode);
    notifyListeners();
  }

  Future<void> setLanguageSelected() async {
    _isLanguageSelected = true;
    await StorageService.setLanguageSelected(true);
    notifyListeners();
  }
}
