// YT-LR-002 / IN4-86 — Lấy phiên âm IPA cho bảng tra từ của chế độ YouTube.
//
// Bọc `CMUDictionaryService` (đã có sẵn trong `lib/features/shadowing/`) để
// màn YouTube không phải tự xử lý "chưa init". `initialize()` đã có guard
// `_initialized || _isLoading` nên gọi lặp an toàn.
//
// File nằm trong `services/` (không phải presentation file) — không đặt literal
// tiếng Việt ở đây.

import '../../shadowing/services/cmu_dictionary_service.dart';

class CmuPhoneticsService {
  /// Dictionary đã nạp xong hay chưa.
  static bool get isReady => CMUDictionaryService.isInitialized;

  /// Phiên âm dạng `/hɛloʊ/`, hoặc null nếu từ không có trong dictionary.
  static Future<String?> ipa(String word) async {
    if (!CMUDictionaryService.isInitialized) {
      await CMUDictionaryService.initialize();
    }
    final phones = CMUDictionaryService.getIPA(word);
    if (phones == null || phones.isEmpty) return null;
    return '/${phones.join('')}/';
  }

  /// Danh sách âm vị (đồng bộ) — chỉ dùng khi đã `isReady`.
  static List<String>? phones(String word) {
    if (!CMUDictionaryService.isInitialized) return null;
    return CMUDictionaryService.getIPA(word);
  }
}
