import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'whisper_ffi_windows.dart'; // For WhisperFfiResult and WhisperFfiSegment

/// Wrapper để gọi whisper.exe qua Command Line Interface trên Windows.
/// Phân tích output JSON thành WhisperFfiResult.
class WhisperCliWindows {
  static String? _cachedWhisperCliPath;

  /// Tìm đường dẫn đến whisper.exe
  static Future<String?> _findWhisperCli() async {
    if (_cachedWhisperCliPath != null) return _cachedWhisperCliPath;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      p.join(exeDir, 'whisper.exe'), // Ưu tiên tìm trong thư mục ứng dụng
      p.join(Directory.current.path, 'windows', 'libs',
          'whisper.exe'), // Folder libs gốc
      p.join(exeDir, 'models', 'whisper.exe'), // Thư mục models thủ công
      'whisper', // Thử tìm trong PATH hệ thống
    ];

    debugPrint('🔍 Searching whisper.exe in: $candidates');

    for (final path in candidates) {
      final isSystemPath = path == 'whisper';
      if (!isSystemPath && !File(path).existsSync()) {
        debugPrint('   ❌ Not found at: $path');
        continue;
      }

      try {
        // Thử chạy để kiểm tra quyền và các DLL phụ thuộc
        final result =
            await Process.run(path, ['--help'], runInShell: isSystemPath);
        if (result.exitCode == 0) {
          _cachedWhisperCliPath = path;
          debugPrint('✅ whisper.exe found and verified: $path');
          return path;
        } else {
          debugPrint(
              '⚠️ whisper.exe tại $path tồn tại nhưng lỗi exitCode: ${result.exitCode}. Có thể thiếu DLL?');
          debugPrint('   Stderr: ${result.stderr}');
        }
      } catch (e) {
        debugPrint('⚠️ Lỗi khi thực thi thử candidate $path: $e');
      }
    }
    debugPrint('❌ whisper.exe not found');
    return null;
  }

  /// Thực hiện transcribe bằng whisper.exe
  static Future<WhisperFfiResult> transcribe({
    required String wavPath,
    required String modelPath,
    required String language,
  }) async {
    final whisperCliPath = await _findWhisperCli();
    if (whisperCliPath == null) {
      return WhisperFfiResult.error('whisper.exe không tìm thấy');
    }

    final tempDir = await getTemporaryDirectory();
    final outputDir = p.join(tempDir.path, 'whisper_cli_output');
    await Directory(outputDir).create(recursive: true);

    final outputJsonPath = p.join(outputDir, 'output.json');

    final args = [
      wavPath,
      '--model',
      modelPath,
      '--language',
      language,
      '--output-format',
      'json',
      '--output-dir',
      outputDir,
      // Mặc định whisper.cpp CLI sẽ xuất segment timestamps.
      // Nếu cần word-level timestamps, thêm '--word-timestamps'
      // Tuy nhiên, _convertFfiResult hiện tại không sử dụng word-level timestamps từ FFI/CLI.
    ];

    debugPrint('🚀 Running whisper.exe: $whisperCliPath ${args.join(' ')}');

    try {
      final result = await Process.run(
        whisperCliPath,
        args,
        runInShell: true,
        workingDirectory:
            outputDir, // Đảm bảo file output được tạo trong outputDir
      );

      if (result.exitCode != 0) {
        debugPrint('❌ whisper.exe failed with exit code ${result.exitCode}');
        debugPrint('Stderr: ${result.stderr}');
        return WhisperFfiResult.error(
            'Whisper CLI thất bại: ${result.stderr.trim()}');
      }

      if (!await File(outputJsonPath).exists()) {
        debugPrint('❌ whisper.exe không tạo ra output.json');
        debugPrint('Stdout: ${result.stdout}');
        return WhisperFfiResult.error('Whisper CLI không tạo ra output.json');
      }

      final jsonString = await File(outputJsonPath).readAsString();
      final json = jsonDecode(jsonString);

      final segments = <WhisperFfiSegment>[];
      final List<dynamic> jsonSegments = json['segments'] ?? [];
      for (final segJson in jsonSegments) {
        segments.add(WhisperFfiSegment(
          text: segJson['text'] ?? '',
          startMs: (segJson['start'] * 1000).round(), // giây sang mili giây
          endMs: (segJson['end'] * 1000).round(), // giây sang mili giây
        ));
      }

      final fullText = segments.map((s) => s.text).join(' ').trim();

      // Dọn dẹp các file tạm
      await Directory(outputDir).delete(recursive: true);

      return WhisperFfiResult(
        segments: segments,
        fullText: fullText,
      );
    } catch (e, stack) {
      debugPrint('❌ Lỗi khi chạy Whisper CLI: $e\n$stack');
      return WhisperFfiResult.error('Lỗi khi chạy Whisper CLI: $e');
    }
  }
}
