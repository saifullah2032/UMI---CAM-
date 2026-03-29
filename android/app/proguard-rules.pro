# UMI 海 - CAM ProGuard/R8 Rules for Production Release

# Basic ProGuard rules for Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native method bridge classes
-keep class com.example.umi_cam.MainActivity { *; }
-keep class com.example.umi_cam.DualCameraManager { *; }
-keep class com.example.umi_cam.VideoComposer { *; }
-keep class com.example.umi_cam.HardwareBridge { *; }

# Preserve camera-related Android APIs
-keep class android.hardware.camera2.** { *; }
-keep class android.media.** { *; }
-keep class android.graphics.** { *; }

# Keep method channel implementations
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler *;
}

# Preserve annotations and reflection used by Flutter
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson/JSON serialization (if used in future)
-keepattributes Signature
-keep class com.google.gson.** { *; }

# Kotlin coroutines and reflection
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# MediaCodec and video encoding
-keep class android.media.MediaCodec { *; }
-keep class android.media.MediaFormat { *; }
-keep class android.media.MediaMuxer { *; }
-keep class android.media.AudioRecord { *; }

# Performance optimization: Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

# Optimize and obfuscate non-essential code
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile