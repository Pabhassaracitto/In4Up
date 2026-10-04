// lib/features/vocab_image/vocab_media_import.dart
//
// LOTTIE-001 — Tải HÀNG LOẠT ảnh/animation về app storage SAU import CSV
// (flow "auto-download"), tôn trọng setting "chỉ tải khi cần" (lazy).
//
// Offline-first giống hệ ảnh tĩnh: import xong là học được không cần mạng.
// Nếu user BẬT lazy (Cài đặt ảnh): giữ nguyên URL — VocabularyMediaWidget
// tự materialize ở lần xem đầu tiên.

import 'package:flutter/foundation.dart';

import '../../providers/vocabulary_provider.dart';
import 'vocab_image_api_config.dart';
import 'vocab_image_service.dart';

/// Một URL media (http) chờ tải về local + id entry nhận path mới.
class VocabMediaPending {
  final String wordId;
  final String url;
  const VocabMediaPending({required this.wordId, required this.url});
}

class VocabMediaMaterializer {
  VocabMediaMaterializer._();

  /// Chống chồng phiên khi user import nhiều lượt liên tiếp.
  static bool _running = false;

  /// Tải tuần tự (không bắn đồng loạt — giữ UI mượt + tránh rate limit).
  /// Lazy setting bật → bỏ qua toàn bộ (lần xem đầu widget tự tải).
  static Future<void> materializeAll(
    VocabularyProvider provider,
    List<VocabMediaPending> items,
  ) async {
    if (items.isEmpty || _running) return;
    final cfg = await VocabImageApiConfig.instance.load();
    if (cfg.lazyDownload) {
      debugPrint(
          'LOTTIE-001: lazyDownload bật → giữ ${items.length} URL, tải khi xem.');
      return;
    }
    _running = true;
    var ok = 0;
    try {
      for (final item in items) {
        try {
          final path = await VocabImageService.instance.saveFromUrl(item.url);
          if (path != null && path.isNotEmpty) {
            // Chỉ thay URL khi entry vẫn đang giữ ĐÚNG url này (user có thể
            // đã đổi minh họa tay trong lúc tải → không đè).
            final current =
                provider.findById(item.wordId)?.imageUrl ?? '';
            if (current.trim() == item.url.trim()) {
              provider.updateImageUrl(item.wordId, path);
              ok++;
            }
          }
        } catch (e) {
          debugPrint('LOTTIE-001 materialize lỗi (${item.url}): $e');
        }
        // Nhịp nhỏ giữa các lượt tải — tránh dồn network/disk sau import lớn.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      debugPrint('LOTTIE-001: materialize xong $ok/${items.length} media.');
    } finally {
      _running = false;
    }
  }
}
