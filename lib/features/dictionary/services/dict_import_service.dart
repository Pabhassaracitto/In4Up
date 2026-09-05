import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;

import '../models/dict_info.dart';
import 'dictionary_service.dart';

/// Service orchestrate import flow: pick file → validate → import
class DictImportService {
  DictImportService._();

  /// Pick .mdx file từ device + import
  static Future<DictInfo?> pickAndImport({
    void Function(double progress, String message)? onProgress,
  }) async {
    // Pick .mdx file
    final result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['mdx'],
      dialogTitle: 'Chọn file từ điển MDX',
    );

    if (result == null || result.files.isEmpty) return null;
    final mdxFile = result.files.first;
    final mdxPath = mdxFile.path;
    if (mdxPath == null) return null;

    // Kiểm tra file tồn tại + size hợp lý
    final file = File(mdxPath);
    if (!file.existsSync()) return null;
    final sizeMB = file.lengthSync() / (1024 * 1024);
    if (sizeMB > 500) {
      onProgress?.call(1.0, 'File quá lớn (${sizeMB.toStringAsFixed(0)} MB). Giới hạn 500 MB.');
      return null;
    }
    if (sizeMB < 0.01) {
      onProgress?.call(1.0, 'File quá nhỏ, không phải MDX hợp lệ.');
      return null;
    }

    // Tìm file .mdd tương ứng (cùng tên, khác đuôi)
    String? mddPath;
    final mddCandidate = mdxPath.replaceAll('.mdx', '.mdd');
    if (File(mddCandidate).existsSync()) {
      mddPath = mddCandidate;
    }

    // Import
    return DictionaryService.instance.importMdx(
      mdxPath,
      mddPath: mddPath,
      onProgress: onProgress,
    );
  }

  /// Validate file MDX (kiểm tra header)
  static Future<String?> validateMdx(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return 'File không tồn tại';
      final bytes = await file.openRead(0, 8).first;
      if (bytes.length < 4) return 'File quá nhỏ';

      // Check MDX signature: 4 bytes length header
      final headerLen = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
      if (headerLen <= 0 || headerLen > 100000) {
        return 'Không phải file MDX hợp lệ';
      }
      return null; // OK
    } catch (e) {
      return 'Lỗi đọc file: $e';
    }
  }
}
