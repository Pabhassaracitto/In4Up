// test/media_tools/media_command_builder_test.dart
//
// AVTOOL-002 (PLAN-046 P1) — máy bắt cho argv FFmpeg.
//
// Vì sao test riêng phần này: mọi lỗi thật đã gặp đều nằm ở THỨ TỰ tham số
// ( `-ss` sau `-i` ⇒ cắt sai mốc; thiếu `-map 0:a:0` ⇒ chọn nhầm track lồng
// tiếng; thiếu `-reset_timestamps` ⇒ phần 2+ hiển thị sai thời gian).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/features/media_tools/services/media_command_builder.dart';

void main() {
  group('MediaCommandBuilder — chuyển đổi cả file', () {
    test('chỉ lấy luồng âm thanh đầu tiên và bỏ video/phụ đề', () {
      final args = MediaCommandBuilder.extractAudio(
        inputPath: '/in/movie.mp4',
        outputPath: '/out/movie.mp3',
        preset: MediaExportPreset.mp3Standard,
      );
      expect(args, containsAllInOrder(['-vn', '-sn', '-dn', '-map', '0:a:0']));
      expect(args, containsAllInOrder(['-c:a', 'libmp3lame', '-b:a', '192k']));
      expect(args.first, '-hide_banner');
      expect(args, contains('-nostdin'));
      expect(args, contains('-map_metadata'));
      expect(args.last, '/out/movie.mp3');
    });

    test('không thêm tham số progress trên mobile', () {
      final args = MediaCommandBuilder.extractAudio(
        inputPath: 'in.m4a',
        outputPath: 'out.mp3',
        preset: MediaExportPreset.mp3Voice,
      );
      expect(args, isNot(contains('-progress')));
    });

    test('desktop bật progress qua pipe:2', () {
      final args = MediaCommandBuilder.extractAudio(
        inputPath: 'in.m4a',
        outputPath: 'out.mp3',
        preset: MediaExportPreset.mp3Voice,
        useProgress: true,
      );
      expect(args, containsAllInOrder(['-progress', 'pipe:2', '-nostats']));
      // progress phải đứng TRƯỚC đường dẫn ra.
      expect(args.indexOf('-progress'), lessThan(args.length - 1));
    });
  });

  group('MediaCommandBuilder — cắt đoạn', () {
    test('-ss đứng TRƯỚC -i (cắt nhanh và đúng mốc)', () {
      final args = MediaCommandBuilder.trimAudio(
        inputPath: '/in/a.mp3',
        outputPath: '/out/a.mp3',
        start: const Duration(minutes: 1, seconds: 2, milliseconds: 500),
        duration: const Duration(seconds: 30),
        preset: MediaExportPreset.mp3Standard,
      );
      final ssIndex = args.indexOf('-ss');
      final iIndex = args.indexOf('-i');
      expect(ssIndex, greaterThanOrEqualTo(0));
      expect(iIndex, greaterThan(ssIndex));
      expect(args[ssIndex + 1], '00:01:02.500');
      expect(args, containsAllInOrder(['-t', '00:00:30.000']));
    });

    test('clip mặc định mã hoá lại (không copy) để đúng mốc tới ms', () {
      final args = MediaCommandBuilder.trimAudio(
        inputPath: 'in.m4a',
        outputPath: 'out.mp3',
        start: const Duration(seconds: 3),
        duration: const Duration(seconds: 5),
        preset: MediaExportPreset.mp3Standard,
      );
      expect(args, isNot(contains('copy')));
      expect(args, contains('libmp3lame'));
    });

    test('preset copy thì truyền -c:a copy', () {
      final args = MediaCommandBuilder.trimAudio(
        inputPath: 'in.m4a',
        outputPath: 'out.m4a',
        start: Duration.zero,
        preset: MediaExportPreset.m4aCopy,
      );
      expect(args, containsAllInOrder(['-c:a', 'copy']));
    });

    test('cắt video copy-only giữ nguyên cả hình lẫn tiếng', () {
      final args = MediaCommandBuilder.trimVideo(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        start: const Duration(seconds: 1),
        duration: const Duration(seconds: 2),
      );
      expect(args, containsAllInOrder(['-c', 'copy']));
      expect(args, isNot(contains('-vn')));
    });
  });

  group('MediaCommandBuilder — tách phần', () {
    test('segment có -reset_timestamps 1', () {
      final args = MediaCommandBuilder.splitByDuration(
        inputPath: 'in.mp3',
        outputPattern: 'out-%03d.mp3',
        segmentSeconds: 600,
        preset: MediaExportPreset.mp3Standard,
      );
      expect(args, containsAllInOrder(['-f', 'segment']));
      expect(args, containsAllInOrder(['-segment_time', '600']));
      expect(args, containsAllInOrder(['-reset_timestamps', '1']));
      expect(args.last, 'out-%03d.mp3');
    });

    test('segmentSeconds < 1 được kẹp về 1 (tránh chia vô hạn)', () {
      final args = MediaCommandBuilder.splitByDuration(
        inputPath: 'in.mp3',
        outputPattern: 'p-%d.mp3',
        segmentSeconds: 0,
        preset: MediaExportPreset.mp3Standard,
      );
      expect(args[args.indexOf('-segment_time') + 1], '1');
    });

    test('splitBySlices sinh đúng số lệnh và đúng mốc', () {
      final commands = MediaCommandBuilder.splitBySlices(
        inputPath: 'in.mp3',
        slices: const [
          MediaExportSlice(start: Duration.zero, duration: Duration(minutes: 1)),
          MediaExportSlice(start: Duration(minutes: 1), duration: Duration(minutes: 2)),
        ],
        outputPathFor: (i, slice) => 'part_$i.mp3',
        preset: MediaExportPreset.mp3Standard,
      );
      expect(commands, hasLength(2));
      expect(commands[0].last, 'part_0.mp3');
      expect(commands[1][commands[1].indexOf('-ss') + 1], '00:01:00.000');
    });
  });

  group('MediaCommandBuilder — nối file', () {
    test('escape dấu nháy đơn và đổi \\ thành /', () {
      final content = MediaCommandBuilder.buildConcatList([
        r"C:\Users\me\Don't stop.mp3",
        '/home/me/a b.mp3',
      ]);
      final lines = content.trim().split('\n');
      expect(lines[0], r"file 'C:/Users/me/Don'\''t stop.mp3'");
      expect(lines[1], "file '/home/me/a b.mp3'");
    });

    test('concat copy không kèm tham số codec', () {
      final args = MediaCommandBuilder.concatCopy(
        listFile: 'list.txt',
        outputPath: 'out.m4a',
      );
      expect(args, containsAllInOrder(['-f', 'concat', '-safe', '0']));
      expect(args, containsAllInOrder(['-c', 'copy']));
    });

    test('concat re-encode chuẩn hoá về 44.1 kHz stereo', () {
      final args = MediaCommandBuilder.concatReencode(
        listFile: 'list.txt',
        outputPath: 'out.mp3',
        preset: MediaExportPreset.mp3Standard,
      );
      expect(args, containsAllInOrder(['-ar', '44100']));
      expect(args, containsAllInOrder(['-ac', '2']));
    });
  });

  group('MediaStreamSignature — quyết định copy hay mã hoá lại', () {
    test('giống hệt nhau thì nối bằng copy được', () {
      final list = areConcatCompatible([
        const MediaStreamSignature(codec: 'mp3', sampleRate: 44100, channels: 2),
        const MediaStreamSignature(codec: 'mp3', sampleRate: 44100, channels: 2),
      ]);
      expect(list, isTrue);
    });

    test('khác tần số lấy mẫu ⇒ phải mã hoá lại', () {
      final list = areConcatCompatible([
        const MediaStreamSignature(codec: 'mp3', sampleRate: 44100, channels: 2),
        const MediaStreamSignature(codec: 'mp3', sampleRate: 16000, channels: 1),
      ]);
      expect(list, isFalse);
    });

    test('một file thì luôn \"tương thích\"', () {
      expect(
        areConcatCompatible(const []),
        isTrue,
      );
    });
  });
}
