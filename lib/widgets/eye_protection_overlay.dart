import 'package:flutter/material.dart';
import '../services/eye_protection_service.dart';
import 'dart:async';
import 'dart:ui';

/// A widget that provides eyeCARE™ protection overlays and controls
class EyeProtectionOverlay extends StatefulWidget {
  final Widget child;
  final DateTime readingStartTime;
  final bool showControls;
  final double? ambientLightLevel;

  const EyeProtectionOverlay({
    Key? key,
    required this.child,
    required this.readingStartTime,
    this.showControls = true,
    this.ambientLightLevel,
  }) : super(key: key);

  @override
  State<EyeProtectionOverlay> createState() => _EyeProtectionOverlayState();
}

class _EyeProtectionOverlayState extends State<EyeProtectionOverlay>
    with SingleTickerProviderStateMixin {
  late EyeProtectionService _eyeProtectionService;
  late Timer _reminderTimer;
  bool _showBreakReminder = false;
  int _secondsLeft = 0;
  bool _isTimerActive = false;
  late StreamSubscription _serviceListener;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _eyeProtectionService = EyeProtectionService();

    // Set up animation controller for smoother transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Listen for service changes
    _serviceListener = _eyeProtectionService.reminderStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Initialize reminder timer
    _startReminderTimer();
  }

  void _startReminderTimer() {
    // Cancel any existing timer
    if (_isTimerActive) {
      _reminderTimer.cancel();
    }

    // Only set up timer if reminders are enabled
    if (_eyeProtectionService.periodicalReminderEnabled &&
        _eyeProtectionService.eyeProtectionEnabled &&
        _eyeProtectionService.readingTimerInterval > 0) {
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
    if (!_eyeProtectionService.periodicalReminderEnabled ||
        !_eyeProtectionService.eyeProtectionEnabled) {
      _startReminderTimer(); // Restart timer for next check
      return;
    }

    setState(() {
      _showBreakReminder = true;
      _secondsLeft = 20; // 20-second break
    });

    // Start countdown timer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _showBreakReminder = false;
          });
        }
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

  void _extendBreak() {
    setState(() {
      _secondsLeft = 30; // Extend to 30 seconds
    });
  }

  @override
  void dispose() {
    if (_isTimerActive) {
      _reminderTimer.cancel();
    }
    _serviceListener.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EyeProtectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If ambient light level changed significantly, update the state
    if (widget.ambientLightLevel != oldWidget.ambientLightLevel &&
        widget.ambientLightLevel != null &&
        _eyeProtectionService.adaptiveBrightnessEnabled) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the overlay color based on the protection settings
    final Color overlayColor = _eyeProtectionService.getOverlayColor();

    // Adjust overlay based on ambient light if available
    final double overlayOpacity =
        widget.ambientLightLevel != null &&
                _eyeProtectionService.adaptiveBrightnessEnabled
            ? overlayColor.opacity *
                (_eyeProtectionService.getAdaptiveBrightness(
                  1.0,
                  DateTime.now(),
                  widget.ambientLightLevel,
                ))
            : overlayColor.opacity;

    final Color adjustedOverlayColor = overlayColor.withOpacity(overlayOpacity);

    return Stack(
      children: [
        // The main content
        widget.child,

        // Eye protection color overlay with fade animation
        if (_eyeProtectionService.eyeProtectionEnabled)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: IgnorePointer(
                child: Container(color: adjustedOverlayColor),
              ),
            ),
          ),

        // Break reminder overlay
        if (_showBreakReminder)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Prevents taps from going through
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
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
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 80,
                                width: 80,
                                child: CircularProgressIndicator(
                                  value: _secondsLeft / 20,
                                  strokeWidth: 5,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const Icon(Icons.remove_red_eye, size: 36),
                            ],
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: 'eye',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                TextSpan(
                                  text: 'CARE™',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: ' Break Time!'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Look away from your screen at something about 20 feet away for 20 seconds.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_secondsLeft seconds left',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _dismissReminder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade300,
                                  foregroundColor: Colors.black87,
                                ),
                                child: const Text('Skip'),
                              ),
                              ElevatedButton(
                                onPressed: _extendBreak,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                child: const Text('Extend +10s'),
                              ),
                            ],
                          ),
                        ],
                      ),
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
