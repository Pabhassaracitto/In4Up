import 'dart:io';

import 'package:path/path.dart' as path;

/// Tiện ích chuyển đổi âm thanh sang định dạng Whisper-compatible (PCM 16kHz, mono).
/// Sử dụng `ffmpeg` thông qua `Process` để đảm bảo an toàn khi chạy trên Main Thread.
class AudioConverter {
  /// Chuyển đổi tệp âm thanh đầu vào sang tệp WAV tạm thời (PCM 16kHz, mono).
  ///
  /// [inputPath] là đường dẫn tới tệp gốc.
  /// Trả về đường dẫn tệp đã chuyển đổi nếu cần, hoặc [inputPath] nếu đã đúng định dạng.
  static Future<String?> convertToWhisperCompatible(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Tệp âm thanh không tồn tại: $inputPath');
    }

    // Kiểm tra nhanh đuôi tệp (đơn giản hóa)
    final ext = path.extension(inputPath).toLowerCase();
    if (ext == '.wav') {
      // Giả định .wav là đạt chuẩn, nếu cần kiểm tra kỹ hơn thì dùng ffprobe
      return inputPath;
    }

    // Tạo đường dẫn tạm
    final dir = Directory.systemTemp.path;
    final fileName = path.basenameWithoutExtension(inputPath);
    final outputPath = path.join(dir, '${fileName}_converted.wav');

    // Gọi ffmpeg để chuyển đổi
    // PCM 16kHz, mono
    final result = await Process.run('ffmpeg', [
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
    ]);

    if (result.exitCode != 0) {
      throw Exception('Chuyển đổi âm thanh thất bại: ${result.stderr}');
    }

    return outputPath;
  }

  /// Xóa tệp tạm nếu tồn tại
  static Future<void> cleanupConvertedFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists() && filePath.contains('_converted.wav')) {
      await file.delete();
    }
  }
}
