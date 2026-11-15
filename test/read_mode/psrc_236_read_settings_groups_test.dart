// PSRC-236 / ADR-0030 — «Cài đặt Text Studio» thành nhóm gập (bước 2/4 của
// yêu cầu owner «I4U - Màn hình»; bước 1 = PSRC-235).
//
// Triệu chứng owner: phần cài đặt tab Đọc «vốn đang rất dài».
//
// Nguyên nhân gốc còn lại sau PSRC-235 (đọc code):
//   1. Bảng là MỘT trang cuộn ⇒ muốn biết đang tô màu gì / IPA bật hay tắt /
//      dịch sang tiếng nào thì phải cuộn tới từng mục.
//   2. Nguyên khối `TtsSettingsSection` (thứ tự engine, model, giọng theo
//      ngôn ngữ, cache, giấy phép — chỉnh MỘT LẦN) nằm chung cột với cỡ chữ.
//   3. `AutoSplitSection` là một THAO TÁC (xem trước → Áp dụng → ghi đè văn
//      bản) nhưng nằm cuối bảng cấu hình.
//
// Cách sửa (ADR-0030):
//   D1  3 nhóm gập, mỗi nhóm có dòng tóm tắt, mở một nhóm mỗi lần.
//   D2  trang riêng «Giọng đọc & engine».
//   D3  «Tách dòng tự động» về panel Công cụ đọc / ReadTopBar.
//   D4  nhóm chrome «Thông tin & Hiển thị» → «Thông tin & Tùy biến».
//   D5  ghi chú: «Chế độ trải nghiệm» TẠM bỏ, đường nối lại còn nguyên.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';
import 'package:in4up/screens/read_mode/widgets/read_settings_group.dart';

String _src(String path) => File(path).readAsStringSync();

/// Bỏ dòng chú thích `//` để pin chỉ soi CODE.
String _code(String path) => _src(path)
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _settingsPath = 'lib/screens/read_mode/sheets/read_settings_sheet.dart';
const _groupPath = 'lib/screens/read_mode/widgets/read_settings_group.dart';
const _voicePagePath =
    'lib/screens/read_mode/sheets/read_voice_settings_page.dart';
const _autoSplitSheetPath =
    'lib/screens/read_mode/sheets/auto_split_sheet.dart';
const _dockPath = 'lib/screens/read_mode/widgets/read_bottom_dock.dart';
const _topBarPath = 'lib/screens/read_mode/widgets/read_top_bar.dart';
const _adrPath =
    'docs/adr/0030-doc-tab-cai-dat-nhom-gap-va-trang-giong-doc.md';

/// Chuỗi UI mới của PSRC-236 (quy tắc vàng #5).
const _newStrings = [
  'Chữ & bố cục',
  'Màu & phiên âm',
  'Giọng đọc & engine',
  'Thứ tự engine, giọng theo ngôn ngữ, model, cache',
  'Nút đọc, tốc độ và Tách dòng tự động nằm ở thanh công cụ đọc.',
  'Thông tin & Tùy biến',
];

Widget _host(Widget child, {double width = 360}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

void main() {
  final settings = _code(_settingsPath);
  final groupSrc = _code(_groupPath);
  final voicePage = _code(_voicePagePath);
  final autoSplitSheet = _code(_autoSplitSheetPath);
  final dock = _code(_dockPath);
  final topBar = _code(_topBarPath);

  group('D1 — widget: nhóm gập có dòng tóm tắt', () {
    const tapKey = Key('group-under-test');
    const childKey = Key('group-child');

    testWidgets('GẬP: thấy tên + tóm tắt, KHÔNG dựng nội dung', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(ReadSettingsGroup(
        tapKey: tapKey,
        icon: Icons.text_fields,
        title: 'Chữ & bố cục',
        summary: 'Font size 18 · Center',
        open: false,
        onToggle: () => taps++,
        children: const [SizedBox(key: childKey, height: 40)],
      )));

      // Tên nhóm là chuỗi nguồn tiếng Việt ⇒ tự dịch theo locale (test chạy
      // ở locale en) — rule #5.
      final title = AppUITranslations.translateExact('Chữ & bố cục', 'en');
      expect(title, isNot('Chữ & bố cục'));
      expect(find.text(title), findsOneWidget);
      expect(find.text('Font size 18 · Center'), findsOneWidget);
      expect(find.byKey(childKey), findsNothing,
          reason: 'Gập thì nội dung không được dựng (trang phải ngắn).');
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      await tester.tap(find.byKey(tapKey));
      expect(taps, 1, reason: 'Chạm tiêu đề phải gọi onToggle đúng 1 lần.');
    });

    testWidgets('MỞ: dựng nội dung, mũi tên đổi chiều, tóm tắt vẫn hiện',
        (tester) async {
      await tester.pumpWidget(_host(ReadSettingsGroup(
        tapKey: tapKey,
        icon: Icons.palette,
        title: 'Màu & phiên âm',
        summary: 'CEFR · IPA: Off',
        open: true,
        onToggle: () {},
        children: const [SizedBox(key: childKey, height: 40)],
      )));

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.text('CEFR · IPA: Off'), findsOneWidget);
    });

    testWidgets('320 px + nhãn rất dài: không tràn, vùng chạm ≥ 56 px',
        (tester) async {
      await tester.pumpWidget(_host(
        ReadSettingsGroup(
          tapKey: tapKey,
          icon: Icons.compare_arrows_rounded,
          title: 'ဘာသာပြန်ခြင်းနှင့် ဘာသာစကားနှစ်မျိုးဖြင့် ဖတ်ရှုခြင်း ' * 3,
          summary: 'Português (Brasil) → Bahasa Indonesia · ' * 4,
          summaryColor: Colors.amber,
          open: false,
          onToggle: () {},
          children: const [SizedBox(height: 40)],
        ),
        width: 320,
      ));

      expect(tester.takeException(), isNull,
          reason: 'Nhãn dài phải bị cắt «…», không được tràn RenderFlex.');
      expect(tester.getSize(find.byKey(tapKey)).height,
          greaterThanOrEqualTo(56));
      expect(tester.getSize(find.byKey(tapKey)).width, lessThanOrEqualTo(320));
    });

    testWidgets('dòng mở TRANG CON: mũi tên phải, chạm gọi onTap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(ReadSettingsLinkRow(
        tapKey: tapKey,
        icon: Icons.record_voice_over,
        title: 'Giọng đọc & engine',
        summary: 'Thứ tự engine, giọng theo ngôn ngữ, model, cache',
        onTap: () => taps++,
      )));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing,
          reason: 'Mở trang khác ≠ gập/mở tại chỗ ⇒ khác mũi tên.');
      expect(
        find.text(AppUITranslations.translateExact('Giọng đọc & engine', 'en')),
        findsOneWidget,
      );
      expect(
        find.text(AppUITranslations.translateExact(
            'Thứ tự engine, giọng theo ngôn ngữ, model, cache', 'en')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(tapKey));
      expect(taps, 1);
    });
  });

  group('D1 — bảng Cài đặt: 3 nhóm, một nhóm mở mỗi lần', () {
    int at(String pin) {
      final idx = settings.indexOf(pin);
      expect(idx, greaterThanOrEqualTo(0), reason: 'Mất $pin');
      return idx;
    }

    test('3 nhóm + dòng «Giọng đọc & engine» đúng thứ tự tần suất', () {
      expect(
          settings.contains('enum _SettingsGroupId { text, translation, color }'),
          isTrue);
      final text = at("title: 'Chữ & bố cục',");
      final translation = at("title: 'Dịch & đọc song ngữ',");
      final color = at("title: 'Màu & phiên âm',");
      final voice = at("title: 'Giọng đọc & engine',");
      expect(text < translation, isTrue);
      expect(translation < color, isTrue);
      expect(color < voice, isTrue);
    });

    test('mỗi điều khiển cũ nằm đúng nhóm của nó — không mất cái nào', () {
      final text = at("title: 'Chữ & bố cục',");
      final translation = at("title: 'Dịch & đọc song ngữ',");
      final color = at("title: 'Màu & phiên âm',");
      final voice = at("title: 'Giọng đọc & engine',");

      void inside(String pin, int from, int to, String groupName) {
        final idx = at(pin);
        expect(idx > from && idx < to, isTrue,
            reason: '$pin phải nằm trong nhóm «$groupName»');
      }

      for (final pin in [
        '_FontSizeControl(tp: tp)',
        '_AlignmentSelector(tp: tp)',
        '_LineOptions(tp: tp)',
        'const _FocusTitlePositionSelector()',
      ]) {
        inside(pin, text, translation, 'Chữ & bố cục');
      }
      inside('_TranslationLanguageSection(tp: tp)', translation, color,
          'Dịch & đọc song ngữ');
      for (final pin in [
        '_ColorModeSelector(tp: tp)',
        '_WordColorStyleSelector(tp: tp)',
        '_LegendPanel(colorMode: tp.colorMode)',
        '_GrammarHighlightSection(tp: tp)',
        '_IpaModeSelector(tp: tp)',
        'const _IpaSaveSourceSection()',
        '_IpaColorOptions(tp: tp)',
      ]) {
        inside(pin, color, voice, 'Màu & phiên âm');
      }
    });

    test('dòng tóm tắt lấy GIÁ TRỊ THẬT từ provider (không chép cứng)', () {
      for (final pin in [
        'tp.fontSize.round()',
        'tp.textAlign == TextAlign.center',
        'source.nativeName',
        'target.nativeName',
        'context.uiText(tp.colorMode.label)',
        'context.uiText(tp.ipaDisplayMode.label)',
      ]) {
        expect(settings.contains(pin), isTrue, reason: 'Mất $pin');
      }
      // Cặp nguồn = đích phải lộ ngay ở tầng ngoài.
      expect(settings.contains('summaryColor: tp.translationPairUsesSameLanguage'),
          isTrue);
    });

    test('mở một nhóm ⇒ gập nhóm đang mở; nhớ nhóm trong phiên', () {
      expect(settings.contains('_open = opening ? id : null;'), isTrue);
      expect(settings.contains('static _SettingsGroupId? _lastOpen;'), isTrue);
      expect(settings.contains('_SettingsGroupId? _open = _lastOpen;'), isTrue);
      for (final id in ['text', 'translation', 'color']) {
        expect(settings.contains('open: _open == _SettingsGroupId.$id,'), isTrue);
        expect(
            settings.contains('onToggle: () => _toggle(_SettingsGroupId.$id),'),
            isTrue);
      }
    });

    test('gập/mở KHÔNG dùng animation (ADR-0021 D4)', () {
      // Khối dựng nhóm gập: cấm mọi widget Animated*.
      for (final banned in [
        'AnimatedSize',
        'AnimatedCrossFade',
        'AnimatedContainer',
        'AnimatedOpacity',
        'ExpansionTile',
        'ExpansionPanel',
      ]) {
        expect(groupSrc.contains(banned), isFalse, reason: 'Cấm $banned');
      }
      // Bảng Cài đặt: cấm thứ làm ĐỔI CHIỀU CAO có animation (các nút chọn
      // bên trong vẫn được dùng AnimatedContainer đổi màu như trước).
      for (final banned in [
        'AnimatedSize',
        'AnimatedCrossFade',
        'ExpansionTile',
        'ExpansionPanel',
      ]) {
        expect(settings.contains(banned), isFalse, reason: 'Cấm $banned');
      }
      expect(groupSrc.contains('if (open)'), isTrue);
      expect(groupSrc.contains('minHeight: 56'), isTrue);
    });

    test('hợp đồng cũ của bảng còn nguyên', () {
      expect(settings.contains("'Cài đặt Text Studio'"), isTrue);
      expect(settings.contains('initialChildSize: 0.6'), isTrue);
      expect(settings.contains('builder: (context) => const _SettingsContent(),'),
          isTrue);
      expect(settings.contains('requestRefresh()'), isTrue);
    });
  });

  group('D2 — trang «Giọng đọc & engine»', () {
    test('bảng Cài đặt KHÔNG còn nhúng khối engine', () {
      expect(settings.contains('TtsSettingsSection'), isFalse);
      expect(settings.contains('tts_settings_section.dart'), isFalse);
      expect(settings.contains('ReadVoiceSettingsPage.open(context)'), isTrue);
    });

    test('trang riêng chứa đúng TtsSettingsSection, có Scaffold riêng', () {
      expect(voicePage.contains('class ReadVoiceSettingsPage'), isTrue);
      expect(voicePage.contains('TtsSettingsSection('), isTrue);
      expect(voicePage.contains('Scaffold('), isTrue,
          reason: 'SnackBar của import model phải hiện trên chính trang này.');
      expect(voicePage.contains("context.uiText('Giọng đọc & engine')"), isTrue);
      expect(voicePage.contains('MaterialPageRoute<void>('), isTrue);
    });

    test('trang giọng đọc KHÔNG phải lối phát thứ hai (ADR-0021 D1)', () {
      for (final banned in ['speakLine(', 'speakAll(', 'setTtsSpeed(']) {
        expect(voicePage.contains(banned), isFalse, reason: 'Cấm $banned');
        expect(settings.contains(banned), isFalse, reason: 'Cấm $banned');
      }
    });
  });

  group('D3 — «Tách dòng tự động» là công cụ, không phải cài đặt', () {
    test('bảng Cài đặt KHÔNG còn AutoSplitSection', () {
      expect(settings.contains('AutoSplitSection'), isFalse);
      expect(settings.contains('auto_split_section.dart'), isFalse);
    });

    test('sheet riêng giữ nguyên logic áp dụng', () {
      expect(autoSplitSheet.contains('void showAutoSplitSheet(BuildContext context)'),
          isTrue);
      expect(autoSplitSheet.contains('AutoSplitSection('), isTrue);
      expect(autoSplitSheet.contains('currentText: tp.fullText,'), isTrue);
      expect(autoSplitSheet.contains('tp.loadFromLines(lines);'), isTrue);
      expect(autoSplitSheet.contains('Navigator.pop(sheetContext);'), isTrue);
      expect(autoSplitSheet.contains('messenger?.showSnackBar('), isTrue);
    });

    test('lối vào ở panel Công cụ đọc của dock', () {
      expect(dock.contains("key: const Key('read-dock-auto-split'),"), isTrue);
      expect(dock.contains("label: Text(context.uiText('Tách dòng tự động')),"),
          isTrue);
      expect(dock.contains('onPressed: () => showAutoSplitSheet(context),'),
          isTrue);
      // Chip nằm TRONG _ToolsPanel, không phải panel khác.
      final tools = dock.indexOf('class _ToolsPanel');
      final display = dock.indexOf('class _DisplayPanel');
      final chip = dock.indexOf("Key('read-dock-auto-split')");
      expect(chip > tools && chip < display, isTrue);
    });

    test('bố cục «Công cụ ở trên» (không có dock) cũng có lối vào', () {
      expect(topBar.contains("label: context.uiText('Tách dòng tự động'),"),
          isTrue);
      expect(topBar.contains('onPressed: () => showAutoSplitSheet(context),'),
          isTrue);
    });

    test('bảng Cài đặt chỉ đường tới chỗ mới (không «mất nút»)', () {
      expect(
          settings.contains(
              "'Nút đọc, tốc độ và Tách dòng tự động nằm ở thanh công cụ đọc.'"),
          isTrue);
    });
  });

  group('D4 — tên nhóm chrome khớp tab dock «Tùy biến»', () {
    test('model + Cài đặt giao diện cùng một tên mới', () {
      final layout = _code('lib/models/read_chrome_layout.dart');
      final shellSettings =
          _code('lib/screens/settings/shell_ui_settings_screen.dart');
      expect(layout.contains("'Thông tin & Tùy biến'"), isTrue);
      expect(shellSettings.contains("context.uiText('Thông tin & Tùy biến')"),
          isTrue);
      expect(layout.contains("'Thông tin & Hiển thị'"), isFalse);
      expect(shellSettings.contains("'Thông tin & Hiển thị'"), isFalse);
    });

    test('chuỗi cũ vẫn ở trong pack (pin _newStrings của READ-UI-120)', () {
      expect(generatedPriorityNativePack['Thông tin & Hiển thị'], isNotNull);
    });
  });

  group('D5 — «Chế độ trải nghiệm» TẠM bỏ: ghi chú và đường nối lại', () {
    test('ADR-0030 ghi quyết định của owner ngày 2026-11-15', () {
      final adr = _src(_adrPath);
      expect(adr.contains('«Chế độ trải nghiệm» TẠM bỏ'), isTrue);
      expect(adr.contains('2026-11-15'), isTrue);
      expect(adr.contains('sẽ thêm lại'), isTrue);
    });

    test('khoá ARB và nơi lưu còn nguyên để thêm lại sau', () {
      expect(_src('lib/l10n/app_en.arb').contains('"grammarExperienceMode"'),
          isTrue);
      final storage = _src('lib/services/storage_service.dart');
      expect(storage.contains('getShellReadSubMode()'), isTrue);
      expect(storage.contains('saveShellReadSubMode('), isTrue);
    });

    test('chưa ai dựng lại bộ chọn chỉ-ghi-state', () {
      expect(settings.contains('_SubModeSelector'), isFalse);
      expect(settings.contains('setSubMode'), isFalse);
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

    test('mọi nhãn mới trong code đều là chuỗi đã có trong catalog', () {
      for (final source in _newStrings) {
        expect(AppUITranslations.containsSource(source), isTrue,
            reason: 'Chuỗi chưa đăng ký: $source');
      }
    });
  });
}
