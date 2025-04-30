import 'package:flutter/material.dart';
import '../services/eye_protection_service.dart';
import 'dart:async';

/// A widget that provides eye protection overlays and controls
class EyeProtectionOverlay extends StatefulWidget {
  final Widget child;
  final DateTime readingStartTime;
  final bool showControls;

  const EyeProtectionOverlay({
    Key? key,
    required this.child,
    required this.readingStartTime,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<EyeProtectionOverlay> createState() => _EyeProtectionOverlayState();
}

class _EyeProtectionOverlayState extends State<EyeProtectionOverlay> {
  late EyeProtectionService _eyeProtectionService;
  late Timer _reminderTimer;
  DateTime _currentTime = DateTime.now();
  bool _showBreakReminder = false;
  int _secondsLeft = 0;
  bool _isTimerActive = false;

  @override
  void initState() {
    super.initState();
    _eyeProtectionService = EyeProtectionService();

    // Initialize reminder timer
    _startReminderTimer();
  }

  void _startReminderTimer() {
    // Cancel any existing timer
    if (_isTimerActive) {
      _reminderTimer.cancel();
    }

    // Only set up timer if reminders are enabled
    if (_eyeProtectionService.periodicalReminderEnabled) {
      _isTimerActive = true;

      // Calculate time until next reminder
      final int reminderIntervalMillis =
          _eyeProtectionService.readingTimerInterval * 60 * 1000;
      final int elapsedMillis =
          DateTime.now().difference(widget.readingStartTime).inMilliseconds;

      // Calculate next reminder time (considering already elapsed time)
      final int millisUntilReminder =
          reminderIntervalMillis - (elapsedMillis % reminderIntervalMillis);

      // Set up timer for the next reminder
      _reminderTimer = Timer(
        Duration(milliseconds: millisUntilReminder),
        _showReminderDialog,
      );
    }
  }

  void _showReminderDialog() {
    // Only show reminder if feature is enabled
    if (!_eyeProtectionService.periodicalReminderEnabled) {
      return;
    }

    setState(() {
      _showBreakReminder = true;
      _secondsLeft = 20; // 20-second break
    });

    // Start countdown timer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _showBreakReminder = false;
        });
        // Restart the reminder timer for the next interval
        _startReminderTimer();
      }
    });
  }

  void _dismissReminder() {
    setState(() {
      _showBreakReminder = false;
    });
    // Restart the reminder timer
    _startReminderTimer();
  }

  @override
  void dispose() {
    if (_isTimerActive) {
      _reminderTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the overlay color based on the protection settings
    final Color overlayColor = _eyeProtectionService.getOverlayColor();

    return Stack(
      children: [
        // The main content
        widget.child,

        // Eye protection color overlay
        if (_eyeProtectionService.eyeProtectionEnabled)
          Positioned.fill(
            child: IgnorePointer(child: Container(color: overlayColor)),
          ),

        // Break reminder overlay
        if (_showBreakReminder)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Prevents taps from going through
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Time for an Eye Break!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Look away from your screen at something about 20 feet away for 20 seconds.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CircularProgressIndicator(
                          value: _secondsLeft / 20,
                          strokeWidth: 5,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_secondsLeft seconds left',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _dismissReminder,
                          child: const Text('Skip Break'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
