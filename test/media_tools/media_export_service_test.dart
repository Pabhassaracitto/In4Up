// test/media_tools/media_export_service_test.dart
//
// AVTOOL-002 (PLAN-046 P1) — máy bắt cho TẦNG SERVICE (không cần thiết bị,
// không cần FFmpeg thật): bơm `MediaFfmpegPort` + `MediaExportHost` giả.
//
// Ba thứ đáng kiểm ở đây (những thứ sẽ gây mất dữ liệu nếu sai):
//   1. Không bao giờ để file dở nằm trong thư viện (ghi `.part` rồi đổi tên).
//   2. Huỷ giữa đường ⇒ không đăng ký "Gần đây", không để lại rác.
//   3. Thiếu chỗ ⇒ chặn TRƯỚC khi ghi byte đầu tiên.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/features/media_tools/services/media_export_service.dart';
import 'package:in4up/features/media_tools/services/lrc_time_shifter.dart';
import 'package:in4up/features/media_tools/services/media_ffmpeg_engine.dart';
import 'package:in4up/screens/listen_mode/models/recent_audio.dart';
import 'package:in4up/services/audio_import_service.dart';

/// Cổng FFmpeg giả: ghi file "giả" có nội dung để service kiểm size.
class _FakeEnginePort implements MediaFfmpegPort {
  _FakeEnginePort({
    this.available = true,
    this.failWith,
    this.cancelAfterFirstChunk = false,
    this.probeLog = '',
  });

  bool available;
  String? failWith;
  bool cancelAfterFirstChunk;
  final String probeLog;

  final List<List<String>> commands = [];
  String? lastOutputPath;

  @override
  Future<bool> isAvailable() async => available;

  @override
  String? get binaryPath => '/fake/ffmpeg';

  @override
  Future<String> probe(String inputPath) async => probeLog;

  @override
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    dynamic token,
  }) async {
    commands.add(args);
    final output = args.last;
    lastOutputPath = output;
    onElapsed?.call(500);
    onElapsed?.call(1000);

    if (cancelAfterFirstChunk) {
      return const MediaCommandOutcome(
        success: false,
        cancelled: true,
        output: 'cancel',
      );
    }
    if (failWith != null) {
      return MediaCommandOutcome(
        success: false,
        cancelled: false,
        output: failWith!,
      );
    }
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(4096, 1));
    return const MediaCommandOutcome(
      success: true,
      cancelled: false,
      output: 'ok',
    );
  }
}

class _FakeHost implements MediaExportHost {
  _FakeHost(this.dir);

  final Directory dir;
  final List<RecentAudio> recents = [];
  final Map<String, String> lrcForAudio = {};
  String? sourceLrc;

  @override
  Future<Directory> outputDirectory() async => dir;

  @override
  Future<String> adopt(AudioImportResult result) async => result.path;

  @override
  Future<String> adoptPath({
    required String tempPath,
    required String fileName,
  }) async {
    // Giống `AudioImportService.ensurePersistent`: đưa vào thư mục thư viện
    // riêng, tên cuối cùng không còn `.part`.
    final library = Directory('${dir.path}/library');
    await library.create(recursive: true);
    final target = '${library.path}/$fileName';
    await File(tempPath).rename(target);
    return target;
  }

  @override
  Future<void> addRecent(RecentAudio audio) async => recents.add(audio);

  @override
  Future<void> rememberLrc({
    required String audioPath,
    required String lrcPath,
  }) async {
    lrcForAudio[audioPath] = lrcPath;
  }

  @override
  Future<String?> readSourceLrc(String audioPath) async => sourceLrc;
}

const _probeOk = '''
Input #0, mp3, from 'in.mp3':
  Duration: 00:01:00.00, start: 0.000000, bitrate: 192 kb/s
  Stream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s
''';

void main() {
  late Directory temp;
  late File input;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('in4up_media_test');
    input = File('${temp.path}/in.mp3');
    await input.writeAsBytes(List<int>.filled(1024, 0));
  });

  tearDown(() async {
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } catch (_) {}
  });

  MediaExportService buildService(
    _FakeEnginePort port,
    _FakeHost host, {
    int? freeSpaceMb = 500,
  }) =>
      MediaExportService(
        engine: MediaFfmpegEngine(port: port),
        host: host,
        materializeUri: (uri) async => uri,
        freeSpaceProbe: (_) => freeSpaceMb,
      );

  group('export — xuất cả file', () {
    test('ghi ra file thật, trả size, đăng ký Gần đây', () async {
      final out = Directory('${temp.path}/out');
      final port = _FakeEnginePort(probeLog: _probeOk);
      final host = _FakeHost(out);
      final service = buildService(port, host);

      final result = await service.export(MediaExportRequest(
        inputPath: input.path,
        preset: MediaExportPreset.mp3Standard,
        title: 'Bài giảng',
      ));

      expect(result.outputPaths, hasLength(1));
      expect(File(result.primaryPath).existsSync(), isTrue);
      expect(result.sizeBytes, greaterThan(0));
      expect(result.primaryPath, endsWith('.mp3'));
      expect(host.recents, hasLength(1));
      // Không còn file tạm `.part`.
      final leftovers = out
          .listSync()
          .where((e) => e.path.contains('.part'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('không đăng ký Gần đây khi registerInRecent = false', () async {
      final port = _FakeEnginePort(probeLog: _probeOk);
      final host = _FakeHost(Directory('${temp.path}/out'));
      final service = buildService(port, host);

      await service.export(MediaExportRequest(
        inputPath: input.path,
        preset: MediaExportPreset.mp3Standard,
        registerInRecent: false,
      ));
      expect(host.recents, isEmpty);
    });

    test('FFmpeg lỗi ⇒ MediaExportException đã phân loại, không để rác', () async {
      final out = Directory('${temp.path}/out');
      final port = _FakeEnginePort(
        probeLog: _probeOk,
        failWith: 'Unknown encoder libmp3lame',
      );
      final service = buildService(port, _FakeHost(out));

      await expectLater(
        service.export(MediaExportRequest(
          inputPath: input.path,
          preset: MediaExportPreset.mp3Standard,
        )),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.unsupported,
        )),
      );
      if (out.existsSync()) {
        expect(out.listSync().where((e) => e.path.endsWith('.mp3')), isEmpty);
      }
    });

    test('FFmpeg chưa cài ⇒ ffmpegMissing (không ném lỗi thô)', () async {
      final port = _FakeEnginePort(available: false, probeLog: _probeOk);
      final service = buildService(port, _FakeHost(Directory('${temp.path}/o')));

      await expectLater(
        service.export(MediaExportRequest(
          inputPath: input.path,
          preset: MediaExportPreset.mp3Standard,
        )),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.ffmpegMissing,
        )),
      );
    });

    test('file nguồn không tồn tại ⇒ inputUnreadable', () async {
      final service = buildService(
        _FakeEnginePort(probeLog: _probeOk),
        _FakeHost(Directory('${temp.path}/o')),
      );
      await expectLater(
        service.export(MediaExportRequest(
          inputPath: '${temp.path}/khong-co.mp3',
          preset: MediaExportPreset.mp3Standard,
        )),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.inputUnreadable,
        )),
      );
    });

    test('thiếu dung lượng ⇒ chặn trước khi chạy FFmpeg', () async {
      final port = _FakeEnginePort(probeLog: _probeOk);
      final service = buildService(
        port,
        _FakeHost(Directory('${temp.path}/o')),
        freeSpaceMb: 0,
      );
      await expectLater(
        service.export(MediaExportRequest(
          inputPath: input.path,
          preset: MediaExportPreset.mp3Standard,
        )),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.noSpace,
        )),
      );
      expect(port.commands, isEmpty, reason: 'không được ghi byte nào');
    });
  });

  group('export — cắt đoạn', () {
    test('tên file có mốc và độ dài, đúng scope clip', () async {
      final out = Directory('${temp.path}/out');
      final port = _FakeEnginePort(probeLog: _probeOk);
      final service = buildService(port, _FakeHost(out));

      final result = await service.export(MediaExportRequest(
        inputPath: input.path,
        preset: MediaExportPreset.mp3Standard,
        scope: MediaExportScope.clip,
        start: const Duration(seconds: 10),
        duration: const Duration(seconds: 20),
        title: 'Câu khó',
      ));
      expect(result.primaryPath, contains('Câu khó'));
      expect(result.primaryPath, contains('00-10-00-30'));
      expect(port.commands.single, contains('-ss'));
    });

    test('huỷ ⇒ cancelled, không đăng ký, không để file dở', () async {
      final out = Directory('${temp.path}/out');
      final port = _FakeEnginePort(
        probeLog: _probeOk,
        cancelAfterFirstChunk: true,
      );
      final host = _FakeHost(out);
      final service = buildService(port, host);

      await expectLater(
        service.export(MediaExportRequest(
          inputPath: input.path,
          preset: MediaExportPreset.mp3Standard,
          scope: MediaExportScope.clip,
          start: const Duration(seconds: 1),
          duration: const Duration(seconds: 2),
        )),
        throwsA(isA<MediaExportException>().having(
          (e) => e.kind,
          'kind',
          MediaExportErrorKind.cancelled,
        )),
      );
      expect(host.recents, isEmpty);
      if (out.existsSync()) {
        expect(out.listSync().where((e) => e.path.endsWith('.mp3')), isEmpty);
      }
    });
  });

  group('export — LRC', () {
    test('có LRC nguồn + keepLrc ⇒ ghi .lrc cùng tên và đăng ký', () async {
      final out = Directory('${temp.path}/out');
      final port = _FakeEnginePort(probeLog: _probeOk);
      final host = _FakeHost(out)
        ..sourceLrc = '[00:00.00]a\n[00:10.00]b\n[00:20.00]c\n';
      final service = buildService(port, host);

      final result = await service.export(MediaExportRequest(
        inputPath: input.path,
        preset: MediaExportPreset.mp3Standard,
        scope: MediaExportScope.clip,
        start: const Duration(seconds: 10),
        duration: const Duration(seconds: 10),
        keepLrc: true,
      ));

      expect(result.lrcPaths, hasLength(1));
      final lrc = File(result.lrcPaths.single);
      expect(lrc.existsSync(), isTrue);
      final content = await lrc.readAsString();
      final parsed = LrcTimeShifter.parse(content);
      expect(parsed.map((l) => l.text), ['b', 'c']);
      expect(parsed.first.start, Duration.zero);
      // Dòng nằm ĐÚNG mốc kết thúc vẫn được giữ (dung sai 250 ms — câu nói ngay
      // tại ranh giới cắt là câu quan trọng nhất với clip học tập).
      expect(parsed.last.start, const Duration(seconds: 10));
      expect(content, isNot(contains(']a')));
      expect(
        result.lrcPaths.single.substring(0, result.lrcPaths.single.length - 4),
        result.primaryPath.substring(0, result.primaryPath.length - 4),
      );
      expect(host.lrcForAudio, contains(result.primaryPath));
    });

    test('keepLrc = false ⇒ không sinh file .lrc', () async {
      final port = _FakeEnginePort(probeLog: _probeOk);
      final host = _FakeHost(Directory('${temp.path}/out'))
        ..sourceLrc = '[00:00.00]a\n';
      final service = buildService(port, host);

      final result = await service.export(MediaExportRequest(
        inputPath: input.path,
        preset: MediaExportPreset.mp3Standard,
        keepLrc: false,
      ));
      expect(result.lrcPaths, isEmpty);
    });
  });

  group('export — tách theo chương', () {
    test('mỗi chặng một file, tiến trình báo đúng tổng số chặng', () async {
      final out = Directory('${temp.path}/out');
      final port = _FakeEnginePort(probeLog: _probeOk);
      final service = buildService(port, _FakeHost(out));
      final progress = <MediaExportProgress>[];

      final result = await service.export(
        MediaExportRequest(
          inputPath: input.path,
          preset: MediaExportPreset.mp3Standard,
          scope: MediaExportScope.chapters,
          title: 'Pháp thoại',
          slices: const [
            MediaExportSlice(
              start: Duration.zero,
              duration: Duration(seconds: 20),
              title: 'Mở đầu',
            ),
            MediaExportSlice(
              start: Duration(seconds: 20),
              duration: Duration(seconds: 40),
              title: 'Thân bài',
            ),
          ],
        ),
        onProgress: progress.add,
      );

      expect(result.outputPaths, hasLength(2));
      expect(result.primaryPath, contains('01 Mở đầu'));
      expect(
        result.outputPaths.last,
        contains('02 Thân bài'),
      );
      expect(port.commands, hasLength(2));
      expect(
        progress.where((p) => p.totalSlices == 2),
        isNotEmpty,
        reason: 'UI cần biết tổng số chặng để hiện "Phần 1/2"',
      );
    });
  });

  group('convertOnly', () {
    test('không đăng ký thư viện (dùng cho tiện ích nội bộ)', () async {
      final port = _FakeEnginePort(probeLog: _probeOk);
      final host = _FakeHost(Directory('${temp.path}/out'));
      final service = buildService(port, host);

      // `convertOnly` trả `String` (đường dẫn), không phải MediaExportResult.
      final producedPath = await service.convertOnly(
        inputPath: input.path,
        preset: MediaExportPreset.mp3Voice,
      );
      expect(File(producedPath).existsSync(), isTrue);
      expect(host.recents, isEmpty);
    });
  });

  group('sourceLrcPreview', () {
    test('trả null khi nguồn không có lời', () async {
      final host = _FakeHost(Directory('${temp.path}/out'));
      final service = buildService(_FakeEnginePort(), host);
      expect(await service.sourceLrcPreview(input.path), isNull);
    });
  });
}
