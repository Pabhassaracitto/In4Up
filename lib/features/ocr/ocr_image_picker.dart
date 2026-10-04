// lib/features/ocr/ocr_image_picker.dart
//
// Seam mỏng bọc `file_picker` cho OCR (ADR-0009 · KANBAN OCR-001).
//
// Lý do tách riêng: OcrService phải unit-test được phần logic thuần
// (normalizeOcrText, guard nền tảng) mà KHÔNG cần plugin native. Gom mọi
// lời gọi picker vào đây → test chỉ cần gán `OcrImagePicker.pick = ...`.
//
// Dùng `file_picker` ĐÃ CÓ trong pubspec (^11.0.2) — cùng API tĩnh
// `FilePicker.pickFiles(type: FileType.image)` mà `vocab_image_service.dart`
// đang dùng → KHÔNG thêm dependency mới cho việc chọn ảnh.
//
// Ghi chú quyền: trên iOS, file_picker mở PHPicker (iOS 14+) nên KHÔNG cần
// NSPhotoLibraryUsageDescription. Trên Android, READ_MEDIA_IMAGES đã có sẵn
// trong AndroidManifest.xml.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Hàm chọn ảnh — khai báo để test có thể thay thế.
typedef OcrPickImagesFn = Future<List<String>> Function({
  bool allowMultiple,
});

class OcrImagePicker {
  OcrImagePicker._();

  /// Implementation thật (file_picker). Test gán đè hàm này.
  static OcrPickImagesFn pick = _pickWithFilePicker;

  /// Chọn ảnh từ máy → danh sách đường dẫn (rỗng nếu user hủy).
  static Future<List<String>> pickImages({bool allowMultiple = true}) {
    return pick(allowMultiple: allowMultiple);
  }

  static Future<List<String>> _pickWithFilePicker({
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: allowMultiple,
      );
      if (result == null || result.files.isEmpty) return const <String>[];
      // Trên web/Android SAF, `path` có thể null nhưng `bytes` có — OCR cần
      // đường dẫn file thật cho InputImage.fromFilePath, nên bỏ qua mục null.
      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      return paths;
    } catch (e) {
      debugPrint('❌ OcrImagePicker: $e');
      return const <String>[];
    }
  }
}
