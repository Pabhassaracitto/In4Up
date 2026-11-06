// ffmpeg_process_impl.dart — Desktop (Windows/macOS/Linux)
// Dung Process.run / Process.start('ffmpeg'), tim binary tu nhieu noi.
//
// AVTOOL-001 (PLAN-046 P0) bo sung cho desktop:
//   - `runFfmpegProcessWithProgress`: doc tien trinh tu `-progress pipe:2`
//     (FFmpeg ghi `out_time_us=...` moi ~0.5s) ⇒ UI co thanh tien trinh.
//   - `FfmpegProcessCancelToken`: `kill()` tien trinh dang chay.
//   - `probeFfmpegProcessAvailability`: tra loi "may nay co ffmpeg khong" ma
//     KHONG nem loi (Windows/Linux bundler khong kem ffmpeg.exe).
//
// Khong doi hanh vi cu: `runFfmpegProcess` / `probeFfmpegProcess` giu nguyen.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ffmpeg_binary_locator.dart';
import 'ffmpeg_common.dart';

Future<void> runFfmpegProcess(List<String> args) async {
  final binary = FfmpegBinaryRegistry.resolve();
  debugPrint('[FfmpegRunner] Process binary: $binary args: $args');

  try {
    final result = await Process.run(
      binary,
      args,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      final stdout = result.stdout.toString();
      // Hint for Windows user
      if (stderr.contains('not found') ||
          stderr.contains('No such file') ||
          result.stderr.toString().isEmpty && result.exitCode == 9009 ||
          stderr.toLowerCase().contains('is not recognized')) {
        throw _ffmpegNotFoundError(binary);
      }
      throw Exception('Chuyen doi that bai (exit ${result.exitCode}): $stderr $stdout');
    }
  } on ProcessException catch (e) {
    // File not found in PATH
    if (e.message.contains('No such file') ||
        e.message.contains('not found') ||
        e.errorCode == 2) {
      throw _ffmpegNotFoundError(binary, originalError: e);
    }
    rethrow;
  }
}

/// Huy mot tien trinh FFmpeg desktop dang chay.
class FfmpegProcessCancelToken {
  Process? _process;
  bool _cancelRequested = false;

  bool get isCancelled => _cancelRequested;

  void _attach(Process process) {
    _process = process;
    if (_cancelRequested) {
      try {
        process.kill();
      } catch (_) {}
    }
  }

  void cancel() {
    _cancelRequested = true;
    try {
      _process?.kill();
    } catch (_) {}
  }
}

/// Chay FFmpeg desktop, doc tien trinh tu stdout/stderr (`-progress pipe:2`),
/// huy duoc bang [token].
///
/// Goi y: nguoi goi tu them `-progress pipe:2 -nostats` vao [args]; noi day chi
/// PARSE, khong tu chen (de lop dung lenh giu toan quyen ve lenh FFmpeg).
Future<FfmpegRunResult> runFfmpegProcessWithProgress(
  List<String> args, {
  void Function(int elapsedMs)? onElapsed,
  FfmpegCancelToken? cancelToken,
}) async {
  // Desktop: bien token chung thanh token cua Process (tu dang ky listener —
  // nguoi dung bam Huy la kill tien trinh ngay).
  final token = FfmpegProcessCancelToken();
  final alreadyCancelled = cancelToken?.isCancelled ?? false;
  if (alreadyCancelled) token.cancel();
  cancelToken?.onCancel(token.cancel);
  final binary = FfmpegBinaryRegistry.resolve();
  debugPrint('[FfmpegRunner] Process (progress) binary: $binary args: $args');

  Process process;
  try {
    process = await Process.start(
      binary,
      args,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
  } on ProcessException catch (e) {
    throw _ffmpegNotFoundError(binary, originalError: e);
  }
  token._attach(process);

  final tail = <String>[];
  var pending = '';

  void handleLine(String line) {
    if (line.isEmpty) return;
    if (tail.length >= 40) tail.removeAt(0);
    tail.add(line);
    final ms = parseProgressElapsedMs(line);
    if (ms != null) onElapsed?.call(ms);
  }

  void consume(String chunk) {
    pending += chunk;
    while (true) {
      final i = pending.indexOf(RegExp(r'\r|\n'));
      if (i < 0) break;
      final sep = pending[i];
      final line = pending.substring(0, i);
      pending = pending.substring(i + 1);
      handleLine(line);
      if (sep == '\r') continue;
    }
    // Giu bo dem nho: log FFmpeg co the rat dai (dung escape 1 dong).
    if (pending.length > 8192) {
      handleLine(pending);
      pending = '';
    }
  }

  process.stdout.listen(consume);
  process.stderr.listen(consume);

  final exitCode = await process.exitCode;
  if (pending.isNotEmpty) handleLine(pending);

  final output = tail.join('\n');
  if (token.isCancelled) {
    return FfmpegRunResult(success: false, cancelled: true, output: output);
  }
  return FfmpegRunResult(
    success: exitCode == 0,
    cancelled: false,
    output: output,
  );
}

/// `out_time_us=1234567` (progress block) · `time=00:00:12.34` (dòng status).
/// Tra ve mili-giay da xu ly, `null` neu dong khong phai thong tin tien trinh.
///
/// HAM THUAN — test tren host VM duoc (xem test/media_tools/).
int? parseProgressElapsedMs(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;

  final us = RegExp(r'^out_time_us=(-?\d+)$').firstMatch(trimmed);
  if (us != null) {
    final micros = int.tryParse(us.group(1)!);
    if (micros == null || micros < 0) return null;
    return micros ~/ 1000;
  }

  final usAlt = RegExp(r'^out_time_ms=(-?\d+)$').firstMatch(trimmed);
  if (usAlt != null) {
    // Mot so ban FFmpeg ghi `out_time_ms` nhung don vi la micro-giay.
    final micros = int.tryParse(usAlt.group(1)!);
    if (micros == null || micros < 0) return null;
    return micros ~/ 1000;
  }

  final clock = RegExp(r'(?:time|out_time)=(\d+):(\d{2}):(\d{2})(?:\.(\d{1,6}))?')
      .firstMatch(trimmed);
  if (clock != null) {
    final h = int.parse(clock.group(1)!);
    final m = int.parse(clock.group(2)!);
    final s = int.parse(clock.group(3)!);
    final frac = clock.group(4);
    var ms = ((h * 3600) + (m * 60) + s) * 1000;
    if (frac != null && frac.isNotEmpty) {
      final padded = frac.padRight(3, '0').substring(0, 3);
      ms += int.parse(padded);
    }
    return ms;
  }
  return null;
}

/// `ffmpeg -version` chay duoc khong (khong nem loi).
Future<bool> probeFfmpegProcessAvailability() async {
  final binary = FfmpegBinaryRegistry.resolve();
  try {
    final result = await Process.run(binary, ['-version'])
        .timeout(const Duration(seconds: 6));
    return result.exitCode == 0;
  } catch (e) {
    debugPrint('[FfmpegRunner] ffmpeg unavailable ($binary): $e');
    return false;
  }
}

Future<String> probeFfmpegProcess(String inputPath) async {
  final binary = FfmpegBinaryRegistry.resolve();
  try {
    final result = await Process.run(
      binary,
      ['-hide_banner', '-i', inputPath],
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    // ffmpeg probe outputs to stderr
    return result.stderr.toString() + result.stdout.toString();
  } catch (e) {
    debugPrint('[FfmpegRunner] probe failed: $e');
    return '';
  }
}

Exception _ffmpegNotFoundError(String binary, {Object? originalError}) {
  return Exception(
    'Khong tim thay FFmpeg ($binary). Tren Windows/Linux can cai ffmpeg '
    'hoac dat bien moi truong FFMPEG_PATH tro toi ffmpeg.exe. '
    '${originalError ?? ''}',
  );
}
