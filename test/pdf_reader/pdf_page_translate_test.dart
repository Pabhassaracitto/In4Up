// PLAN-035 · KANBAN XLAT-SCR-001 — Dịch màn hình trong PDF Reader.
//
// Khoá lại hành vi của phần "não" (`services/pdf_page_translate.dart`):
//  - cuesToTranslationSeeds: chỉ giữ cue dùng được, giữ đúng original/bounds;
//  - translatePdfPageUnits: dịch tuần tự, lỗi không giết cả trang nhưng 5 lỗi
//    liên tiếp thì dừng (mirror translateAll), shouldStop hủy từ ngoài;
//  - splitOcrTextIntoUnits: ngắt theo đoạn trống, gom câu theo budget, cắt
//    cứng khi câu không có dấu chấm.
//
// Thuần Dart: translator là closure giả — không cần TranslationService.

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/models/pdf_page_translation.dart';
import 'package:in4up/features/pdf_reader/models/pdf_sentence_cue.dart';
import 'package:in4up/features/pdf_reader/services/pdf_page_translate.dart';

PdfSentenceCue _cue(
  int pageIndex,
  String text, {
  bool usable = true,
}) {
  return PdfSentenceCue(
    pageIndex: pageIndex,
    startOffset: 0,
    endOffset: text.length,
    speakText: text,
    lineRects: usable ? [const Rect.fromLTWH(10, 20, 30, 5)] : const [],
  );
}

void main() {
  group('cuesToTranslationSeeds', () {
    test('chỉ giữ cue dùng được (isUsable), giữ nguyên original + bounds',
        () {
      final cues = [
        _cue(3, 'Câu đầu.'),
        _cue(3, 'x', usable: false), // 1 ký tự → không usable
        _cue(3, 'Câu thứ hai.'),
      ];
      final seeds = cuesToTranslationSeeds(3, cues);

      expect(seeds.length, 2);
      expect(seeds[0].original, 'Câu đầu.');
      expect(seeds[0].pageIndex, 3);
      expect(seeds[0].bounds, const Rect.fromLTWH(10, 20, 30, 5));
      expect(seeds[0].translation, isNull);
      expect(seeds[1].original, 'Câu thứ hai.');
    });

    test('cue không usable bị loại hết → seeds rỗng (caller rơi sang OCR)',
        () {
      final seeds = cuesToTranslationSeeds(0, [
        _cue(0, 'a', usable: false),
        _cue(0, '', usable: false),
      ]);
      expect(seeds, isEmpty);
    });
  });

  group('translatePdfPageUnits', () {
    test('dịch tuần tự đủ số câu, gắn bản dịch đúng từng câu', () async {
      final seeds = [
        PdfPageSentenceTranslation(
            pageIndex: 2, original: 'One.', bounds: Rect.zero),
        PdfPageSentenceTranslation(
            pageIndex: 2, original: 'Two.', bounds: Rect.zero),
      ];

      final progress = <int>[];
      final report = await translatePdfPageUnits(
        pageIndex: 2,
        seeds: seeds,
        translate: (text) async => 'VI[$text]',
        onProgress: (done, total) => progress.add(done),
        delayBetween: Duration.zero,
      );

      expect(report.translatedCount, 2);
      expect(report.failedCount, 0);
      expect(report.stoppedEarly, isFalse);
      expect(report.translations[0].translation, 'VI[One.]');
      expect(report.translations[1].translation, 'VI[Two.]');
      expect(progress, const [1, 2]);
    });

    test('một câu fail không giết cả trang — câu đó null, câu sau vẫn dịch',
        () async {
      final seeds = [
        for (final t in ['A.', 'B.', 'C.'])
          PdfPageSentenceTranslation(
              pageIndex: 0, original: t, bounds: Rect.zero),
      ];

      final report = await translatePdfPageUnits(
        pageIndex: 0,
        seeds: seeds,
        translate: (text) async => text == 'B.' ? null : 'VI[$text]',
        delayBetween: Duration.zero,
      );

      expect(report.translatedCount, 2);
      expect(report.failedCount, 1);
      expect(report.translations[1].hasTranslation, isFalse);
      expect(report.translations[2].translation, 'VI[C.]');
    });

    test('5 lỗi liên tiếp → dừng sớm, không đốt request chết', () async {
      final seeds = [
        for (var i = 0; i < 20; i++)
          PdfPageSentenceTranslation(
              pageIndex: 0, original: 'S$i.', bounds: Rect.zero),
      ];

      var calls = 0;
      final report = await translatePdfPageUnits(
        pageIndex: 0,
        seeds: seeds,
        translate: (text) async {
          calls++;
          return null; // engine chết hoàn toàn
        },
        delayBetween: Duration.zero,
      );

      expect(report.stoppedEarly, isTrue);
      expect(report.failedCount, 5);
      expect(calls, 5); // dừng đúng tại ngưỡng, không chạy hết 20
    });

    test('shouldStop (đổi trang / đóng panel) → hủy ngay, không dịch tiếp',
        () async {
      final seeds = [
        for (var i = 0; i < 10; i++)
          PdfPageSentenceTranslation(
              pageIndex: 0, original: 'S$i.', bounds: Rect.zero),
      ];

      var stop = false;
      final report = await translatePdfPageUnits(
        pageIndex: 0,
        seeds: seeds,
        translate: (text) async {
          if (text == 'S1.') stop = true; // user lật trang giữa chừng
          return 'VI[$text]';
        },
        shouldStop: () => stop,
        delayBetween: Duration.zero,
      );

      expect(report.stoppedEarly, isTrue);
      expect(report.translations.length, 2); // S0. + S1. rồi dừng
    });

    test('translator throw → coi như fail câu đó, không crash cả trang',
        () async {
      final seeds = [
        PdfPageSentenceTranslation(
            pageIndex: 0, original: 'Boom.', bounds: Rect.zero),
        PdfPageSentenceTranslation(
            pageIndex: 0, original: 'Ok.', bounds: Rect.zero),
      ];

      final report = await translatePdfPageUnits(
        pageIndex: 0,
        seeds: seeds,
        translate: (text) async {
          if (text == 'Boom.') throw Exception('engine died');
          return 'VI[$text]';
        },
        delayBetween: Duration.zero,
      );

      expect(report.failedCount, 1);
      expect(report.translations[1].translation, 'VI[Ok.]');
    });

    test('seeds rỗng → report rỗng ngay (không gọi engine)', () async {
      var calls = 0;
      final report = await translatePdfPageUnits(
        pageIndex: 0,
        seeds: const [],
        translate: (text) async {
          calls++;
          return 'x';
        },
      );
      expect(report.isEmpty, isTrue);
      expect(calls, 0);
    });
  });

  group('splitOcrTextIntoUnits (OCR fallback cho trang scan)', () {
    test('ngắt theo dòng trống — mỗi đoạn là một đơn vị dịch', () {
      final units = splitOcrTextIntoUnits('Đoạn một.\nDòng hai.\n\nĐoạn hai.');
      expect(units, const ['Đoạn một.\nDòng hai.', 'Đoạn hai.']);
    });

    test('đoạn ngắn hơn budget → giữ nguyên một khối', () {
      final text = List.filled(10, 'Câu ngắn.').join(' ');
      final units = splitOcrTextIntoUnits(text);
      expect(units.length, 1);
      expect(units.first, text);
    });

    test('đoạn dài → gom theo câu, mỗi unit không vượt budget', () {
      final sentence = 'Đây là một câu dài khoảng năm mươi ký tự cho budget.';
      final text = List.filled(20, sentence).join(' '); // ~1.4k ký tự
      final units = splitOcrTextIntoUnits(text, maxUnitLength: 200);

      expect(units.length, greaterThan(1));
      for (final unit in units) {
        expect(unit.length, lessThanOrEqualTo(200));
      }
      // Không mất chữ: ghép lại (bỏ space join) vẫn đủ nội dung.
      expect(units.join(' '), text);
    });

    test('câu đơn dài hơn budget (không dấu chấm) → cắt cứng tại budget',
        () {
      final long = 'a' * 1200;
      final units = splitOcrTextIntoUnits(long, maxUnitLength: 480);
      expect(units.length, 3); // 480 + 480 + 240
      expect(units.join(''), long);
    });

    test('text rỗng / chỉ khoảng trắng → không có unit nào', () {
      expect(splitOcrTextIntoUnits(''), isEmpty);
      expect(splitOcrTextIntoUnits('  \n  \n\n   '), isEmpty);
    });
  });

  group('ocrTextToTranslationSeeds', () {
    test('OCR text → seed pageIndex đúng, bounds Rect.zero, theo thứ tự',
        () {
      final seeds = ocrTextToTranslationSeeds(7, 'A.\n\nB.');
      expect(seeds.length, 2);
      expect(seeds[0].pageIndex, 7);
      expect(seeds[0].original, 'A.');
      expect(seeds[0].bounds, Rect.zero);
      expect(seeds[1].original, 'B.');
    });
  });
}
