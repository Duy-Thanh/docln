import 'package:flutter/material.dart';
import 'dart:async';

class CustomToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void _cleanup() {
    _timer?.cancel();
    _timer = null;
    try {
      if (_overlayEntry != null) {
        // Check mounted if available, or just try-catch
        _overlayEntry?.remove();
      }
    } catch (e) {
      // Ignore: already removed
    }
    _overlayEntry = null;
  }

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _cleanup();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50.0,
        left: MediaQuery.of(context).size.width * 0.1,
        right: MediaQuery.of(context).size.width * 0.1,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _cleanup,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Insert new overlay safely
    try {
      Overlay.of(context).insert(_overlayEntry!);

      // Start new timer
      _timer = Timer(duration, _cleanup);
    } catch (e) {
      // If context is invalid or overlay not found
      _cleanup();
    }
  }

  // Method to manually dismiss the toast
  static void dismiss() {
    _cleanup();
  }
}
