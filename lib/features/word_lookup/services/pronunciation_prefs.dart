// lib/features/word_lookup/services/pronunciation_prefs.dart
//
// PRON-002 — phần lưu trữ RẤT NHỎ của "nguồn phát âm": người dùng chọn nguồn
// nào thì app nhớ nguồn đó (chỉ vậy — không thêm 7 key như prompt Gemini).
//
// Vì sao không để trong `YouGlishPrefs` (lib/screens/tools/youglish/): nguồn
// phát âm là khái niệm của word_lookup, YouGlish chỉ là một nguồn (ADR-0015
// D1). `YouGlishPrefs` vẫn là CHỦ DUY NHẤT của `youglish.*` — nhất là kill-
// switch `youglish.enabled` (ADR-0015 D2); file này không được định nghĩa lại
// key đó.

import 'package:shared_preferences/shared_preferences.dart';

import '../pronunciation_source.dart';

class PronunciationPrefs {
  PronunciationPrefs._();

  static const String keySource = 'pronunciation.source';

  static PronunciationSource? _lastSource;

  /// `null` = người dùng chưa chọn ⇒ dùng `PronunciationSourcePolicy.preferredOrder`.
  static PronunciationSource? get lastSource => _lastSource;

  static Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _lastSource = PronunciationSource.fromPrefCode(sp.getString(keySource));
    } catch (_) {
      // Trạng thái suy giảm: coi như chưa chọn gì (policy sẽ tự chọn bậc đầu
      // tiên còn khả dụng) — không ném, không chặn nút loa.
      _lastSource = null;
    }
  }

  static Future<void> setLastSource(PronunciationSource source) async {
    _lastSource = source;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(keySource, source.prefCode);
    } catch (_) {/* best effort */ }
  }
}
