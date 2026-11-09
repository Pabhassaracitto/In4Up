// IN4-30 (READ-FOCUS-002) + IN4-31 (READ-SCROLL-CLUSTER-001) — tab Đọc.
//
// IN4-30: cơ chế ẩn LINH HOẠT + tùy chọn Focus chỉ giữ phần tiêu đề
//          (trên/dưới).
// IN4-31: (a) đã ẩn icon chức năng thì ẩn LUÔN nền (gập height 0) —
//          không còn trạng thái "icon biến mất mà nền đen vẫn dính";
//          (b) thanh mode KHÔNG tự ẩn sau 4 giây nữa; muốn ẩn thì bấm X
//          (tắt luôn chế độ tự ẩn, lưu setting).
//
// Test source-scan (máy bắt) + logic thuần cho pref Focus.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/generated_legacy_ui_fallbacks.dart';
import 'package:in4up/core/language/priority_ui_overrides.dart';

void main() {
  final readScreen =
      File('lib/screens/read_mode/read_mode_screen.dart').readAsStringSync();
  final topBar = File('lib/screens/read_mode/widgets/read_top_bar.dart')
      .readAsStringSync();
  final collapsible = File(
          'lib/screens/read_mode/widgets/collapsible_bottom_controls.dart')
      .readAsStringSync();
  final settingsSheet = File(
          'lib/screens/read_mode/sheets/read_settings_sheet.dart')
      .readAsStringSync();
  final storage =
      File('lib/services/storage_service.dart').readAsStringSync();
  final shell = File('lib/screens/main_shell.dart').readAsStringSync();

  group('IN4-30 — Focus: ẩn linh hoạt + tùy chọn giữ phần tiêu đề', () {
    test('có pref 3 giá trị: hidden | top | bottom', () {
      expect(storage.contains('readFocusTitleHidden'), isTrue);
      expect(storage.contains('readFocusTitleTop'), isTrue);
      expect(storage.contains('readFocusTitleBottom'), isTrue);
      expect(storage.contains('getReadFocusTitlePosition'), isTrue);
      expect(storage.contains('saveReadFocusTitlePosition'), isTrue);
    });

    test('màn Đọc đọc pref + dựng thanh tiêu đề tối giản ở trên/dưới', () {
      expect(readScreen.contains('getReadFocusTitlePosition()'), isTrue);
      expect(readScreen.contains("_focusTitlePosition == 'top'"), isTrue);
      expect(readScreen.contains("_focusTitlePosition == 'bottom'"), isTrue);
      expect(readScreen.contains('ReadFocusTitleBar('), isTrue);
    });

    test('ReadFocusTitleBar chỉ hiện TIÊU ĐỀ (không kéo icon chức năng)', () {
      expect(topBar.contains('class ReadFocusTitleBar'), isTrue);
      final idx = topBar.indexOf('class ReadFocusTitleBar');
      final body = topBar.substring(idx, topBar.length);
      expect(body, contains('_TitleButton('),
          reason: 'Dùng lại nút tiêu đề sẵn có.');
      // Không được dựng lại cụm icon của ReadTopBar trong thanh Focus.
      expect(body.contains('_ColorModeChip('), isFalse);
      expect(body.contains('ReadBottomBar('), isFalse);
    });

    test('Cài đặt có bộ chọn Ẩn/Trên/Dưới', () {
      expect(settingsSheet.contains('_FocusTitlePositionSelector'), isTrue);
      expect(settingsSheet.contains('readFocusTitleHidden'), isTrue);
      expect(settingsSheet.contains('readFocusTitleTop'), isTrue);
      expect(settingsSheet.contains('readFocusTitleBottom'), isTrue);
    });
  });

  group('IN4-31 — ẩn icon thì ẩn luôn nền (không còn "dính nền")', () {
    test('CollapsibleBottomControls gập height 0 khi ẩn', () {
      expect(collapsible.contains('class CollapsibleBottomControls'), isTrue);
      // Không còn dùng Opacity(0) giữ chỗ layout khi ẩn.
      final idx = collapsible.indexOf('Widget build(BuildContext context) {');
      final body = collapsible.substring(idx);
      expect(body, contains('if (!visible) {'),
          reason: 'Phải có nhánh ẩn riêng (gập height 0).');
      expect(body, contains('height: 0'));
      expect(
        body.contains('Opacity('),
        isFalse,
        reason: 'Opacity(0) giữ chỗ layout ⇒ còn nền đen "dính" (nguyên nhân '
            'gốc của cảm giác khó hiểu).',
      );
    });

    test('màn Đọc không còn spacer 8px chừa chỗ cho nền đã ẩn', () {
      expect(
        readScreen.contains(
            'isSmallScreen && !isFocusMode && !_bottomControlsVisible'),
        isFalse,
        reason: 'Cụm đáy đã gập height 0 ⇒ spacer 8px là khoảng trống thừa.',
      );
    });
  });

  group('IN4-31 — thanh mode KHÔNG tự ẩn sau vài giây; X để tắt ẩn', () {
    test('không còn timer ẩn 4 giây', () {
      expect(
        shell.contains('Timer(const Duration(seconds: 4)'),
        isFalse,
        reason: 'Không được tự ẩn thanh mode (người dùng chưa kịp chọn).',
      );
    });

    test('có nút X tắt chế độ tự ẩn (lưu setting)', () {
      expect(shell.contains('_disableAutoHideModeSwitch'), isTrue);
      expect(shell.contains('saveShellAutoHideModeSwitch(false)'), isTrue);
      expect(shell.contains('Icons.close'), isTrue);
    });
  });

  group('IN4-30/31 — i18n chuỗi mới (rule #5: 5 locale)', () {
    const newStrings = [
      'Tắt tự ẩn thanh chế độ',
      'Đã tắt tự ẩn thanh chế độ',
      'Chế độ Focus: giữ tiêu đề',
      'Ẩn',
      'Trên',
      'Dưới',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si'];

    for (final s in newStrings) {
      test('priorityUiOverrides["$s"] đủ 5 locale + fallback en', () {
        final entry = priorityUiOverrides[s];
        expect(entry, isNotNull, reason: 'Thiếu entry "$s"');
        for (final loc in locales) {
          expect(entry![loc], isNotNull, reason: 'Thiếu locale $loc cho "$s"');
        }
        expect(generatedLegacyUiEnglishFallbacks[s], isNotNull,
            reason: 'Thiếu English fallback "$s"');
      });
    }
  });
}
