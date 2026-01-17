import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/services/theme_services.dart';
import 'package:docln/core/services/preferences_service.dart';

class AppearanceSettingsProvider extends ChangeNotifier {
  // State
  bool _isDarkMode = false;
  double _textSize = 16.0;

  // Loading state
  bool _isLoading = false;

  // Getters
  bool get isDarkMode => _isDarkMode;
  double get textSize => _textSize;
  bool get isLoading => _isLoading;

  // Dependencies
  // We need context or access to ThemeServices/PreferencesService.
  // Since this is a provider, we can't easily get other providers via constructor injection usually unless using ProxyProvider.
  // But we can resolve them in methods if we pass context, or use a locator if available.
  // The existing pattern uses Provider.of(context) in the UI.
  // We will replicate the pattern used in NetworkSettingsProvider: instantiate services directly if they are singletons/services,
  // OR rely on saveSettings() being passed dependencies or doing lookups.
  // ThemeServices is a ChangeNotifier itself.

  // Actually, NetworkSettingsProvider instantiated services:
  // final SettingsService _settingsService = SettingsService();

  // ThemeServices is likely a Provider-bound service.
  // Let's check `theme_services.dart` usage.
  // It is accessed via `Provider.of<ThemeServices>(context)`.

  // So we cannot instantiate `ThemeServices` easily inside here if it holds state.
  // We should probably accept initial values or load them.

  AppearanceSettingsProvider() {
    // We can't load from ThemeServices here without context.
    // We will require an `init(BuildContext context)` or similar, or pass values in constructor.
  }

  // Initialize with current values
  void init(bool currentDarkMode, double currentTextSize) {
    _isDarkMode = currentDarkMode;
    _textSize = currentTextSize;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setTextSize(double value, {Function(double)? onPreview}) {
    _textSize = value;
    onPreview?.call(value);
    notifyListeners();
  }

  Future<void> saveSettings(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefsService = PreferencesService();
      await prefsService.initialize(); // Ensure initialized
      final themeService = Provider.of<ThemeServices>(context, listen: false);

      await Future.wait([
        prefsService.setBool('darkMode', _isDarkMode),
        prefsService.setDouble('textSize', _textSize),
        themeService.setThemeMode(_isDarkMode),
        Future(() => themeService.setTextSize(_textSize)),
      ]);
    } catch (e) {
      debugPrint('Error saving appearance settings: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void revertSettings(BuildContext context) {
    // Revert logic: reload from actual services
    final themeService = Provider.of<ThemeServices>(context, listen: false);
    _isDarkMode = themeService.themeMode == ThemeMode.dark;
    _textSize = themeService.textSize;

    // Reset preview if needed?
    // ThemeServices.setTextSize sets the actual size.
    // previewTextSize sets a temporary one?
    // We should probably explicitly reset text size in theme service to stored value just in case preview stuck.
    themeService.setTextSize(_textSize);

    notifyListeners();
  }
}
