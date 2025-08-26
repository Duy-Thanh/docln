import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'preferences_service.dart';

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

  // Preferences service instance
  final PreferencesService _prefsService = PreferencesService();

  ThemeMode get themeMode => _themeMode;
  // New getter for textScaler
  TextScaler get textScaler => TextScaler.linear(_textSize / 16.0);
  double get textSize => _textSize;

  Future<void> init() async {
    try {
      // Initialize preferences service if not already initialized
      await _prefsService.initialize();

      // Get values from preferences service
      _themeMode =
          _prefsService.getBool('darkMode') ? ThemeMode.dark : ThemeMode.light;
      _textSize = (_prefsService.getDouble(
        'textSize',
        defaultValue: 16.0,
      )).clamp(12.0, 24.0);
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
    await _prefsService.setBool('darkMode', isDark);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setTextSize(double size) async {
    try {
      size = size.clamp(12.0, 24.0);
      await _prefsService.setDouble('textSize', size);
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

    const primaryColor = Color(0xFF4361EE);
    const secondaryColor = Color(0xFFFF6B6B);

    // Apply scale factor to all sizes
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: const Color(0xFF4CC9F0),
        surface: Colors.white,
        background: const Color(0xFFF8F9FA),
        surfaceVariant: const Color(0xFFEEF2FF),
        primaryContainer: const Color(0xFFD8E2FF),
        secondaryContainer: const Color(0xFFFFE8E8),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: baseSizes['displayLarge']! * _textScaleFactor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: baseSizes['displayMedium']! * _textScaleFactor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          fontSize: baseSizes['displaySmall']! * _textScaleFactor,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          fontSize: baseSizes['headlineLarge']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          fontSize: baseSizes['headlineMedium']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontSize: baseSizes['headlineSmall']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: baseSizes['titleLarge']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: baseSizes['titleMedium']! * _textScaleFactor,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          fontSize: baseSizes['titleSmall']! * _textScaleFactor,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          fontSize: baseSizes['bodyLarge']! * _textScaleFactor,
          letterSpacing: 0.2,
        ),
        bodyMedium: TextStyle(
          fontSize: baseSizes['bodyMedium']! * _textScaleFactor,
          letterSpacing: 0.2,
        ),
        bodySmall: TextStyle(
          fontSize: baseSizes['bodySmall']! * _textScaleFactor,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primaryColor,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.1),
        labelStyle: TextStyle(
          color: primaryColor,
          fontSize: 12 * _textScaleFactor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        indicator: BoxDecoration(
          border: Border(bottom: BorderSide(color: primaryColor, width: 2)),
        ),
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

    const primaryColor = Color(0xFF4CC9F0);
    const secondaryColor = Color(0xFFFF6B6B);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: const Color(0xFF4361EE),
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        surfaceVariant: const Color(0xFF2A2A2A),
        primaryContainer: const Color(0xFF20385B),
        secondaryContainer: const Color(0xFF662B2B),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: baseSizes['displayLarge']! * _textScaleFactor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
        displayMedium: TextStyle(
          fontSize: baseSizes['displayMedium']! * _textScaleFactor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
          color: Colors.white,
        ),
        displaySmall: TextStyle(
          fontSize: baseSizes['displaySmall']! * _textScaleFactor,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineLarge: TextStyle(
          fontSize: baseSizes['headlineLarge']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: baseSizes['headlineMedium']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineSmall: TextStyle(
          fontSize: baseSizes['headlineSmall']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: baseSizes['titleLarge']! * _textScaleFactor,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: baseSizes['titleMedium']! * _textScaleFactor,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        titleSmall: TextStyle(
          fontSize: baseSizes['titleSmall']! * _textScaleFactor,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: baseSizes['bodyLarge']! * _textScaleFactor,
          letterSpacing: 0.2,
          color: Colors.white.withOpacity(0.9),
        ),
        bodyMedium: TextStyle(
          fontSize: baseSizes['bodyMedium']! * _textScaleFactor,
          letterSpacing: 0.2,
          color: Colors.white.withOpacity(0.9),
        ),
        bodySmall: TextStyle(
          fontSize: baseSizes['bodySmall']! * _textScaleFactor,
          letterSpacing: 0.2,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF121212),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primaryColor,
          elevation: 3,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.2),
        labelStyle: TextStyle(
          color: primaryColor,
          fontSize: 12 * _textScaleFactor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        indicator: BoxDecoration(
          border: Border(bottom: BorderSide(color: primaryColor, width: 2)),
        ),
      ),
    );
  }
}
