import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

/// Eye Protection Service to reduce eye strain while reading
///
/// Based on scientific research on blue light filtering, contrast reduction,
/// melanopsin signaling, pupillary responses, and reading ergonomics to minimize eye strain during extended reading sessions.
class EyeProtectionService {
  // Singleton instance
  static final EyeProtectionService _instance =
      EyeProtectionService._internal();
  factory EyeProtectionService() => _instance;
  EyeProtectionService._internal();

  // Default values
  static const double defaultBlueFilter =
      0.3; // Increased from 0.2 based on melanopsin research
  static const double defaultContrastReduction =
      0.15; // New parameter for optimal contrast
  static const double defaultBrightnessAdjustment =
      0.1; // New parameter for brightness adaptation
  static const int defaultReadingTimer = 20; // minutes
  static const bool defaultEyeProtectionEnabled = true;
  static const bool defaultAdaptiveBrightnessEnabled = true;
  static const double defaultWarmColorTemperature = 3200; // Kelvin
  static const bool defaultDynamicFilteringEnabled =
      true; // New parameter for time-based filtering
  static const double defaultPupilResponseCompensation =
      0.2; // New parameter based on pupil research

  // Values that will be loaded from preferences
  bool _eyeProtectionEnabled = defaultEyeProtectionEnabled;
  double _blueFilterLevel = defaultBlueFilter;
  double _contrastReduction = defaultContrastReduction;
  double _brightnessAdjustment = defaultBrightnessAdjustment;
  int _readingTimerDuration = defaultReadingTimer;
  bool _adaptiveBrightnessEnabled = defaultAdaptiveBrightnessEnabled;
  double _warmColorTemperature = defaultWarmColorTemperature;
  bool _dynamicFilteringEnabled = defaultDynamicFilteringEnabled;
  double _pupilResponseCompensation = defaultPupilResponseCompensation;

  // Internal state
  DateTime? _readingStartTime;
  StreamController<bool> _reminderController =
      StreamController<bool>.broadcast();
  bool _isNightTime = false;
  Timer? _circadianTimer;
  int _readingTimerInterval = 20; // Default 20 minutes for timer interval
  bool _periodicalReminderEnabled =
      true; // Default enabled for periodic reminders
  double _warmthLevel = 0.5; // Default warmth level (0.0-1.0)

  // Ambient light sensitivity (0.0-1.0)
  double _ambientLightSensitivity = 0.5;

  // Getters
  bool get eyeProtectionEnabled => _eyeProtectionEnabled;
  double get blueFilterLevel => _blueFilterLevel;
  double get contrastReduction => _contrastReduction;
  double get brightnessAdjustment => _brightnessAdjustment;
  int get readingTimerDuration => _readingTimerDuration;
  bool get adaptiveBrightnessEnabled => _adaptiveBrightnessEnabled;
  double get warmColorTemperature => _warmColorTemperature;
  bool get dynamicFilteringEnabled => _dynamicFilteringEnabled;
  double get pupilResponseCompensation => _pupilResponseCompensation;
  int get readingTimerInterval => _readingTimerInterval;
  bool get periodicalReminderEnabled => _periodicalReminderEnabled;
  double get warmthLevel => _warmthLevel;
  double get ambientLightSensitivity => _ambientLightSensitivity;

  Stream<bool> get reminderStream => _reminderController.stream;
  DateTime? get readingStartTime => _readingStartTime;
  bool get isNightTime => _isNightTime;

  // Calculate effective blue filter level based on time of day and user settings
  double get effectiveBlueFilterLevel {
    if (!_dynamicFilteringEnabled) return _blueFilterLevel;

    final now = DateTime.now();
    final hour = now.hour;

    // Increase blue filtering in evening hours (after 6 PM)
    // Based on melanopsin sensitivity research
    if (hour >= 18 || hour < 6) {
      _isNightTime = true;
      // Progressively increase blue filtering from 6 PM to 11 PM
      double timeBasedIncrease = 0.0;
      if (hour >= 18 && hour <= 23) {
        timeBasedIncrease =
            (hour - 18) * 0.05; // Gradually increase by 5% each hour
      } else {
        timeBasedIncrease = 0.25; // Maximum increase during night (30%)
      }
      return math.min(0.7, _blueFilterLevel + timeBasedIncrease); // Cap at 70%
    } else {
      _isNightTime = false;
      return _blueFilterLevel;
    }
  }

  // Calculate effective brightness based on pupillary response compensation
  double get effectiveBrightnessAdjustment {
    if (!_adaptiveBrightnessEnabled) return _brightnessAdjustment;

    final now = DateTime.now();
    final hour = now.hour;

    // Implement pupil-based adjustment - based on research showing different pupil responses
    // at different times of day and with different light exposure
    double timeBasedAdjustment = 0.0;

    // Pupils more dilated in morning, less sensitive to light
    if (hour >= 5 && hour < 9) {
      timeBasedAdjustment = -0.05; // Lower brightness in morning
    }
    // Pupils more constricted mid-day, more sensitive to light
    else if (hour >= 10 && hour < 16) {
      timeBasedAdjustment = 0.05; // Increase brightness mid-day
    }
    // Pupils more dilated in evening, melanopsin more sensitive
    else if (hour >= 19) {
      timeBasedAdjustment =
          -0.1 - ((hour - 19) * 0.02); // Progressively lower brightness
    }

    return _brightnessAdjustment +
        timeBasedAdjustment +
        _pupilResponseCompensation;
  }

  // Initialize and load saved preferences
  Future<void> initialize() async {
    await loadPreferences();
    _startCircadianTimer();
    return;
  }

  // Start the reading timer
  void startReadingTimer() {
    _readingStartTime = DateTime.now();
  }

  // Check if it's time for a break
  bool checkBreakNeeded() {
    if (_readingStartTime == null) return false;

    final now = DateTime.now();
    final difference = now.difference(_readingStartTime!);
    return difference.inMinutes >= _readingTimerDuration;
  }

  // Reset the reading timer
  void resetReadingTimer() {
    _readingStartTime = DateTime.now();
  }

  // Load preferences from SharedPreferences
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _eyeProtectionEnabled =
        prefs.getBool('eye_protection_enabled') ?? defaultEyeProtectionEnabled;
    _blueFilterLevel =
        prefs.getDouble('blue_filter_level') ?? defaultBlueFilter;
    _contrastReduction =
        prefs.getDouble('contrast_reduction') ?? defaultContrastReduction;
    _brightnessAdjustment =
        prefs.getDouble('brightness_adjustment') ?? defaultBrightnessAdjustment;
    _readingTimerDuration =
        prefs.getInt('reading_timer_duration') ?? defaultReadingTimer;
    _adaptiveBrightnessEnabled =
        prefs.getBool('adaptive_brightness_enabled') ??
        defaultAdaptiveBrightnessEnabled;
    _warmColorTemperature =
        prefs.getDouble('warm_color_temperature') ??
        defaultWarmColorTemperature;
    _dynamicFilteringEnabled =
        prefs.getBool('dynamic_filtering_enabled') ??
        defaultDynamicFilteringEnabled;
    _pupilResponseCompensation =
        prefs.getDouble('pupil_response_compensation') ??
        defaultPupilResponseCompensation;
    _readingTimerInterval = prefs.getInt('reading_timer_interval') ?? 20;
    _periodicalReminderEnabled =
        prefs.getBool('periodical_reminder_enabled') ?? true;
    _warmthLevel = prefs.getDouble('warmth_level') ?? 0.5;
    _ambientLightSensitivity =
        prefs.getDouble('ambient_light_sensitivity') ?? 0.5;
  }

  // Save a preference
  Future<void> savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    switch (key) {
      case 'eye_protection_enabled':
        _eyeProtectionEnabled = value;
        await prefs.setBool(key, value);
        break;
      case 'blue_filter_level':
        _blueFilterLevel = value;
        await prefs.setDouble(key, value);
        break;
      case 'contrast_reduction':
        _contrastReduction = value;
        await prefs.setDouble(key, value);
        break;
      case 'brightness_adjustment':
        _brightnessAdjustment = value;
        await prefs.setDouble(key, value);
        break;
      case 'reading_timer_duration':
        _readingTimerDuration = value;
        await prefs.setInt(key, value);
        break;
      case 'adaptive_brightness_enabled':
        _adaptiveBrightnessEnabled = value;
        await prefs.setBool(key, value);
        break;
      case 'warm_color_temperature':
        _warmColorTemperature = value;
        await prefs.setDouble(key, value);
        break;
      case 'dynamic_filtering_enabled':
        _dynamicFilteringEnabled = value;
        await prefs.setBool(key, value);
        break;
      case 'pupil_response_compensation':
        _pupilResponseCompensation = value;
        await prefs.setDouble(key, value);
        break;
      case 'reading_timer_interval':
        _readingTimerInterval = value;
        await prefs.setInt(key, value);
        break;
      case 'periodical_reminder_enabled':
        _periodicalReminderEnabled = value;
        await prefs.setBool(key, value);
        break;
      case 'warmth_level':
        _warmthLevel = value;
        await prefs.setDouble(key, value);
        break;
      case 'ambient_light_sensitivity':
        _ambientLightSensitivity = value;
        await prefs.setDouble(key, value);
        break;
    }
  }

  // Generate a filter color based on current settings and time of day
  Color getFilterColor() {
    // Calculate blue reduction based on effective filter level
    final blueReduction = effectiveBlueFilterLevel;

    // Calculate red and green channels based on warm color temperature
    // Higher color temperature = more blue, cooler
    // Lower color temperature = more red/yellow, warmer
    double normalizedTemp =
        (_warmColorTemperature - 1800) / 3500; // Normalize from 1800K to 5300K
    normalizedTemp = normalizedTemp.clamp(0.0, 1.0);

    // More warm at night (reduce blue, increase red slightly)
    if (_isNightTime) {
      normalizedTemp *= 0.7; // Make it warmer at night
    }

    // Calculate RGB values for overlay filter
    double redChannel = 1.0 - (_contrastReduction * 0.5);
    double greenChannel =
        1.0 - (_contrastReduction * 0.7) - (normalizedTemp * 0.1);
    double blueChannel = 1.0 - blueReduction - (_contrastReduction * 0.8);

    // Ensure values are in valid range
    redChannel = redChannel.clamp(0.0, 1.0);
    greenChannel = greenChannel.clamp(0.0, 1.0);
    blueChannel = blueChannel.clamp(0.0, 1.0);

    return Color.fromRGBO(
      (redChannel * 255).round(),
      (greenChannel * 255).round(),
      (blueChannel * 255).round(),
      blueReduction * 0.8, // Use blue reduction to determine alpha
    );
  }

  // Get text color adjustment based on current settings
  TextStyle getTextStyleAdjustment(TextStyle baseStyle) {
    // Determine brightness adjustment
    double brightness = 1.0 - effectiveBrightnessAdjustment;

    // Calculate color
    Color originalColor = baseStyle.color ?? Colors.black;
    Color adjustedColor;

    // For dark mode (white/light text)
    if (_getLuminance(originalColor) > 0.5) {
      // For light text (dark background), we slightly reduce the brightness
      // This helps reduce the harsh contrast between text and background
      adjustedColor = Color.fromRGBO(
        (originalColor.red * brightness).round(),
        (originalColor.green * brightness).round(),
        ((originalColor.blue * brightness) *
                (1.0 - (effectiveBlueFilterLevel * 0.3)))
            .round(),
        1.0,
      );
    }
    // For light mode (dark/black text)
    else {
      // For dark text, we might want to slightly increase brightness to compensate
      // for the overlay filter's darkening effect
      double textBrightnessCompensation = 1.0 + (_contrastReduction * 0.5);

      adjustedColor = Color.fromRGBO(
        math.min(255, (originalColor.red * textBrightnessCompensation).round()),
        math.min(
          255,
          (originalColor.green * textBrightnessCompensation).round(),
        ),
        math.min(
          255,
          (originalColor.blue *
                  textBrightnessCompensation *
                  (1.0 - (effectiveBlueFilterLevel * 0.2)))
              .round(),
        ),
        1.0,
      );
    }

    // Return adjusted style
    return baseStyle.copyWith(
      color: adjustedColor,
      // Slightly increase letter spacing for better readability
      letterSpacing: (baseStyle.letterSpacing ?? 0.0) + 0.1,
    );
  }

  // Helper to get luminance of a color
  double _getLuminance(Color color) {
    return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
  }

  // Start circadian timer to adjust filter values throughout the day
  void _startCircadianTimer() {
    // Check every 10 minutes if filter values need to be adjusted
    _circadianTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      // The getters already calculate based on time of day
      // This timer just ensures the UI refreshes periodically
      if (_reminderController.hasListener) {
        _reminderController.add(false);
      }
    });
  }

  // Dispose resources
  void dispose() {
    _circadianTimer?.cancel();
    _reminderController.close();
  }

  // Convenience setter methods
  Future<void> setEyeProtectionEnabled(bool enabled) async {
    await savePreference('eye_protection_enabled', enabled);
  }

  Future<void> setBlueFilterLevel(double level) async {
    await savePreference('blue_filter_level', level);
  }

  Future<void> setWarmthLevel(double level) async {
    await savePreference('warmth_level', level);
  }

  Future<void> setAdaptiveBrightnessEnabled(bool enabled) async {
    await savePreference('adaptive_brightness_enabled', enabled);
  }

  Future<void> setPeriodicalReminderEnabled(bool enabled) async {
    await savePreference('periodical_reminder_enabled', enabled);
  }

  Future<void> setReadingTimerInterval(int minutes) async {
    await savePreference('reading_timer_interval', minutes);
  }

  Future<void> setAmbientLightSensitivity(double sensitivity) async {
    await savePreference('ambient_light_sensitivity', sensitivity);
  }

  // Initialize service
  Future<void> initSettings() async {
    await initialize();
  }

  // Apply eye protection to text color
  Color applyEyeProtection(Color color) {
    return getTextStyleAdjustment(TextStyle(color: color)).color ?? color;
  }

  // Get color for overlay
  Color getOverlayColor() {
    return getFilterColor();
  }

  // Get adaptive brightness based on time of day and ambient light
  double getAdaptiveBrightness(
    double currentBrightness,
    DateTime time, [
    double? ambientLightLevel,
  ]) {
    if (!adaptiveBrightnessEnabled) return currentBrightness;

    final hour = time.hour;
    double adjustment = 0.0;

    // Reduce brightness in evening/night
    if (hour >= 19 || hour < 6) {
      // Progressive reduction after 7 PM
      if (hour >= 19 && hour <= 23) {
        adjustment = -0.05 * (hour - 18); // -5% per hour after 6 PM
      } else {
        adjustment = -0.25; // Maximum reduction at night
      }
    }

    // Factor in pupil response compensation
    adjustment +=
        _pupilResponseCompensation * (hour >= 19 || hour < 6 ? -0.1 : 0.05);

    // Factor in ambient light if provided
    if (ambientLightLevel != null && _ambientLightSensitivity > 0) {
      // Scale from 0-1 where 0 is dark and 1 is bright
      double ambientAdjustment =
          (0.5 - ambientLightLevel) * _ambientLightSensitivity;
      adjustment += ambientAdjustment;
    }

    // Apply adjustment but keep within bounds (0.1 to 1.0)
    return (currentBrightness + adjustment).clamp(0.1, 1.0);
  }

  // Export settings to a JSON string
  Future<String> exportSettings() async {
    Map<String, dynamic> settings = {
      'eye_protection_enabled': _eyeProtectionEnabled,
      'blue_filter_level': _blueFilterLevel,
      'contrast_reduction': _contrastReduction,
      'brightness_adjustment': _brightnessAdjustment,
      'reading_timer_duration': _readingTimerDuration,
      'adaptive_brightness_enabled': _adaptiveBrightnessEnabled,
      'warm_color_temperature': _warmColorTemperature,
      'dynamic_filtering_enabled': _dynamicFilteringEnabled,
      'pupil_response_compensation': _pupilResponseCompensation,
      'reading_timer_interval': _readingTimerInterval,
      'periodical_reminder_enabled': _periodicalReminderEnabled,
      'warmth_level': _warmthLevel,
      'ambient_light_sensitivity': _ambientLightSensitivity,
      'export_date': DateTime.now().toIso8601String(),
      'version': '1.0',
      'profile_name': 'eyeCARE™ Configuration',
    };

    return jsonEncode(settings);
  }

  // Import settings from a JSON string
  Future<bool> importSettings(String jsonSettings) async {
    try {
      final Map<String, dynamic> settings = jsonDecode(jsonSettings);

      // Validate settings version
      if (settings['version'] != '1.0') {
        return false;
      }

      // Import all settings
      await setEyeProtectionEnabled(
        settings['eye_protection_enabled'] ?? defaultEyeProtectionEnabled,
      );
      await setBlueFilterLevel(
        settings['blue_filter_level'] ?? defaultBlueFilter,
      );
      await savePreference(
        'contrast_reduction',
        settings['contrast_reduction'] ?? defaultContrastReduction,
      );
      await savePreference(
        'brightness_adjustment',
        settings['brightness_adjustment'] ?? defaultBrightnessAdjustment,
      );
      await savePreference(
        'reading_timer_duration',
        settings['reading_timer_duration'] ?? defaultReadingTimer,
      );
      await setAdaptiveBrightnessEnabled(
        settings['adaptive_brightness_enabled'] ??
            defaultAdaptiveBrightnessEnabled,
      );
      await savePreference(
        'warm_color_temperature',
        settings['warm_color_temperature'] ?? defaultWarmColorTemperature,
      );
      await savePreference(
        'dynamic_filtering_enabled',
        settings['dynamic_filtering_enabled'] ?? defaultDynamicFilteringEnabled,
      );
      await savePreference(
        'pupil_response_compensation',
        settings['pupil_response_compensation'] ??
            defaultPupilResponseCompensation,
      );
      await setReadingTimerInterval(settings['reading_timer_interval'] ?? 20);
      await setPeriodicalReminderEnabled(
        settings['periodical_reminder_enabled'] ?? true,
      );
      await setWarmthLevel(settings['warmth_level'] ?? 0.5);
      await setAmbientLightSensitivity(
        settings['ambient_light_sensitivity'] ?? 0.5,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get settings summary for display purposes
  Map<String, dynamic> getSettingsSummary() {
    return {
      'blue_filter': (_blueFilterLevel * 100).round(),
      'is_night_mode': _isNightTime,
      'eye_protection': _eyeProtectionEnabled,
      'break_interval': _readingTimerInterval,
      'adaptive_brightness': _adaptiveBrightnessEnabled,
      'warmth_level': (_warmthLevel * 100).round(),
    };
  }
}
