// lib/screens/tools/youglish/youglish_prefs.dart
//
// PRON-001 (ADR-0015 D5) — ngôn ngữ / accent / kill-switch của YouGlish có ĐÚNG
// MỘT nơi lưu. Trước đây mỗi điểm vào giữ state riêng trong `setState` nên
// "đang xem tiếng Anh-US ở tool, mở từ đã lưu lại quay về mặc định".
//
// Mẫu: `lib/features/cabin/services/cabin_session_settings.dart` (không dựng
// ChangeNotifier cho 4 giá trị này — xem ADR-0015 mục "Loại bỏ").

import 'package:shared_preferences/shared_preferences.dart';

import 'youglish_config.dart';

class YouGlishPrefs {
  /// Khóa PRON-001/002. `true` = mọi điểm vào YouGlish hiện; `false` = ẩn toàn
  /// bộ điểm vào trong hàng "Phát âm" (owner dùng khi YouGlish từ chối cấp
  /// quyền — ADR-0015 D2). Đọc ở PRON-002 (nơi đầu tiên có hàng "Phát âm").
  static const String keyEnabled = 'youglish.enabled';
  static const String keyLanguage = 'youglish.lang';
  static const String keyAccent = 'youglish.accent';

  /// PRON-003 mới ĐỔI mặc định sang `false` (tắt autoplay cho toàn app, có chủ
  /// đích). PRON-001 giữ `true` = đúng hành vi cũ của cả 2 điểm vào.
  static const String keyAutoplay = 'youglish.autoplay';

  static Future<YouGlishPrefs> load() async {
    final sp = await SharedPreferences.getInstance();
    return YouGlishPrefs._(
      enabled: sp.getBool(keyEnabled) ?? true,
      language: YouGlishLanguage.fromCode(sp.getString(keyLanguage)) ??
          YouGlishLanguage.english,
      accent: YouGlishAccent.fromCode(sp.getString(keyAccent)) ??
          YouGlishAccent.us,
      autoplay: sp.getBool(keyAutoplay) ?? true,
    );
  }

  const YouGlishPrefs._({
    required this.enabled,
    required this.language,
    required this.accent,
    required this.autoplay,
  });

  final bool enabled;
  final YouGlishLanguage language;
  final YouGlishAccent accent;
  final bool autoplay;

  /// Accent chỉ có nghĩa với English — cùng quy tắc `YouGlishUrl.build` dùng.
  YouGlishAccent? get accentForLanguage =>
      language == YouGlishLanguage.english ? accent : null;

  Future<void> setLanguage(YouGlishLanguage value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(keyLanguage, value.code);
  }

  Future<void> setAccent(YouGlishAccent value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(keyAccent, value.code);
  }

  Future<void> setAutoplay(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(keyAutoplay, value);
  }

  Future<void> setEnabled(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(keyEnabled, value);
  }
}
