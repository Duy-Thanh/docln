import 'package:flutter/material.dart';

class CustomToast {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, String message) {
    // Remove any existing toast
    _overlayEntry?.remove();
    _overlayEntry = null; // Clear the reference

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
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _overlayEntry?.remove(); // Safely remove the overlay entry
                    _overlayEntry = null; // Clear the reference
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);

    // Remove the toast after a delay
    Future.delayed(Duration(seconds: 3), () {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null; // Clear the reference
      }
    });
  }
}