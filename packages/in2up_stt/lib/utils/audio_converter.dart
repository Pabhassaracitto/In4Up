import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'src/ffmpeg_runner.dart';

/// Chuyen doi am thanh sang dinh dang Whisper-compatible (PCM 16kHz, mono).
///
/// Backend theo nen tang:
///  - Mobile (Android/iOS): dung [FFmpegKit] (native lib duoc bundle san,
///    khong can cai `ffmpeg` ngoai). Truoc day goi `Process` bi loi
///    `No such file or directory` vi Android khong co binary `ffmpeg`.
///  - Desktop (Windows/macOS/Linux): dung `ffmpeg` qua [Process].
///
/// ## Windows build note (fix C1083):
/// Package `ffmpeg_kit_flutter_new` 4.2.1 bi loi thieu header
/// `include/ffmpeg_kit_flutter_new_full/f_fmpeg_kit_flutter_plugin.h`.
/// Da fix bang 2 cach:
///   1. Nang version len ^4.6.2 (commit c83a702 fix unpack dir)
///   2. Patch windows/CMakeLists.txt de loai plugin nay khoi build Windows
///      (vi Dart da guard _useFFmpegKit chi cho Android/iOS).
/// Xem windows/CMakeLists.txt :: PATCH for ffmpeg_kit.
///
class AudioConverter {
  /// Chuyen doi tep am thanh dau vao sang tep WAV tam thoi
  /// (PCM 16kHz, mono).
  static Future<String?> convertToWhisperCompatible(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Tep am thanh khong ton tai: $inputPath');
    }

    // Kiem tra nhanh duoi tep
    final ext = path.extension(inputPath).toLowerCase();
    if (ext == '.wav') {
      // TODO: co the check header dung 16k/mono, nhung tam coi .wav la ok
      return inputPath;
    }

    // Tao duong dan tam -- SANITIZE ten file
    final dir = Directory.systemTemp.path;
    final rawName = path.basenameWithoutExtension(inputPath);
    final safeName = sanitizeFileName(rawName);
    final outputPath = path.join(dir, '${safeName}_converted.wav');

    final args = <String>[
      '-i',
      inputPath,
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      '-y',
      outputPath,
    ];

    if (_useFFmpegKit) {
      await FfmpegRunner.runWithKit(args);
    } else {
      await FfmpegRunner.runWithProcess(args);
    }

    if (!await File(outputPath).exists()) {
      throw Exception(
        'Chuyen doi am thanh that bai: file dau ra khong duoc tao ($outputPath)',
      );
    }

    return outputPath;
  }

  static Future<void> cleanupConvertedFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists() && filePath.contains('_converted.wav')) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Ước lượng thời lượng file (ms)
  static Future<int?> probeDurationMs(String inputPath) async {
    try {
      if (_useFFmpegKit) {
        final log = await FfmpegRunner.probeWithKit(inputPath);
        return _parseDuration(log);
      } else {
        final log = await FfmpegRunner.probeWithProcess(inputPath);
        return _parseDuration(log);
      }
    } catch (e) {
      debugPrint('[AudioConverter] probeDurationMs error: $e');
      return null;
    }
  }

  static int? _parseDuration(String log) {
    final m = RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2})\.(\d{2})')
        .firstMatch(log);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final mi = int.parse(m.group(2)!);
      final s = int.parse(m.group(3)!);
      final cs = int.parse(m.group(4)!);
      return ((h * 3600) + (mi * 60) + s) * 1000 + cs * 10;
    }
    return null;
  }

  /// Cắt file WAV 16k/mono thành nhiều chunk
  static Future<({
    List<String> chunkPaths,
    int? durationMs,
  })> splitIntoChunks(
    String inputWavPath, {
    int chunkDurationSeconds = 30,
  }) async {
    final durationMs = await probeDurationMs(inputWavPath);

    final chunkSec = chunkDurationSeconds > 0 ? chunkDurationSeconds : 30;
    final totalSec = durationMs == null ? null : (durationMs / 1000.0).ceil();

    final chunkCount = totalSec == null
        ? 1
        : ((totalSec + chunkSec - 1) ~/ chunkSec).clamp(1, 1 << 20);

    final dir = Directory.systemTemp.path;
    final baseName = path.basenameWithoutExtension(inputWavPath);
    final chunkPaths = <String>[];

    for (var i = 0; i < chunkCount; i++) {
      final startSec = i * chunkSec;
      final outPath = path.join(dir, '${baseName}_chunk_$i.wav');

      final args = <String>[
        '-ss',
        '$startSec',
        '-i',
        inputWavPath,
        '-t',
        '$chunkSec',
        '-ar',
        '16000',
        '-ac',
        '1',
        '-c:a',
        'pcm_s16le',
        '-y',
        outPath,
      ];

      if (_useFFmpegKit) {
        await FfmpegRunner.runWithKit(args);
      } else {
        await FfmpegRunner.runWithProcess(args);
      }

      if (await File(outPath).exists()) {
        chunkPaths.add(outPath);
      }
    }

    if (chunkPaths.isEmpty) {
      chunkPaths.add(inputWavPath);
    }

    return (chunkPaths: chunkPaths, durationMs: durationMs);
  }

  static Future<void> cleanupChunkFiles(List<String> chunkPaths) async {
    for (final p in chunkPaths) {
      try {
        final f = File(p);
        if (await f.exists() && p.contains('_chunk_')) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  // -- Backend selector ---------------------------------------------------

  static bool get _useFFmpegKit =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // -- Helpers ------------------------------------------------------------

  static String sanitizeFileName(String name) {
    var safe = name.trim();
    // Loại bỏ ký tự unicode đặc biệt gây lỗi trên Windows (’ ‘ “ ” …)
    safe = safe.replaceAll('’', '_').replaceAll('‘', '_')
        .replaceAll('“', '_').replaceAll('”', '_')
        .replaceAll('…', '_').replaceAll('–', '_').replaceAll('—', '_');
    safe = safe.replaceAll('"', '').replaceAll('\\', '');
    safe = safe.replaceAll('%', '_');
    // Chỉ giữ ascii an toàn cho file system
    safe = safe.replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '_');
    safe = safe.replaceAll(RegExp(r'\s+'), '_');
    safe = safe.replaceAll(RegExp(r'_+'), '_');
    safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'audio' : safe;
  }
}
