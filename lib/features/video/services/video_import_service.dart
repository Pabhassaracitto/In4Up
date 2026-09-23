// lib/features/video/services/video_import_service.dart
// VIDEO-ADD-001 — Copy video vừa chọn (cache của file_picker) vào thư mục
// PERSISTENT của app: getApplicationDocumentsDirectory()/video_imports/
//
// Cùng bệnh với audio (SHADOW-FILE-001): file_picker trả path trong
// /cache/file_picker/<ts>/ — Android dọn cache bất kỳ lúc nào ⇒ video trong
// thư viện mở lại báo "không phát được" dù vẫn hiện trong danh sách.
//
// Nguyên tắc (giữ nguyên như AudioImportService để đồng nhất):
//  - Dedup: cùng tên + cùng nội dung (size + md5 đầu/cuối 64KB) → reuse.
//    Khác nội dung cùng tên → "name (2).mp4", KHÔNG ghi đè.
//  - Không xóa dữ liệu cũ.
//  - Chỉ copy khi path nằm vùng tạm/cache; path đã ổn định giữ nguyên
//    (tránh nhân đôi bộ nhớ với video lớn).
//  - Injectable `appDocumentsDir` để test không cần platform channel.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/video_library_channel.dart';

/// Kết quả đảm bảo path persistent cho một video.
class VideoImportResult {
  final String path;
  final String displayName;
  final String identity;
  final int sizeBytes;
  final bool importedIntoLibrary;
  final bool reusedExisting;

  const VideoImportResult({
    required this.path,
    required this.displayName,
    required this.identity,
    required this.sizeBytes,
    required this.importedIntoLibrary,
    required this.reusedExisting,
  });
}

class VideoImportException implements Exception {
  final String message;
  final String sourcePath;
  const VideoImportException(this.message, this.sourcePath);

  @override
  String toString() => 'VideoImportException($sourcePath): $message';
}

class VideoImportService {
  static final VideoImportService instance = VideoImportService();

  static const String importDirName = 'video_imports';
  static const int _fingerprintSampleSize = 64 * 1024;

  /// Injectable cho unit test (truyền thư mục tạm).
  final Future<Directory> Function()? appDocumentsDirOverride;

  VideoImportService({this.appDocumentsDirOverride});

  // ─── PURE helpers (test được) ────────────────────────────────────────

  static String _norm(String path) => path.replaceAll(r'\', '/').trim();

  /// Path ở vùng cache/tạm mà hệ điều hành có thể xoá bất kỳ lúc nào.
  static bool isVolatilePath(String path) {
    final n = _norm(path).toLowerCase();
    if (n.isEmpty || n.startsWith('content://')) return false;
    return n.contains('/cache/') ||
        n.contains('/caches/') ||
        n.contains('/code_cache/') ||
        n.contains('/tmp/') ||
        n.contains('/temp/') ||
        n.contains('/.temp/') ||
        n.startsWith('/var/tmp/') ||
        n.contains('/appdata/local/temp/');
  }

  static bool isContentUri(String path) => path.startsWith('content://');

  static String sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'video.mp4';
    }
    return cleaned;
  }

  // ─── Import ─────────────────────────────────────────────────────────

  Future<Directory> _appDocumentsDir() async {
    final override = appDocumentsDirOverride;
    if (override != null) return override();
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> importDirectory() async {
    final docs = await _appDocumentsDir();
    final dir = Directory(p.join(docs.path, importDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isInsideImports(String path) async {
    final dirPath = _norm((await importDirectory()).path).toLowerCase();
    return _norm(path).toLowerCase().startsWith('$dirPath/');
  }

  Future<bool> shouldImport(String sourcePath) async {
    if (isContentUri(sourcePath)) return false; // resolve riêng qua channel
    if (await isInsideImports(sourcePath)) return false;
    return isVolatilePath(sourcePath);
  }

  /// Trả path persistent để lưu vào thư viện + phát.
  Future<VideoImportResult> ensurePersistent({
    required String sourcePath,
    String? displayName,
  }) async {
    var normalized = _norm(sourcePath);

    // content:// (MediaStore/SAF) — copy sang cache thật trước rồi import.
    if (isContentUri(normalized)) {
      final resolved =
          await VideoLibraryChannel.copyContentToCache(normalized);
      if (resolved == null ||
          resolved == normalized ||
          isContentUri(resolved)) {
        throw VideoImportException(
          'Không đọc được nguồn content:// (thiết bị chưa hỗ trợ resolve)',
          sourcePath,
        );
      }
      normalized = _norm(resolved);
    }

    final src = File(normalized);
    if (!await src.exists()) {
      throw VideoImportException(
        'File nguồn không tồn tại (có thể hệ thống đã dọn cache)',
        sourcePath,
      );
    }

    final name = sanitizeFileName(
      (displayName != null && displayName.trim().isNotEmpty)
          ? displayName
          : p.basename(normalized),
    );
    final size = await src.length();
    final fp = await _contentFingerprint(src, size);

    if (!await shouldImport(normalized)) {
      return VideoImportResult(
        path: normalized,
        displayName: name,
        identity: fp,
        sizeBytes: size,
        importedIntoLibrary: false,
        reusedExisting: false,
      );
    }

    final dir = await importDirectory();
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';

    var candidate = p.join(dir.path, name);
    var suffix = 1;
    while (await File(candidate).exists()) {
      final existing = File(candidate);
      final existingSize = await existing.length();
      if (existingSize == size &&
          await _contentFingerprint(existing, existingSize) == fp) {
        debugPrint('🎬 Import video dedup hit: $candidate');
        return VideoImportResult(
          path: candidate,
          displayName: p.basename(candidate),
          identity: fp,
          sizeBytes: size,
          importedIntoLibrary: true,
          reusedExisting: true,
        );
      }
      suffix += 1;
      candidate = p.join(dir.path, '$stem ($suffix)$ext');
    }

    await _copyStreamed(src, File(candidate));
    debugPrint('🎬 Imported video → $candidate ($size bytes)');
    return VideoImportResult(
      path: candidate,
      displayName: p.basename(candidate),
      identity: fp,
      sizeBytes: size,
      importedIntoLibrary: true,
      reusedExisting: false,
    );
  }

  // ─── Fingerprint + copy ─────────────────────────────────────────────

  static Future<String> _contentFingerprint(File file, int size) async {
    final contentDigest = await _sampleDigest(file, size);
    return md5.convert(utf8.encode('$size|$contentDigest')).toString();
  }

  static Future<String> _sampleDigest(File file, int size) async {
    final raf = await file.open();
    try {
      final bytes = BytesBuilder(copy: false);
      final sample =
          size < _fingerprintSampleSize ? size : _fingerprintSampleSize;
      if (sample > 0) {
        bytes.add(await raf.read(sample));
      }
      if (size > _fingerprintSampleSize) {
        await raf.setPosition(size - _fingerprintSampleSize);
        bytes.add(await raf.read(_fingerprintSampleSize));
      }
      return md5.convert(bytes.toBytes()).toString();
    } finally {
      await raf.close();
    }
  }

  static Future<void> _copyStreamed(File src, File dest) async {
    final out = dest.openWrite();
    try {
      await out.addStream(src.openRead());
      await out.flush();
    } finally {
      await out.close();
    }
  }
}
