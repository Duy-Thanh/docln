import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeServices extends ChangeNotifier {
  static final ThemeServices _instance = ThemeServices._internal();
  factory ThemeServices() => _instance;
  ThemeServices._internal() {
    // Initialize with default values
    _themeMode = ThemeMode.light;
    _textSize = 16.0;
    _textScaleFactor = 1.0;
  }

  late ThemeMode _themeMode;
  double _textScaleFactor = 1.0;
  double _textSize = 16.0;

  ThemeMode get themeMode => _themeMode;
  // New getter for textScaler
  TextScaler get textScaler => TextScaler.linear(_textSize / 16.0);
  double get textSize => _textSize;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = prefs.getBool('darkMode') == true ? ThemeMode.dark : ThemeMode.light;
      _textSize = (prefs.getDouble('textSize') ?? 16.0).clamp(12.0, 24.0);
      print('🔤 Initialized text size: $_textSize');
      notifyListeners();
    } catch (e) {
      print('Error initializing ThemeServices: $e');
      _themeMode = ThemeMode.light;
      _textSize = 16.0;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setTextSize(double size) async {
    try {
      size = size.clamp(12.0, 24.0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('textSize', size);
      _textSize = size;
      print('🔤 Set text size to: $_textSize');
      notifyListeners();
    } catch (e) {
      print('Error setting text size: $e');
    }
  }

  // Add preview functionality
  void previewTextSize(double size) {
    _textSize = size.clamp(12.0, 24.0);
    notifyListeners();
  }

  // Add method to reset text size
  void resetTextSize(double originalSize) {
    _textSize = originalSize.clamp(12.0, 24.0);
    notifyListeners();
  }

  ThemeData getLightTheme() {
    // Base font sizes
    final baseSizes = {
      'displayLarge': 24.0,
      'displayMedium': 20.0,
      'displaySmall': 18.0,
      'headlineLarge': 16.0,
      'headlineMedium': 15.0,
      'headlineSmall': 14.0,
      'titleLarge': 14.0,
      'titleMedium': 13.0,
      'titleSmall': 12.0,
      'bodyLarge': 14.0,
      'bodyMedium': 13.0,
      'bodySmall': 12.0,
    };

    // Apply scale factor to all sizes
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: Colors.blue,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: baseSizes['displayLarge']! * _textScaleFactor),
        displayMedium: TextStyle(fontSize: baseSizes['displayMedium']! * _textScaleFactor),
        displaySmall: TextStyle(fontSize: baseSizes['displaySmall']! * _textScaleFactor),
        headlineLarge: TextStyle(fontSize: baseSizes['headlineLarge']! * _textScaleFactor),
        headlineMedium: TextStyle(fontSize: baseSizes['headlineMedium']! * _textScaleFactor),
        headlineSmall: TextStyle(fontSize: baseSizes['headlineSmall']! * _textScaleFactor),
        titleLarge: TextStyle(fontSize: baseSizes['titleLarge']! * _textScaleFactor),
        titleMedium: TextStyle(fontSize: baseSizes['titleMedium']! * _textScaleFactor),
        titleSmall: TextStyle(fontSize: baseSizes['titleSmall']! * _textScaleFactor),
        bodyLarge: TextStyle(fontSize: baseSizes['bodyLarge']! * _textScaleFactor),
        bodyMedium: TextStyle(fontSize: baseSizes['bodyMedium']! * _textScaleFactor),
        bodySmall: TextStyle(fontSize: baseSizes['bodySmall']! * _textScaleFactor),
      ),
    );
  }

  ThemeData getDarkTheme() {
    // Reuse the same base sizes
    final baseSizes = {
      'displayLarge': 24.0,
      'displayMedium': 20.0,
      'displaySmall': 18.0,
      'headlineLarge': 16.0,
      'headlineMedium': 15.0,
      'headlineSmall': 14.0,
      'titleLarge': 14.0,
      'titleMedium': 13.0,
      'titleSmall': 12.0,
      'bodyLarge': 14.0,
      'bodyMedium': 13.0,
      'bodySmall': 12.0,
    };

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Colors.blue,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: baseSizes['displayLarge']! * _textScaleFactor),
        displayMedium: TextStyle(fontSize: baseSizes['displayMedium']! * _textScaleFactor),
        displaySmall: TextStyle(fontSize: baseSizes['displaySmall']! * _textScaleFactor),
        headlineLarge: TextStyle(fontSize: baseSizes['headlineLarge']! * _textScaleFactor),
        headlineMedium: TextStyle(fontSize: baseSizes['headlineMedium']! * _textScaleFactor),
        headlineSmall: TextStyle(fontSize: baseSizes['headlineSmall']! * _textScaleFactor),
        titleLarge: TextStyle(fontSize: baseSizes['titleLarge']! * _textScaleFactor),
        titleMedium: TextStyle(fontSize: baseSizes['titleMedium']! * _textScaleFactor),
        titleSmall: TextStyle(fontSize: baseSizes['titleSmall']! * _textScaleFactor),
        bodyLarge: TextStyle(fontSize: baseSizes['bodyLarge']! * _textScaleFactor),
        bodyMedium: TextStyle(fontSize: baseSizes['bodyMedium']! * _textScaleFactor),
        bodySmall: TextStyle(fontSize: baseSizes['bodySmall']! * _textScaleFactor),
      ),
    );
  }
}
