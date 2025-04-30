import 'package:flutter/material.dart';
import '../services/eye_protection_service.dart';
import 'dart:async';

/// A widget that monitors pupillary response to detect eye strain
class PupillaryMonitoringWidget extends StatefulWidget {
  final Widget child;
  final Function(double fatigueLevel) onFatigueDetected;

  const PupillaryMonitoringWidget({
    Key? key,
    required this.child,
    required this.onFatigueDetected,
  }) : super(key: key);

  @override
  State<PupillaryMonitoringWidget> createState() =>
      _PupillaryMonitoringWidgetState();
}

class _PupillaryMonitoringWidgetState extends State<PupillaryMonitoringWidget> {
  late EyeProtectionService _eyeProtectionService;
  Timer? _checkTimer;
  bool _isInitialized = false;
  bool _cameraPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _eyeProtectionService = EyeProtectionService();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_eyeProtectionService.pupillaryMonitoringEnabled) {
      try {
        bool success = await _eyeProtectionService.startPupillaryMonitoring();
        setState(() {
          _isInitialized = success;
          _cameraPermissionDenied = !success;
        });

        if (success) {
          // Set up a timer to regularly check pupillary fatigue
          _checkTimer = Timer.periodic(
            const Duration(seconds: 30),
            (_) => _checkFatigue(),
          );
        }
      } catch (e) {
        setState(() {
          _isInitialized = false;
          _cameraPermissionDenied = true;
        });
      }
    }
  }

  void _checkFatigue() {
    double fatigueLevel = _eyeProtectionService.getPupillaryFatigueLevel();

    // If fatigue level is above 0.7 (70%), notify the parent
    if (fatigueLevel > 0.7) {
      widget.onFatigueDetected(fatigueLevel);
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _eyeProtectionService.stopPupillaryMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Camera preview for debugging (normally would be hidden)
        if (_isInitialized && false) // Set to true only for debugging
          Positioned(
            top: 10,
            right: 10,
            width: 100,
            height: 100,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.red)),
              child: const SizedBox(), // Placeholder for camera preview
            ),
          ),

        // Permission denied message
        if (_cameraPermissionDenied)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Camera permission needed for pupillary monitoring',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),

        // Fatigue indicator
        Positioned(top: 10, right: 10, child: _buildFatigueIndicator()),
      ],
    );
  }

  Widget _buildFatigueIndicator() {
    // Only show when monitoring is active
    if (!_isInitialized) return const SizedBox.shrink();

    double fatigueLevel = _eyeProtectionService.getPupillaryFatigueLevel();

    // Determine color based on fatigue level
    Color indicatorColor = Colors.green;
    if (fatigueLevel > 0.7) {
      indicatorColor = Colors.red;
    } else if (fatigueLevel > 0.4) {
      indicatorColor = Colors.orange;
    }

    return Opacity(
      opacity: 0.7,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_red_eye, color: indicatorColor, size: 16),
            const SizedBox(width: 4),
            Container(
              width: 30,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fatigueLevel,
                child: Container(
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
