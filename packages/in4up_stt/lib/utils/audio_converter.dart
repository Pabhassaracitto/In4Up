import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'src/ffmpeg_runner.dart';

/// Chuyen doi am thanh sang dinh dang Whisper-compatible (PCM 16kHz, mono).
class AudioConverter {
  static Future<String?> convertToWhisperCompatible(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Tep am thanh khong ton tai: $inputPath');
    }

    final ext = path.extension(inputPath).toLowerCase();
    if (ext == '.wav') {
      return inputPath;
    }

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

  /// Tinh so chunk can thiet cho file dai
  static Future<int> getChunkCount(String inputWavPath, {int chunkDurationSeconds = 30}) async {
    final durationMs = await probeDurationMs(inputWavPath);
    if (durationMs == null) return 1;
    final chunkSec = chunkDurationSeconds > 0 ? chunkDurationSeconds : 30;
    final totalSec = (durationMs / 1000.0).ceil();
    return ((totalSec + chunkSec - 1) ~/ chunkSec).clamp(1, 1000);
  }

  /// Cat 1 chunk duy nhat - dung cho lazy chunking de tiet kiem RAM
  static Future<String?> cutSingleChunk({
    required String inputWavPath,
    required int chunkIndex,
    required int chunkDurationSeconds,
    String? customBaseName,
  }) async {
    final dir = Directory.systemTemp.path;
    final baseName = customBaseName ?? path.basenameWithoutExtension(inputWavPath);
    final startSec = chunkIndex * chunkDurationSeconds;
    final outPath = path.join(dir, '${baseName}_chunk_${chunkIndex}_${DateTime.now().millisecondsSinceEpoch}.wav');

    final args = <String>[
      '-ss',
      '$startSec',
      '-i',
      inputWavPath,
      '-t',
      '$chunkDurationSeconds',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      '-y',
      outPath,
    ];

    try {
      if (_useFFmpegKit) {
        await FfmpegRunner.runWithKit(args);
      } else {
        await FfmpegRunner.runWithProcess(args);
      }
      if (await File(outPath).exists()) return outPath;
    } catch (e) {
      debugPrint('[AudioConverter] cutSingleChunk error chunk $chunkIndex: $e');
    }
    return null;
  }

  /// Cu - van giu de tuong thich, nhung gio chi dung cho file ngan < 5 phut
  /// Voi file dai, hay dung cutSingleChunk + lazy loop trong transcribeMobileChunked
  static Future<({
    List<String> chunkPaths,
    int? durationMs,
  })> splitIntoChunks(
    String inputWavPath, {
    int chunkDurationSeconds = 30,
  }) async {
    final durationMs = await probeDurationMs(inputWavPath);
    final chunkCount = await getChunkCount(inputWavPath, chunkDurationSeconds: chunkDurationSeconds);
    
    // Canh bao neu file qua dai - khuyen dung lazy
    if (chunkCount > 10) {
      debugPrint('[AudioConverter] File dai ${durationMs}ms ~ $chunkCount chunks, khuyen dung lazy chunking de tranh OOM');
    }

    final dir = Directory.systemTemp.path;
    final baseName = path.basenameWithoutExtension(inputWavPath);
    final chunkPaths = <String>[];

    for (var i = 0; i < chunkCount; i++) {
      final chunkPath = await cutSingleChunk(
        inputWavPath: inputWavPath,
        chunkIndex: i,
        chunkDurationSeconds: chunkDurationSeconds,
        customBaseName: baseName,
      );
      if (chunkPath != null) chunkPaths.add(chunkPath);
      
      // Giai phong RAM sau moi chunk cat - tranh tich luy native memory
      if (i % 3 == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
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

  static bool get _useFFmpegKit =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String sanitizeFileName(String name) {
    var safe = name.trim();
    final buffer = StringBuffer();
    for (final r in safe.runes) {
      if (r <= 127) {
        buffer.writeCharCode(r);
      } else {
        buffer.write('_');
      }
    }
    safe = buffer.toString();
    safe = safe.replaceAll('"', '');
    safe = safe.replaceAll("'", '');
    safe = safe.replaceAll("\\", '');
    safe = safe.replaceAll('%', '_');
    safe = safe.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    safe = safe.replaceAll(RegExp(r'\s+'), '_');
    safe = safe.replaceAll(RegExp(r'_+'), '_');
    safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'audio' : safe;
  }
}
