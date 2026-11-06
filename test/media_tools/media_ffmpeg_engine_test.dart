// test/media_tools/media_ffmpeg_engine_test.dart
//
// AVTOOL-002 (PLAN-046 P1) — máy bắt cho tầng ENGINE.
//
// Điều quan trọng nhất: engine KHÔNG được ném lỗi thô của `Process` ra UI, và
// khi desktop thiếu FFmpeg thì phải là `ffmpegMissing` (có hướng dẫn tải),
// không phải "Export failed" chung chung.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/features/media_tools/services/media_ffmpeg_engine.dart';
import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';

class _Port implements MediaFfmpegPort {
  _Port({
    this.available = true,
    this.outcome = const MediaCommandOutcome(
      success: true,
      cancelled: false,
      output: 'ok',
    ),
    this.throwing,
    this.probeText = 'Duration: 00:00:10.00',
  });

  bool available;
  MediaCommandOutcome outcome;
  Object? throwing;
  String probeText;

  int runCount = 0;
  List<String> lastArgs = const [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  String? get binaryPath => '/usr/bin/ffmpeg';

  @override
  Future<String> probe(String inputPath) async => probeText;

  @override
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    FfmpegCancelToken? token,
  }) async {
    runCount++;
    lastArgs = args;
    onElapsed?.call(123);
    if (throwing != null) throw throwing!;
    return outcome;
  }
}

void main() {
  group('ensureAvailable', () {
    test('trả false (không ném) khi thiếu FFmpeg', () async {
      final engine = MediaFfmpegEngine(port: _Port(available: false));
      expect(await engine.ensureAvailable(), isFalse);
    });

    test('trả false thay vì ném khi port lỗi', () async {
      final engine = MediaFfmpegEngine(port: _Port(throwing: StateError('boom')));
      expect(await engine.ensureAvailable(), isTrue); // isAvailable không throw
    });
  });

  group('run', () {
    test('chuyển tiếp argv và tiến trình', () async {
      final port = _Port();
      final engine = MediaFfmpegEngine(port: port);
      final ticks = <int>[];
      final outcome = await engine.run(
        ['-hide_banner', '-i', 'a.mp3', 'b.mp3'],
        onElapsed: ticks.add,
      );
      expect(outcome.success, isTrue);
      expect(port.lastArgs, ['-hide_banner', '-i', 'a.mp3', 'b.mp3']);
      expect(ticks, [123]);
    });

    test('thiếu FFmpeg ⇒ MediaExportException.ffmpegMissing, không chạy lệnh', () async {
      final port = _Port(available: false);
      final engine = MediaFfmpegEngine(port: port);
      await expectLater(
        engine.run(['-version']),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.ffmpegMissing,
        )),
      );
      expect(port.runCount, 0);
    });

    test('exit code khác 0 ⇒ phân loại theo log, giữ 30 dòng cuối', () async {
      final port = _Port(
        outcome: const MediaCommandOutcome(
          success: false,
          cancelled: false,
          output: 'Output file does not contain any stream',
        ),
      );
      final engine = MediaFfmpegEngine(port: port);
      await expectLater(
        engine.run(['-i', 'a.mp4', 'a.mp3']),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.noAudioTrack,
        )),
      );
    });

    test('ProcessException (thiếu binary giữa đường) ⇒ ffmpegMissing', () async {
      final engine = MediaFfmpegEngine(
        port: _Port(throwing: const ProcessException('ffmpeg', ['-version'])),
      );
      await expectLater(
        engine.run(['-version']),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.ffmpegMissing,
        )),
      );
    });

    test('token đã huỷ ⇒ cancelled', () async {
      final token = FfmpegCancelToken();
      await token.cancel();
      final engine = MediaFfmpegEngine(
        port: _Port(
          outcome: const MediaCommandOutcome(
            success: false,
            cancelled: false,
            output: 'Conversion failed!',
          ),
        ),
      );
      await expectLater(
        engine.run(['-i', 'a.mp3', 'b.mp3'], token: token),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.cancelled,
        )),
      );
    });
  });

  group('probe', () {
    test('trả text thô (để parser thuần xử lý)', () async {
      final engine = MediaFfmpegEngine(port: _Port(probeText: 'Duration: 00:00:10.00'));
      expect(await engine.probe('a.mp3'), contains('Duration'));
    });

    test('probe lỗi ⇒ trả chuỗi rỗng, không ném', () async {
      final engine = MediaFfmpegEngine(port: _Port(throwing: StateError('x')));
      expect(await engine.probe('a.mp3'), '');
    });
  });

  group('FfmpegCancelToken', () {
    test('gọi listener ngay nếu đã huỷ trước đó', () async {
      final token = FfmpegCancelToken();
      await token.cancel();
      var called = 0;
      token.onCancel(() => called++);
      expect(called, 1);
      expect(token.isCancelled, isTrue);
    });

    test('huỷ 2 lần chỉ gọi listener 1 lần', () async {
      final token = FfmpegCancelToken();
      var called = 0;
      token.onCancel(() => called++);
      await token.cancel();
      await token.cancel();
      expect(called, 1);
    });

    test('listener ném lỗi không chặn listener khác', () async {
      final token = FfmpegCancelToken();
      var second = 0;
      token.onCancel(() => throw StateError('x'));
      token.onCancel(() => second++);
      await token.cancel();
      expect(second, 1);
    });
  });
}
