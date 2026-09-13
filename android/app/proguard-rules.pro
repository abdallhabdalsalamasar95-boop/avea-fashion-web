# Flutter / Android (R8) shrink rules
#
# Keep this file minimal and add rules only when you encounter a
# release-only crash (NoClassDefFoundError, ClassNotFoundException, etc).

# Flutter engine + embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Flutter plugin packages (safe keep; can be tightened later)
-keep class io.flutter.plugins.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }

# Keep annotations (helps some libraries)
-keepattributes *Annotation*
