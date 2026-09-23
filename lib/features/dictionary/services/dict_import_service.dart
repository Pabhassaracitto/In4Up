// lib/features/dictionary/services/dict_import_service.dart
// Chọn file .mdx (+ .mdd) từ thiết bị → import vào thư viện từ điển.
//
// ⚠️ Hai bẫy đã fix ở đây (nguyên nhân "chọn file xong vẫn hiện 'Chưa có từ
// điển nào'"):
//
// 1. `FileType.custom` + `allowedExtensions: ['mdx']` — `mdx` KHÔNG có trong
//    `MimeTypeMap` của Android ⇒ plugin lọc ra danh sách MIME rỗng ⇒ trình
//    chọn file hiện trống / trả về null mà không báo lỗi. Fix: mở picker
//    `FileType.any` rồi tự lọc đuôi `.mdx` / `.mdd` ở Dart (chắc chắn chạy
//    mọi phiên bản Android + desktop).
// 2. `file_picker` trả path trong CACHE (`/cache/file_picker/<ts>/…`) — hệ
//    điều hành có thể xoá bất kỳ lúc nào (nhất là khi import file lớn mất
//    vài phút) ⇒ parse dang dở mất file ⇒ 0 entry, không báo lỗi. Fix:
//    sao chép file vào `dictionaries/staging/` (bộ nhớ riêng của app) TRƯỚC
//    khi parse, parse xong mới xoá bản staging.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/dict_import_result.dart';
import 'dictionary_service.dart';

export '../models/dict_import_result.dart' show DictImportResult;

/// Service import file từ điển từ device
class DictImportService {
  DictImportService._();

  /// Định dạng file từ điển được chấp nhận.
  static const String mdxExtension = '.mdx';
  static const String mddExtension = '.mdd';

  /// Chọn và import file .mdx (+ .mdd nếu người dùng chọn kèm).
  ///
  /// [dialogTitle] truyền từ UI (đã qua `context.uiText`).
  /// [onProgress] nhận (0..1, thông báo pha hiện tại).
  /// Trả [DictImportResult] — KHÔNG trả null im lặng.
  static Future<DictImportResult> pickAndImportMdx({
    String? dialogTitle,
    void Function(double progress, String message)? onProgress,
  }) async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any, // xem bẫy (1) ở đầu file
        allowMultiple: true, // cho phép chọn kèm .mdd (resource)
        dialogTitle: dialogTitle,
        withData: false,
      );
    } catch (e) {
      return DictImportResult.failure(
        'Không mở được trình chọn file ($e). Hãy thử lại hoặc cấp quyền '
        'truy cập tệp cho In4Up.',
      );
    }

    if (picked == null || picked.files.isEmpty) {
      return const DictImportResult.cancelled();
    }

    final mdxFiles = picked.files
        .where((f) => f.path != null && _hasExtension(f.name, mdxExtension))
        .toList();
    if (mdxFiles.isEmpty) {
      final names = picked.files.map((f) => f.name).take(3).join(', ');
      return DictImportResult.failure(
        'File được chọn không phải từ điển .mdx ($names). '
        'Hãy chọn file có đuôi .mdx.',
      );
    }

    final mdxFile = mdxFiles.first;

    // File resource .mdd (ảnh/âm thanh) nếu người dùng chọn kèm.
    PlatformFile? mddFile;
    for (final file in picked.files) {
      if (file.path != null && _hasExtension(file.name, mddExtension)) {
        mddFile = file;
        break;
      }
    }

    // Bẫy (2): staging trước khi parse.
    String? stagedMdx;
    try {
      stagedMdx = await _stageFile(
        mdxFile.path!,
        mdxFile.name,
        onProgress: onProgress,
      );
    } catch (e) {
      return DictImportResult.failure(
        'Không sao chép được file .mdx vào bộ nhớ ứng dụng ($e). '
        'Thử lại hoặc chọn file ở bộ nhớ trong.',
      );
    }

    final mddPath = mddFile?.path;

    try {
      final result = await DictionaryService.instance.importMdx(
        stagedMdx,
        mddPath: mddPath,
        displayName: mdxFile.name,
        onProgress: onProgress,
      );
      return result;
    } finally {
      await _deleteStaged(stagedMdx);
    }
  }

  static bool _hasExtension(String name, String extension) =>
      name.toLowerCase().endsWith(extension);

  // ═══ Staging ═════════════════════════════════════════════════════════

  /// Thư mục staging (bộ nhớ riêng của app).
  static Future<Directory> stagingDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'dictionaries', 'staging'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Sao chép file vào bộ nhớ app khi nó đang nằm ở vùng tạm/cache.
  /// Trả path dùng để parse (path gốc nếu đã ở vùng an toàn).
  static Future<String> _stageFile(
    String sourcePath,
    String displayName, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final normalizedSource = sourcePath.replaceAll(r'\', '/');
    final normalizedDocs = docs.path.replaceAll(r'\', '/');
    if (normalizedSource.startsWith(normalizedDocs) &&
        File(sourcePath).existsSync()) {
      return sourcePath; // đã nằm trong bộ nhớ app — không nhân bản
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'File nguồn không tồn tại (có thể hệ thống đã dọn cache)',
        sourcePath,
      );
    }

    final dir = await stagingDirectory();
    final name = _sanitizeFileName(displayName);
    var candidate = p.join(dir.path, name);
    var suffix = 1;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    while (await File(candidate).exists()) {
      suffix += 1;
      candidate = p.join(dir.path, '$stem ($suffix)$ext');
    }

    onProgress?.call(0.02, 'Đang sao chép file vào bộ nhớ ứng dụng…');
    final out = File(candidate).openWrite();
    try {
      await out.addStream(source.openRead());
      await out.flush();
    } finally {
      await out.close();
    }
    return candidate;
  }

  static Future<void> _deleteStaged(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Không sao: file staging sẽ bị dọn ở lần import sau.
    }
  }

  static String _sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'dictionary.mdx' : cleaned;
  }
}
