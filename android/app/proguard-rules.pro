# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Your app
-keep class com.cyberdaystudios.apps.docln.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }

# Common Android
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# For native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep setters in Views so that animations can still work.
-keepclassmembers public class * extends android.view.View {
    void set*(***);
    *** get*();
}

# Performance Optimizations (Safe additions)
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification

# Remove debug logs in release (Safe)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}

# Keep Parcelables (Safe - for data transfer)
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Memory optimizations (Safe)
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}

# Safe class loading optimizations
-keepattributes Signature
-keepattributes Exceptions

# Remove kotlin metadata annotations (Safe - reduces size)
-dontwarn kotlin.reflect.jvm.internal.**

# Firebase Performance (ignore missing classes)
-dontwarn com.google.firebase.perf.**
-dontwarn com.google.firebase.perf.network.FirebasePerfUrlConnection

# --- Firebase Core & Messaging (critical rules) ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep Firebase initialization provider
-keepnames class com.google.firebase.provider.FirebaseInitProvider

# Keep Firebase Messaging Service and related components
-keep class com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class com.google.firebase.iid.FirebaseInstanceIdReceiver { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# Keep all classes annotated with @Keep
-keep @com.google.firebase.annotations.Keep class * { *; }
-keepclassmembers class * {
    @com.google.firebase.annotations.Keep *;
}

# Keep attributes for Crashlytics / Analytics stack traces (optional but safe)
# -keepattributes SourceFile,LineNumberTable

# XML handling (fix for R8 missing classes)
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**
-dontwarn java.beans.**
-dontwarn javax.xml.**
-keep class javax.xml.stream.** { *; }

# WebView and related classes
-keep class android.webkit.** { *; }
-keep class androidx.webkit.** { *; }

# Wireguard flutter
-keep class billion.group.wireguard_flutter.** { *; }

# Keep all classes that might be referenced via reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
