import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'preferences_service.dart';
import 'wallpaper_theme_service.dart';

class ThemeServices extends ChangeNotifier {
  static final ThemeServices _instance = ThemeServices._internal();
  factory ThemeServices() => _instance;
  ThemeServices._internal() {
    // Initialize with default values
    _themeMode = ThemeMode.light;
    _textSize = 16.0;
    _textScaleFactor = 1.0;

    // Listen to wallpaper theme changes
    _wallpaperThemeService.addListener(_onWallpaperThemeChanged);
  }

  late ThemeMode _themeMode;
  double _textScaleFactor = 1.0;
  double _textSize = 16.0;
  bool _useDynamicColor = true;
  bool _useWallpaperColors = false;
  ColorScheme? _lightDynamicColorScheme;
  ColorScheme? _darkDynamicColorScheme;

  // Preferences service instance
  final PreferencesService _prefsService = PreferencesService();

  // Wallpaper theme service
  final WallpaperThemeService _wallpaperThemeService =
      WallpaperThemeService.instance;

  void _onWallpaperThemeChanged() {
    // When wallpaper colors change, notify listeners to rebuild themes
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  // New getter for textScaler
  TextScaler get textScaler => TextScaler.linear(_textSize / 16.0);
  double get textSize => _textSize;
  bool get useDynamicColor => _useDynamicColor;
  bool get useWallpaperColors => _useWallpaperColors;
  bool get hasWallpaperColors => _wallpaperThemeService.hasWallpaperColors;
  ColorScheme? get lightDynamicColorScheme => _lightDynamicColorScheme;
  ColorScheme? get darkDynamicColorScheme => _darkDynamicColorScheme;
  WallpaperThemeService get wallpaperThemeService => _wallpaperThemeService;

  Future<void> init() async {
    try {
      // Initialize preferences service if not already initialized
      await _prefsService.initialize();

      // Get values from preferences service
      _themeMode = _prefsService.getBool('darkMode')
          ? ThemeMode.dark
          : ThemeMode.light;
      _textSize = (_prefsService.getDouble(
        'textSize',
        defaultValue: 16.0,
      )).clamp(12.0, 24.0);
      _useDynamicColor = _prefsService.getBool(
        'useDynamicColor',
        defaultValue: true,
      );
      _useWallpaperColors = _prefsService.getBool(
        'useWallpaperColors',
        defaultValue: false,
      );

      // Load dynamic colors from system (Material You)
      await _loadDynamicColors();

      // Load saved wallpaper colors from storage
      if (_useWallpaperColors) {
        await _wallpaperThemeService.extractor.loadSavedColors();
      }

      // Sync wallpaper theme service setting
      _wallpaperThemeService.setUseWallpaperColors(_useWallpaperColors);

      print('🔤 Initialized text size: $_textSize');
      print('🎨 Dynamic colors enabled: $_useDynamicColor');
      print('🖼️ Wallpaper colors enabled: $_useWallpaperColors');
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

  // Load dynamic colors from system
  Future<void> _loadDynamicColors() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        _lightDynamicColorScheme = corePalette.toColorScheme(
          brightness: Brightness.light,
        );
        _darkDynamicColorScheme = corePalette.toColorScheme(
          brightness: Brightness.dark,
        );
        print('🎨 Loaded dynamic colors from system');
      } else {
        print('🎨 Dynamic colors not available on this device');
      }
    } catch (e) {
      print('🎨 Error loading dynamic colors: $e');
    }
  }

  Future<void> setDynamicColor(bool useDynamic) async {
    await _prefsService.setBool('useDynamicColor', useDynamic);
    _useDynamicColor = useDynamic;
    if (useDynamic) {
      await _loadDynamicColors();
    }
    notifyListeners();
  }

  Future<void> setUseWallpaperColors(bool useWallpaper) async {
    await _prefsService.setBool('useWallpaperColors', useWallpaper);
    _useWallpaperColors = useWallpaper;
    _wallpaperThemeService.setUseWallpaperColors(useWallpaper);
    notifyListeners();
  }

  Future<bool> updateWallpaperColors() async {
    final result = await _wallpaperThemeService.updateWallpaperColors();
    if (result) {
      notifyListeners();
    }
    return result;
  }

  Future<bool> updateWallpaperColorsFromSystem() async {
    final result = await _wallpaperThemeService
        .updateWallpaperColorsFromSystem();
    if (result) {
      notifyListeners();
    }
    return result;
  }

  void clearWallpaperColors() {
    _wallpaperThemeService.clearWallpaperColors();
    _useWallpaperColors = false;
    _prefsService.setBool('useWallpaperColors', false);
    notifyListeners();
  }

  List<Color> getWallpaperColorPreview() {
    return _wallpaperThemeService.getColorPreview();
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

    // Priority order: Wallpaper colors > System dynamic colors > Static fallback
    ColorScheme colorScheme;
    if (_useWallpaperColors &&
        _wallpaperThemeService.extractor.lightColorScheme != null) {
      colorScheme = _wallpaperThemeService.extractor.lightColorScheme!;
      print('🎨 Using wallpaper light color scheme');
    } else if (_useDynamicColor && _lightDynamicColorScheme != null) {
      colorScheme = _lightDynamicColorScheme!;
      print('🎨 Using dynamic light color scheme');
    } else {
      // Fallback Material You inspired color scheme
      const primaryColor = Color(0xFF4361EE);
      colorScheme = ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      );
      print('🎨 Using static light color scheme');
    }

    // Apply scale factor to all sizes
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
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
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 12 * _textScaleFactor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  } // End of getLightTheme

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

    // Priority order: Wallpaper colors > System dynamic colors > Static fallback
    ColorScheme colorScheme;
    if (_useWallpaperColors &&
        _wallpaperThemeService.extractor.darkColorScheme != null) {
      colorScheme = _wallpaperThemeService.extractor.darkColorScheme!;
      print('🎨 Using wallpaper dark color scheme');
    } else if (_useDynamicColor && _darkDynamicColorScheme != null) {
      colorScheme = _darkDynamicColorScheme!;
      print('🎨 Using dynamic dark color scheme');
    } else {
      // Fallback Material You inspired color scheme
      const primaryColor = Color(0xFF4CC9F0);
      colorScheme = ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      );
      print('🎨 Using static dark color scheme');
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
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
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFF121212),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: colorScheme.primary,
          elevation: 3,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 12 * _textScaleFactor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wallpaperThemeService.removeListener(_onWallpaperThemeChanged);
    super.dispose();
  }
}
