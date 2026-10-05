// XLAT-SCR-002 — khối OCR + bbox (thuần Dart, chạy host VM).
//
// Máy bắt cho 3 lỗi dễ xảy ra khi đọc dữ liệu ML Kit:
//  - block chỉ có khoảng trắng → vẽ ô đen rỗng trên màn hình user,
//  - toạ độ âm/vượt mép ảnh → overlay vẽ lệch ra ngoài màn hình,
//  - thứ tự block không theo thứ tự đọc → bản dịch nhảy lung tung.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';

void main() {
  group('makeOcrBlock', () {
    test('giữ nguyên khối hợp lệ và dọn khoảng trắng thừa', () {
      final block = makeOcrBlock(
        text: '  Hello   world  ',
        left: 10,
        top: 20,
        right: 110,
        bottom: 60,
        imageWidth: 1080,
        imageHeight: 2400,
      );
      expect(block, isNotNull);
      expect(block!.text, 'Hello world');
      expect(block.rect, const OcrBlockRect(left: 10, top: 20, right: 110, bottom: 60));
      expect(block.rect.width, 100);
      expect(block.rect.height, 40);
    });

    test('bỏ khối rỗng / chỉ khoảng trắng', () {
      expect(
        makeOcrBlock(
          text: '   \n\t ',
          left: 0,
          top: 0,
          right: 50,
          bottom: 20,
          imageWidth: 100,
          imageHeight: 100,
        ),
        isNull,
      );
    });

    test('bỏ khối không có diện tích', () {
      expect(
        makeOcrBlock(
          text: 'x',
          left: 30,
          top: 30,
          right: 30,
          bottom: 50,
          imageWidth: 100,
          imageHeight: 100,
        ),
        isNull,
      );
    });

    test('clamp toạ độ âm / vượt mép về trong ảnh', () {
      final block = makeOcrBlock(
        text: 'Pāḷi',
        left: -20,
        top: -5,
        right: 1200,
        bottom: 2600,
        imageWidth: 1080,
        imageHeight: 2400,
      );
      expect(block, isNotNull);
      expect(block!.rect,
          const OcrBlockRect(left: 0, top: 0, right: 1080, bottom: 2400));
    });

    test('toạ độ đảo chiều vẫn dựng được khung đúng', () {
      final block = makeOcrBlock(
        text: 'abc',
        left: 200,
        top: 300,
        right: 100,
        bottom: 150,
        imageWidth: 500,
        imageHeight: 500,
      );
      expect(block, isNotNull);
      expect(block!.rect,
          const OcrBlockRect(left: 100, top: 150, right: 200, bottom: 300));
    });
  });

  group('sortOcrBlocksForReading', () {
    OcrBlock at(int left, int top, String text) => OcrBlock(
          text: text,
          rect: OcrBlockRect(
            left: left,
            top: top,
            right: left + 80,
            bottom: top + 30,
          ),
        );

    test('trên→dưới, cùng hàng thì trái→phải', () {
      final sorted = sortOcrBlocksForReading(<OcrBlock>[
        at(400, 500, 'd'),
        at(20, 100, 'a'),
        at(300, 108, 'b'), // lệch 8px so với 'a' ⇒ coi là cùng hàng
        at(10, 500, 'c'),
      ]);
      expect(sorted.map((b) => b.text).toList(), <String>['a', 'b', 'c', 'd']);
    });

    test('rowTolerance nhỏ thì hai khối lệch nhẹ tách thành hai hàng', () {
      final sorted = sortOcrBlocksForReading(
        <OcrBlock>[at(300, 108, 'b'), at(20, 100, 'a')],
        rowTolerance: 4,
      );
      expect(sorted.map((b) => b.text).toList(), <String>['a', 'b']);
    });
  });
}
