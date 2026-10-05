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
# ── XLAT-SCR-002 — Dịch màn hình toàn hệ thống (ADR-0011) ─────────────
# Service/Activity được gọi qua tên lớp trong AndroidManifest + Intent, còn
# entrypoint Dart `screenTranslateMain` được tra bằng CHUỖI từ native: R8
# không thấy đường gọi nào nên có thể cắt mất. Giữ nguyên tên.
-keep class com.in4up.screentranslate.** { *; }
-keepclassmembers class com.in4up.screentranslate.ScreenTranslateService {
    public *;
}
