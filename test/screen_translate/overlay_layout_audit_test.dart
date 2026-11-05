// AUDIT-1.21.0 #1 / XLAT-SCR-005 — bong bóng dịch NHIỀU KHỐI chồng chữ.
// Test THUẦN trên host VM (không cần thiết bị / MediaProjection).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/screen_translate/screen_translate_overlay_layout.dart';

ScreenBlock _b(int top, int bottom, String translation, {int left = 0}) {
  return ScreenBlock(
    rect: OverlayRect(left: left, top: top, right: left + 300, bottom: bottom),
    original: 'original',
    translation: translation,
    textSizeSp: 14,
  );
}

void main() {
  group('layoutTranslatedBlocks — không chồng khung', () {
    test('0/1 khối được giữ nguyên', () {
      final single = [_b(100, 160, 'Xin chào')];
      expect(layoutTranslatedBlocks(single).single.translation, 'Xin chào');
      expect(layoutTranslatedBlocks(<ScreenBlock>[]), isEmpty);
    });

    test('khối TRÊN bị cắt đúng mép trên của khối DƯỚI (có khe hở)', () {
      final out = layoutTranslatedBlocks([
        _b(100, 200, 'Bản dịch thứ nhất'),
        _b(150, 250, 'Bản dịch thứ hai'),
      ]);

      expect(out, hasLength(2));
      expect(out[0].rect.top, 100);
      expect(out[0].rect.bottom, lessThan(150));
      expect(out[0].rect.bottom, greaterThan(100));
      expect(out[1].rect.top, 150);
      expect(out[1].rect.bottom, 250);
      // Chữ đều còn (không bị nuốt mất câu).
      expect(out[0].translation, 'Bản dịch thứ nhất');
      expect(out[1].translation, 'Bản dịch thứ hai');
    });

    test('hai bbox OCR trùng nội dung ⇒ chỉ vẽ MỘT ô', () {
      final out = layoutTranslatedBlocks([
        _b(100, 180, 'Cùng một dòng'),
        _b(110, 190, 'Cùng một dòng'),
      ]);
      expect(out, hasLength(2), reason: 'giữ nguyên số khối theo hợp đồng');
      expect(out[0].translation, 'Cùng một dòng');
      expect(out[1].translation, isEmpty,
          reason: 'khối thứ hai bị loại khỏi vẽ (native bỏ qua)');
    });

    test('hai cột chữ cạnh nhau (giao 2px) KHÔNG bị cắt nhầm', () {
      final out = layoutTranslatedBlocks([
        _b(100, 160, 'Cột trái', left: 0),
        _b(100, 160, 'Cột phải', left: 298),
      ]);
      expect(out[0].rect.bottom, 160);
      expect(out[1].rect.top, 100);
      expect(out[1].translation, 'Cột phải');
    });

    test('khung bị cắt quá mỏng ⇒ bỏ vẽ để lộ chữ gốc', () {
      final out = layoutTranslatedBlocks([
        _b(100, 120, 'Bản dịch dài phía trên'),
        _b(104, 180, 'Bản dịch phía dưới'),
      ]);
      expect(out[0].translation, isEmpty);
      expect(out[1].translation, 'Bản dịch phía dưới');
    });

    test('frame giả trong test (màn < 200px) không áp ngưỡng thiết bị', () {
      final blocks = [_b(10, 30, 'A'), _b(20, 40, 'B')];
      final out = layoutTranslatedBlocks(
        blocks,
        screenWidth: 120,
        screenHeight: 80,
      );
      expect(out[0].translation, 'A');
      expect(out[1].translation, 'B');
      expect(out[0].rect.bottom, 30);
    });

    test('cỡ chữ được tính lại theo chiều cao khung ĐÃ CẮT', () {
      final out = layoutTranslatedBlocks([
        _b(100, 105, 'A very long translation that will not fit at all'),
        _b(150, 250, 'Second'),
      ]);
      expect(out[1].textSizeSp, greaterThan(0));
      expect(out[1].textSizeSp, lessThanOrEqualTo(28));
    });
  });
}
