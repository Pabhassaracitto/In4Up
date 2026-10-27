// YT-CLOUD-COPY-001 (#4 owner 2026-10-28) — "lưu luôn đám mây hay không".
//
// Vì sao phải có lớp này thay vì gọi thẳng `TextLibraryService`:
//  • `TextLibraryService.add()` cần **đăng nhập** và Firestore. Máy chưa đăng
//    nhập ⇒ phải nói rõ "chưa đăng nhập", không được im lặng coi như đã lưu.
//  • Người dùng bấm lại nút Tải nhiều lần ⇒ phải biết **đã lưu đúng phiên bản
//    phụ đề này chưa** (dấu vân tay nội dung), nếu không thư viện đám mây sẽ
//    đầy bản trùng của cùng một video.
//  • Dấu vân tay lưu ở `shared_preferences` nên kiểm tra được khi offline.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/text_library_service.dart';

class YtCloudCopyResult {
  const YtCloudCopyResult({required this.ok, this.reason});

  final bool ok;

  /// Mã máy (không phải câu tiếng Anh thô): `not_signed_in`,
  /// `unsupported_platform`, `failed`, `empty`.
  final String? reason;
}

class YtCloudCopyService {
  YtCloudCopyService._();
  static final YtCloudCopyService instance = YtCloudCopyService._();

  static String _key(String videoId) => 'yt_cloud_copy_fp_$videoId';

  /// Vân tay nội dung: đổi một chữ trong phụ đề ⇒ vân tay đổi ⇒ lưu bản mới.
  @visibleForTesting
  static String fingerprint(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    return sha1.convert(utf8.encode(normalized)).toString();
  }

  /// Phụ đề này đã được lưu lên đám mây chưa (đúng phiên bản).
  Future<bool> isUpToDate(String videoId, String content) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_key(videoId));
      return saved != null && saved == fingerprint(content);
    } catch (_) {
      return false;
    }
  }

  Future<void> _markSaved(String videoId, String content) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key(videoId), fingerprint(content));
    } catch (e) {
      debugPrint('YtCloudCopyService._markSaved: $e');
    }
  }

  /// Lưu phụ đề (dạng văn bản, mỗi dòng một câu) vào thư viện đám mây.
  ///
  /// [title] nên có tiền tố để người dùng nhận ra nguồn: UI đã truyền
  /// `"YouTube · <tên video>"`.
  Future<YtCloudCopyResult> save({
    required String videoId,
    required String title,
    required String content,
  }) async {
    final text = content.trim();
    if (text.isEmpty) {
      return const YtCloudCopyResult(ok: false, reason: 'empty');
    }
    final svc = TextLibraryService();
    if (!svc.isAvailable) {
      // Không có Firebase (desktop/Linux) hoặc chưa đăng nhập — hai nguyên
      // nhân khác nhau nhưng cùng một cách xử lý cho người dùng: báo rõ.
      return const YtCloudCopyResult(ok: false, reason: 'not_signed_in');
    }
    try {
      final entry = await svc.add(
        title: title,
        content: text,
        category: 'YouTube',
      );
      if (entry == null) {
        return const YtCloudCopyResult(ok: false, reason: 'failed');
      }
      await _markSaved(videoId, text);
      return const YtCloudCopyResult(ok: true);
    } catch (e) {
      debugPrint('YtCloudCopyService.save: $e');
      return const YtCloudCopyResult(ok: false, reason: 'failed');
    }
  }
}
