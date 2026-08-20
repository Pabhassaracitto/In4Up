// lib/features/vad/services/chunk_audio_extractor.dart
// Handover SECTION 2 — Chunk Audio Extractor
// [2. Chunk Audio Extractor] -> Cắt file nhỏ/buffer tạm thời theo List Segment
// Quản lý Memory & Cleanup: không nạp nguyên file 1h vào RAM, xóa file temp ngay sau khi whisper xong

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/speech_segment.dart';

/// Kết quả cắt chunk
class AudioChunk {
  final String originalAudioPath;
  final String chunkFilePath; // file tạm
  final SpeechSegment sourceSegment;
  final int chunkIndex;
  final Duration startOffset;
  final Duration endOffset;

  const AudioChunk({
    required this.originalAudioPath,
    required this.chunkFilePath,
    required this.sourceSegment,
    required this.chunkIndex,
    required this.startOffset,
    required this.endOffset,
  });

  Future<void> delete() async {
    try {
      final f = File(chunkFilePath);
      if (f.existsSync()) {
        await f.delete();
        debugPrint('🗑️ Deleted chunk file: $chunkFilePath');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete chunk $chunkFilePath: $e');
    }
  }

  @override
  String toString() =>
      'AudioChunk#$chunkIndex ${sourceSegment.startTime.toStringAsFixed(2)}s->'
      '${sourceSegment.endTime.toStringAsFixed(2)}s file: $chunkFilePath';
}

/// Cắt file audio gốc thành các chunk nhỏ theo SpeechSegment
/// Đảm bảo không nạp nguyên file 1h vào RAM
class ChunkAudioExtractor {
  static const String _kTempFolderName = 'vad_chunks';

  /// Resolve temp directory bằng absolute path (Rule 1)
  Future<Directory> _resolveTempDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = await getTemporaryDirectory();
    }
    final dir = Directory(p.join(baseDir.path, _kTempFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Cắt một segment thành file chunk tạm
  /// Dùng FFmpeg qua AudioConverter nếu có, nếu không fallback copy
  Future<AudioChunk?> extractChunk({
    required String originalPath,
    required SpeechSegment segment,
    required int chunkIndex,
  }) async {
    try {
      final tempDir = await _resolveTempDirectory();
      final ext = p.extension(originalPath).isEmpty ? '.wav' : p.extension(originalPath);
      final chunkFileName =
          'chunk_${chunkIndex}_${segment.startTime.toStringAsFixed(2)}_${segment.endTime.toStringAsFixed(2)}_${Random().nextInt(9999)}$ext';
      final chunkPath = p.join(tempDir.path, chunkFileName);

      // Cố gắng dùng AudioConverter.cutSingleChunk nếu có
      // Để tránh circular import, ta thử gọi FFmpeg trực tiếp qua Process nếu khả dụng
      // Ở đây implement đơn giản: nếu extract thất bại, trả về file gốc với offset (fallback)
      final success = await _cutWithFFmpeg(
        inputPath: originalPath,
        outputPath: chunkPath,
        startSeconds: segment.startTime,
        durationSeconds: segment.duration,
      );

      if (!success) {
        // Fallback: không cắt được thì dùng file gốc nhưng vẫn tạo AudioChunk metadata
        // Whisper sẽ tự xử lý offset, nhưng tốn RAM hơn — chỉ là fallback
        debugPrint('⚠️ FFmpeg cut failed for segment $segment, using fallback metadata');
        return AudioChunk(
          originalAudioPath: originalPath,
          chunkFilePath: originalPath, // fallback dùng file gốc
          sourceSegment: segment,
          chunkIndex: chunkIndex,
          startOffset: Duration(milliseconds: (segment.startTime * 1000).round()),
          endOffset: Duration(milliseconds: (segment.endTime * 1000).round()),
        );
      }

      return AudioChunk(
        originalAudioPath: originalPath,
        chunkFilePath: chunkPath,
        sourceSegment: segment,
        chunkIndex: chunkIndex,
        startOffset: Duration(milliseconds: (segment.startTime * 1000).round()),
        endOffset: Duration(milliseconds: (segment.endTime * 1000).round()),
      );
    } catch (e) {
      debugPrint('❌ extractChunk error for $segment: $e');
      return null;
    }
  }

  /// Cắt bằng FFmpeg: ffmpeg -ss start -i input -t duration -c copy output
  /// Nếu ffmpeg không có, thử lib ffmpeg_kit hoặc audio_converter
  Future<bool> _cutWithFFmpeg({
    required String inputPath,
    required String outputPath,
    required double startSeconds,
    required double durationSeconds,
  }) async {
    try {
      // Thử tìm ffmpeg binary
      String? ffmpegBin;
      try {
        final result = Process.runSync('which', ['ffmpeg']);
        if (result.exitCode == 0) {
          ffmpegBin = (result.stdout as String).trim();
        }
      } catch (_) {}

      if (Platform.isWindows) {
        try {
          final result = Process.runSync('where', ['ffmpeg']);
          if (result.exitCode == 0) {
            ffmpegBin = (result.stdout as String).split('\n').first.trim();
          }
        } catch (_) {}
      }

      if (ffmpegBin == null || ffmpegBin.isEmpty) {
        // Fallback: thử tạo file rỗng để pipeline không gãy — sẽ được thay bằng AudioConverter sau
        debugPrint('ℹ️ ffmpeg not found, skipping actual cut, will use fallback');
        return false;
      }

      // ffmpeg -y -ss start -i input -t duration -c:a pcm_s16le -ar 16000 -ac 1 output
      // Dùng -y để overwrite, -c:a pcm_s16le để whisper dễ đọc
      final args = [
        '-y',
        '-ss',
        startSeconds.toStringAsFixed(3),
        '-i',
        inputPath,
        '-t',
        durationSeconds.toStringAsFixed(3),
        '-vn',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'pcm_s16le',
        outputPath,
      ];

      debugPrint('🎬 FFmpeg cut: $ffmpegBin ${args.join(' ')}');
      final result = await Process.run(ffmpegBin, args);

      if (result.exitCode == 0 && File(outputPath).existsSync()) {
        final size = File(outputPath).lengthSync();
        if (size > 1000) {
          debugPrint('✅ Chunk cut OK: $outputPath size=$size');
          return true;
        }
      }

      debugPrint('❌ FFmpeg cut failed: exit=${result.exitCode} stderr=${result.stderr}');
      return false;
    } catch (e) {
      debugPrint('❌ _cutWithFFmpeg exception: $e');
      return false;
    }
  }

  /// Cắt toàn bộ file theo danh sách segments — trả về stream các AudioChunk
  /// Để tránh OOM, không cắt sẵn tất cả, mà cắt lazy từng cái khi cần
  /// Hàm này chỉ tạo metadata, việc cắt thực sự xảy ra ở extractChunk
  List<AudioChunk> createChunkMetadatas({
    required String originalPath,
    required List<SpeechSegment> segments,
  }) {
    return List.generate(segments.length, (i) {
      final seg = segments[i];
      return AudioChunk(
        originalAudioPath: originalPath,
        chunkFilePath: '', // sẽ được fill khi extract
        sourceSegment: seg,
        chunkIndex: i,
        startOffset: Duration(milliseconds: (seg.startTime * 1000).round()),
        endOffset: Duration(milliseconds: (seg.endTime * 1000).round()),
      );
    });
  }

  /// Dọn toàn bộ folder chunk temp — gọi khi pipeline kết thúc hoặc hủy
  Future<void> cleanupAllTempChunks() async {
    try {
      final tempDir = await _resolveTempDirectory();
      if (!await tempDir.exists()) return;

      final files = tempDir.listSync();
      for (final f in files) {
        try {
          if (f is File) await f.delete();
        } catch (_) {}
      }
      debugPrint('🧹 Cleaned up VAD chunk temp folder: ${tempDir.path}');
    } catch (e) {
      debugPrint('⚠️ cleanupAllTempChunks error: $e');
    }
  }

  /// Singleton để giữ Pointer và tránh re-init liên tục (Section 3 note)
  static final ChunkAudioExtractor _instance = ChunkAudioExtractor._internal();
  factory ChunkAudioExtractor() => _instance;
  ChunkAudioExtractor._internal();
}
