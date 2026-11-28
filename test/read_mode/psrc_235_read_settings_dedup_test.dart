// PSRC-235 — gọn «Cài đặt Text Studio» (bước 1: cắt bỏ) + hết trùng tên
// «Hiển thị» trong chrome tab Đọc.
//
// Triệu chứng owner: phần cài đặt tab Đọc «vốn đang rất dài», tên «Hiển thị»
// lồng nhau 4 tầng (popup cạnh ⚡ → tab dock → chip trong tab → tiêu đề sheet).
//
// Nguyên nhân gốc (đọc code):
//   1. «Chế độ trải nghiệm» ghi `TextProvider.subMode`, nhưng giá trị đó KHÔNG
//      được đọc ở đâu khác ⇒ mục đầu tiên của bảng bấm không đổi gì.
//   2. Cụm «Text-to-Speech» trong Cài đặt là lối phát THỨ HAI (Đọc dòng / Đọc
//      tất cả / Dừng) và đường tốc độ THỨ HAI: gọi thẳng `tp.setTtsSpeed`
//      (0.25–2.0), bỏ qua `setReadSpeed` (clamp 0.5–2.0 + đồng bộ
//      `PlaybackController`) ⇒ lệch ADR-0021 D1 «một lối vào, một nguồn tốc độ».
//   3. «Hiện bản dịch» và «Box từng từ» là bản sao của nút đã có ở dock / cụm
//      Tùy biến chữ (READ-ACT-001: mỗi thứ một chỗ).
//   4. Nhãn `'Hiển thị'` dùng cho 7 chỗ ⇒ một tên chỉ nhiều đích đến.
//
// Source-pin + catalog ⇒ chạy trên CI không cần widget tree / thiết bị thật.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';

String _src(String path) => File(path).readAsStringSync();

/// Bỏ dòng chú thích `//` để pin chỉ soi CODE (chú thích được phép nhắc lại
/// tên cũ khi giải thích lý do).
String _code(String path) => _src(path)
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _settingsPath = 'lib/screens/read_mode/sheets/read_settings_sheet.dart';
const _dockPath = 'lib/screens/read_mode/widgets/read_bottom_dock.dart';
const _topBarPath = 'lib/screens/read_mode/widgets/read_top_bar.dart';
const _controlsPath = 'lib/screens/read_mode/widgets/read_display_controls.dart';
const _shellPath = 'lib/screens/main_shell.dart';

/// Chuỗi UI mới của PSRC-235 (quy tắc vàng #5).
const _newStrings = ['Tùy biến', 'Bố cục đọc', 'Dòng văn bản'];

/// Lời giải thích của công tắc «Box từng từ» cũ — nay là tooltip của chip.
const _boxHint = 'Tắt = bôi nhiều chữ (mặc định). Bật = mỗi từ một hộp, '
    'long-press lưu từ — nền lưu hàng loạt.';

void main() {
  final settings = _code(_settingsPath);
  final dock = _code(_dockPath);
  final topBar = _code(_topBarPath);
  final controls = _code(_controlsPath);
  final shell = _code(_shellPath);

  group('Cài đặt Text Studio — bỏ mục chết và lối vào trùng', () {
    test('«Chế độ trải nghiệm» (subMode không ai đọc) đã bị xoá tận gốc', () {
      expect(settings.contains('_SubModeSelector'), isFalse);
      expect(settings.contains("'Chế độ trải nghiệm'"), isFalse);
      expect(settings.contains('setSubMode'), isFalse);
      // State chết cũng không còn trong provider ⇒ không ai dựng lại nhầm.
      final provider = _code('lib/providers/text_provider.dart');
      expect(provider.contains('ReadSubMode'), isFalse);
      expect(provider.contains('_subMode'), isFalse);
    });

    test('không còn lối phát TTS thứ hai trong Cài đặt (ADR-0021 D1)', () {
      for (final pin in [
        '_TtsControls',
        '_TtsButton',
        'speakCurrentLine',
        'speakAllLines',
        "'Text-to-Speech'",
        "'Đọc dòng'",
        "'Đọc tất cả'",
      ]) {
        expect(settings.contains(pin), isFalse, reason: 'Còn sót $pin');
      }
    });

    test('không còn đường tốc độ thứ hai — chỉ `setReadSpeed` được ghi', () {
      expect(settings.contains('setTtsSpeed'), isFalse,
          reason: 'Thanh tốc độ trong Cài đặt bỏ qua PlaybackController.');
      final playback =
          _code('lib/screens/read_mode/widgets/smart_playback_bar.dart');
      expect(playback.contains('Future<void> setReadSpeed('), isTrue);
      expect(playback.contains('await tp.setTtsSpeed(next);'), isTrue);
      expect(playback.contains('await controller.syncSpeed(next);'), isTrue);
    });

    test('2 công tắc trùng đã bỏ, và chỗ ở DUY NHẤT của chúng vẫn còn', () {
      expect(settings.contains("'Hiện bản dịch'"), isFalse);
      expect(settings.contains('setWordTapBoxes'), isFalse);
      expect(settings.contains('setTranslationDisplayMode'), isFalse);
      // Box từng từ ⇄ Bôi nhiều chữ: cụm Tùy biến chữ.
      expect(controls.contains('tp.setWordTapBoxes(!tp.wordTapBoxes)'), isTrue);
      // Bản dịch Ẩn / Dưới / Cột: sheet Bố cục đọc.
      expect(topBar.contains('tp.setTranslationDisplayMode(entry.key)'),
          isTrue);
    });

    test('lời giải thích «Box từng từ» không mất — chuyển thành tooltip', () {
      final flat = controls.replaceAll(RegExp(r"'\s*\n\s*'"), '');
      expect(flat.contains("tooltip: context.uiText(\n"), isTrue);
      expect(flat.contains(_boxHint), isTrue);
      expect(generatedPriorityNativePack[_boxHint], isNotNull,
          reason: 'Tooltip phải có bản dịch sẵn trong pack.');
    });

    test('các mục có thật vẫn còn nguyên', () {
      for (final pin in [
        '_FontSizeControl(tp: tp)',
        '_AlignmentSelector(tp: tp)',
        '_TranslationLanguageSection(tp: tp)',
        '_ColorModeSelector(tp: tp)',
        '_WordColorStyleSelector(tp: tp)',
        '_IpaModeSelector(tp: tp)',
        'const _FocusTitlePositionSelector()',
        // PSRC-236 / ADR-0030: `TtsSettingsSection` và `AutoSplitSection`
        // đã rời bảng này (trang «Giọng đọc & engine» / panel Công cụ đọc)
        // — pin ở `psrc_236_read_settings_groups_test.dart`.
        'tp.toggleLineNumbers()',
        'tp.toggleAutoSplit(v)',
        'requestRefresh()',
      ]) {
        expect(settings.contains(pin), isTrue, reason: 'Mất $pin');
      }
    });

    // PSRC-236 / ADR-0030 D1: các mục nay nằm trong 3 nhóm gập. Thứ tự
    // TẦN SUẤT của PSRC-235 (chữ → dịch → màu) vẫn giữ; «Dòng văn bản» và
    // «Focus: giữ tiêu đề» gộp vào nhóm «Chữ & bố cục».
    test('thứ tự theo tần suất dùng: chữ (+ dòng, Focus) → dịch → màu → IPA',
        () {
      final order = [
        '_FontSizeControl(tp: tp)',
        '_AlignmentSelector(tp: tp)',
        '_LineOptions(tp: tp)',
        'const _FocusTitlePositionSelector()',
        '_TranslationLanguageSection(tp: tp)',
        '_ColorModeSelector(tp: tp)',
        '_IpaModeSelector(tp: tp)',
      ];
      var last = -1;
      for (final pin in order) {
        final idx = settings.indexOf(pin);
        expect(idx, greaterThan(last), reason: '$pin sai thứ tự');
        last = idx;
      }
    });
  });

  group('Một đích đến = một tên (hết 4 tầng «Hiển thị»)', () {
    test('không file chrome tab Đọc nào còn nhãn trần «Hiển thị»', () {
      for (final entry in {
        _settingsPath: settings,
        _dockPath: dock,
        _topBarPath: topBar,
        _controlsPath: controls,
        _shellPath: shell,
      }.entries) {
        expect(entry.value.contains("'Hiển thị'"), isFalse,
            reason: '${entry.key} còn nhãn «Hiển thị»');
      }
    });

    // AUDIT v1.30.1 (mục 6) — popup 2 mục «Tùy biến / Cài đặt» cạnh ⚡ đã bị
    // BỎ: góc trên phải chỉ còn MỘT icon ⚙ mở thẳng bảng cài đặt, và «Bố cục
    // đọc» ra thành chip thường trực. Vì vậy shell KHÔNG còn chứa nhãn «Tùy
    // biến» — pin cũ được thay bằng pin mới dưới đây.
    test('panel dock vẫn là «Tùy biến» (một nguồn, một tên)', () {
      expect(dock.contains("ReadDockPanel.display: 'Tùy biến',"), isTrue,
          reason: 'nhãn tab dock (định nghĩa trong read_bottom_dock.dart)');
      expect(dock.contains("tooltip: context.uiText('Tùy biến'),"), isTrue);
    });

    test('AUDIT v1.30.1 #6 — shell mở THẲNG cài đặt, không còn menu 2 mục', () {
      expect(shell.contains('PopupMenuButton'), isFalse,
          reason: 'góc trên phải không còn popup 2 lựa chọn');
      expect(shell.contains("tooltip: context.uiText('Cài đặt'),"), isTrue);
      expect(shell.contains('ReadSettingsSheet.show(context)'), isTrue);
      // Không còn mục «Tùy biến» thứ hai trong shell.
      expect(shell.contains("menuContext.uiText('Tùy biến')"), isFalse);
    });

    test('sheet nhanh = «Bố cục đọc» ở tiêu đề và mọi nút mở nó', () {
      expect(topBar.contains("Text(context.uiText('Bố cục đọc'),"), isTrue,
          reason: 'Tiêu đề sheet');
      expect(topBar.contains("label: context.uiText('Bố cục đọc'),"), isTrue,
          reason: 'Nút trong ReadTopBar (bố cục «Công cụ ở trên»)');
      // AUDIT v1.30.1 (mục 6): chip «Bố cục đọc» đã RA KHỎI panel Tùy biến và
      // thành cụm chip thường trực trong vùng đọc.
      expect(dock.contains("label: Text(context.uiText('Bố cục đọc')),"),
          isTrue,
          reason: 'Chip «Bố cục đọc» thường trực (ngoài panel)');
      // Pin theo từng DÒNG (code format xuống dòng sau `=>`), không pin cả
      // câu — nếu không test đỏ vì xuống dòng, không phải vì hành vi.
      expect(dock.contains('showReadDisplaySheet(context, controller: controller)'),
          isTrue,
          reason: 'Chip mở sheet bố cục đọc');
    });

    test('mục còn lại trong Cài đặt = «Dòng văn bản»', () {
      expect(settings.contains("title: 'Dòng văn bản'"), isTrue);
      expect(settings.contains('class _LineOptions'), isTrue);
      expect(settings.contains('_DisplayOptions'), isFalse);
    });

    // PSRC-236 / ADR-0030 D4: tên nhóm đi theo tab dock «Tùy biến».
    test('tên nhóm trong Cài đặt giao diện khớp tab dock «Tùy biến»', () {
      expect(
          _code('lib/models/read_chrome_layout.dart')
              .contains("'Thông tin & Tùy biến'"),
          isTrue);
      expect(
          _code('lib/models/read_chrome_layout.dart')
              .contains("'Thông tin & Hiển thị'"),
          isFalse);
    });
  });

  group('Rule #5 — chuỗi mới có en + 7 locale ưu tiên', () {
    const priorityLocales = ['en', 'zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja'];
    final vietnameseOnly = RegExp(
      r'[đĐơƠưƯ]|[ảạằắẳẵặầấẩẫậ]|[ẻẽẹềếểễệ]|[ỉĩị]|[ỏọồốổỗộờớởỡợ]|[ủũụừứửữự]|[ỳỷỹỵ]',
    );

    test('generatedPriorityNativePack đủ locale, không rơi về tiếng Việt', () {
      for (final source in _newStrings) {
        final entry = generatedPriorityNativePack[source];
        expect(entry, isNotNull, reason: 'Thiếu pack entry: $source');
        for (final locale in priorityLocales) {
          final value = (entry![locale] ?? '').trim();
          expect(value.isNotEmpty, isTrue, reason: '$source thiếu $locale');
          expect(vietnameseOnly.hasMatch(value), isFalse,
              reason: '$source [$locale] còn ký tự Việt: $value');
        }
        expect(AppUITranslations.translate(source, 'en'), entry!['en']);
        expect(AppUITranslations.translate(source, 'ja'), entry['ja']);
      }
    });

    test('legacy English overrides cũng có', () {
      final overrides = jsonDecode(
        File('tool/legacy_ui_english_overrides.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final source in _newStrings) {
        expect(overrides[source], isNotNull, reason: 'Thiếu en: $source');
        expect(vietnameseOnly.hasMatch(overrides[source] as String), isFalse,
            reason: 'English fallback còn ký tự Việt: $source');
      }
    });
  });
}
