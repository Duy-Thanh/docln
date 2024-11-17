import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Language {
  final String code;
  final String name;
  final String nativeName;
  final String? flag;

  const Language(this.code, this.name, this.nativeName, {this.flag});
}

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // List of supported languages
  static const List<Language> supportedLanguages = [
    Language('en', 'English', 'English', flag: '🇺🇸'),
    Language('vi', 'Vietnamese', 'Tiếng Việt', flag: '🇻🇳'),
    Language('ja', 'Japanese', '日本語', flag: '🇯🇵'),
    Language('ko', 'Korean', '한국어', flag: '🇰🇷'),
    Language('zh', 'Chinese', '中文', flag: '🇨🇳'),
    Language('fr', 'French', 'Français', flag: '🇫🇷'),
    Language('de', 'German', 'Deutsch', flag: '🇩🇪'),
    Language('es', 'Spanish', 'Español', flag: '🇪🇸'),
    Language('it', 'Italian', 'Italiano', flag: '🇮🇹'),
    Language('ru', 'Russian', 'Русский', flag: '🇷🇺'),
  ];

  Locale _currentLocale = const Locale('en');
  Language _currentLanguage = supportedLanguages.first;

  Locale get currentLocale => _currentLocale;
  Language get currentLanguage => _currentLanguage;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('languageCode') ?? 'en';
      await setLanguage(savedCode);
    } catch (e) {
      print('🌐 Error initializing language service: $e');
    }
  }

  Future<void> setLanguage(String code) async {
    try {
      final language = supportedLanguages.firstWhere(
        (lang) => lang.code == code,
        orElse: () => supportedLanguages.first,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', code);
      
      _currentLocale = Locale(code);
      _currentLanguage = language;
      
      print('🌐 Language set to: ${language.name} (${language.nativeName})');
      notifyListeners();
    } catch (e) {
      print('🌐 Error setting language: $e');
    }
  }
}
