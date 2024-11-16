import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  Locale _currentLocale = Locale('en');

  Locale get currentLocale => _currentLocale;

  final Map<String, String> _supportedLanguages = {
    'English': 'en',
    'Tiếng Việt': 'vi',
    'Français': 'fr',
    'Española': 'es',
    'Deutsch': 'de',
    'Italiana': 'it',
    'Nederlands': 'nl',
    'Português': 'pt',
    'Русский': 'ru',
    '日本語': 'ja',
    '한국인': 'ko',
    '中国人': 'zh',
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final languageName = prefs.getString('language') ?? 'English';
    final languageCode = _supportedLanguages[languageName] ?? 'en';
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLanguage(String languageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageName);
    final languageCode = _supportedLanguages[languageName] ?? 'en';
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }
}
