// test/widgets/loop_gap_label_test.dart
//
// AUDIT v1.30.1 (mục 7) — hồi quy cho «ô khoảng lặng lặp AB: chọn xong chữ/
// biểu tượng không đổi theo giá trị».
//
// Nguyên nhân: slider 0–10s chia 20 ⇒ bước 0.5s, nhưng nhãn in `toInt()` nên
// 1.5s hiện «1s» (trùng nhãn với 1.0s) và 0.5s hiện «0s» (trùng với «Tắt»).
// Test khoá lại: mọi bước 0.5s phải ra nhãn KHÁC NHAU.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/widgets/loop_gap_label.dart';

void main() {
  group('formatGapDurationLabel', () {
    test('giá trị nguyên bỏ .0', () {
      expect(formatGapDurationLabel(0), '0s');
      expect(formatGapDurationLabel(1), '1s');
      expect(formatGapDurationLabel(3), '3s');
      expect(formatGapDurationLabel(5), '5s');
      expect(formatGapDurationLabel(10), '10s');
    });

    test('giá trị lẻ GIỮ phần lẻ (lỗi cũ nuốt mất)', () {
      expect(formatGapDurationLabel(0.5), '0.5s');
      expect(formatGapDurationLabel(1.5), '1.5s');
      expect(formatGapDurationLabel(2.5), '2.5s');
      expect(formatGapDurationLabel(9.5), '9.5s');
    });

    test('mọi bước 0.5s của slider ra nhãn KHÁC NHAU', () {
      final labels = <String>{};
      for (var i = 0; i <= 20; i++) {
        labels.add(formatGapDurationLabel(i * 0.5));
      }
      // 21 bước từ 0 đến 10 ⇒ 21 nhãn phân biệt.
      expect(labels.length, 21);
    });

    test('sai số dấu phẩy động không tạo nhãn rác', () {
      expect(formatGapDurationLabel(1.0000000001), '1s');
      expect(formatGapDurationLabel(0.4999999999), '0.5s');
    });

    test('NaN/Infinity không làm vỡ UI', () {
      expect(formatGapDurationLabel(double.nan), '0s');
      expect(formatGapDurationLabel(double.infinity), '0s');
    });
  });

  group('formatGapDurationBadge', () {
    test('0 = tắt', () {
      expect(formatGapDurationBadge(0), 'off');
      expect(formatGapDurationBadge(-1), 'off');
    });

    test('khác 0 dùng cùng nhãn với chip preset', () {
      expect(formatGapDurationBadge(1.5), formatGapDurationLabel(1.5));
      expect(formatGapDurationBadge(2), '2s');
    });
  });
}
