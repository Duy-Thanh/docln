import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Service that simulates human pupil adaptation to different light conditions
///
/// Based on research of pupillary light reflex, melanopsin photoreceptors, and circadian rhythm impact on
/// pupil dilation. This simulates how human eyes naturally adapt to changing light conditions.
class PupilAdaptationService {
  // Singleton instance
  static final PupilAdaptationService _instance =
      PupilAdaptationService._internal();
  factory PupilAdaptationService() => _instance;
  PupilAdaptationService._internal();

  // Pupil adaptation constants based on physiological research
  static const double _maxPupilDiameter =
      8.0; // mm, maximum dilation in darkness
  static const double _minPupilDiameter =
      2.0; // mm, minimum constriction in bright light
  static const Duration _initialAdaptationTime = Duration(
    milliseconds: 200,
  ); // Initial rapid response
  static const Duration _fullAdaptationTime = Duration(
    seconds: 30,
  ); // Complete dark/light adaptation

  // Current adaptation state
  double _currentPupilDiameter = 5.0; // mm, starting at mid-dilation
  double _targetPupilDiameter = 5.0; // mm, target based on ambient light
  double _adaptationRate = 0.8; // How quickly pupil adapts (0-1)
  bool _isAdapting = false;
  Timer? _adaptationTimer;

  // Melanopsin sensitivity parameters (affects non-visual light sensing)
  double _melanopsinSensitivity = 1.0; // Base sensitivity level
  DateTime? _lastBrightExposure; // Tracks last exposure to bright light
  DateTime? _lastBlueExposure; // Tracks last exposure to blue light

  // Getters
  double get currentPupilDiameter => _currentPupilDiameter;
  double get adaptationRate => _adaptationRate;
  double get adaptationProgress =>
      (_currentPupilDiameter - _minPupilDiameter) /
      (_maxPupilDiameter - _minPupilDiameter);
  double get melanopsinSensitivity => _melanopsinSensitivity;

  /// Simulate pupil response to ambient light level (0.0 = darkest, 1.0 = brightest)
  void respondToAmbientLight(
    double lightLevel, {
    bool containsBlueLight = true,
  }) {
    // Calculate target pupil diameter based on light level using logarithmic response
    // (Human eyes have logarithmic response to light intensity)
    final logResponse = -math.log(lightLevel.clamp(0.01, 1.0)) / math.log(10);
    _targetPupilDiameter =
        _minPupilDiameter +
        (_maxPupilDiameter - _minPupilDiameter) *
            (logResponse / 2.0).clamp(0.0, 1.0);

    // Record bright light exposure for melanopsin adaptation
    if (lightLevel > 0.6) {
      _lastBrightExposure = DateTime.now();
      // Blue light particularly affects melanopsin photoreceptors
      if (containsBlueLight) {
        _lastBlueExposure = DateTime.now();
        // Temporarily increase adaptation rate for blue light
        _adaptationRate = math.min(1.0, _adaptationRate + 0.1);
      }
    }

    // Start or continue adaptation process
    _startAdaptation();
  }

  /// Set sensitivity to light based on circadian rhythm and environmental conditions
  void adjustMelanopsinSensitivity(DateTime time) {
    final hour = time.hour;

    // Calculate base circadian sensitivity
    // Melanopsin is more sensitive in evening/night (after sunset)
    double circadianFactor;
    if (hour >= 18 || hour < 6) {
      // Evening/night (higher sensitivity to blue light)
      circadianFactor =
          1.2 + (hour >= 18 ? (hour - 18) * 0.05 : (hour + 6) * 0.05);
    } else {
      // Morning/day (normal sensitivity)
      circadianFactor = 1.0;
    }

    // Recent bright light exposure temporarily reduces sensitivity (adaptation)
    double exposureFactor = 1.0;
    if (_lastBrightExposure != null) {
      final minutesSinceExposure =
          DateTime.now().difference(_lastBrightExposure!).inMinutes;

      // Recovery curve after bright light exposure
      if (minutesSinceExposure < 30) {
        exposureFactor = 0.8 + (minutesSinceExposure / 30) * 0.2;
      }
    }

    // Recent blue light exposure has stronger and longer-lasting effect
    double blueLightFactor = 1.0;
    if (_lastBlueExposure != null) {
      final minutesSinceBlueExposure =
          DateTime.now().difference(_lastBlueExposure!).inMinutes;

      // Blue light has longer recovery period (affects melatonin production)
      if (minutesSinceBlueExposure < 60) {
        blueLightFactor = 0.7 + (minutesSinceBlueExposure / 60) * 0.3;
      }
    }

    // Calculate overall sensitivity
    _melanopsinSensitivity = circadianFactor * exposureFactor * blueLightFactor;
  }

  /// Calculate eye strain factor based on pupil state and adaptation
  /// Returns 0.0 (no strain) to 1.0 (high strain)
  double calculateEyeStrainFactor() {
    // Rapid changes in pupil diameter indicate strain
    final adaptationStrain =
        _isAdapting
            ? (_targetPupilDiameter - _currentPupilDiameter).abs() /
                (_maxPupilDiameter - _minPupilDiameter)
            : 0.0;

    // Long-term constriction (small pupil in bright conditions) is tiring
    final constrictionStrain =
        _currentPupilDiameter < 3.5 ? (3.5 - _currentPupilDiameter) / 1.5 : 0.0;

    // Calculate overall strain factor
    return (adaptationStrain * 0.4 + constrictionStrain * 0.6).clamp(0.0, 1.0);
  }

  /// Get ideal color temperature based on pupil state and time of day
  /// Returns color temperature in Kelvin
  double getIdealColorTemperature(DateTime time) {
    final hour = time.hour;

    // Base color temperature varies by time of day
    // Research: blue light is more disruptive in evening
    double baseTemperature;
    if (hour >= 19 || hour < 6) {
      // Evening/night: warmer light (lower color temperature)
      baseTemperature = 2700.0;
    } else if (hour >= 6 && hour < 10) {
      // Morning: moderate temperature
      baseTemperature = 4000.0;
    } else {
      // Daytime: cooler light (higher color temperature)
      baseTemperature = 5000.0;
    }

    // Adjust based on current pupil state
    // More constricted pupils (bright conditions) prefer warmer light
    if (_currentPupilDiameter < 4.0) {
      baseTemperature -= 300.0;
    }

    // Adjust based on melanopsin sensitivity
    // Higher sensitivity prefers warmer light to reduce impact
    baseTemperature -= (_melanopsinSensitivity - 1.0) * 500.0;

    return baseTemperature.clamp(1800.0, 6500.0);
  }

  /// Get recommended contrast reduction based on pupil state and strain
  /// Returns recommended contrast reduction factor (0.0 to 0.5)
  double getRecommendedContrastReduction() {
    // Calculate base recommendation based on pupil diameter
    // Smaller pupils (bright conditions) need more contrast reduction
    double baseReduction = 0.15;

    // Modify based on pupil size
    if (_currentPupilDiameter < 4.0) {
      // More constricted pupil in bright conditions needs more reduction
      baseReduction += (4.0 - _currentPupilDiameter) * 0.05;
    } else if (_currentPupilDiameter > 6.0) {
      // More dilated pupil in dark conditions needs less reduction
      baseReduction -= (_currentPupilDiameter - 6.0) * 0.03;
    }

    // If high strain detected, increase contrast reduction
    final strainFactor = calculateEyeStrainFactor();
    baseReduction += strainFactor * 0.1;

    return baseReduction.clamp(0.05, 0.5);
  }

  /// Get recommended blue light filter level based on pupil state and time
  /// Returns recommended blue light filter level (0.0 to 0.7)
  double getRecommendedBlueFilterLevel(DateTime time) {
    final hour = time.hour;

    // Base level varies by time of day
    double baseLevel;
    if (hour >= 19 || hour < 6) {
      // Evening/night: higher blue filter
      baseLevel = 0.4 + (hour >= 19 ? math.min(0.2, (hour - 19) * 0.04) : 0.0);
    } else if (hour >= 6 && hour < 10) {
      // Morning: moderate filter
      baseLevel = 0.25;
    } else {
      // Daytime: lower filter
      baseLevel = 0.2;
    }

    // Adjust based on melanopsin sensitivity
    baseLevel *= _melanopsinSensitivity;

    // Dilated pupils are more sensitive to blue light
    if (_currentPupilDiameter > 5.0) {
      baseLevel += (_currentPupilDiameter - 5.0) * 0.05;
    }

    return baseLevel.clamp(0.0, 0.7);
  }

  // Start the adaptation simulation
  void _startAdaptation() {
    if (_adaptationTimer != null) {
      _adaptationTimer!.cancel();
    }

    _isAdapting = true;

    // Initial fast adaptation (initial pupillary light reflex)
    _adaptationTimer = Timer.periodic(_initialAdaptationTime, (timer) {
      // Calculate adaptation step size
      final step =
          (_targetPupilDiameter - _currentPupilDiameter) *
          _adaptationRate *
          0.2;

      // Update current diameter
      _currentPupilDiameter += step;

      // Check if adaptation is complete
      if ((_targetPupilDiameter - _currentPupilDiameter).abs() < 0.1) {
        _currentPupilDiameter = _targetPupilDiameter;
        _isAdapting = false;
        timer.cancel();
      }
    });
  }

  void dispose() {
    _adaptationTimer?.cancel();
  }
}
