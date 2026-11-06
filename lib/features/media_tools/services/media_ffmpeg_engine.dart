// lib/features/media_tools/services/media_ffmpeg_engine.dart
//
// AVTOOL-002 (PLAN-046 P1) — tầng ENGINE: chạy FFmpeg qua ĐÚNG một cửa.
//
// Không tự gọi `FFmpegKit` hay `Process` ở đây: mọi thứ đi qua
// `FfmpegRunner` của `packages/in4up_stt` (đã có 2 đường mobile/desktop).
// Nhờ vậy:
//   - chỉ MỘT nơi biết "nền tảng nào dùng gì",
//   - P0 (AVTOOL-001: argument + huỷ + clearSessions) tự động áp cho export,
//   - test không cần thiết bị (inject [runner]).
//
// Điểm quan trọng: `isAvailable()` phải TRẢ FALSE thay vì ném lỗi khi desktop
// thiếu ffmpeg — UI hiện hướng dẫn thay vì màn hình lỗi.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';

import '../models/media_export_models.dart';

/// Kết quả chạy 1 lệnh.
class MediaCommandOutcome {
  const MediaCommandOutcome({
    required this.success,
    required this.cancelled,
    required this.output,
  });

  final bool success;
  final bool cancelled;
  final String output;
}

/// Cổng ra cho engine — bơm bản giả trong test.
abstract class MediaFfmpegPort {
  Future<bool> isAvailable();
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    FfmpegCancelToken? token,
  });
  Future<String> probe(String inputPath);
  String? get binaryPath;
}

/// Bản thật: chuyển tiếp sang `FfmpegRunner`.
class FfmpegRunnerPort implements MediaFfmpegPort {
  const FfmpegRunnerPort();

  @override
  Future<bool> isAvailable() => FfmpegRunner.isAvailable();

  @override
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    FfmpegCancelToken? token,
  }) async {
    final result = await FfmpegRunner.run(
      args,
      onElapsed: onElapsed,
      token: token,
    );
    return MediaCommandOutcome(
      success: result.success,
      cancelled: result.cancelled,
      output: result.output,
    );
  }

  @override
  Future<String> probe(String inputPath) =>
      FfmpegRunner.usesKit
          ? FfmpegRunner.probeWithKit(inputPath)
          : FfmpegRunner.probeWithProcess(inputPath);

  @override
  String? get binaryPath =>
      FfmpegRunner.usesKit ? null : FfmpegRunner.debugBinaryPath;
}

/// Chuẩn hoá lỗi thô của FFmpeg thành [MediaExportErrorKind].
///
/// HÀM THUẦN — test trên host VM.
MediaExportErrorKind classifyFfmpegFailure({
  required String output,
  required bool cancelled,
  bool ffmpegMissing = false,
}) {
  if (cancelled) return MediaExportErrorKind.cancelled;
  if (ffmpegMissing) return MediaExportErrorKind.ffmpegMissing;
  final text = output.toLowerCase();
  if (text.contains('no such file or directory') ||
      text.contains('invalid data found') ||
      text.contains('cannot open') ||
      text.contains('moov atom not found')) {
    return MediaExportErrorKind.inputUnreadable;
  }
  if (text.contains('does not contain any stream') ||
      text.contains('stream map') && text.contains('matches no streams')) {
    return MediaExportErrorKind.noAudioTrack;
  }
  if (text.contains('no space left on device') ||
      text.contains('enospc')) {
    return MediaExportErrorKind.noSpace;
  }
  if (text.contains('unknown encoder') ||
      text.contains('encoder not found') ||
      text.contains('unsupported codec') ||
      text.contains('protocol not found')) {
    return MediaExportErrorKind.unsupported;
  }
  return MediaExportErrorKind.failed;
}

class MediaFfmpegEngine {
  MediaFfmpegEngine({MediaFfmpegPort? port})
      : _port = port ?? const FfmpegRunnerPort();

  final MediaFfmpegPort _port;

  /// Có FFmpeg dùng được không (cache 1 lần / phiên).
  Future<bool> ensureAvailable() async {
    try {
      return await _port.isAvailable();
    } catch (e) {
      debugPrint('[MediaTools] isAvailable error: $e');
      return false;
    }
  }

  String? get binaryPath => _port.binaryPath;

  /// Chạy một lệnh, trả kết quả hoặc ném [MediaExportException] đã phân loại.
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    FfmpegCancelToken? token,
  }) async {
    if (!await ensureAvailable()) {
      throw const MediaExportException(MediaExportErrorKind.ffmpegMissing);
    }
    MediaCommandOutcome outcome;
    try {
      outcome = await _port.run(args, onElapsed: onElapsed, token: token);
    } catch (e) {
      final kind = classifyFfmpegFailure(
        output: e.toString(),
        cancelled: token?.isCancelled ?? false,
        ffmpegMissing: e.toString().contains('Khong tim thay FFmpeg') ||
            e.toString().contains('ffmpeg.exe') ||
            e is ProcessException,
      );
      throw MediaExportException(
        kind,
        detail: _tail(e.toString()),
      );
    }
    if (outcome.success) return outcome;
    throw MediaExportException(
      classifyFfmpegFailure(
        output: outcome.output,
        cancelled: outcome.cancelled || (token?.isCancelled ?? false),
      ),
      detail: _tail(outcome.output),
    );
  }

  /// Probe bằng `ffmpeg -i` (luôn có trên mọi nền tảng; ffprobe có thể thiếu
  /// trên bản FFmpeg build tối giản của Linux).
  Future<String> probe(String inputPath) async {
    try {
      return await _port.probe(inputPath);
    } catch (e) {
      debugPrint('[MediaTools] probe error: $e');
      return '';
    }
  }

  static String _tail(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 30) return text;
    return lines.sublist(lines.length - 30).join('\n');
  }
}

class MediaExportException implements Exception {
  const MediaExportException(this.kind, {this.detail});

  final MediaExportErrorKind kind;
  final String? detail;

  MediaExportError toError() => MediaExportError(kind, detail: detail);

  @override
  String toString() => 'MediaExportException(${kind.name})${detail == null ? '' : ': $detail'}';
}
