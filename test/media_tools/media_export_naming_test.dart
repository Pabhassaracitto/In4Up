// test/media_tools/media_export_naming_test.dart
//
// AVTOOL-002 (PLAN-047 P1) — máy bắt cho tên file xuất ra.
//
// Quy tắc: (1) GIỮ dấu tiếng Việt (tên file là thứ người dùng nhìn thấy),
// (2) không có ký tự làm hỏng FAT/exFAT/Windows, (3) không ghi đè file cũ,
// (4) tên clip/chương phải tự giải thích nội dung.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/services/media_export_naming.dart';

void main() {
  group('sanitize', () {
    test('giữ nguyên dấu tiếng Việt', () {
      expect(
        MediaExportNaming.sanitize('Bài giảng số 1 - Tứ niệm xứ'),
        'Bài giảng số 1 - Tứ niệm xứ',
      );
    });

    test('loại ký tự nguy hiểm cho hệ tệp', () {
      expect(
        MediaExportNaming.sanitize(r'Bài: giảng / phần 2 * hay?'),
        'Bài giảng phần 2 hay',
      );
    });

    test('bỏ dấu chấm ở cuối (Windows tự cắt ⇒ lệch tên)', () {
      expect(MediaExportNaming.sanitize('Bài giảng...'), 'Bài giảng');
    });

    test('rỗng hoặc toàn ký tự xấu ⇒ tên mặc định', () {
      expect(MediaExportNaming.sanitize(''), 'audio');
      expect(MediaExportNaming.sanitize('///'), 'audio');
      expect(MediaExportNaming.sanitize('  ..  '), 'audio');
    });

    test('cắt rất dài về giới hạn an toàn', () {
      final long = 'a' * 300;
      expect(
        MediaExportNaming.sanitize(long).length,
        lessThanOrEqualTo(MediaExportNaming.maxBaseLength),
      );
    });
  });

  group('clipBaseName', () {
    test('có mốc bắt đầu và kết thúc, không dùng dấu hai chấm', () {
      final name = MediaExportNaming.clipBaseName(
        sourceTitle: 'Kinh Pháp Cú.mp3',
        start: const Duration(minutes: 1, seconds: 5),
        duration: const Duration(seconds: 30),
      );
      expect(name, 'Kinh Pháp Cú [01:05-01:35]'.replaceAll(':', '-'));
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('.mp3')));
    });

    test('clip ngắn hơn 1 giờ không có phần giờ', () {
      final name = MediaExportNaming.clipBaseName(
        sourceTitle: 'a.mp3',
        start: const Duration(minutes: 2, seconds: 3),
        duration: const Duration(seconds: 4),
      );
      expect(name, 'a [02-03:02-07]'.replaceAll(':', '-'));
    });

    test('dài hơn 1 giờ có phần giờ', () {
      final name = MediaExportNaming.clipBaseName(
        sourceTitle: 'a.mp3',
        start: const Duration(hours: 1, minutes: 2, seconds: 3),
        duration: null,
      );
      expect(name, startsWith('a [01-02-03'));
    });
  });

  group('chapterBaseName', () {
    test('có số thứ tự 2 chữ số + tiêu đề chương', () {
      final name = MediaExportNaming.chapterBaseName(
        sourceTitle: 'Pháp thoại.mp3',
        index: 4,
        chapterTitle: 'Phần mở đầu',
      );
      expect(name, 'Pháp thoại - 05 Phần mở đầu');
    });

    test('chương không có tiêu đề ⇒ dùng mốc thời gian', () {
      final name = MediaExportNaming.chapterBaseName(
        sourceTitle: 'a.mp3',
        index: 0,
        start: const Duration(minutes: 1),
      );
      expect(name, 'a - 01 01-00');
    });

    test('chương không có cả tiêu đề lẫn mốc ⇒ "Phần NN"', () {
      expect(
        MediaExportNaming.chapterBaseName(sourceTitle: 'a.mp3', index: 2),
        'a - Phần 03',
      );
    });
  });

  group('uniqueFileName', () {
    test('file đầu tiên giữ nguyên tên', () {
      expect(
        MediaExportNaming.uniqueFileName(
          baseName: 'Bài',
          extension: 'mp3',
          directory: '/out',
          exists: (_) => false,
        ),
        '/out/Bài.mp3',
      );
    });

    test('trùng tên ⇒ thêm (2), (3)… không ghi đè', () {
      final taken = {'/out/Bài.mp3', '/out/Bài (2).mp3'};
      expect(
        MediaExportNaming.uniqueFileName(
          baseName: 'Bài',
          extension: '.mp3',
          directory: '/out',
          exists: taken.contains,
        ),
        '/out/Bài (3).mp3',
      );
    });
  });

  group('segmentPattern', () {
    test('có %03d để segment muxer tự đánh số', () {
      expect(
        MediaExportNaming.segmentPattern(
          directory: '/out',
          baseName: 'Pháp thoại',
          extension: 'mp3',
        ),
        '/out/Pháp thoại_%03d.mp3',
      );
    });
  });

  group('concatListPath', () {
    test('nằm trong thư mục tạm và có đuôi .txt', () {
      final path = MediaExportNaming.concatListPath('/tmp');
      expect(path, startsWith('/tmp/in4up_concat_'));
      expect(path, endsWith('.txt'));
    });
  });
}
