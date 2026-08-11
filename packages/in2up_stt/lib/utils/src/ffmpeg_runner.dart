// lib/utils/src/ffmpeg_runner.dart
//
// Facade cho FFmpeg: mobile dung FFmpegKit, desktop dung Process.
// Tach FFmpegKit import ra file rieng de tranh Windows build bi include
// header loi C1083 khi chua patch CMake.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'ffmpeg_kit_impl.dart' as kit_impl;
import 'ffmpeg_process_impl.dart' as proc_impl;

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

  static Future<String> probeWithKit(String inputPath) async {
    return kit_impl.probeFFmpegKit(inputPath);
  }

  static Future<String> probeWithProcess(String inputPath) async {
    return proc_impl.probeFfmpegProcess(inputPath);
  }

  // Helper shared
  static String quotePath(String arg) {
    if (arg.startsWith('-')) return arg;
    final escaped = arg.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }

  static String findFfmpegBinary() {
    // 1. Env var
    final envPath = Platform.environment['FFMPEG_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      final f = File(envPath);
      if (f.existsSync()) return envPath;
      // if env var is dir
      final joined = path.join(envPath, Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg');
      if (File(joined).existsSync()) return joined;
    }

    if (Platform.isWindows) {
      // 2. Same dir as executable (flutter build output)
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          path.join(exeDir, 'ffmpeg.exe'),
          path.join(exeDir, 'data', 'ffmpeg.exe'),
          path.join(exeDir, 'data', 'flutter_assets', 'ffmpeg.exe'),
        ];
        for (final c in candidates) {
          if (File(c).existsSync()) return c;
        }
      } catch (_) {}

      // 3. Project local libs (dev) — windows/libs/ffmpeg.exe
      // This only works when running from source with flutter run
      try {
        final current = Directory.current.path;
        final devCandidates = [
          path.join(current, 'windows', 'libs', 'ffmpeg.exe'),
          path.join(current, 'windows', 'libs', 'ffmpeg', 'bin', 'ffmpeg.exe'),
          path.join(current, 'ffmpeg.exe'),
        ];
        for (final c in devCandidates) {
          if (File(c).existsSync()) return c;
        }
      } catch (_) {}

      // 4. Common Windows install locations
      const common = [
        r'C:\ffmpeg\bin\ffmpeg.exe',
        r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
      ];
      for (final c in common) {
        if (File(c).existsSync()) return c;
      }

      // 5. Let system PATH resolve 'ffmpeg.exe'
      return 'ffmpeg.exe';
    } else {
      // macOS / Linux
      return 'ffmpeg';
    }
  }
}
