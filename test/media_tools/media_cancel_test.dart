// test/media_tools/media_cancel_test.dart
//
// AVTOOL-003 (PLAN-047 P2) — máy bắt cho ĐƯỜNG HUỶ.
//
// Vì sao cần riêng một file: bug "bấm Huỷ vài giây sau khi bắt đầu thì không
// merge được / dialog quay mãi" đến từ 3 chỗ khác nhau, và cả 3 đều KHÔNG bị
// test cũ bắt vì test cũ chỉ kiểm nhánh "FFmpeg trả về cancelled":
//   1. token không được kiểm ở các bước trước FFmpeg (materialize/probe) ⇒
//      huỷ sớm bị bỏ qua, service chạy tiếp.
//   2. `finally` dọn dẹp vô dụng (`produced` còn rỗng khi `_runSingle` ném) ⇒
//      chương đã xuất xong nằm lại trong thư viện của lần xuất bị huỷ.
//   3. `cancel()` native không trả lời ⇒ UI treo (kiểm ở tầng service là đủ:
//      ui chỉ cần service dứt điểm).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/features/media_tools/services/media_export_service.dart';
import 'package:in4up/features/media_tools/services/media_ffmpeg_engine.dart';
import 'package:in4up_stt/utils/src/ffmpeg_runner.dart';
import 'package:in4up/screens/listen_mode/models/recent_audio.dart';
import 'package:in4up/services/audio_import_service.dart';

/// Cổng FFmpeg giả "chậm": mỗi lệnh gọi [onSlowStep] để test có thể huỷ
/// ĐÚNG lúc service đang ở giữa đường, rồi mới trả kết quả.
class _SlowPort implements MediaFfmpegPort {
  _SlowPort({
    required this.onProbe,
    required this.onRun,
    this.writeFile = true,
  });

  final Future<void> Function()? onProbe;
  final Future<void> Function(int index)? onRun;
  final bool writeFile;

  final List<List<String>> commands = [];
  int _runs = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  String? get binaryPath => '/fake/ffmpeg';

  @override
  Future<String> probe(String inputPath) async {
    await onProbe?.call();
    return _probeOk;
  }

  @override
  Future<MediaCommandOutcome> run(
    List<String> args, {
    void Function(int elapsedMs)? onElapsed,
    FfmpegCancelToken? token,
  }) async {
    final index = _runs++;
    commands.add(args);
    if (writeFile) {
      final file = File(args.last);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(4096, 1));
    }
    await onRun?.call(index);
    if (token?.isCancelled ?? false) {
      return const MediaCommandOutcome(
        success: false,
        cancelled: true,
        output: 'cancelled',
      );
    }
    return const MediaCommandOutcome(
      success: true,
      cancelled: false,
      output: 'ok',
    );
  }
}

class _Host implements MediaExportHost {
  _Host(this.dir);

  final Directory dir;
  final List<RecentAudio> recents = [];

  @override
  Future<Directory> outputDirectory() async => dir;

  @override
  Future<String> adopt(AudioImportResult result) async => result.path;

  @override
  Future<String> adoptPath({
    required String tempPath,
    required String fileName,
  }) async {
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
  }) async {}

  @override
  Future<String?> readSourceLrc(String audioPath) async => null;
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
    temp = await Directory.systemTemp.createTemp('in4up_cancel_test');
    input = File('${temp.path}/in.mp3');
    await input.writeAsBytes(List<int>.filled(1024, 0));
  });

  tearDown(() async {
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } catch (_) {}
  });

  MediaExportService build(_SlowPort port, _Host host) => MediaExportService(
        engine: MediaFfmpegEngine(port: port),
        host: host,
        materializeUri: (uri) async => uri,
        freeSpaceProbe: (_) => 500,
      );

  Matcher throwsCancelled() => throwsA(isA<MediaExportException>()
      .having((e) => e.kind, 'kind', MediaExportErrorKind.cancelled));

  group('huỷ TRƯỚC khi chạy FFmpeg', () {
    test('huỷ trong lúc probe ⇒ dừng ngay, không chạy lệnh nào', () async {
      final token = FfmpegCancelToken();
      final host = _Host(Directory('${temp.path}/out'));
      final port = _SlowPort(
        onProbe: () async => token.cancel(),
        onRun: (_) async {},
      );

      await expectLater(
        build(port, host).export(
          MediaExportRequest(
            inputPath: input.path,
            preset: MediaExportPreset.mp3Standard,
          ),
          token: token,
        ),
        throwsCancelled(),
      );

      expect(port.commands, isEmpty,
          reason: 'huỷ trước khi chạy thì không được gọi FFmpeg');
      expect(host.recents, isEmpty);
    });

    test('huỷ khi token đã huỷ từ trước ⇒ cancelled ngay, không side effect',
        () async {
      final token = FfmpegCancelToken();
      await token.cancel();
      final host = _Host(Directory('${temp.path}/out2'));
      final port = _SlowPort(onProbe: null, onRun: (_) async {});

      await expectLater(
        build(port, host).export(
          MediaExportRequest(
            inputPath: input.path,
            preset: MediaExportPreset.mp3Standard,
          ),
          token: token,
        ),
        throwsCancelled(),
      );
      expect(host.recents, isEmpty);
    });
  });

  group('huỷ GIỮA đường', () {
    test('huỷ trong lúc FFmpeg chạy ⇒ cancelled, không đăng ký Gần đây',
        () async {
      final token = FfmpegCancelToken();
      final host = _Host(Directory('${temp.path}/out3'));
      final port = _SlowPort(
        onProbe: null,
        onRun: (_) async => token.cancel(),
      );

      await expectLater(
        build(port, host).export(
          MediaExportRequest(
            inputPath: input.path,
            preset: MediaExportPreset.mp3Standard,
            scope: MediaExportScope.clip,
            start: const Duration(seconds: 1),
            duration: const Duration(seconds: 2),
          ),
          token: token,
        ),
        throwsCancelled(),
      );

      expect(host.recents, isEmpty);
      final leftovers = Directory('${temp.path}/out3')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.contains('.part'))
          .toList();
      expect(leftovers, isEmpty, reason: 'không được để lại file .part');
    });

    test('huỷ ở chương thứ 2 ⇒ chương 1 đã xuất cũng bị dọn', () async {
      final token = FfmpegCancelToken();
      final out = Directory('${temp.path}/out4');
      final host = _Host(out);
      // Chương 0 chạy xong bình thường; chương 1 mới huỷ.
      final port = _SlowPort(
        onProbe: null,
        onRun: (index) async {
          if (index == 1) await token.cancel();
        },
      );

      await expectLater(
        build(port, host).export(
          MediaExportRequest(
            inputPath: input.path,
            preset: MediaExportPreset.mp3Standard,
            scope: MediaExportScope.chapters,
            slices: const [
              MediaExportSlice(
                start: Duration.zero,
                duration: Duration(seconds: 10),
                title: 'Một',
              ),
              MediaExportSlice(
                start: Duration(seconds: 10),
                duration: Duration(seconds: 10),
                title: 'Hai',
              ),
            ],
          ),
          token: token,
        ),
        throwsCancelled(),
      );

      expect(host.recents, isEmpty);
      // Cả file chương 1 (đã chuyển sang thư viện) lẫn chương 0 phải bị xoá:
      // một lần xuất bị huỷ không được để lại NỬA kết quả.
      final files = out.existsSync()
          ? out.listSync(recursive: true).whereType<File>().toList()
          : <File>[];
      expect(files.where((f) => f.path.endsWith('.mp3')), isEmpty);
    });
  });
}
