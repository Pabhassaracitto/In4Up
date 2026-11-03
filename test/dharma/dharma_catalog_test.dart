// test/dharma/dharma_catalog_test.dart
//
// AT-1 (phần lập danh mục) + AT-2/AT-3 (nền của "nghe tiếp").
//
// `buildDharmaCatalog` là hàm THUẦN nên test được không cần Hive/plugin.
// Mô phỏng đúng cấu trúc thật của kho Drive Pa Auk:
//   <gốc>/C. Bài giảng…/34. Sayadaw U Kovida …/B1 …mp3
//   <gốc>/A. Kinh tụng…/01. Pa Auk Sayadawgyi Chanting/….

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dharma/models/dharma_talk.dart';
import 'package:in4up/features/dharma/services/dharma_scanner.dart';

DharmaScanEntry entry(String relativePath, {int size = 1024}) {
  return DharmaScanEntry(
    relativePath: relativePath,
    name: relativePath.split('/').last,
    source: '/root/$relativePath',
    sizeBytes: size,
    modifiedAt: DateTime(2024, 12, 13),
  );
}

void main() {
  const cFolder =
      'C. Bài giảng - Pháp thoại các Ngài Thiền Sư - Đã giảng xong';
  const series34 = '$cFolder/34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt';

  group('buildDharmaCatalog', () {
    test('gom theo thư mục, suy ra collection + vị Thầy', () {
      final catalog = buildDharmaCatalog(
        entries: [
          entry('$series34/B1 180324 Hướng dẫn Thiền Niệm Hơi Thở .mp3'),
          entry('$series34/B2 Bojjhaṅga Sutta - Kinh Thất Giác Chi P1 - 190324.mp3'),
          entry('$cFolder/12. Sayalay Dipankara/01. Bài một.mp3'),
        ],
        speakerOverrides: const {},
        rootName: 'Pháp thoại Pa Auk',
      );

      expect(catalog.series.length, 2);
      expect(catalog.episodeCount, 3);

      final kovida = catalog.series.firstWhere(
        (s) => s.speakerGroupKey == 'sayadaw_u_kovida',
      );
      expect(kovida.collection, DharmaCollection.talkArchive);
      expect(kovida.episodes.map((e) => e.episodeStart), [1, 2]);
      expect(kovida.episodes.every((e) => e.episodeKey.startsWith('local:')), isTrue);

      final dipankara = catalog.series.firstWhere(
        (s) => s.speakerGroupKey == 'sayalay_dipankara',
      );
      expect(dipankara.episodeCount, 1);
    });

    test('nhóm theo vị Thầy gộp nhiều series của cùng một người (F5)', () {
      final catalog = buildDharmaCatalog(
        entries: [
          entry('$cFolder/21. Sayadaw U Kovida - Giác Chi 2019/01.mp3'),
          entry('$cFolder/34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt/B1.mp3'),
          entry('$cFolder/37. Cẩm Nang Cho Thiền Sinh - SU Kovida Nepal 25/01.mp3'),
        ],
        speakerOverrides: const {},
      );

      final groups = catalog.groupBySpeaker();
      expect(groups.keys, contains('sayadaw_u_kovida'));
      expect(groups['sayadaw_u_kovida']!.length, 3,
          reason: 'Kovida/SU Kovida phải gộp còn MỘT nhóm');
    });

    test('sắp xếp series theo collection rồi số thứ tự (không theo lexicographic)', () {
      final catalog = buildDharmaCatalog(
        entries: [
          entry('$cFolder/39. TÓM TẮT MANGALA/B1.mp3'),
          entry('$cFolder/02. Sayadaw U Kovida - Thanh tịnh đạo/B1.mp3'),
          entry('A. Kinh tụng truyền thống Pa Auk/01. Pa Auk Sayadawgyi Chanting/01.mp3'),
          entry('$cFolder/21. Sayadaw U Kovida - Giác Chi 2019/01.mp3'),
        ],
        speakerOverrides: const {},
      );

      final order = catalog.series.map((s) => s.orderIndex).toList();
      expect(order.first, 1, reason: 'Kinh tụng (collection A) đứng trước');
      expect(order.sublist(1), [2, 21, 39]);
    });

    test('file nằm ngay ở thư mục gốc không bị bỏ sót', () {
      final catalog = buildDharmaCatalog(
        entries: [entry('Bai giang le.mp3')],
        speakerOverrides: const {},
        rootName: 'Pháp thoại Pa Auk',
      );
      expect(catalog.series.length, 1);
      expect(catalog.series.first.title, 'Pháp thoại Pa Auk');
      expect(catalog.episodeCount, 1);
    });

    test('sửa tay tên vị Thầy (theo seriesKey) được áp dụng khi quét', () {
      final base = buildDharmaCatalog(
        entries: [entry('$series34/B1.mp3')],
        speakerOverrides: const {},
      );
      final key = base.series.first.seriesKey;
      final edited = buildDharmaCatalog(
        entries: [entry('$series34/B1.mp3')],
        speakerOverrides: {key: 'Ngài Kovida (sửa tay)'},
      );
      expect(edited.series.first.speakerDisplay, 'Ngài Kovida (sửa tay)');
      expect(edited.series.first.speakerGroupKey, 'ngai_kovida_sua_tay');
    });

    test('findEpisode tra được buổi theo episodeKey', () {
      final catalog = buildDharmaCatalog(
        entries: [
          entry('$series34/B1 180324 Hướng dẫn.mp3'),
          entry('$series34/B2 Bojjhaṅga.mp3'),
        ],
        speakerOverrides: const {},
      );
      final target = catalog.series.first.episodes.last;
      expect(catalog.findEpisode(target.episodeKey)?.title, target.title);
      expect(catalog.findSeriesOfEpisode(target.episodeKey), isNotNull);
      expect(catalog.findEpisode('local:khong-ton-tai'), isNull);
    });

    test('cùng tên file ở hai series khác nhau ⇒ episodeKey KHÁC nhau', () {
      final catalog = buildDharmaCatalog(
        entries: [
          entry('$cFolder/21. Sayadaw U Kovida - Giác Chi 2019/01.mp3'),
          entry('$cFolder/34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt/01.mp3'),
        ],
        speakerOverrides: const {},
      );
      final keys = <String>{};
      for (final s in catalog.series) {
        for (final e in s.episodes) {
          keys.add(e.episodeKey);
        }
      }
      expect(keys.length, 2, reason: 'khoá phải phân biệt được hai bài cùng tên');
    });

    test('catalog rỗng khi không có file audio', () {
      final catalog = buildDharmaCatalog(
        entries: const <DharmaScanEntry>[],
        speakerOverrides: const {},
      );
      expect(catalog.isEmpty, isTrue);
      expect(catalog.series, isEmpty);
    });
  });

  group('DharmaProgress (AT-2: nghe tiếp)', () {
    test('chưa đủ dữ liệu thì không kết luận "xong"', () {
      const p = DharmaProgress(
        episodeKey: 'k',
        lastPosition: Duration(minutes: 10),
        duration: Duration.zero,
      );
      expect(p.isCompleted, isFalse);
      expect(p.isInProgress, isTrue);
    });

    test('còn ≤30 giây cuối ⇒ xong (bài dài)', () {
      const p = DharmaProgress(
        episodeKey: 'k',
        lastPosition: Duration(minutes: 57, seconds: 40),
        duration: Duration(minutes: 58),
      );
      expect(p.isCompleted, isTrue);
    });

    test('bài ngắn dùng ngưỡng 20% để không "xong" quá sớm', () {
      expect(
        DharmaProgress.isFinished(
          position: const Duration(seconds: 40),
          duration: const Duration(seconds: 50),
        ),
        isTrue,
      );
      expect(
        DharmaProgress.isFinished(
          position: const Duration(seconds: 20),
          duration: const Duration(seconds: 50),
        ),
        isFalse,
      );
    });

    test('đánh dấu tay thắng mọi suy luận', () {
      const p = DharmaProgress(
        episodeKey: 'k',
        lastPosition: Duration(minutes: 1),
        duration: Duration(minutes: 60),
        completedManually: true,
      );
      expect(p.isCompleted, isTrue);
      expect(p.isInProgress, isFalse);
    });

    test('round-trip JSON giữ nguyên vị trí và thời lượng (AT-3)', () {
      final p = DharmaProgress(
        episodeKey: 'local:abc',
        lastPosition: const Duration(minutes: 12, seconds: 34),
        duration: const Duration(minutes: 58),
        lastPlayedAt: DateTime(2026, 11, 3, 10, 30),
      );
      final restored = DharmaProgress.fromJson(p.toJson());
      expect(restored.lastPosition, p.lastPosition);
      expect(restored.duration, p.duration);
      expect(restored.lastPlayedAt, p.lastPlayedAt);
      expect(restored.isInProgress, isTrue);
    });

    test('series round-trip JSON giữ nguyên episodeKey, kể cả ký tự Pāḷi', () {
      final catalog = buildDharmaCatalog(
        entries: [
          entry('$series34/B10 Hỷ giác chi Ân Đức Tăng Bảo - Bojjhaṅga Sutta.mp3'),
        ],
        speakerOverrides: const {},
      );
      final original = catalog.series.first;
      final restored = DharmaSeries.fromJson(original.toJson());
      expect(restored.seriesKey, original.seriesKey);
      expect(restored.speakerKey, 'sayadaw_u_kovida');
      expect(restored.episodes.single.episodeKey,
          original.episodes.single.episodeKey);
      expect(restored.episodes.single.rawName,
          'B10 Hỷ giác chi Ân Đức Tăng Bảo - Bojjhaṅga Sutta.mp3');
    });
  });
}
