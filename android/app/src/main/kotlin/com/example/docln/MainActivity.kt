package com.cyberdaystudios.apps.docln

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager
import android.view.View

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Remove the Flutter splash screen
        intent.putExtra("background_mode", "transparent")
        intent.putExtra("enable_state_restoration", false)
        
        super.onCreate(savedInstanceState)

        // Hide system bars
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        
        // Make window background transparent
        window.setBackgroundDrawableResource(android.R.color.transparent)
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Disable the Android 12+ splash screen
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
    }
}