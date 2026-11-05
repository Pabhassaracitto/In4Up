// AUDIT-1.21.0 #8 — "∞ ∞ 1× 3× 5× 7× … 20×" ⇒ chỉ còn MỘT ∞.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/loop_presets.dart';

void main() {
  test('dropdownValues không còn giá trị âm / trùng', () {
    expect(LoopPresets.dropdownValues.toSet().length,
        LoopPresets.dropdownValues.length);
    expect(LoopPresets.dropdownValues.any((v) => v < 0), isFalse);
  });

  test('CHỈ MỘT mục ∞ trong toàn bộ danh sách chọn', () {
    final labels = LoopPresets.dropdownValues
        .map(LoopPresets.labelFor)
        .where((label) => label == '∞')
        .toList();
    expect(labels, hasLength(1));
    expect(LoopPresets.dropdownValues.first, 0);
    expect(LoopPresets.dropdownValues.skip(1).every((v) => v > 0), isTrue);
  });

  test('giữ đủ dãy 1× 3× 5× 7× … 20×', () {
    expect(
      LoopPresets.dropdownValues.skip(1).toList(),
      <int>[1, 3, 5, 7, 10, 15, 20],
    );
  });

  test('cài đặt cũ -1 được gom về 0 (không sinh ∞ thứ hai)', () {
    expect(LoopPresets.safeDropdownValue(-1), 0);
    expect(LoopPresets.safeDropdownValue(3), 3);
    expect(LoopPresets.safeDropdownValue(999), 0);
  });

  test('badge cycle vẫn có đúng 1 ∞ cho chế độ lặp bài', () {
    expect(LoopPresets.badgeModes.toSet().length,
        LoopPresets.badgeModes.length);
    expect(
      LoopPresets.badgeLabels.where((l) => l == '∞').toList(),
      hasLength(1),
    );
    expect(LoopPresets.badgeLabels.length, LoopPresets.badgeModes.length);
  });
}
