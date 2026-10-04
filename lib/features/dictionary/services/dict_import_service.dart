import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/dict_info.dart';
import 'dict_bundle_scanner.dart';
import 'dictionary_service.dart';

/// Service import file từ điển từ device (I4U18-DICT-001).
///
/// Hỗ trợ 2 nguồn: **thư mục** (walk đệ quy → scanner ghép set mdx+mdd+css)
/// và **nhiều file** (multi-file pick phẳng), qua 2 chế độ: link/index
/// (không copy dữ liệu lớn) hoặc import/copy vào app storage.
class DictImportService {
  /// Chọn và import file .mdx đơn lẻ (đường cũ — giữ tương thích).
  static Future<DictInfo?> pickAndImportMdx({
    void Function(double progress, String message)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx'],
    );

    if (result == null || result.files.isEmpty) return null;
    final mdxPath = result.files.single.path;
    if (mdxPath == null) return null;

    return await DictionaryService.instance.importMdx(
      mdxPath,
      onProgress: onProgress,
    );
  }

  /// Chọn THƯ MỤC chứa bộ từ điển (mdx + mdd + css/asset) → import theo
  /// [mode]. Trả outcome để UI báo phần import được + file phụ còn thiếu.
  static Future<DictImportOutcome> pickFolderAndImport(
    DictStorageMode mode, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null || dirPath.isEmpty) {
      return const DictImportOutcome(error: 'Chưa chọn thư mục');
    }

    onProgress?.call(0.05, 'Đang quét thư mục…');
    final files = await _walkFiles(dirPath);
    if (files.isEmpty) {
      return const DictImportOutcome(
        error: 'Thư mục rỗng hoặc app không đọc được (quyền truy cập). '
            'Thử chọn nhiều file thay vì thư mục.',
      );
    }

    return DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: files,
      rootPath: DictBundleScanner.normSep(dirPath),
      mode: mode,
      onProgress: onProgress,
    );
  }

  /// Chọn NHIỀU FILE (mdx + mdd + css chọn tay) → import theo [mode].
  ///
  /// File phụ thiếu (quên chọn .mdd/.css) được báo rõ trong outcome;
  /// từ điển vẫn dùng được ở chế độ giảm cấp.
  static Future<DictImportOutcome> pickFilesAndImport(
    DictStorageMode mode, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx', 'mdd', 'css'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return const DictImportOutcome(error: 'Chưa chọn file nào');
    }

    final paths = <String>[
      for (final f in result.files)
        if (f.path != null && f.path!.isNotEmpty) f.path!,
    ];
    if (paths.isEmpty) {
      return const DictImportOutcome(
        error: 'Không đọc được file (SAF). Thử chọn cả thư mục.',
      );
    }

    return DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: paths,
      rootPath: '',
      mode: mode,
      onProgress: onProgress,
    );
  }

  /// Walk đệ quy (giới hạn độ sâu + số file → không treo trên folder lớn
  /// kiểu Downloads nặng, vẫn bắt được mdx/mdd/css ở 1-2 tầng con).
  static Future<List<String>> _walkFiles(String rootPath) async {
    final out = <String>[];
    Future<void> walk(Directory dir, int depth) async {
      if (depth > 4 || out.length > 4000) return;
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (out.length > 4000) return;
          if (entity is Directory) {
            await walk(entity, depth + 1);
          } else if (entity is File) {
            out.add(entity.path);
          }
        }
      } catch (_) {
        // folder con không đọc được (quyền) → bỏ qua, không fail cả lượt.
      }
    }

    await walk(Directory(rootPath), 0);
    return out;
  }
}
