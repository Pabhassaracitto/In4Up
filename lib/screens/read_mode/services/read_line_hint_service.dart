// lib/screens/read_mode/services/read_line_hint_service.dart
//
// I4U18-READ-IPA-001 (F1) — hướng dẫn "chạm dòng / chạm từ" cho chế độ dòng.
//
// Vì sao cần: người mở .docx/.doc từ Word không có cách nào đoán được rằng
// CHẠM MỘT DÒNG sẽ bật lớp IPA của dòng đó, còn CHẠM MỘT TỪ thì đọc/tra từ.
// Trước đây không có tín hiệu nào cả → tính năng coi như không tồn tại.
//
// Luật hiển thị (thuần tuý, test được — không cần Flutter/prefs):
//   • chỉ nhắc khi tài liệu ĐANG mở là nguồn văn bản dạng dòng (docx/doc/
//     md/txt/json… — tức mọi nguồn file chữ, không phải PDF/web);
//   • chỉ nhắc TỰ ĐỘNG một lần cho mỗi tài liệu (khoá theo documentId) và
//     chỉ khi người dùng chưa từng bấm "Hiểu rồi";
//   • mở lại BẤT CỨ LÚC NÀO qua nút Trợ giúp trên thanh trên cùng
//     (`force: true` bỏ qua mọi khoá).
//
// Trạng thái "đã xem" lưu qua SharedPreferences, nhưng mọi quyết định hiển
// thị nằm trong [shouldAutoShowLineHint] để test không phải dựng plugin.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Đuôi file được coi là "nguồn chữ theo dòng" của tab Đọc.
///
/// `.doc` có trong danh sách để khi người dùng thử mở Word 97–2003 (app từ
/// chối đọc) ta vẫn không coi đó là lỗi của gợi ý này.
const Set<String> kLineModeTextExtensions = {
  'docx',
  'doc',
  'md',
  'markdown',
  'txt',
  'json',
  'lrc',
  'srt',
};

/// Đuôi file (viết thường, không có dấu chấm) của [path]; rỗng nếu không có.
String readSourceExtension(String? path) {
  if (path == null) return '';
  final name = path.split('/').last.split('\\').last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// True khi tài liệu đang mở là một file chữ theo dòng (Word/DOCX, md, txt…).
bool isLineModeTextSource(String? path) =>
    kLineModeTextExtensions.contains(readSourceExtension(path));

/// True khi nguồn là Word (.docx) — dùng để đổi câu nhắc cho đúng ngữ cảnh.
bool isWordSource(String? path) {
  final ext = readSourceExtension(path);
  return ext == 'docx' || ext == 'doc';
}

/// Quyết định có tự bật gợi ý hay không (thuần tuý).
///
/// [documentId] null (chưa có tài liệu) → không nhắc.
bool shouldAutoShowLineHint({
  required String? path,
  required String? documentId,
  required bool dismissedForever,
  required String? lastShownDocumentId,
  required bool hasLines,
}) {
  if (!hasLines) return false;
  if (documentId == null || documentId.isEmpty) return false;
  if (dismissedForever) return false;
  if (lastShownDocumentId == documentId) return false;
  return isLineModeTextSource(path);
}

/// Khoá "đã hiểu rồi" (persist) + khoá phiên theo tài liệu (bộ nhớ).
class ReadLineHintService {
  ReadLineHintService._();

  static final ReadLineHintService instance = ReadLineHintService._();

  static const String _keyDismissed = 'read_line_hint_dismissed_v1';

  bool _dismissedForever = false;
  bool _loaded = false;
  String? _lastShownDocumentId;

  bool get dismissedForever => _dismissedForever;
  String? get lastShownDocumentId => _lastShownDocumentId;

  /// Đọc cờ đã lưu (gọi được nhiều lần, chỉ đọc đĩa một lần).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissedForever = prefs.getBool(_keyDismissed) ?? false;
    } catch (e) {
      debugPrint('ReadLineHintService.ensureLoaded error: $e');
    }
  }

  void markShown(String documentId) => _lastShownDocumentId = documentId;

  /// "Hiểu rồi" — không tự bật nữa (vẫn mở lại được bằng nút Trợ giúp).
  Future<void> dismissForever() async {
    _dismissedForever = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDismissed, true);
    } catch (e) {
      debugPrint('ReadLineHintService.dismissForever error: $e');
    }
  }

  /// Chỉ dùng cho test: trả về trạng thái sạch.
  @visibleForTesting
  void resetForTest() {
    _dismissedForever = false;
    _loaded = false;
    _lastShownDocumentId = null;
  }
}
