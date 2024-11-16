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

  
}
