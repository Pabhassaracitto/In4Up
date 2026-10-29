// READ-POP-003 — vị trí pop tra từ nhanh trong tab Đọc.
//
// Owner 2026-10-25: pop phải "trồi lên" cạnh từ, không làm tối phần còn lại,
// chạm chỗ khác thì tự ẩn. Phần "không modal" nằm ở `word_mini_pop.dart` (dùng
// OverlayEntry + Listener translucent); phần TOÁN HỌC đặt pop nằm ở
// `word_pop_layout.dart` và được khoá bằng test thuần dưới đây.

import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/services/word_pop_layout.dart';

void main() {
  const screen = Size(400, 800);

  group('computeWordPopPlacement — đặt pop cạnh từ', () {
    test('từ ở nửa trên ⇒ pop đặt DƯỚI từ', () {
      final placement = computeWordPopPlacement(
        anchor: const Rect.fromLTWH(40, 100, 60, 22),
        screen: screen,
      );
      expect(placement.below, isTrue);
      expect(placement.top, 100 + 22 + 8);
      expect(placement.left, 40);
      expect(placement.maxHeight, greaterThan(96));
    });

    test('từ sát đáy ⇒ pop LẬT LÊN TRÊN, vẫn nằm trong màn hình', () {
      final placement = computeWordPopPlacement(
        anchor: const Rect.fromLTWH(40, 760, 60, 22),
        screen: screen,
      );
      expect(placement.below, isFalse);
      expect(placement.top, greaterThanOrEqualTo(8));
      expect(placement.top + placement.maxHeight,
          lessThanOrEqualTo(screen.height));
    });

    test('từ sát mép phải ⇒ pop bị kẹp vào trong màn hình', () {
      final placement = computeWordPopPlacement(
        anchor: const Rect.fromLTWH(380, 200, 20, 22),
        screen: screen,
      );
      expect(placement.left + placement.width,
          lessThanOrEqualTo(screen.width - 8 + 0.001));
      expect(placement.left, greaterThanOrEqualTo(8));
    });

    test('màn hình hẹp ⇒ pop không rộng hơn màn hình và vẫn có chỗ tối thiểu',
        () {
      final placement = computeWordPopPlacement(
        anchor: const Rect.fromLTWH(0, 50, 20, 20),
        screen: const Size(320, 640),
        maxWidth: 340,
      );
      expect(placement.width, 320 - 16);
      expect(placement.maxHeight, greaterThanOrEqualTo(96));
    });

    test('bề rộng bị giới hạn bởi maxWidth khi màn hình rộng', () {
      final placement = computeWordPopPlacement(
        anchor: const Rect.fromLTWH(100, 100, 40, 20),
        screen: const Size(1200, 900),
        maxWidth: 340,
      );
      expect(placement.width, 340);
    });
  });
}
