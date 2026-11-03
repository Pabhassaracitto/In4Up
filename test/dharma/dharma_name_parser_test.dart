// test/dharma/dharma_name_parser_test.dart
//
// AT-1 (PLAN-042 §11) — máy bắt cho bộ phân tích tên.
//
// Dữ liệu là TÊN THẬT lấy từ kho Drive công khai ngày 2026-11-03 (xem
// `test/fixtures/dharma_drive_names.csv`). Mỗi test dưới đây tương ứng một bẫy
// đã thực sự xảy ra khi viết probe Python (PLAN-042 §3.3 F1..F10) — nếu ai sửa
// parser mà đảo thứ tự luật, các test này đỏ ngay.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dharma/models/dharma_talk.dart';
import 'package:in4up/features/dharma/services/dharma_name_parser.dart';
import 'package:in4up/features/dharma/services/dharma_text.dart';

const parser = DharmaNameParser();

void main() {
  group('danh tính & tiện ích chuỗi', () {
    test('isDharmaAudioFile lọc rác hệ điều hành và giữ đuôi audio', () {
      expect(isDharmaAudioFile('B1 180324 Hướng dẫn.mp3'), isTrue);
      expect(isDharmaAudioFile('lesson.M4A'), isTrue);
      expect(isDharmaAudioFile('desktop.ini'), isFalse);
      expect(isDharmaAudioFile('Phu luc 14-Dec-2024.csv'), isFalse);
      expect(isDharmaAudioFile('Sách - Ebook.pdf'), isFalse);
      expect(isDharmaAudioFile('khong-co-duoi'), isFalse);
      expect(isDharmaAudioFile('.hidden.mp3'), isFalse);
    });

    test('foldDiacritics giữ cùng một vị Thầy về cùng khoá (F5)', () {
      final variants = [
        'Sayadaw U Revata',
        'Sayadaw U Reveta',
        'sayadaw u revata',
      ];
      final keys = variants.map(searchKey).toSet();
      expect(keys.length, 1, reason: 'Cùng vị Thầy phải cùng khoá: $keys');

      expect(searchKey('Sayadaw U Kumārābhivaṃsa'), 'sayadaw_u_kumarabhivamsa');
      expect(searchKey('Pa Auk Sayadawgyi'), 'pa_auk_sayadawgyi');
      expect(searchKey('Đà Lạt'), 'da_lat');
      expect(searchKey('Bojjhaṅga Sutta'), 'bojjhanga_sutta');
    });

    test('naturalCompare đặt B2 trước B10 (F1 — thứ tự Drive sai)', () {
      final files = [
        'B10 Hỷ giác chi.mp3',
        'B2 Bojjhaṅga Sutta.mp3',
        'B13 Định giác chi.mp3',
        'B1 180324.mp3',
      ]..sort(naturalCompare);
      expect(files, [
        'B1 180324.mp3',
        'B2 Bojjhaṅga Sutta.mp3',
        'B10 Hỷ giác chi.mp3',
        'B13 Định giác chi.mp3',
      ]);
    });
  });

  group('parseEpisode — tên file thật', () {
    test('B1 + ngày ddMMyy: tách được số buổi, ngày, tiêu đề sạch (F2/F10)', () {
      final info = parser.parseEpisode('B1 180324 Hướng dẫn Thiền Niệm Hơi Thở .mp3');
      expect(info.episodeStart, 1);
      expect(info.date, DateTime(2024, 3, 18));
      expect(info.dateConfident, isTrue);
      // F10: token ngày KHÔNG được lọt vào tiêu đề.
      expect(info.title, 'Hướng dẫn Thiền Niệm Hơi Thở');
      expect(info.rawName, 'B1 180324 Hướng dẫn Thiền Niệm Hơi Thở .mp3');
    });

    test('tiền tố "01." (kiểu cũ) + ngày 6 số', () {
      final info = parser.parseEpisode('01.Satisambhojjhanga Niệm Giác Chi 150919.mp3');
      expect(info.episodeStart, 1);
      expect(info.date, DateTime(2019, 9, 15));
      expect(info.title, 'Satisambhojjhanga Niệm Giác Chi');
    });

    test('range "05-06." phải ra 2 buổi và không để "06." trong tiêu đề (F3/F9)', () {
      final info = parser.parseEpisode('05-06. 5 Quyền - Phần 3-4 (52).mp3');
      expect(info.episodeStart, 5);
      expect(info.episodeEnd, 6);
      expect(info.durationHintMin, 52);
      expect(info.title, '5 Quyền - Phần 3-4');
      expect(info.title.startsWith('06'), isFalse);
    });

    test('"(54 phút)" là gợi ý thời lượng, bị bỏ khỏi tiêu đề (F4)', () {
      final info = parser
          .parseEpisode('03. 5 Quyền Tín - Tấn - Niệm - Định - Tuệ Phần 1 (54 phút) - end sound.mp3');
      expect(info.durationHintMin, 54);
      expect(info.part, 1);
      expect(info.housekeeping, isTrue, reason: '"- end sound" phải thành cờ (F7)');
      expect(info.title.contains('54'), isFalse);
      expect(info.title.toLowerCase().contains('end sound'), isFalse);
    });

    test('"phần cuối(60)" vẫn giữ được gợi ý thời lượng', () {
      final info = parser.parseEpisode('10. 5 quyền - phần cuối(60).mp3');
      expect(info.durationHintMin, 60);
      expect(info.episodeStart, 10);
    });

    test('"Phần N" lấy mốc CUỐI (B12 có P1 ở giữa tên)', () {
      final info = parser
          .parseEpisode('B12 Khinh an và Định(P1) giác chi - Bojjhaṅga Sutta - Kinh Thất Giác Chi P11 .mp3');
      expect(info.episodeStart, 12);
      expect(info.part, 11);
    });

    test('"A-01." (mã nội bộ) vẫn ra số buổi 1', () {
      final info = parser.parseEpisode('01. A-01. Hướng dẫn Niệm hơi thở căn bản.mp3');
      expect(info.episodeStart, 1);
      expect(info.title, 'Hướng dẫn Niệm hơi thở căn bản');
    });

    test('không bịa ngày khi tên không có ngày hợp lệ', () {
      final info = parser.parseEpisode('10.Hỷ Giác Chi-Ân Đức Tăng Bảo 201119.mp3');
      expect(info.date, DateTime(2019, 11, 20));
      // '12.Hỷ Giác Chi-Niệm Thiên,Niết Bàn.mp3' — không có ngày.
      final noDate = parser.parseEpisode('12.Hỷ Giác Chi-Niệm Thiên,Niết Bàn.mp3');
      expect(noDate.date, isNull);
      expect(noDate.episodeStart, 12);
    });
  });

  group('parseSeries — tên thư mục thật', () {
    test('số thứ tự + năm + vị Thầy', () {
      final info = parser.parseSeries('34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt');
      expect(info.orderIndex, 34);
      expect(info.year, 2024);
      expect(info.speakerKey, 'sayadaw_u_kovida');
      expect(info.speakerDisplay, 'Sayadaw U Kovida');
      expect(info.language, DharmaLanguage.vi);
    });

    test('song ngữ phải xét TRƯỚC "vi" (F8)', () {
      final info = parser.parseSeries('33. Sayadaw U Kovida Khoá thiền Phước Sơn 2024 - Song ngữ');
      expect(info.language, DharmaLanguage.bilingual);
      expect(info.venue, 'Phước Sơn');
    });

    test('"En-Vi" là song ngữ, không phải vi', () {
      final info = parser.parseSeries('17. Vinaya - Luat tap yeu En-Vi - Sayadaw U Kuṇḍadhāna 2022');
      expect(info.language, DharmaLanguage.bilingual);
    });

    test('alias "SU Kovida" và "Ngài U Kovida" về cùng một vị Thầy (F5)', () {
      final su = parser.parseSeries('37. Cẩm Nang Cho Thiền Sinh - SU Kovida Nepal 25');
      expect(su.speakerKey, 'sayadaw_u_kovida');
      expect(su.speakerDisplay, 'Sayadaw U Kovida');
      expect(su.venue, 'Nepal');
    });

    test('alias "Reveta" → Revata và "Pa-Auk Sayadawgyi" → Pa Auk Sayadawgyi', () {
      expect(
        parser.parseSeries('05. Sayadaw U Reveta Chanting').speakerDisplay,
        'Sayadaw U Revata',
      );
      expect(
        parser.parseSeries('01. Pa-Auk Sayadawgyi giảng Da Lat 2014').speakerKey,
        'pa_auk_sayadawgyi',
      );
    });

    test('Sayalay cũng là vị Thầy', () {
      final info = parser.parseSeries('12. Sayalay Dipankara');
      expect(info.speakerKey, 'sayalay_dipankara');
      expect(info.orderIndex, 12);
    });

    test('nhận chủ đề Pāḷi và giữ nguyên tên gốc', () {
      final info = parser.parseSeries(
        '39. TÓM TẮT CÁC ĐIỀU PHƯỚC LÀNH TRONG KINH MANGALA SUTTA',
      );
      expect(info.topic, 'Mangala Sutta');
      expect(info.rawName,
          '39. TÓM TẮT CÁC ĐIỀU PHƯỚC LÀNH TRONG KINH MANGALA SUTTA');
    });

    test('collection suy ra từ đường dẫn gốc A..G', () {
      expect(DharmaNameParser.collectionBelow('A. Kinh tụng truyền thống Pa Auk'),
          DharmaCollection.chanting);
      expect(DharmaNameParser.collectionBelow('B. Sách nói các Ngài Thiền Sư'),
          DharmaCollection.audiobook);
      expect(
        DharmaNameParser.collectionBelow(
            'C. Bài giảng - Pháp thoại các Ngài Thiền Sư - Đã giảng xong'),
        DharmaCollection.talkArchive,
      );
      expect(DharmaNameParser.collectionBelow('D. Pháp thoại đang giảng'),
          DharmaCollection.talkOngoing);
    });
  });

  group('buildSeries', () {
    test('sắp xếp buổi theo số (B2 trước B10) và giữ tên gốc', () {
      final series = parser.buildSeries(
        folderName: '34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt',
        relativeFolder:
            'C. Bài giảng - Pháp thoại các Ngài Thiền Sư - Đã giảng xong/34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt',
        seriesKey: 'local:abc',
        files: const [
          DharmaFileRef(
            name: 'B10 Hỷ giác chi Ân Đức Tăng Bảo - Bojjhaṅga Sutta - Kinh Thất Giác Chi P9 270324.mp3',
            source: '/x/B10.mp3',
            episodeKey: 'local:b10',
          ),
          DharmaFileRef(
            name: 'B2 Bojjhaṅga Sutta - Kinh Thất Giác Chi P1 - 190324.mp3',
            source: '/x/B2.mp3',
            episodeKey: 'local:b2',
          ),
        ],
      );

      expect(series.collection, DharmaCollection.talkArchive);
      expect(series.speakerKey, 'sayadaw_u_kovida');
      expect(series.episodes.map((e) => e.episodeStart), [2, 10]);
      expect(series.episodes.first.rawName, startsWith('B2 '));
      expect(series.episodeCount, 2);
    });

    test('bỏ file không phải audio (desktop.ini, csv)', () {
      final series = parser.buildSeries(
        folderName: '21. Sayadaw U Kovida - Giác Chi 2019',
        relativeFolder: 'C./21. Sayadaw U Kovida - Giác Chi 2019',
        seriesKey: 'local:def',
        files: const [
          DharmaFileRef(
            name: 'desktop.ini',
            source: '/x/desktop.ini',
            episodeKey: 'local:ini',
          ),
          DharmaFileRef(
            name: 'Phu luc.csv',
            source: '/x/a.csv',
            episodeKey: 'local:csv',
          ),
          DharmaFileRef(
            name: '01.Satisambhojjhanga Niệm Giác Chi 150919.mp3',
            source: '/x/01.mp3',
            episodeKey: 'local:01',
          ),
        ],
      );
      expect(series.episodeCount, 1);
    });

    test('sửa tay tên vị Thầy thắng parser', () {
      final series = parser.buildSeries(
        folderName: '12. Sayalay Dipankara',
        relativeFolder: 'C./12. Sayalay Dipankara',
        seriesKey: 'local:ghi',
        files: const [],
        speakerOverride: 'Sư Bà Dipankara',
      );
      expect(series.speakerDisplay, 'Sư Bà Dipankara');
      expect(series.speakerKey, 'su_ba_dipankara');
      // Tên gốc vẫn còn để đối chiếu.
      expect(series.rawName, '12. Sayalay Dipankara');
    });
  });
}
