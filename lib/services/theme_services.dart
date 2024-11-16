import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeServices extends ChangeNotifier {
  static final ThemeServices _instance = ThemeServices._internal();
  factory ThemeServices() => _instance;
  ThemeServices._internal();

  late ThemeMode _themeMode;
  double _textScaleFactor = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getBool('darkMode') == true ? ThemeMode.dark : ThemeMode.light;
    _textScaleFactor = prefs.getDouble('textSize') ?? 1.0;
    notifyListeners();
  }

  Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setTextScaleFactor(double factor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textSize', factor);
    _textScaleFactor = factor;
    notifyListeners();
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: Colors.blue,
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Colors.blue,
    );
  }
}
