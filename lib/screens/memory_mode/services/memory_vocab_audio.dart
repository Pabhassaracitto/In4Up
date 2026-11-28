// lib/screens/memory_mode/services/memory_vocab_audio.dart
//
// AUDIT v1.30.1 (mục 8) — «SRS chưa có âm thanh từ vựng: icon loa tự đọc từ
// vựng; chạm vào nó thì tắt tự động đọc».
//
// Trước đây vườn nhớ (SRS) hoàn toàn im lặng: không có loa, không có cách
// nghe phát âm của từ đang ôn, dù mọi bề mặt khác (từ điển, PDF wordlist, tab
// Đọc) đều đã có `TtsService`.
//
// Hành vi được chốt ở đây (một chỗ, test được trên host VM nếu cần tách tiếp):
//   • Bấm loa lần đầu  → BẬT tự đọc + đọc NGAY từ đó (một hành động = hai
//     điều người dùng muốn, không phải bấm thêm lần nữa).
//   • Bấm loa lần nữa  → TẮT tự đọc + dừng audio đang phát (không để tiếng
//     chạy tiếp sau khi đã bảo tắt).
//   • Tự đọc = mỗi lần một thẻ được chọn (chạm thẻ) hoặc khi lật thẻ, đọc
//     đúng từ của thẻ đó — không đọc hàng loạt, không đọc khi cuộn.
//
// Trạng thái lưu ở SharedPreferences (khoá riêng, không đụng `MemoryItem`):
// người dùng đã bật thì lần mở app sau vẫn bật.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/tts/tts_service.dart';

/// Khoá SharedPreferences cho công tắc «tự đọc từ vựng».
const String kMemoryVocabAutoReadPrefKey = 'memory_vocab_auto_read';

/// Ngôn ngữ dùng để đọc từ vựng.
///
/// `MemoryItem` không có trường `language`, và vườn nhớ chứa từ của TÀI LIỆU
/// đang học (Anh/Trung/Nhật/Hàn/… tuỳ người dùng). Vì vậy luôn để `auto`:
/// `TtsService` tự khớp giọng theo `matchVoiceLanguage: true` — ghim `vi-VN`
/// sẽ đọc từ tiếng Nhật bằng giọng Việt, tệ hơn nhiều so với để engine chọn.
const String kMemoryVocabSpeakLanguage = 'auto';

/// Đọc (nói) một mục từ vựng bằng TTS.
///
/// Không ném lỗi ra UI: máy thiếu engine TTS chỉ im lặng — thẻ nhớ vẫn dùng
/// được, đây là tiện ích phụ.
Future<void> speakMemoryVocab(String word) async {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return;
  try {
    await TtsService().speak(
      trimmed,
      language: kMemoryVocabSpeakLanguage,
      matchVoiceLanguage: true,
    );
  } catch (e) {
    debugPrint('Memory vocab audio: $e');
  }
}

/// Công tắc «tự đọc từ vựng» — một `ValueNotifier` dùng chung cho mọi thẻ
/// trong vườn nhớ + danh sách.
///
/// Vì sao không đặt trong `MemoryController`: controller quản lý DỮ LIỆU thẻ
/// (FSRS, stage, filter) và được tạo/huỷ theo tab; công tắc này phải sống
/// xuyên tab (bấm loa ở vườn → mở danh sách vẫn còn bật) và chỉ tốn một
/// SharedPreferences read lúc khởi động.
class MemoryVocabAudio {
  MemoryVocabAudio._();

  static final MemoryVocabAudio instance = MemoryVocabAudio._();

  final ValueNotifier<bool> autoRead = ValueNotifier<bool>(false);

  bool _loaded = false;

  /// Đọc trạng thái đã lưu (gọi 1 lần khi màn Nhớ dựng).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      autoRead.value = prefs.getBool(kMemoryVocabAutoReadPrefKey) ?? false;
    } catch (e) {
      debugPrint('MemoryVocabAudio load: $e');
    }
  }

  /// Bật/tắt tự đọc. Tắt ⇒ dừng luôn audio đang phát.
  Future<void> setAutoRead(bool value) async {
    if (autoRead.value == value) return;
    autoRead.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kMemoryVocabAutoReadPrefKey, value);
    } catch (e) {
      debugPrint('MemoryVocabAudio save: $e');
    }
    if (!value) {
      try {
        await TtsService().stop();
      } catch (_) {
        // Engine chưa sẵn sàng — không có gì đang phát.
      }
    }
  }

  /// Bấm icon loa: bật/tắt tự đọc, và khi BẬT thì đọc ngay [word] để phản hồi
  /// tức thì (một lần chạm phải nghe được gì đó).
  Future<void> toggleFor({required String word}) async {
    final next = !autoRead.value;
    await setAutoRead(next);
    if (next) await speakMemoryVocab(word);
  }
}
