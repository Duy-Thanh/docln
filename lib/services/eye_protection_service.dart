import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Eye Protection Service to reduce eye strain while reading
///
/// Based on scientific research on blue light filtering, contrast reduction,
/// and reading ergonomics to minimize eye strain during extended reading sessions.
class EyeProtectionService {
  // Singleton instance
  static final EyeProtectionService _instance =
      EyeProtectionService._internal();
  factory EyeProtectionService() => _instance;
  EyeProtectionService._internal();

  // Default values
  static const double defaultBlueFilter = 0.2;
  static const double defaultContrast = 0.8;
  static const int defaultReadingTimer = 20; // minutes
  static const bool defaultEyeProtectionEnabled = true;
  static const bool defaultAdaptiveBrightnessEnabled = true;
  static const double defaultWarmthLevel = 0.3;
  static const bool defaultPeriodicalReminderEnabled = true;
  static const bool defaultPupillaryMonitoringEnabled = true;

  // Current settings
  bool _eyeProtectionEnabled = defaultEyeProtectionEnabled;
  double _blueFilterLevel = defaultBlueFilter;
  double _contrastLevel = defaultContrast;
  int _readingTimerInterval = defaultReadingTimer;
  bool _adaptiveBrightnessEnabled = defaultAdaptiveBrightnessEnabled;
  double _warmthLevel = defaultWarmthLevel;
  bool _periodicalReminderEnabled = defaultPeriodicalReminderEnabled;
  bool _pupillaryMonitoringEnabled = defaultPupillaryMonitoringEnabled;

  // Pupillary monitoring variables
  dynamic _cameraController; // Placeholder for CameraController
  Timer? _pupillaryMonitoringTimer;
  double _lastPupilSize = 0.0;
  double _baselinePupilSize = 0.0;
  bool _isPupillaryMonitoringActive = false;
  DateTime _lastPupilSizeUpdate = DateTime.now();

  // Pupillary fatigue threshold - when pupil size changes more than this percentage
  // from baseline, we consider it as potential eye fatigue
  static const double pupilFatigueThreshold = 0.15; // 15% change

  // Getters
  bool get eyeProtectionEnabled => _eyeProtectionEnabled;
  double get blueFilterLevel => _blueFilterLevel;
  double get contrastLevel => _contrastLevel;
  int get readingTimerInterval => _readingTimerInterval;
  bool get adaptiveBrightnessEnabled => _adaptiveBrightnessEnabled;
  double get warmthLevel => _warmthLevel;
  bool get periodicalReminderEnabled => _periodicalReminderEnabled;
  bool get pupillaryMonitoringEnabled => _pupillaryMonitoringEnabled;
  bool get isPupillaryMonitoringActive => _isPupillaryMonitoringActive;
  dynamic get cameraController => _cameraController;

  /// Initialize settings from shared preferences
  Future<void> initSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _eyeProtectionEnabled =
        prefs.getBool('eye_protection_enabled') ?? defaultEyeProtectionEnabled;
    _blueFilterLevel =
        prefs.getDouble('blue_filter_level') ?? defaultBlueFilter;
    _contrastLevel = prefs.getDouble('contrast_level') ?? defaultContrast;
    _readingTimerInterval =
        prefs.getInt('reading_timer_interval') ?? defaultReadingTimer;
    _adaptiveBrightnessEnabled =
        prefs.getBool('adaptive_brightness_enabled') ??
        defaultAdaptiveBrightnessEnabled;
    _warmthLevel = prefs.getDouble('warmth_level') ?? defaultWarmthLevel;
    _periodicalReminderEnabled =
        prefs.getBool('periodical_reminder_enabled') ??
        defaultPeriodicalReminderEnabled;
    _pupillaryMonitoringEnabled =
        prefs.getBool('pupillary_monitoring_enabled') ??
        defaultPupillaryMonitoringEnabled;
  }

  // PUPILLARY MONITORING METHODS

  /// Start pupillary response monitoring
  Future<bool> startPupillaryMonitoring() async {
    if (!_pupillaryMonitoringEnabled) return false;

    try {
      // Placeholder: In a real implementation, this would initialize the camera
      // and set up pupil tracking using computer vision

      // Simulate baseline pupil size
      _baselinePupilSize = 3.5; // Average pupil size in mm

      // Set up monitoring timer (every 10 seconds)
      _pupillaryMonitoringTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _simulatePupilSizeDetection(),
      );

      _isPupillaryMonitoringActive = true;
      return true;
    } catch (e) {
      print('Error starting pupillary monitoring: $e');
      _isPupillaryMonitoringActive = false;
      return false;
    }
  }

  /// Stop pupillary response monitoring
  Future<void> stopPupillaryMonitoring() async {
    _pupillaryMonitoringTimer?.cancel();

    // In a real implementation, this would dispose of camera resources
    _cameraController = null;

    _isPupillaryMonitoringActive = false;
  }

  /// Simulate pupil size detection (for demonstration)
  void _simulatePupilSizeDetection() {
    // In a real implementation, this would be replaced with actual
    // pupil detection algorithm

    // Simulate baseline if not set
    if (_baselinePupilSize == 0.0) {
      _baselinePupilSize = 3.5; // Average pupil size in mm
    }

    // Simulate pupil size changes based on time (constricting with screen use)
    final timeElapsed =
        DateTime.now().difference(_lastPupilSizeUpdate).inMinutes;

    // Simple model: pupil constricts over time with screen use
    double simulatedSize =
        _baselinePupilSize * (1.0 - (0.02 * timeElapsed).clamp(0.0, 0.3));

    // Add some random variation
    simulatedSize += (DateTime.now().millisecond % 10) / 100;

    _lastPupilSize = simulatedSize;
    _lastPupilSizeUpdate = DateTime.now();
  }

  /// Check if pupil shows signs of eye fatigue
  bool _checkPupilFatigue() {
    if (_baselinePupilSize == 0.0 || _lastPupilSize == 0.0) return false;

    // Calculate change from baseline
    double change =
        (_lastPupilSize - _baselinePupilSize).abs() / _baselinePupilSize;

    // Check if change exceeds threshold
    return change > pupilFatigueThreshold;
  }

  /// Get pupillary fatigue level (0.0 to 1.0)
  double getPupillaryFatigueLevel() {
    if (!_isPupillaryMonitoringActive || _baselinePupilSize == 0.0) return 0.0;

    // Calculate change from baseline
    double change =
        (_lastPupilSize - _baselinePupilSize).abs() / _baselinePupilSize;

    // Normalize to a 0.0-1.0 scale where 1.0 means high fatigue
    return (change / pupilFatigueThreshold).clamp(0.0, 1.0);
  }

  /// Enable or disable pupillary monitoring
  Future<void> setPupillaryMonitoringEnabled(bool enabled) async {
    _pupillaryMonitoringEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pupillary_monitoring_enabled', enabled);

    if (enabled && !_isPupillaryMonitoringActive) {
      await startPupillaryMonitoring();
    } else if (!enabled && _isPupillaryMonitoringActive) {
      await stopPupillaryMonitoring();
    }
  }

  /// Enable or disable eye protection
  Future<void> setEyeProtectionEnabled(bool enabled) async {
    _eyeProtectionEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eye_protection_enabled', enabled);
  }

  /// Set blue light filter level (0.0 - 1.0)
  Future<void> setBlueFilterLevel(double level) async {
    _blueFilterLevel = level.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('blue_filter_level', _blueFilterLevel);
  }

  /// Set contrast level (0.0 - 1.0)
  Future<void> setContrastLevel(double level) async {
    _contrastLevel = level.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('contrast_level', _contrastLevel);
  }

  /// Set reading timer interval in minutes
  Future<void> setReadingTimerInterval(int minutes) async {
    _readingTimerInterval = minutes.clamp(1, 60);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reading_timer_interval', _readingTimerInterval);
  }

  /// Enable or disable adaptive brightness
  Future<void> setAdaptiveBrightnessEnabled(bool enabled) async {
    _adaptiveBrightnessEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adaptive_brightness_enabled', enabled);
  }

  /// Set color temperature warmth level (0.0 - 1.0)
  Future<void> setWarmthLevel(double level) async {
    _warmthLevel = level.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('warmth_level', _warmthLevel);
  }

  /// Enable or disable periodical reminders
  Future<void> setPeriodicalReminderEnabled(bool enabled) async {
    _periodicalReminderEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('periodical_reminder_enabled', enabled);
  }

  /// Get overlay color for the eye protection layer
  Color getOverlayColor() {
    if (!_eyeProtectionEnabled) {
      return Colors.transparent;
    }

    // Amber tint reduces blue light
    // The higher the blue filter level, the more amber the tint
    final double blueReduction = _blueFilterLevel * 0.1; // Subtle effect

    // Warm color overlay reduces blue light and creates a more pleasant reading experience
    // Combine sepia tone with amber for a warm, paper-like effect
    Color overlayColor = Color.fromRGBO(
      255, // Red
      (255 * (1 - _warmthLevel * 0.3)).toInt(), // Green
      (255 * (1 - _blueFilterLevel * 0.5)).toInt(), // Blue
      _blueFilterLevel * 0.25, // Alpha - subtle overlay
    );

    return overlayColor;
  }

  /// Apply eye protection to a color
  /// This adjusts the color's blue component and contrast to reduce eye strain
  Color applyEyeProtection(Color color) {
    if (!_eyeProtectionEnabled) {
      return color;
    }

    // Extract color components
    int red = color.red;
    int green = color.green;
    int blue = color.blue;

    // Reduce blue component based on blue filter level
    blue = (blue * (1.0 - _blueFilterLevel * 0.3)).round().clamp(0, 255);

    // Apply warmth (increase red, slightly decrease blue)
    red = (red * (1.0 + _warmthLevel * 0.1)).round().clamp(0, 255);
    blue = (blue * (1.0 - _warmthLevel * 0.1)).round().clamp(0, 255);

    // Adjust contrast to reduce eye strain from too much contrast
    // Move colors slightly closer to middle gray for less harshness
    final int midGray = 128;
    if (_contrastLevel < 1.0) {
      final double contrastFactor = 1.0 - ((1.0 - _contrastLevel) * 0.3);
      red = ((red - midGray) * contrastFactor + midGray).round().clamp(0, 255);
      green = ((green - midGray) * contrastFactor + midGray).round().clamp(
        0,
        255,
      );
      blue = ((blue - midGray) * contrastFactor + midGray).round().clamp(
        0,
        255,
      );
    }

    return Color.fromARGB(color.alpha, red, green, blue);
  }

  /// Get adaptive brightness based on time of day
  /// Returns adjusted brightness level
  double getAdaptiveBrightness(double currentBrightness, DateTime dateTime) {
    if (!_adaptiveBrightnessEnabled) {
      return currentBrightness;
    }

    // Get the hour (0-23)
    final int hour = dateTime.hour;

    // Define brightness adjustments by time of day
    // Late evening and night: reduce brightness
    if (hour >= 21 || hour < 5) {
      // After 9 PM or before 5 AM
      return (currentBrightness * 0.7).clamp(0.1, 1.0);
    }
    // Evening: slightly reduce brightness
    else if (hour >= 18) {
      // Between 6 PM and 9 PM
      return (currentBrightness * 0.85).clamp(0.1, 1.0);
    }
    // Early morning: moderate brightness
    else if (hour < 8) {
      // Between 5 AM and 8 AM
      return (currentBrightness * 0.9).clamp(0.1, 1.0);
    }

    // Daytime: use normal brightness
    return currentBrightness;
  }

  /// Calculate ideal font size based on readability research
  /// Returns a recommended font size in logical pixels
  double getIdealFontSize(double currentFontSize) {
    // Research suggests 16-18pt is optimal for reading on screens
    // We'll adjust the user's preference slightly in that direction
    if (currentFontSize < 14.0) {
      return (currentFontSize * 1.1).clamp(currentFontSize, 14.0);
    }

    return currentFontSize;
  }

  /// Calculate ideal line height (line spacing) for optimal readability
  /// Returns a recommended line height multiplier
  double getIdealLineHeight(double currentLineHeight) {
    // Research suggests 1.5 to 2.0 is optimal for reading
    if (currentLineHeight < 1.5) {
      return (currentLineHeight * 1.1).clamp(currentLineHeight, 1.5);
    }

    return currentLineHeight;
  }

  /// Apply eye strain reduction techniques to a widget's background
  Color getEyeFriendlyBackgroundColor(Color baseColor, bool isDarkMode) {
    if (!_eyeProtectionEnabled) {
      return baseColor;
    }

    // For dark mode, use slightly lighter than pure black (reduces eye strain)
    if (isDarkMode && baseColor.computeLuminance() < 0.1) {
      return Color.fromRGBO(
        30,
        30,
        35,
        1.0,
      ); // Very dark gray with slight blue tint
    }

    // For light mode, add a slight cream/sepia tone for less harshness than pure white
    if (!isDarkMode && baseColor.computeLuminance() > 0.9) {
      return Color.fromRGBO(
        252,
        250,
        245,
        1.0,
      ); // Off-white with slight warm tint
    }

    return baseColor;
  }

  // Check if the user has been reading for too long
  bool shouldShowBreakReminder(DateTime startTime, DateTime currentTime) {
    if (!_periodicalReminderEnabled) return false;

    // Calculate reading duration in minutes
    int readingDuration = currentTime.difference(startTime).inMinutes;

    // Show reminder if reading time exceeds the interval
    return readingDuration >= _readingTimerInterval;
  }
}
