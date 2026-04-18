# Google ML Kit Text Recognition ProGuard Rules
# These rules prevent R8 from failing when the Latin-only version is used
# but the plugin code references other languages (Chinese, Devanagari, etc.)

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# General ML Kit keeps
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
