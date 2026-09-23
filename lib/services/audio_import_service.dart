// lib/services/audio_import_service.dart
// SHADOW-FILE-001 — Copy audio vừa chọn (file_picker cache) vào thư mục
// PERSISTENT của app: getApplicationDocumentsDirectory()/audio_imports/
//
// Root cause: file_picker trả path trong /cache/file_picker/<ts>/ — Android
// xóa cache bất kỳ lúc nào → path chết → ExoPlayer ENOENT khi mở lại app.
// Fix: copy ngay sau khi pick, player/LRC/VAD/shadowing dùng path persistent.
//
// Nguyên tắc:
//  - Dedup an toàn: cùng tên + cùng nội dung (size + fingerprint 2 đầu) →
//    reuse file đã import (không nhân bản vô hạn khi user chọn lặp lại).
//    Khác nội dung nhưng trùng tên → KHÔNG ghi đè, đổi tên "name (2).ext".
//  - KHÔNG xóa dữ liệu cũ: service này không delete bất kỳ file nào
//    (kể cả nguồn cache). Cleanup/migration phải là luồng riêng có xác nhận.
//  - Chỉ copy khi cần: path đã nằm trong audio_imports/ hoặc ở vị trí
//    ổn định (desktop, thư mục user) thì giữ nguyên, không nhân đôi dữ liệu.
//
// Testable: inject `appDocumentsDir` để chạy unit test không cần platform
// channel (xem test/audio_import_service_test.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_library_channel.dart';

/// Kết quả của một lần import/đảm bảo path persistent.
class AudioImportResult {
  /// Path BỀN VỮNG để phát / LRC / VAD / shadowing dùng.
  final String path;

  /// Tên hiển thị (basename của file persistent — giữ tên gốc user chọn).
  final String displayName;

  /// Fingerprint ổn định của nội dung: md5(size|md5(đầu+cuối 64KB)).
  final String identity;

  final int sizeBytes;

  /// true nếu file đã được copy vào audio_imports/ (false = path vốn đã ổn
  /// định, không cần copy — tránh nhân đôi bộ nhớ với thư viện lớn).
  final bool importedIntoLibrary;

  /// true nếu destination đã tồn tại đúng nội dung → reuse, không copy lại.
  final bool reusedExisting;

  const AudioImportResult({
    required this.path,
    required this.displayName,
    required this.identity,
    required this.sizeBytes,
    required this.importedIntoLibrary,
    required this.reusedExisting,
  });
}

class AudioImportException implements Exception {
  final String message;
  final String sourcePath;
  const AudioImportException(this.message, this.sourcePath);

  @override
  String toString() => 'AudioImportException($sourcePath): $message';
}

class AudioImportService {
  static final AudioImportService instance = AudioImportService();

  /// Tên thư mục persistent trong application documents.
  static const String importDirName = 'audio_imports';

  /// Số bytes đọc ở đầu/cuối file để chấm fingerprint dedup.
  static const int _fingerprintSampleSize = 64 * 1024;

  /// Injectable — mặc định dùng path_provider (plugin). Test truyền giá trị
  /// riêng (temp dir) để không cần platform channel.
  final Future<Directory> Function()? appDocumentsDirOverride;

  AudioImportService({this.appDocumentsDirOverride});

  // ────────────────────────────────────────────────────────────
  // Path helpers (PURE — test được)
  // ────────────────────────────────────────────────────────────

  static String _norm(String path) =>
      path.replaceAll(r'\', '/').trim();

  /// Path có nằm trong vùng CACHE/tạm mà OS/app có thể xóa bất kỳ lúc nào
  /// không? (file_picker cache, temp dir, code_cache...).
  static bool isVolatilePath(String path) {
    final n = _norm(path).toLowerCase();
    if (n.isEmpty || n.startsWith('content://')) return false;
    // Linux/macOS/Windows temp + Android app cache + file_picker cache.
    return n.contains('/cache/') ||
        n.contains('/caches/') ||
        n.contains('/code_cache/') ||
        n.contains('/tmp/') ||
        n.contains('/temp/') ||
        n.contains('/.temp/') ||
        n.startsWith('/tmp/') ||
        n.startsWith('/var/tmp/') ||
        n.contains('/appdata/local/temp/');
  }

  /// Path có phải content:// URI (không đọc trực tiếp bằng dart:io được).
  static bool isContentUri(String path) => path.startsWith('content://');

  /// Tên file hợp lệ cho destination: bảo toàn tên gốc, chỉ loại ký tự
  /// nguy hiểm cho FS (separator, control). Giữ nguyên unicode/dấu cách.
  static String sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'audio';
    }
    return cleaned;
  }

  // ────────────────────────────────────────────────────────────
  // Directories
  // ────────────────────────────────────────────────────────────

  Future<Directory> _appDocumentsDir() async {
    final override = appDocumentsDirOverride;
    if (override != null) return override();
    return getApplicationDocumentsDirectory();
  }

  /// Thư mục import persistent (tạo nếu chưa có).
  Future<Directory> importDirectory() async {
    final docs = await _appDocumentsDir();
    final dir = Directory(p.join(docs.path, importDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Path đã nằm bên trong thư mục import chưa (idempotent guard).
  Future<bool> isInsideImports(String path) async {
    final dirPath = _norm((await importDirectory()).path).toLowerCase();
    final n = _norm(path).toLowerCase();
    return n.startsWith('$dirPath/');
  }

  // ────────────────────────────────────────────────────────────
  // Import
  // ────────────────────────────────────────────────────────────

  /// Quyết định nhanh: file này có cần copy vào audio_imports/ không.
  /// - Đã trong imports → không.
  /// - Ở vùng cache/tạm (volatile) → CÓ (đây là bug ENOENT).
  /// - Vị trí ổn định khác (desktop, thư mục user quản lý) → không cần,
  ///   path gốc đã bền; nếu user tự xóa file thì UI có hướng dẫn chọn lại.
  Future<bool> shouldImport(String sourcePath) async {
    if (isContentUri(sourcePath)) return false; // xử lý riêng qua channel
    if (await isInsideImports(sourcePath)) return false;
    return isVolatilePath(sourcePath);
  }

  /// Đảm bảo file có path persistent:
  /// - Cần import → copy (dedup) vào audio_imports/.
  /// - Không cần → trả result với path gốc (importedIntoLibrary=false).
  ///
  /// Ném [AudioImportException] khi source không đọc được — CALLER phải catch
  /// và hiện thông báo, không để crash.
  Future<AudioImportResult> ensurePersistent({
    required String sourcePath,
    String? displayName,
  }) async {
    var normalized = _norm(sourcePath);

    // Một số máy trả content:// thay vì path cache — resolve sang file thật
    // (cache) trước rồi import tiếp như thường. Lỗi resolve → exception rõ.
    if (isContentUri(normalized)) {
      final resolved = await AudioLibraryChannel.copyContentToCache(normalized);
      if (resolved == null ||
          resolved == normalized ||
          isContentUri(resolved)) {
        throw AudioImportException(
          'Không đọc được nguồn content:// (thiết bị chưa hỗ trợ resolve)',
          sourcePath,
        );
      }
      normalized = _norm(resolved);
    }

    final src = File(normalized);
    if (!await src.exists()) {
      throw AudioImportException(
        'File nguồn không tồn tại (có thể hệ thống đã dọn cache)',
        sourcePath,
      );
    }

    final name = sanitizeFileName(
      (displayName != null && displayName.trim().isNotEmpty)
          ? displayName!
          : p.basename(normalized),
    );
    final size = await src.length();
    final fp = await _contentFingerprint(src, size);

    if (!await shouldImport(normalized)) {
      return AudioImportResult(
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

    // Dedup: candidate trùng tên — nếu nội dung giống hệt → reuse;
    // nếu khác nội dung → đổi tên "stem (n).ext" (KHÔNG ghi đè).
    var candidate = p.join(dir.path, name);
    var suffix = 1;
    while (await File(candidate).exists()) {
      final existing = File(candidate);
      final existingSize = await existing.length();
      if (existingSize == size &&
          await _contentFingerprint(existing, existingSize) == fp) {
        debugPrint('📥 Import dedup hit: $candidate');
        return AudioImportResult(
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
    debugPrint('📥 Imported audio → $candidate ($size bytes)');
    return AudioImportResult(
      path: candidate,
      displayName: p.basename(candidate),
      identity: fp,
      sizeBytes: size,
      importedIntoLibrary: true,
      reusedExisting: false,
    );
  }

  /// Tìm file trong audio_imports/ có basename giống [originalPath] — dùng để
  /// TỰ KHÔI PHỤC khi path cũ (cache, đã bị xóa) gặp ENOENT. An toàn: chỉ trả
  /// về khi ĐÚNG 1 file trùng tên (nhiều file cùng tên = mơ hồ, không đoán).
  Future<String?> findImportedMatch(String originalPath) async {
    try {
      final dir = await importDirectory();
      final base = _norm(p.basename(originalPath)).toLowerCase();
      if (base.isEmpty) return null;
      final matches = <String>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File &&
            _norm(p.basename(entity.path)).toLowerCase() == base) {
          matches.add(entity.path);
        }
      }
      return matches.length == 1 ? matches.first : null;
    } catch (e) {
      debugPrint('⚠️ findImportedMatch error: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  // Fingerprint + copy (private)
  // ────────────────────────────────────────────────────────────

  /// md5(size | md5(sample đầu 64KB + cuối 64KB)) — đủ mạnh cho dedup file
  /// nhạc (đầu file có metadata/id3, cuối file có dữ liệu cuối).
  static Future<String> _contentFingerprint(File file, int size) async {
    final contentDigest = await _sampleDigest(file, size);
    final raw = '$size|$contentDigest';
    return md5.convert(utf8.encode(raw)).toString();
  }

  static Future<String> _sampleDigest(File file, int size) async {
    final raf = await file.open();
    try {
      final bytes = BytesBuilder(copy: false);
      final sample = size < _fingerprintSampleSize
          ? size
          : _fingerprintSampleSize;
      if (sample > 0) {
        bytes.add(await raf.read(sample));
      }
      if (size > _fingerprintSampleSize) {
        final tailStart = size - _fingerprintSampleSize;
        await raf.setPosition(tailStart);
        bytes.add(await raf.read(_fingerprintSampleSize));
      }
      return md5.convert(bytes.toBytes()).toString();
    } finally {
      await raf.close();
    }
  }

  /// Copy theo stream (an toàn cho file lớn, không đọc hết vào RAM).
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
