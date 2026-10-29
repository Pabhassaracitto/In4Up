// ffmpeg_process_impl.dart — Desktop (Windows/macOS/Linux)
// Dung Process.run('ffmpeg'), tim binary tu nhieu noi.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ffmpeg_runner.dart';

Future<void> runFfmpegProcess(List<String> args) async {
  final binary = FfmpegRunner.findFfmpegBinary();
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

Future<String> probeFfmpegProcess(String inputPath) async {
  final binary = FfmpegRunner.findFfmpegBinary();
  try {
    final result = await Process.run(
      binary,
      ['-i', inputPath],
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

Exception _ffmpegNotFoundError(String triedBinary, {Object? originalError}) {
  final isWin = Platform.isWindows;
  final msg = StringBuffer();
  msg.writeln('FFmpeg binary khong tim thay: $triedBinary');
  if (originalError != null) msg.writeln('Chi tiet: $originalError');
  msg.writeln();
  msg.writeln('CACH KHAC PHUC:');
  if (isWin) {
    msg.writeln('1. Tai ffmpeg.exe tu https://ffmpeg.org/download.html');
    msg.writeln('   (Windows build tu https://github.com/BtbN/FFmpeg-Builds/releases)');
    msg.writeln('2. Dat ffmpeg.exe vao 1 trong:');
    msg.writeln('   - Cung thu muc voi in4up.exe (build/windows/x64/runner/Debug/)');
    msg.writeln('   - windows/libs/ffmpeg.exe (de CMake copy vao build)');
    msg.writeln('   - C:\\ffmpeg\\bin\\ va them vao PATH');
    msg.writeln('   - Hoac set env FFMPEG_PATH=C:\\path\\to\\ffmpeg.exe');
    msg.writeln('3. Chay lai app.');
  } else {
    msg.writeln('- Cai ffmpeg: brew install ffmpeg (macOS) hoac sudo apt install ffmpeg (Linux)');
    msg.writeln('- Hoac set env FFMPEG_PATH');
  }
  return Exception(msg.toString());
}
