// lib/utils/src/ffmpeg_runner.dart
//
// Facade cho FFmpeg: mobile dung FFmpegKit, desktop dung Process.
// Tach FFmpegKit import ra file rieng de tranh Windows build bi include
// header loi C1083 khi chua patch CMake.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'ffmpeg_binary_locator.dart';
import 'ffmpeg_common.dart';
import 'ffmpeg_kit_impl.dart' as kit_impl;
import 'ffmpeg_process_impl.dart' as proc_impl;

export 'ffmpeg_common.dart' show FfmpegCancelToken, FfmpegRunResult;

class FfmpegRunner {
  /// Run via FFmpegKit (Android/iOS)
  static Future<void> runWithKit(List<String> args) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await kit_impl.runFFmpegKit(args);
    } else {
      // Fallback: neu ai do goi nham tren desktop, dung Process
      debugPrint('[FfmpegRunner] runWithKit called on desktop -> fallback to Process');
      await runWithProcess(args);
    }
  }

  /// Run via Process (Windows/macOS/Linux)
  static Future<void> runWithProcess(List<String> args) async {
    await proc_impl.runFfmpegProcess(args);
  }

  /// Nen tang co FFmpegKit nhung san (khong can binary ngoai).
  static bool get usesKit => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Chay co TIEN TRINH + HUY duoc (AVTOOL-001).
  ///
  /// [onElapsed] nhan so mili-giay da xu ly. Desktop doc tu `-progress pipe:2`
  /// (tham so do noi goi tu them), mobile doc tu Statistics cua FFmpegKit.
  static Future<FfmpegRunResult> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    FfmpegCancelToken? token,
  }) async {
    if (usesKit) {
      final outcome = await kit_impl.runFFmpegKitWithProgress(
        args,
        onElapsed: onElapsed,
        token: token,
      );
      return FfmpegRunResult(
        success: outcome.success,
        cancelled: outcome.cancelled,
        output: outcome.output,
      );
    }

    // Desktop: impl tu dang ky cach huy len token chung (listener).
    return proc_impl.runFfmpegProcessWithProgress(
      args,
      onElapsed: onElapsed,
      cancelToken: token,
    );
  }

  /// FFmpeg co san tren may nay khong?
  ///
  /// - Mobile: luon co (FFmpegKit bundled).
  /// - Desktop: co the KHONG co (`ffmpeg.exe` / `ffmpeg` khong nam trong
  ///   release). Goi `ffmpeg -version` 1 lan, cache ket qua.
  static Future<bool> isAvailable() async {
    if (usesKit) return true;
    _desktopAvailability ??= proc_impl.probeFfmpegProcessAvailability();
    return _desktopAvailability!;
  }

  static Future<bool>? _desktopAvailability;

  /// Xoa cache "co FFmpeg khong" — goi sau khi vua cai/xoa binary.
  static void resetAvailabilityCache() {
    _desktopAvailability = null;
  }

  /// Dang ky binary ngoai (vi du ffmpeg tai ve tu man "Cong cu media" ->
  /// `documents/ffmpeg_runtime/bin/ffmpeg.exe`). Uu tien cao nhat: nguoi dung
  /// da bam tai thi phai dung ban do.
  static void registerBinary(String? path) {
    FfmpegBinaryRegistry.registeredPath =
        (path == null || path.isEmpty) ? null : path;
    _desktopAvailability = null; // do lai khi doi binary
  }

  static String? get registeredBinaryPath => FfmpegBinaryRegistry.registeredPath;

  /// Bom ham tra ve thu muc/duong dan da cai (null = khong biet).
  static void setBinaryHintProvider(String? Function()? provider) {
    FfmpegBinaryRegistry.hintProvider = provider;
    _desktopAvailability = null;
  }

  /// Duong dan binary FFmpeg ma desktop se dung (null neu khong tim thay).
  static String? get debugBinaryPath => Platform.isWindows || Platform.isLinux || Platform.isMacOS
      ? findFfmpegBinary()
      : null;

  static Future<String> probeWithKit(String inputPath) async {
    return kit_impl.probeFFmpegKit(inputPath);
  }

  static Future<String> probeWithProcess(String inputPath) async {
    return proc_impl.probeFfmpegProcess(inputPath);
  }

  // Helper shared
  static String quotePath(String arg) {
    if (arg.startsWith('-')) return arg;
    // Simple quoting: wrap in double quotes, escape existing quotes
    if (!arg.contains(' ') && !arg.contains('"') && !arg.contains("'")) {
      return arg;
    }
    final escaped = arg.replaceAll('"', r'\"');
    return '"$escaped"';
  }

  static String findFfmpegBinary() => FfmpegBinaryRegistry.resolve();
}