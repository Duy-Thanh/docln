package com.cyberdaystudios.apps.docln

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager
import android.view.View
import android.view.ViewTreeObserver
import android.os.Build
import android.view.WindowInsetsController
import android.graphics.PixelFormat
import android.content.ComponentCallbacks2
import android.content.Context
import android.app.ActivityManager
import android.util.Log
import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.plugin.common.MethodChannel
import com.cyberdaystudios.apps.docln.performance.PerformanceManager

class MainActivity: FlutterActivity(), ComponentCallbacks2 {
    private val memoryThreshold = 0.8
    private val PERFORMANCE_CHANNEL = "com.cyberdaystudios.apps.docln/performance"
    private var isPerformanceInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Remove the Flutter splash screen
        intent.putExtra("background_mode", "transparent")
        intent.putExtra("enable_state_restoration", false)
        
        super.onCreate(savedInstanceState)

        // Enable hardware acceleration
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        // Optimize window for performance
        window.apply {
            // Better color format for performance
            setFormat(PixelFormat.RGBA_8888)
            
            // Keep screen on while app is active
            addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            
            // Enable hardware-accelerated rendering
            attributes.flags = attributes.flags or 
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
                
            // Optimize window drawing
            setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        }

        // Modern system UI handling
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.apply {
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
        
        // Make window background transparent
        window.setBackgroundDrawableResource(android.R.color.transparent)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Optimize Android 12+ splash screen exit
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }

        // Initialize PerformanceManager
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val channel = MethodChannel(messenger, PERFORMANCE_CHANNEL)
            PerformanceManager.initialize(this, channel)
        }

        // Initialize memory management
        initializeMemoryManagement()
    }

    private fun initializeMemoryManagement() {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        
        // Monitor memory usage periodically
        Thread {
            while (!isFinishing) {
                activityManager.getMemoryInfo(memoryInfo)
                val percentAvailable = memoryInfo.availMem.toDouble() / memoryInfo.totalMem.toDouble()
                
                if (percentAvailable < memoryThreshold) {
                    runOnUiThread {
                        performMemoryCleanup()
                    }
                }
                Thread.sleep(5000) // Check every 5 seconds
            }
        }.start()
    }

    private fun performMemoryCleanup() {
        // Clear any caches
        flutterEngine?.let { engine ->
            // Suggest garbage collection
            System.gc()
            
            // Log memory state in debug builds
            if (BuildConfig.DEBUG) {
                val runtime = Runtime.getRuntime()
                val usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1024
                val maxMemory = runtime.maxMemory() / 1024
                Log.d("Memory", "Used Memory: $usedMemory KB / Max Memory: $maxMemory KB")
            }
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        when (level) {
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL,
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW -> {
                performMemoryCleanup()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-enable hardware acceleration if needed
        if (!window.attributes.flags.and(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED).equals(0)
        ) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
            )
        }
    }

    override fun onPause() {
        super.onPause()
        // Clear any flags that might impact performance when app is in background
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onLowMemory() {
        super.onLowMemory()
        performMemoryCleanup()
    }

    override fun onDestroy() {
        try {
            if (isPerformanceInitialized) {
                PerformanceManager.cleanup()
                isPerformanceInitialized = false
            }
            super.onDestroy()
        } catch (e: Exception) {
            Log.e("MainActivity", "Error in onDestroy: ${e.message}")
        }
    }
}