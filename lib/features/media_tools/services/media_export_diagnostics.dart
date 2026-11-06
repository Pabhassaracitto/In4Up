// lib/features/media_tools/services/media_export_diagnostics.dart
//
// AVTOOL-002 (PLAN-046 P1) — CHẨN ĐOÁN "máy này có làm được gì?".
//
// Vì sao cần màn này (không phải "cho đẹp"):
//   - Mobile: FFmpegKit đã nằm trong app ⇒ luôn có. Nhưng bản build `audio` rút
//     gọn có thể THIẾU `libmp3lame` ⇒ phải biết trước khi hứa với người dùng.
//   - Desktop: repo KHÔNG kèm `ffmpeg.exe` (owner chọn: không đóng gói sẵn,
//     chỉ tải khi người dùng thật sự dùng) ⇒ phải có chỗ nói rõ "chưa cài" và
//     đường dẫn tới nút cài.
//
// Phép tự kiểm dùng nguồn TỔNG HỢP của FFmpeg (`lavfi sine`) — không cần file
// của người dùng, mà vẫn chạy trọn chuỗi decode → encode → mux, đúng thứ sẽ
// hỏng nếu build thiếu encoder.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media_export_models.dart';
import 'media_ffmpeg_engine.dart';

class MediaDiagnosticsReport {
  const MediaDiagnosticsReport({
    required this.available,
    this.versionLine,
    this.binaryPath,
    this.mp3EncoderFound,
    this.selfTestPassed,
    this.selfTestDetail,
    this.platformNote,
  });

  final bool available;
  final String? versionLine;
  final String? binaryPath;

  /// `libmp3lame` có trong danh sách encoder không (null = chưa kiểm được).
  final bool? mp3EncoderFound;

  /// Chạy thử xuất 1 file mp3 từ nguồn tổng hợp.
  final bool? selfTestPassed;
  final String? selfTestDetail;

  /// Ghi chú theo nền tảng (ví dụ "Windows cần cài FFmpeg").
  final String? platformNote;

  bool get isReady => available && (selfTestPassed ?? false);
}

class MediaExportDiagnostics {
  const MediaExportDiagnostics({MediaFfmpegEngine? engine})
      : _engine = engine;

  final MediaFfmpegEngine? _engine;

  MediaFfmpegEngine get _resolved => _engine ?? MediaFfmpegEngine();

  /// Đọc dòng `ffmpeg version ...` từ output.
  /// HÀM THUẦN.
  static String? parseVersionLine(String output) {
    for (final line in output.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.toLowerCase().startsWith('ffmpeg version')) return t;
    }
    return null;
  }

  /// Danh sách encoder có `libmp3lame`/`aac` không.
  /// HÀM THUẦN.
  static bool? detectEncoder(String encoderListOutput, String encoder) {
    if (encoderListOutput.trim().isEmpty) return null;
    // Dạng dòng: ` A....D libmp3lame          libmp3lame MP3 (MPEG audio layer 3)`
    final re = RegExp('\\s${RegExp.escape(encoder)}\\s');
    return re.hasMatch(encoderListOutput);
  }

  /// Chạy toàn bộ phép kiểm. Không ném lỗi — trả cờ false + chi tiết.
  Future<MediaDiagnosticsReport> run({
    bool includeSelfTest = true,
  }) async {
    final engine = _resolved;
    final available = await engine.ensureAvailable();
    if (!available) {
      return MediaDiagnosticsReport(
        available: false,
        binaryPath: engine.binaryPath,
        platformNote: _platformNote(),
      );
    }

    String? versionLine;
    try {
      final outcome = await engine.run(['-hide_banner', '-version']);
      versionLine = parseVersionLine(outcome.output);
    } catch (e) {
      debugPrint('[MediaTools] version probe failed: $e');
    }

    bool? mp3;
    try {
      final outcome = await engine.run(['-hide_banner', '-encoders']);
      mp3 = detectEncoder(outcome.output, 'libmp3lame');
    } catch (e) {
      debugPrint('[MediaTools] encoder probe failed: $e');
    }

    bool? selfTest;
    String? selfTestDetail;
    if (includeSelfTest) {
      final result = await _runSelfTest(engine);
      selfTest = result.$1;
      selfTestDetail = result.$2;
    }

    return MediaDiagnosticsReport(
      available: true,
      versionLine: versionLine,
      binaryPath: engine.binaryPath,
      mp3EncoderFound: mp3,
      selfTestPassed: selfTest,
      selfTestDetail: selfTestDetail,
      platformNote: _platformNote(),
    );
  }

  /// Xuất 1 giây âm thanh tổng hợp → mp3 rồi kiểm kích thước.
  Future<(bool, String?)> _runSelfTest(MediaFfmpegEngine engine) async {
    Directory? dir;
    try {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(docs.path, 'media_exports', '.self_test'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = p.join(dir.path, 'self_test.mp3');

      await engine.run([
        '-hide_banner',
        '-nostdin',
        '-y',
        '-f', 'lavfi',
        '-i', 'sine=frequency=440:duration=1',
        '-c:a', 'libmp3lame',
        '-b:a', '192k',
        target,
      ]);

      final file = File(target);
      final size = await file.exists() ? await file.length() : 0;
      if (size < 1024) {
        return (false, 'Output too small ($size B)');
      }
      try {
        await file.delete();
      } catch (_) {}
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    } finally {
      try {
        if (dir != null && await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  String? _platformNote() {
    if (kIsWeb) return 'Web builds cannot run FFmpeg.';
    if (Platform.isWindows || Platform.isLinux) {
      return 'Desktop builds do not bundle FFmpeg; install it or download it '
          'from the media tools screen.';
    }
    return null;
  }
}
