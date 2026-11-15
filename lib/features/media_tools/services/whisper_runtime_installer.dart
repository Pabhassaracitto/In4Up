// lib/features/media_tools/services/whisper_runtime_installer.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — TẢI "BỘ CHẠY WHISPER" CHO DESKTOP.
//
// Vì sao phải có (thay vì bắt người dùng chép tay):
//   App Windows KHÔNG đóng gói whisper.cpp (~25 MB). Đường chạy hiện tại là
//   CLI `whisper-cli.exe`, và LỖI THẬT người dùng gặp là:
//     `exit -1073741515` (0xC0000135 STATUS_DLL_NOT_FOUND) + STDOUT/STDERR
//     RỖNG — vì họ chép "4 file" mà bộ đầy đủ là **6 file**
//     (`whisper-cli.exe`, `whisper.dll`, `ggml.dll`, `ggml-base.dll`,
//     `ggml-cpu-*.dll`, `SDL2.dll`). Loader Windows chạy trước `main()` nên
//     không có log nào để đọc.
//
// Nguyên tắc an toàn (theo đúng khuôn `FfmpegRuntimeInstaller` đã có):
//   - Tải ra `.part` rồi rename ⇒ mạng đứt không để lại file hỏng.
//   - Chỉ giải nén ĐÚNG bộ file chạy được (`whisper-cli.exe`, `whisper.dll`,
//     `ggml*.dll`, `SDL2.dll`) — bỏ model, bỏ `*.pdb`.
//   - Chặn zip-slip (`..`, ổ đĩa, đường dẫn tuyệt đối).
//   - KHÔNG tự chạy khi mở app; chỉ khi người dùng bấm.
//   - Sau khi giải nén, soi lại import table của `whisper-cli.exe`
//     (`probeWhisperBinary`) để chắc chắn DLL còn thiếu KHÔNG bị bỏ qua.

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:in4up_stt/utils/src/whisper_cli_locator.dart';
import 'package:in4up_stt/utils/src/whisper_cli_runtime.dart';

enum WhisperInstallStage { downloading, extracting, verifying, done }

class WhisperInstallProgress {
  const WhisperInstallProgress(this.stage, this.fraction, {this.message});

  final WhisperInstallStage stage;

  /// 0..1
  final double fraction;
  final String? message;
}

class WhisperInstallResult {
  const WhisperInstallResult({
    required this.success,
    this.binaryPath,
    this.error,
    this.probe,
  });

  final bool success;
  final String? binaryPath;
  final String? error;
  final WhisperBinaryProbe? probe;

  static const WhisperInstallResult cancelled =
      WhisperInstallResult(success: false, error: 'cancelled');
}

class WhisperRuntimeInstaller {
  WhisperRuntimeInstaller({
    http.Client? client,
    Future<Directory> Function()? directoryOverride,
    List<String>? assetCandidates,
  })  : _client = client ?? http.Client(),
        _directoryOverride = directoryOverride,
        _assetCandidates = assetCandidates;

  final http.Client _client;
  final Future<Directory> Function()? _directoryOverride;
  final List<String>? _assetCandidates;

  /// Release được ghim: bản có `whisper-bin-x64.zip` (kèm `whisper.dll` +
  /// `ggml-cpu-*.dll`). Đổi số ở đây khi cần nâng cấp — có test pin.
  static const String pinnedTag = 'v1.9.2';

  /// Thứ tự thử: x64 trước (bản app phát hành là x64), rồi bản "blas"
  /// (cùng bộ file) nếu release ghim không còn asset.
  static const List<String> defaultAssetCandidates = <String>[
    'whisper-bin-x64.zip',
    'whisper-blas-bin-x64.zip',
  ];

  static List<String> get assetCandidates => defaultAssetCandidates;

  /// Tên asset sẽ dùng cho nền tảng hiện tại (null = không hỗ trợ tải).
  static String? assetNameForPlatform() {
    if (kIsWeb) return null;
    if (Platform.isWindows) return defaultAssetCandidates.first;
    // Linux/macOS: dùng trình quản lý gói (apt/brew) — tránh sai libc/ABI.
    return null;
  }

  static Uri assetUri(String asset, {String tag = pinnedTag}) => Uri.parse(
        'https://github.com/ggml-org/whisper.cpp/releases/download/$tag/$asset',
      );

  static Uri releasePageUri({String tag = pinnedTag}) =>
      Uri.parse('https://github.com/ggml-org/whisper.cpp/releases/tag/$tag');

  /// Thư mục cài: `documents/whisper_runtime/` (bền vững, không bị dọn cache).
  Future<Directory> installDirectory() async {
    final base = _directoryOverride == null
        ? await getApplicationDocumentsDirectory()
        : await _directoryOverride!();
    final dir = Directory(p.join(base.path, 'whisper_runtime'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Đã cài chưa? Trả đường dẫn binary khi bộ file đã đủ (soi import table).
  Future<WhisperBinaryProbe?> installedRuntime() async {
    final dir = await installDirectory();
    final exe = p.join(dir.path, 'whisper-cli.exe');
    if (!await File(exe).exists()) return null;
    final probe = probeWhisperBinaryOnDisk(exe);
    return probe.isRunnable ? probe : null;
  }

  /// Tải + giải nén. [cancelToken] huỷ giữa chừng (giống FfmpegInstaller).
  Future<WhisperInstallResult> downloadAndInstall({
    void Function(WhisperInstallProgress progress)? onProgress,
    Future<void>? cancelToken,
    String tag = pinnedTag,
  }) async {
    final candidates = _assetCandidates ?? defaultAssetCandidates;
    final assets = <String>[];
    for (final a in candidates) {
      if (a.isEmpty) continue;
      if (!assets.contains(a)) assets.add(a);
    }
    if (assets.isEmpty) {
      return const WhisperInstallResult(success: false, error: 'unsupported-platform');
    }

    var cancelled = false;
    cancelToken?.then((_) => cancelled = true);

    final dir = await installDirectory();
    Object? lastError;

    for (final asset in assets) {
      final archivePath = p.join(dir.path, asset);
      try {
        final received = await _download(
          assetUri(asset, tag: tag),
          archivePath,
          onProgress: (done, total) {
            onProgress?.call(WhisperInstallProgress(
              WhisperInstallStage.downloading,
              total == null || total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
            ));
          },
          isCancelled: () => cancelled,
        );
        if (received == null) return WhisperInstallResult.cancelled;

        onProgress?.call(
          const WhisperInstallProgress(WhisperInstallStage.extracting, 0),
        );
        final extracted = await _extract(archivePath, dir, onProgress: (f) {
          onProgress?.call(WhisperInstallProgress(WhisperInstallStage.extracting, f));
        });
        await _safeDelete(archivePath);
        if (extracted == null) {
          lastError = 'extract-failed';
          continue;
        }

        onProgress?.call(
          const WhisperInstallProgress(WhisperInstallStage.verifying, 0),
        );
        final probe = probeWhisperBinaryOnDisk(extracted);
        if (!probe.isRunnable) {
          onProgress?.call(const WhisperInstallProgress(WhisperInstallStage.done, 1));
          return WhisperInstallResult(
            success: false,
            error: 'incomplete-runtime',
            probe: probe,
          );
        }

        onProgress?.call(const WhisperInstallProgress(WhisperInstallStage.done, 1));
        return WhisperInstallResult(
          success: true,
          binaryPath: extracted,
          probe: probe,
        );
      } catch (e, st) {
        lastError = e;
        debugPrint('[WhisperInstaller] $asset thất bại: $e\n$st');
        await _safeDelete(archivePath);
      }
    }

    return WhisperInstallResult(
      success: false,
      error: lastError?.toString() ?? 'download-failed',
    );
  }

  /// HÀM THUẦN — file nào trong archive là phần của bộ chạy.
  ///
  /// Bản release `whisper-bin-x64.zip` chứa thêm model mẫu, `*.pdb`, các exe
  /// khác (`whisper-bench`, `whisper-server`, `parakeet-*`…) — chỉ lấy đúng
  /// 6 nhóm file sau, tránh phình ổ đĩa và tránh 2 binary cùng tên đè nhau.
  static bool isRuntimeFile(String name) {
    // Zip có thể dùng '\' (Windows) hoặc '/' (POSIX). `p.basename` chỉ tách
    // theo dấu của NỀN TẢNG đang chạy ⇒ phải chuẩn hóa trước, nếu không entry
    // kiểu `whisper-bin-x64\\Release\\whisper.dll` bị coi là file lạ trên
    // máy build Linux và bộ chạy giải nén ra thiếu DLL.
    final base = p.basename(name.replaceAll('\\', '/')).toLowerCase();
    if (base.isEmpty) return false;
    if (base == 'whisper-cli.exe') return true;
    if (base == 'whisper.dll' || base == 'libwhisper.dll') return true;
    if (base == 'ggml.dll') return true;
    if (base == 'sdl2.dll') return true;
    if (base.endsWith('.dll')) {
      // ggml-base.dll, ggml-cpu-*.dll, ggml-blas.dll …
      return ggmlFamilyOf(base) != null;
    }
    return false;
  }

  /// HÀM THUẦN — chặn zip-slip: không `..`, không ổ đĩa, không tuyệt đối.
  static String? safeRelativePath(String entryName) {
    final normalized = entryName.replaceAll('\\', '/');
    final parts = <String>[];
    for (final segment in normalized.split('/')) {
      final s = segment.trim();
      if (s.isEmpty || s == '.') continue;
      if (s == '..') return null;
      if (s.contains(':')) return null;
      parts.add(s);
    }
    if (parts.isEmpty) return null;
    return parts.join('/');
  }

  Future<String?> _extract(
    String archivePath,
    Directory dir, {
    void Function(double fraction)? onProgress,
  }) async {
    final input = InputFileStream(archivePath);
    final written = <String>[];
    String? cliPath;
    try {
      final archive = ZipDecoder().decodeStream(input);
      final files = archive.where((e) => e.isFile).toList(growable: false);
      var index = 0;
      for (final entry in files) {
        index++;
        if (files.isNotEmpty) {
          onProgress?.call((index / files.length).clamp(0.0, 1.0));
        }
        if (!isRuntimeFile(entry.name)) continue;
        final safe = safeRelativePath(entry.name);
        if (safe == null) continue;
        // Bỏ thư mục gốc trong zip (`whisper-bin-x64/Release/...`) — mọi file
        // bộ chạy nằm PHẲNG trong thư mục cài, đúng như Windows loader cần.
        final flat = p.basename(safe);
        final outputPath = p.join(dir.path, flat);
        final output = OutputFileStream(outputPath);
        entry.writeContent(output);
        output.closeSync();
        written.add(flat);
        if (flat.toLowerCase() == 'whisper-cli.exe') cliPath = outputPath;
      }
    } catch (e) {
      debugPrint('[WhisperInstaller] extract error: $e');
      return null;
    } finally {
      input.closeSync();
    }

    debugPrint('[WhisperInstaller] Đã giải nén ${written.length} file: $written');
    if (cliPath == null) {
      // Một số bản đóng gói đặt tên cũ `main.exe` — chấp nhận và đổi tên.
      final legacy = written
          .where((f) => f.toLowerCase() == 'main.exe' || f.toLowerCase() == 'whisper.exe')
          .toList();
      if (legacy.isNotEmpty) {
        final src = p.join(dir.path, legacy.first);
        final dst = p.join(dir.path, 'whisper-cli.exe');
        try {
          await File(src).rename(dst);
          cliPath = dst;
        } catch (_) {
          cliPath = src;
        }
      }
    }
    return cliPath;
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
      final response =
          await _client.send(request).timeout(const Duration(minutes: 2));
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

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
