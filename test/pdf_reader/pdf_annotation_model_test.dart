// PdfAnnotation là "hợp đồng mở lại đúng chỗ" (quy tắc vàng #3): nếu round-trip
// JSON làm mất rect/offset thì ghi chú còn trong danh sách nhưng không nhảy về
// chỗ cũ được nữa — lỗi đã tồn tại âm thầm vì rect lưu theo quy ước PDF.
import 'dart:convert';
import 'dart:ui' show Color, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/models/pdf_annotation.dart';
import 'package:in4up/features/pdf_reader/models/pdf_sentence_cue.dart';

/// Rect PDF space: `top > bottom` (y hướng lên).
const Rect kPdfRect = Rect.fromLTRB(72, 720, 540, 700);

void main() {
  group('PdfAnnotation', () {
    test('round-trip JSON giữ nguyên rect/offset/màu/loại', () {
      final annotation = PdfAnnotation(
        id: 'a-1',
        pageIndex: 7,
        bounds: kPdfRect,
        lineRects: const [
          Rect.fromLTRB(72, 720, 540, 700),
          Rect.fromLTRB(72, 700, 400, 680),
        ],
        selectedText: 'Một câu khá dài trải trên hai dòng',
        note: 'để ý chỗ này',
        color: const Color(0xFF80DEEA),
        type: AnnotationType.note,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        textStartOffset: 128,
        textEndOffset: 160,
      );

      final restored = PdfAnnotation.fromJson(
        jsonDecode(jsonEncode(annotation)) as Map<String, dynamic>,
      );

      expect(restored.id, annotation.id);
      expect(restored.pageIndex, 7);
      expect(restored.bounds, kPdfRect);
      expect(restored.lineRects, annotation.lineRects);
      expect(restored.selectedText, annotation.selectedText);
      expect(restored.note, 'để ý chỗ này');
      expect(restored.color, const Color(0xFF80DEEA));
      expect(restored.type, AnnotationType.note);
      expect(restored.createdAt, annotation.createdAt);
      expect(restored.textStartOffset, 128);
      expect(restored.textEndOffset, 160);
    });

    test('rect PDF space vẫn được coi là hợp lệ (height của Rect là SỐ ÂM)', () {
      final annotation = PdfAnnotation(
        id: 'a',
        pageIndex: 0,
        bounds: kPdfRect,
        selectedText: 'x',
        createdAt: DateTime.utc(2024, 5, 6),
      );
      expect(annotation.bounds.height, lessThan(0)); // bản chất Rect của Flutter
      expect(annotation.hasValidBounds, isTrue); // ... còn ta phải coi là hợp lệ
      expect(annotation.canReopenToPosition, isTrue);
      expect(annotation.rectsForPainting, [kPdfRect]);
    });

    test('dữ liệu cũ: không lineRects / không offset thì vẫn dùng bounds', () {
      final legacy = PdfAnnotation.fromJson(const {
        'id': 'old',
        'pageIndex': 2,
        'bounds': {'left': 10.0, 'top': 300.0, 'right': 90.0, 'bottom': 288.0},
        'selectedText': 'old note',
        'color': 0xFFFFD54F,
        'createdAt': '2024-01-02T03:04:05.000',
      });
      expect(legacy.lineRects, isEmpty);
      expect(legacy.rectsForPainting.single.top, 300.0);
      expect(legacy.hasValidBounds, isTrue);
      expect(legacy.type, AnnotationType.highlight);
    });

    test('bounds rect dạng list (kiểu gọn) cũng đọc được', () {
      final parsed = PdfAnnotation.fromJson(const {
        'id': 'l',
        'pageIndex': 0,
        'bounds': [1.0, 50.0, 20.0, 40.0],
        'lineRects': [
          [1.0, 50.0, 20.0, 40.0]
        ],
        'selectedText': 'a',
        'createdAt': '2024-01-01T00:00:00.000',
      });
      expect(parsed.bounds, const Rect.fromLTRB(1, 50, 20, 40));
      expect(parsed.lineRects.single, const Rect.fromLTRB(1, 50, 20, 40));
    });

    test('thiếu/hỏng bounds -> không mở lại được, nhưng không ném', () {
      final broken = PdfAnnotation.fromJson(const {
        'id': 'b',
        'pageIndex': 1,
        'bounds': null,
        'selectedText': 'a',
      });
      expect(broken.bounds, Rect.zero);
      expect(broken.hasValidBounds, isFalse);
      expect(broken.canReopenToPosition, isFalse);
      expect(broken.rectsForPainting, isEmpty);
      expect(broken.createdAt.millisecondsSinceEpoch, 0);

      // ...nhưng còn offset thì vẫn nhảy về trang + resolve lại bằng offset
      final byOffset = broken.copyWith(textStartOffset: 4, textEndOffset: 9);
      expect(byOffset.canReopenToPosition, isTrue);
    });

    test('copyWith giữ id và createdAt (không tạo bản ghi mới)', () {
      final annotation = PdfAnnotation(
        id: 'keep',
        pageIndex: 0,
        bounds: kPdfRect,
        selectedText: 'x',
        createdAt: DateTime.utc(2024, 1, 2, 3, 4),
      );
      final edited = annotation.copyWith(note: 'khác', color: const Color(0xFF00FF00));
      expect(edited.id, 'keep');
      expect(edited.createdAt, annotation.createdAt);
      expect(edited.note, 'khác');
      expect(edited.color, const Color(0xFF00FF00));
    });
  });

  group('PdfSentenceCue', () {
    test('bounds là hợp nhất các dòng, preview cắt 80 ký tự', () {
      // `'a' * 100` không phải hằng số → không được bọc `const`.
      final cue = PdfSentenceCue(
        pageIndex: 3,
        startOffset: 10,
        endOffset: 90,
        speakText: 'a' * 100,
        lineRects: [
          Rect.fromLTRB(0, 100, 200, 90),
          Rect.fromLTRB(0, 90, 120, 80),
        ],
      );
      expect(cue.bounds, const Rect.fromLTRB(0, 100, 200, 80));
      expect(cue.isUsable, isTrue);
      expect(cue.preview.length, 78); // 77 ký tự + dấu …
      expect(cue.preview.endsWith('…'), isTrue);

      const empty = PdfSentenceCue(
        pageIndex: 0,
        startOffset: 0,
        endOffset: 1,
        speakText: ' ',
        lineRects: [],
      );
      expect(empty.isUsable, isFalse);
      expect(empty.bounds, Rect.zero);
    });
  });
}
