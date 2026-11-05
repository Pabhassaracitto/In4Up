// READ-UI-120 — hợp đồng của đợt chỉnh sửa audio/hiển thị tab Đọc (v1.20.0).
//
// Test dạng "source pin" như các test audit khác trong repo: khoá các bất
// biến mà owner đã chốt, để một refactor vô tình không đưa lỗi cũ quay lại.
// Chỉ đọc file + catalog thuần Dart ⇒ chạy được trên CI không có Flutter
// widget tree / thiết bị thật.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';

String _src(String path) => File(path).readAsStringSync();

const _newStrings = [
  'Đang dịch, sẽ đọc bản dịch khi có',
  'Chưa có bản dịch, đang đọc nguồn',
  'Tự động dịch khi phát song ngữ',
  'Vị trí công cụ',
  'Nhớ trạng thái bung',
  'Mở tab Đọc chỉ còn nguồn ở trên và một hàng công cụ ở dưới; bung từng nhóm khi cần.',
  'Thông tin & Hiển thị',
];

void main() {
  group('P0 — phát không còn bị chặn bởi bản dịch', () {
    final bar =
        _src('lib/screens/read_mode/widgets/smart_playback_bar.dart');

    test('bỏ 3 nhánh chặn Play cũ', () {
      expect(bar.contains('Đang dịch, vui lòng chờ hoàn tất…'), isFalse);
      expect(bar.contains('Hãy chọn ngôn ngữ đích khác nguồn trước khi phát.'),
          isFalse);
      expect(bar.contains('await tp.translateAll()'), isFalse);
    });

    test('dịch nền KHÔNG await; có fallback viOnly chưa có bản dịch', () {
      expect(bar.contains('unawaited(tp.translateAll())'), isTrue);
      expect(bar.contains('Future<void> startReadPlayback('), isTrue);
      expect(bar.contains('Future<void> toggleReadPlayback('), isTrue);
      expect(bar.contains('recipeOverride: recipeOverride'), isTrue);
      expect(bar.contains('mode: PlaybackMode.enOnly'), isTrue);
    });

    test('một nguồn tốc độ duy nhất', () {
      expect(bar.contains('speed: tp.ttsSpeed'), isTrue);
      expect(bar.contains('Future<void> setReadSpeed('), isTrue);
      expect(bar.contains('await controller.syncSpeed(next)'), isTrue);
      // Không còn UI tự tăng giảm recipe.speed.
      expect(bar.contains('controller.adjustSpeed('), isFalse);
    });
  });

  group('P0 — PlaybackController', () {
    final controller =
        _src('lib/screens/read_mode/services/playback_controller.dart');

    test('mặc định không lệ thuộc bản dịch', () {
      expect(
        controller.contains(
            'PlaybackRecipe _recipe = PlaybackRecipe.enOnly;'),
        isTrue,
      );
    });

    test('nhận tốc độ + recipe override cho từng phiên phát', () {
      expect(controller.contains('double? speed,'), isTrue);
      expect(controller.contains('PlaybackRecipe? recipeOverride,'), isTrue);
      expect(controller.contains('Future<void> syncSpeed(double speed)'),
          isTrue);
      expect(controller.contains('speed: _activeSpeed,'), isTrue);
    });
  });

  group('P1 — dock đáy tối giản, không animation', () {
    final dock =
        _src('lib/screens/read_mode/widgets/read_bottom_dock.dart');

    test('READ-TOOLBAR-001 v2: cấm 4 widget animation', () {
      for (final forbidden in [
        'AnimatedSize(',
        'AnimatedSlide(',
        'AnimatedOpacity(',
        'ClipRect(',
      ]) {
        expect(dock.contains(forbidden), isFalse,
            reason: '$forbidden gây khối đen trên GPU Mali/Adreno');
      }
    });

    test('một hàng luôn hiện + mũi tên bung cố định ngoài vùng cuộn', () {
      expect(dock.contains("Key('read-bottom-dock')"), isTrue);
      expect(dock.contains("Key('read-bottom-dock-expand')"), isTrue);
      expect(dock.contains("Key('read-bottom-dock-play')"), isTrue);
    });

    test('panel audio nhúng thanh cũ KHÔNG vẽ hàng nút chính', () {
      expect(dock.contains('showMainRow: false'), isTrue);
      expect(dock.contains('forceExpanded: true'), isTrue);
    });

    test('dời cả TranslationToolbar + dòng Áp dụng cho xuống dock', () {
      expect(dock.contains('const TranslationToolbar()'), isTrue);
      expect(dock.contains("'Áp dụng cho'"), isTrue);
      expect(dock.contains('ReadTextActionRunner.targetFor(tp)'), isTrue);
    });
  });

  group('P1/P2 — nối vào shell', () {
    final screen = _src('lib/screens/read_mode/read_mode_screen.dart');
    final shell = _src('lib/screens/main_shell.dart');
    final settings =
        _src('lib/screens/settings/shell_ui_settings_screen.dart');

    test('giữ đường cũ cho lựa chọn «Công cụ ở trên»', () {
      expect(screen.contains('visible: _readerChromeVisible'), isTrue);
      expect(screen.contains('if (useDock) ...['), isTrue);
      expect(screen.contains('ReadBottomDock('), isTrue);
      expect(screen.contains('final layout = widget.chromeLayout;'), isTrue);
    });

    test('app bar: 1 nút overflow cạnh ⚡, không phải 2 icon rời rạc', () {
      expect(shell.contains('showReadDisplaySheet(context)'), isTrue);
      expect(shell.contains('if (isReader &&'), isTrue);
      expect(shell.contains('_readChromeLayout.useBottomDock &&'), isTrue);
      // Nhóm Hiển thị ở trạng thái Ẩn ⇒ lối vào cạnh ⚡ cũng biến mất.
      expect(shell.contains('!_readChromeLayout.displayHidden'), isTrue);
      expect(shell.contains('chromeLayout: _readChromeLayout,'), isTrue);
      // READ-UI-121: mặc định dock đáy vẫn KHÔNG vẽ ReadTopBar; chỉ khôi phục
      // thanh cũ khi owner chọn «Vị trí công cụ: Trên».
      expect(shell.contains('showTopBar: !_readChromeLayout.useBottomDock,'),
          isTrue);
      expect(shell.contains('showTopBar: false,'), isFalse);
    });

    test('5 nút context chỉ còn 1 chỗ (dock) khi dùng bố cục đáy', () {
      expect(shell.contains('!_readChromeLayout.useBottomDock'), isTrue);
      expect(shell.contains('_buildReadContextHeader(context)'), isTrue);
    });

    test('màn Giao diện shell có card 3 nhóm + khôi phục mặc định', () {
      expect(settings.contains('class _ReadChromeCard'), isTrue);
      expect(settings.contains('ReadChromeLayout.defaults'), isTrue);
      expect(settings.contains('ReadChromeGroupState.hidden'), isTrue);
      expect(settings.contains('ReadToolsPlacement.top'), isTrue);
      expect(settings.contains('ReadChromeGroupId.source'), isTrue);
      expect(settings.contains('group.allowHide'), isTrue);
    });

    test('3 key lưu theo nhóm, ghi đồng bộ với blob JSON', () {
      final storage = _src('lib/services/storage_service.dart');
      expect(storage.contains('readChromeGroupKey(String groupId)'), isTrue);
      expect(storage.contains("'read_chrome_group_\${groupId}_v1'"), isTrue);
      expect(storage.contains('group.storageKey'), isTrue);
    });

    test('bung nhóm Nguồn ⇒ hiện đủ source picker', () {
      expect(screen.contains('layout.sourceExpanded'), isTrue);
      expect(shell.contains('showSourcePicker: true,'), isTrue);
    });
  });

  group('Rule #5 — 7 chuỗi chrome mới có en + 7 locale ưu tiên', () {
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
        expect(AppUITranslations.translate(source, 'ja'), entry!['ja']);
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
