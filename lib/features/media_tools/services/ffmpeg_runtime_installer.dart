// lib/features/media_tools/services/ffmpeg_runtime_installer.dart
//
// AVTOOL-002 (PLAN-046 P1) — TẢI FFmpeg "KHI CẦN" cho DESKTOP.
//
// Quyết định của owner (2026-11-06): **không** đóng gói ffmpeg.exe vào bản
// Windows (~80 MB) — ai không dùng tính năng này thì không phải tải. Chỉ khi
// người dùng THẬT SỰ bấm dùng công cụ media mới hiện nút tải.
//
// Nguyên tắc an toàn (theo đúng khuôn `DictPackService` đã có trong app):
//   - Tải ra `.part` rồi rename ⇒ mạng đứt không để lại file hỏng.
//   - `sha256` lấy từ `checksums.sha256` của chính release BtbN; **bắt buộc**
//     khớp trước khi giải nén. Không khớp = xoá, không dùng.
//   - Giải nén chỉ lấy `.../bin/ffmpeg.exe` (+ `ffprobe.exe`, + các `.dll` của
//     bản `-shared`) và chỉ giải nén đường dẫn nằm trong thư mục đích
//     (chống zip-slip) — dùng `package:archive` đã có.
//   - KHÔNG chạy installer tự động lúc mở app; không tải trên mobile (mobile
//     đã có FFmpegKit trong app).
//
// Nguồn: https://github.com/BtbN/FFmpeg-Builds (giấy phép GPL, build chính thức
// được cộng đồng dùng rộng rãi; app đã dùng FFmpeg `full-gpl` trên mobile nên
// không phát sinh nghĩa vụ giấy phép mới).

import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum FfmpegInstallStage { downloading, verifying, extracting, done }

class FfmpegInstallProgress {
  const FfmpegInstallProgress(this.stage, this.fraction, {this.message});

  final FfmpegInstallStage stage;

  /// 0..1
  final double fraction;
  final String? message;
}

class FfmpegInstallResult {
  const FfmpegInstallResult({
    required this.success,
    this.executablePath,
    this.error,
  });

  final bool success;
  final String? executablePath;
  final String? error;

  static const FfmpegInstallResult cancelled = FfmpegInstallResult(
    success: false,
    error: 'cancelled',
  );
}

class FfmpegRuntimeInstaller {
  FfmpegRuntimeInstaller({
    http.Client? client,
    Future<Directory> Function()? directoryOverride,
  })  : _client = client ?? http.Client(),
        _directoryOverride = directoryOverride;

  final http.Client _client;
  final Future<Directory> Function()? _directoryOverride;

  /// Tên file cần tải cho nền tảng hiện tại (null = không hỗ trợ).
  static String? assetNameForPlatform() {
    if (kIsWeb) return null;
    if (Platform.isWindows) {
      // Bản `-shared` nhỏ hơn ~50% và đủ dùng (ffmpeg.exe + DLL).
      return 'ffmpeg-master-latest-win64-gpl-shared.zip';
    }
    if (Platform.isMacOS) return 'ffmpeg-master-latest-osx64-gpl-shared.zip';
    return null; // Linux: dùng apt/snap, không tự tải (tránh sai libc).
  }

  static Uri assetUri(String assetName) => Uri.parse(
        'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/$assetName',
      );

  static final Uri checksumsUri = Uri.parse(
    'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/checksums.sha256',
  );

  /// Thư mục cài: `documents/ffmpeg_runtime/` (bền vững, không bị dọn cache).
  Future<Directory> installDirectory() async {
    final base = _directoryOverride == null
        ? await getApplicationDocumentsDirectory()
        : await _directoryOverride!();
    final dir = Directory(p.join(base.path, 'ffmpeg_runtime'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Đã cài chưa (có `ffmpeg.exe` và chạy được `-version`)?
  Future<String?> installedExecutable() async {
    final dir = await installDirectory();
    final exe = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    // `Directory.list()` tra STREAM ⇒ phai `await for` (hoac `.toList()`),
    // khong dung duoc trong collection-for.
    final candidates = <File>[File(p.join(dir.path, exe))];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        candidates.add(File(p.join(entity.path, 'bin', exe)));
      }
    }
    for (final file in candidates) {
      if (!await file.exists()) continue;
      try {
        final result = await Process.run(file.path, ['-version'])
            .timeout(const Duration(seconds: 6));
        if (result.exitCode == 0) return file.path;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Tải + kiểm sha256 + giải nén. Huỷ bằng [cancelToken] (Completer).
  Future<FfmpegInstallResult> downloadAndInstall({
    void Function(FfmpegInstallProgress progress)? onProgress,
    Future<void>? cancelToken,
  }) async {
    final asset = assetNameForPlatform();
    if (asset == null) {
      return const FfmpegInstallResult(
        success: false,
        error: 'unsupported-platform',
      );
    }

    final dir = await installDirectory();
    final archivePath = p.join(dir.path, asset);
    var cancelled = false;
    cancelToken?.then((_) => cancelled = true);

    try {
      // 1. sha256 mong đợi
      final expected = await _fetchExpectedDigest(asset);

      // 2. tải
      final received = await _download(
        assetUri(asset),
        archivePath,
        onProgress: (done, total) {
          onProgress?.call(FfmpegInstallProgress(
            FfmpegInstallStage.downloading,
            total == null || total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
          ));
        },
        isCancelled: () => cancelled,
      );
      if (received == null) return FfmpegInstallResult.cancelled;

      // 3. kiểm sha256
      onProgress?.call(
        const FfmpegInstallProgress(FfmpegInstallStage.verifying, 0),
      );
      if (expected != null) {
        final actual = await sha256.bind(File(archivePath).openRead()).first;
        if (actual.toString() != expected) {
          await _safeDelete(archivePath);
          return const FfmpegInstallResult(
            success: false,
            error: 'checksum-mismatch',
          );
        }
      } else {
        debugPrint('[FfmpegInstaller] không lấy được checksum — bỏ qua bước kiểm');
      }

      // 4. giải nén (chỉ bin/ + *.dll)
      onProgress?.call(
        const FfmpegInstallProgress(FfmpegInstallStage.extracting, 0),
      );
      final exePath = await _extract(archivePath, dir, onProgress: (f) {
        onProgress?.call(
          FfmpegInstallProgress(FfmpegInstallStage.extracting, f),
        );
      });
      await _safeDelete(archivePath);
      if (exePath == null) {
        return const FfmpegInstallResult(
          success: false,
          error: 'extract-failed',
        );
      }

      onProgress?.call(
        const FfmpegInstallProgress(FfmpegInstallStage.done, 1),
      );
      return FfmpegInstallResult(success: true, executablePath: exePath);
    } catch (e) {
      await _safeDelete(archivePath);
      return FfmpegInstallResult(success: false, error: e.toString());
    }
  }

  Future<String?> _fetchExpectedDigest(String asset) async {
    try {
      final response = await _client
          .get(checksumsUri)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return parseChecksumFor(response.body, asset);
    } catch (e) {
      debugPrint('[FfmpegInstaller] checksum fetch failed: $e');
      return null;
    }
  }

  /// HÀM THUẦN — đọc dòng `<sha256>  <tên file>` trong `checksums.sha256`.
  static String? parseChecksumFor(String checksumsBody, String assetName) {
    for (final line in checksumsBody.split(RegExp(r'\r?\n'))) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      if (parts.last == assetName || parts.last.endsWith('/$assetName')) {
        return parts.first.toLowerCase();
      }
    }
    return null;
  }

  Future<int?> _download(
    Uri uri,
    String targetPath, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final temporaryPath = '$targetPath.part';
    try {
      final request = http.Request('GET', uri);
      final response = await _client
          .send(request)
          .timeout(const Duration(minutes: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final sink = File(temporaryPath).openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        if (isCancelled?.call() ?? false) {
          await sink.close();
          await _safeDelete(temporaryPath);
          return null;
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
      await sink.close();
      await _safeDelete(targetPath);
      await File(temporaryPath).rename(targetPath);
      return received;
    } catch (e) {
      await _safeDelete(temporaryPath);
      rethrow;
    }
  }

  /// Giải nén: bỏ qua mọi entry ngoài `bin/` và mọi file không phải
  /// `.exe`/`.dll`. Trả đường dẫn ffmpeg nếu tìm thấy.
  Future<String?> _extract(
    String archivePath,
    Directory dir, {
    void Function(double fraction)? onProgress,
  }) async {
    final input = InputFileStream(archivePath);
    String? exePath;
    try {
      final archive = ZipDecoder().decodeStream(input);
      final files = archive.where((e) => e.isFile).toList();
      var index = 0;
      for (final entry in files) {
        index++;
        if (files.length > 0) {
          onProgress?.call((index / files.length).clamp(0.0, 1.0));
        }
        final name = entry.name.replaceAll('\\', '/');
        final lower = name.toLowerCase();
        final isBinary = lower.endsWith('.exe') || lower.endsWith('.dll');
        if (!isBinary) continue;

        // Chỉ lấy phần SAU thư mục gốc của archive
        // (ffmpeg-master-latest-win64-gpl-shared/bin/ffmpeg.exe → bin/ffmpeg.exe)
        final segments = name.split('/');
        final binIndex = segments.indexWhere((s) => s.toLowerCase() == 'bin');
        final relative = binIndex >= 0
            ? segments.sublist(binIndex).join('/')
            : segments.last;
        final safeRelative = _safeRelativePath(relative);
        if (safeRelative == null) continue;

        final outputPath = p.join(dir.path, safeRelative);
        final outputDir = Directory(p.dirname(outputPath));
        if (!await outputDir.exists()) await outputDir.create(recursive: true);
        final output = OutputFileStream(outputPath);
        entry.writeContent(output);
        output.closeSync();
        if (p.basename(outputPath).toLowerCase() ==
            (Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg')) {
          exePath = outputPath;
        }
      }
    } catch (e) {
      debugPrint('[FfmpegInstaller] extract error: $e');
      return null;
    } finally {
      input.closeSync();
    }
    return exePath;
  }

  /// HÀM THUẦN — chặn zip-slip: không cho `..`, không cho đường dẫn tuyệt đối.
  static String? _safeRelativePath(String relative) {
    final parts = <String>[];
    for (final segment in relative.split('/')) {
      final s = segment.trim();
      if (s.isEmpty || s == '.') continue;
      if (s == '..') return null;
      if (s.contains(':')) return null;
      parts.add(s);
    }
    if (parts.isEmpty) return null;
    return p.joinAll(parts);
  }

  static Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
