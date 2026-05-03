# Giữ lại code cho Flutter và các plugin
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.** { *; }

# Quan trọng: Giữ lại thư viện Audio (just_audio, v.v.)
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# Tránh xóa các class được gọi qua reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}