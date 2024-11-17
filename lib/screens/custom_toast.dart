import 'package:flutter/material.dart';
import 'dart:async';

class CustomToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void show(BuildContext context, String message) {
    // Cancel any existing timer
    _timer?.cancel();
    
    // Remove any existing toast
    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50.0,
        left: MediaQuery.of(context).size.width * 0.1,
        right: MediaQuery.of(context).size.width * 0.1,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    _timer?.cancel();
                    _overlayEntry?.remove();
                    _overlayEntry = null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);

    // Start new timer for auto-dismiss
    _timer = Timer(Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _timer = null;
    });
  }

  // Method to manually dismiss the toast
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}