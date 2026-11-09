// test/media_tools/media_export_diagnostics_test.dart
//
// AVTOOL-002 (PLAN-047 P1) — máy bắt cho phần THUẦN của màn chẩn đoán.
//
// Chẩn đoán phải trả lời được: "bản build này có libmp3lame không?" — vì bản
// ffmpeg-kit rút gọn có thể thiếu, khi đó mọi preset MP3 sẽ hỏng ngay ở bước
// encode, và người dùng chỉ thấy "Xuất thất bại" mà không hiểu tại sao.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/services/media_export_diagnostics.dart';
import 'package:in4up/features/media_tools/services/media_ffmpeg_engine.dart';

const _encoders = '''
Encoders:
 V..... = Video
 A..... = Audio
 ------
 A....D aac                  AAC (Advanced Audio Coding)
 A....D libmp3lame           libmp3lame MP3 (MPEG audio layer 3)
 A....D libopus              libopus Opus
''';

void main() {
  group('parseVersionLine', () {
    test('lấy đúng dòng phiên bản', () {
      final line = MediaExportDiagnostics.parseVersionLine(
        'ffmpeg version 6.1.1-full_build Copyright (c) 2000-2023\n'
        'built with gcc 13.2.0',
      );
      expect(line, startsWith('ffmpeg version 6.1.1'));
    });

    test('không có dòng phiên bản ⇒ null', () {
      expect(MediaExportDiagnostics.parseVersionLine('random log'), isNull);
    });
  });

  group('detectEncoder', () {
    test('thấy libmp3lame', () {
      expect(
        MediaExportDiagnostics.detectEncoder(_encoders, 'libmp3lame'),
        isTrue,
      );
    });

    test('thiếu encoder ⇒ false (không phải null)', () {
      expect(
        MediaExportDiagnostics.detectEncoder(_encoders, 'libfdk_aac'),
        isFalse,
      );
    });

    test('không đọc được danh sách ⇒ null (UI không kết luận bừa)', () {
      expect(MediaExportDiagnostics.detectEncoder('', 'libmp3lame'), isNull);
    });

    test('không khớp nhầm tên nằm giữa chuỗi khác', () {
      // "aac" xuất hiện trong "libmp3lame ... AAC" nhưng phải là token riêng.
      expect(
        MediaExportDiagnostics.detectEncoder(' A....D aacx  something', 'aac'),
        isFalse,
      );
    });
  });

  group('MediaDiagnosticsReport.isReady', () {
    test('có FFmpeg nhưng tự kiểm hỏng ⇒ chưa sẵn sàng', () {
      const report = MediaDiagnosticsReport(
        available: true,
        selfTestPassed: false,
      );
      expect(report.isReady, isFalse);
    });

    test('có FFmpeg + tự kiểm đạt ⇒ sẵn sàng', () {
      const report = MediaDiagnosticsReport(
        available: true,
        selfTestPassed: true,
      );
      expect(report.isReady, isTrue);
    });

    test('chưa cài FFmpeg ⇒ chưa sẵn sàng', () {
      const report = MediaDiagnosticsReport(available: false);
      expect(report.isReady, isFalse);
    });
  });

  group('MediaFfmpegEngine với port giả', () {
    test('ensureAvailable nuốt lỗi port', () async {
      final engine = MediaFfmpegEngine(port: _ThrowingPort());
      expect(await engine.ensureAvailable(), isTrue);
    });
  });
}

class _ThrowingPort implements MediaFfmpegPort {
  @override
  Future<bool> isAvailable() async => true;

  @override
  String? get binaryPath => null;

  @override
  Future<String> probe(String inputPath) async => '';

  @override
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    dynamic token,
  }) async =>
      throw StateError('boom');
}
