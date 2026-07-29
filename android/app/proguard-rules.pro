## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication

## This app's own code.
## gradle.properties sets android.enableR8.fullMode=true, which optimises
## anything without a keep rule far more aggressively. Only io.flutter.** was
## kept, so the launcher's own classes were fair game -- and the method-channel
## plumbing added in v1.4.0 broke in release builds only, where every call that
## went through it stopped returning. Debug builds are not minified, which is
## why nothing caught it before release.
-keep class cz.smotrim.launcher.** { *; }
-keepclassmembers class cz.smotrim.launcher.** { *; }