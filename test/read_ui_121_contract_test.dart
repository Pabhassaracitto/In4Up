// READ-UI-121 — khôi phục các nút tab Đọc bị giấu sau READ-UI-120, đổi
// nhãn ABC → IPA và bổ sung tự cuộn theo dòng đang đọc (có thể tắt).
//
// Source-pin + hàm thuần Dart ⇒ chạy được trên CI không cần widget tree /
// thiết bị thật. Xem docs/adr/0024-doc-tab-khoi-phuc-thanh-cong-cu-va-tu-cuon.md.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';
import 'package:in4up/screens/read_mode/services/read_auto_scroll_policy.dart';

String _src(String path) => File(path).readAsStringSync();

const _newStrings = [
  'Tùy biến chữ',
  'Tự cuộn theo dòng đang đọc; tắt để cuộn tay.',
];

void main() {
  group('Khôi phục 5 nút cũ — một cụm dùng chung, không tạo state mới', () {
    final controls =
        _src('lib/screens/read_mode/widgets/read_display_controls.dart');
    final dock = _src('lib/screens/read_mode/widgets/read_bottom_dock.dart');
    final sheet = _src('lib/screens/read_mode/widgets/read_top_bar.dart');
    final shell = _src('lib/screens/main_shell.dart');
    final screen = _src('lib/screens/read_mode/read_mode_screen.dart');

    test('cụm điều khiển gọi ĐÚNG API hiện có của TextProvider/Controller', () {
      for (final pin in [
        'tp.cycleColorMode()',
        'tp.setShowColorModeDetails(',
        'tp.setWordTapBoxes(',
        'tp.setIpaLegendVisible(',
        'ReadLineHint.showSheet(context)',
        'ctrl.toggleAutoSync()',
        'ctrl.toggleFocusMode()',
      ]) {
        expect(controls.contains(pin), isTrue, reason: 'Thiếu $pin');
      }
      expect(controls.contains('tp.colorMode.label'), isTrue,
          reason: 'Nhãn «Không màu / Loại từ / CEFR / Độ khó» lấy từ model');
      expect(
          _src('lib/models/color_mode.dart').contains("return 'Không màu';"),
          isTrue);
      // Nhãn «?» / Focus / Đồng bộ tự động đều còn (owner báo mất hết).
      for (final label in [
        'Bôi nhiều chữ',
        'Đồng bộ tự động',
        'Hướng dẫn đọc theo dòng',
        'Chế độ Focus',
        'Màu IPA',
      ]) {
        expect(controls.contains(label), isTrue, reason: 'Thiếu nhãn $label');
      }
    });

    test('dock + sheet Hiển thị + overflow ⚡ dùng CHUNG một cụm', () {
      expect(dock.contains('ReadDisplayControls(controller: controller)'),
          isTrue);
      expect(sheet.contains('ReadDisplayControls(controller: readController)'),
          isTrue);
      expect(dock.contains("Key('read-bottom-dock-display')"), isTrue,
          reason: 'Phải có lối vào 1 chạm, không giấu sau 2 lớp tab');
      expect(shell.contains('ReadChromeLayoutStore.instance'), isTrue);
      expect(shell.contains('lastPanel: ReadDockPanel.display'), isTrue);
      // Bố cục «Trên» lấy lại ReadTopBar cũ cho người quen tay.
      expect(shell.contains('showTopBar: !_readChromeLayout.useBottomDock,'),
          isTrue);
    });

    test('ABC → IPA: dock dùng textIcon như thanh cũ', () {
      expect(dock.contains("textIcon: 'IPA'"), isTrue);
      expect(dock.contains('final String? textIcon;'), isTrue);
      expect(
          _src('lib/screens/read_mode/widgets/read_bottom_bar.dart')
              .contains("textIcon: 'IPA'"),
          isTrue);
    });

    test('READ-TOOLBAR-001 v2 vẫn cấm 4 widget animation trên dock', () {
      for (final forbidden in [
        'AnimatedSize(',
        'AnimatedSlide(',
        'AnimatedOpacity(',
        'ClipRect(',
      ]) {
        expect(dock.contains(forbidden), isFalse);
      }
    });

    test('màn Đọc tự cuộn theo TTS, có nhường quyền khi kéo tay', () {
      expect(screen.contains('shouldAutoFollowPlayback('), isTrue);
      expect(screen.contains('_manualScrollUntil'), isTrue);
      expect(screen.contains('notification.dragDetails != null'), isTrue);
      expect(screen.contains('_controller.scrollToLine(_scrollController, index)'),
          isTrue);
    });
  });

  group('Chính sách tự cuộn (thuần Dart)', () {
    bool follow({
      bool autoSyncEnabled = true,
      bool isRunning = true,
      bool singleLineMode = false,
      bool manualScrollActive = false,
      int lineIndex = 3,
      int lineCount = 10,
    }) =>
        shouldAutoFollowPlayback(
          autoSyncEnabled: autoSyncEnabled,
          isRunning: isRunning,
          singleLineMode: singleLineMode,
          manualScrollActive: manualScrollActive,
          lineIndex: lineIndex,
          lineCount: lineCount,
        );

    test('mặc định: đang phát cả bài ⇒ tự cuộn', () {
      expect(follow(), isTrue);
    });

    test('«Đồng bộ tự động» TẮT ⇒ không cuộn (có thể tắt)', () {
      expect(follow(autoSyncEnabled: false), isFalse);
    });

    test('không có phiên phát / Một dòng / kéo tay ⇒ không cuộn', () {
      expect(follow(isRunning: false), isFalse);
      expect(follow(singleLineMode: true), isFalse);
      expect(follow(manualScrollActive: true), isFalse);
    });

    test('chỉ số dòng ngoài biên ⇒ không cuộn, không crash', () {
      expect(follow(lineIndex: -1), isFalse);
      expect(follow(lineIndex: 10), isFalse);
      expect(follow(lineCount: 0), isFalse);
      expect(follow(lineIndex: 9, lineCount: 10), isTrue);
    });

    test('khoảng nhường quyền 5 giây', () {
      expect(readAutoScrollManualPause, const Duration(seconds: 5));
    });
  });

  group('Rule #5 — 2 chuỗi mới có en + 7 locale ưu tiên', () {
    const priorityLocales = ['en', 'zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja'];

    test('generatedPriorityNativePack đủ locale, không rơi về tiếng Việt', () {
      for (final source in _newStrings) {
        final entry = generatedPriorityNativePack[source];
        expect(entry, isNotNull, reason: 'Thiếu pack entry: $source');
        for (final locale in priorityLocales) {
          expect((entry![locale] ?? '').trim().isNotEmpty, isTrue,
              reason: '$source thiếu $locale');
        }
        expect(AppUITranslations.translate(source, 'en'), entry!['en']);
        expect(AppUITranslations.translate(source, 'ja'), entry['ja']);
      }
    });

    test('legacy English overrides cũng được review', () {
      final overrides = jsonDecode(
        File('tool/legacy_ui_english_overrides.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final source in _newStrings) {
        expect(overrides[source], isNotNull, reason: 'Thiếu en: $source');
        expect(overrides[source] as String, isNot(contains('đ')),
            reason: 'English fallback còn ký tự Việt: $source');
      }
    });
  });
}
