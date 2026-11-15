// test/read_mode/psrc_239_display_controls_convention_test.dart
//
// PSRC-239 / ADR-0032 (bước 4/4 «I4U - Màn hình») — MỘT quy ước điều khiển
// trong cụm «Tùy biến chữ».
//
// Triệu chứng: 6 chip trông giống hệt nhau (`ActionChip`) nhưng làm ba loại
// việc khác nhau — xoay vòng 4 chế độ màu, bật / tắt, mở bảng khác. Nhìn vào
// không đoán được bấm sẽ xảy ra gì; trạng thái bật / tắt chỉ hiện qua màu
// icon.
//
// Quy ước mới (hình dạng nói lên loại việc):
//   * chọn 1 trong N  → nhóm nút chung một viền (`ChoiceChip`);
//   * bật / tắt       → công tắc (`Switch`);
//   * mở bảng khác    → chip rời có mũi tên (`ActionChip`).
//
// Máy bắt ba lớp:
//   1. widget `ReadDisplayControlsView` — đúng kiểu điều khiển cho từng mục,
//      chạm gọi đúng callback, mục theo ngữ cảnh tự ẩn, không tràn ở
//      320 / 360 px và màn ngang với nhãn của 8 locale;
//   2. ghim nguồn cho phần nối dây `ReadDisplayControls` — hàm được gọi và
//      nơi lưu KHÔNG đổi;
//   3. gói ngôn ngữ — mọi nhãn của cụm có đủ 8 locale (quy tắc vàng #5).
//
// Không cần `TextProvider` / Hive / thiết bị: phần vẽ chỉ nhận giá trị và
// callback.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';
import 'package:in4up/models/color_mode.dart';
import 'package:in4up/screens/read_mode/widgets/read_display_controls.dart';

const _controlsPath = 'lib/screens/read_mode/widgets/read_display_controls.dart';

String _src(String path) => File(path).readAsStringSync();

/// Bỏ dòng chú thích `//` để pin chỉ soi CODE.
String _code(String path) => _src(path)
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

int _count(String haystack, String needle) =>
    needle.isEmpty ? 0 : haystack.split(needle).length - 1;

/// Lời giải thích của «Box từng từ» (PSRC-235) — phải còn nguyên.
const _boxHint = 'Tắt = bôi nhiều chữ (mặc định). Bật = mỗi từ một hộp, '
    'long-press lưu từ — nền lưu hàng loạt.';

const _colorKeys = <ColorMode, Key>{
  ColorMode.none: Key('read-display-color-none'),
  ColorMode.wordType: Key('read-display-color-wordType'),
  ColorMode.cefrLevel: Key('read-display-color-cefrLevel'),
  ColorMode.difficulty: Key('read-display-color-difficulty'),
};
const _multiKey = Key('read-display-word-tap-multi');
const _boxesKey = Key('read-display-word-tap-boxes');
const _detailsKey = Key('read-display-switch-color-details');
const _ipaKey = Key('read-display-switch-ipa-colors');
const _focusKey = Key('read-display-switch-focus');
const _syncKey = Key('read-display-switch-auto-sync');
const _guideKey = Key('read-display-line-guide');

/// Trạng thái giả của cụm + nhật ký các callback đã được gọi.
class _Fake {
  ColorMode colorMode = ColorMode.difficulty;
  bool wordTapBoxes = false;
  bool colorDetails = true;
  bool? ipaLegend = false;
  bool? focus = false;
  bool? autoSync = true;
  final List<String> log = <String>[];
}

const _supportedLocales = <Locale>[
  Locale('vi'),
  Locale('en'),
  Locale('hi'),
  Locale('zh'),
  Locale('si'),
  Locale('my'),
  Locale('th'),
  Locale('ja'),
];

/// Dựng cụm trong khung giống panel dock: vùng cuộn dọc, lề 10 px.
Widget _host(
  _Fake fake, {
  Locale locale = const Locale('vi'),
  double textScale = 1.0,
  double horizontalPadding = 10,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: _supportedLocales,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 10),
        child: StatefulBuilder(
          builder: (context, setState) {
            final ipaLegend = fake.ipaLegend;
            final focus = fake.focus;
            final autoSync = fake.autoSync;
            return ReadDisplayControlsView(
              colorMode: fake.colorMode,
              onColorModeSelected: (mode) => setState(() {
                fake.log.add('color:${mode.name}');
                fake.colorMode = mode;
              }),
              wordTapBoxes: fake.wordTapBoxes,
              onWordTapBoxesSelected: (boxes) => setState(() {
                fake.log.add('boxes:$boxes');
                fake.wordTapBoxes = boxes;
              }),
              showColorDetails: fake.colorDetails,
              onShowColorDetailsChanged: (value) => setState(() {
                fake.log.add('details:$value');
                fake.colorDetails = value;
              }),
              ipaLegendVisible: ipaLegend,
              onIpaLegendVisibleChanged: ipaLegend == null
                  ? null
                  : (value) => setState(() {
                        fake.log.add('ipa:$value');
                        fake.ipaLegend = value;
                      }),
              focusMode: focus,
              onFocusModeChanged: focus == null
                  ? null
                  : (value) => setState(() {
                        fake.log.add('focus:$value');
                        fake.focus = value;
                      }),
              autoSync: autoSync,
              onAutoSyncChanged: autoSync == null
                  ? null
                  : (value) => setState(() {
                        fake.log.add('sync:$value');
                        fake.autoSync = value;
                      }),
              onOpenLineGuide: () => fake.log.add('guide'),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Fake fake, {
  Size size = const Size(360, 640),
  Locale locale = const Locale('vi'),
  double textScale = 1.0,
  double horizontalPadding = 10,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _host(
      fake,
      locale: locale,
      textScale: textScale,
      horizontalPadding: horizontalPadding,
    ),
  );
  await tester.pumpAndSettle();
}

ChoiceChip _chip(WidgetTester tester, Key key) => tester.widget<ChoiceChip>(
      find.descendant(of: find.byKey(key), matching: find.byType(ChoiceChip)),
    );

Switch _switchIn(WidgetTester tester, Key key) => tester.widget<Switch>(
      find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
    );

void main() {
  group('PSRC-239 — mỗi điều khiển đúng MỘT trong ba kiểu', () {
    testWidgets('đủ mục: 6 lựa chọn (4 màu + 2 kiểu chạm), 4 công tắc, '
        '1 chip mở bảng', (tester) async {
      final fake = _Fake();
      await _pump(tester, fake);

      expect(find.byType(ChoiceChip), findsNWidgets(6));
      // 3 công tắc gọn + công tắc «Đồng bộ tự động».
      expect(find.byType(Switch), findsNWidgets(4));
      expect(find.byType(ActionChip), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Chọn 1 trong N: cả 4 chế độ màu hiện CÙNG LÚC, đúng một cái đang chọn.
      for (final entry in _colorKeys.entries) {
        expect(find.byKey(entry.value), findsOneWidget);
        expect(
          _chip(tester, entry.value).selected,
          entry.key == ColorMode.difficulty,
          reason: '${entry.key.name}: chỉ chế độ đang dùng được tô chọn',
        );
      }
      expect(find.text('Không màu'), findsOneWidget);
      expect(find.text('Loại từ'), findsOneWidget);
      expect(find.text('CEFR'), findsOneWidget);
      expect(find.text('Độ khó'), findsOneWidget);

      // Hai kiểu chạm chữ đều có TÊN, không còn một nhãn đổi theo trạng thái.
      expect(find.text('Bôi nhiều chữ'), findsOneWidget);
      expect(find.text('Box từng từ'), findsOneWidget);
      expect(_chip(tester, _multiKey).selected, isTrue);
      expect(_chip(tester, _boxesKey).selected, isFalse);

      // Bật / tắt: là `Switch`, giá trị đọc được trên chính điều khiển.
      expect(_switchIn(tester, _detailsKey).value, isTrue);
      expect(_switchIn(tester, _ipaKey).value, isFalse);
      expect(_switchIn(tester, _focusKey).value, isFalse);
      expect(_switchIn(tester, _syncKey).value, isTrue);
      expect(find.text('Thông tin màu'), findsOneWidget);
      expect(find.text('Màu IPA'), findsOneWidget);
      expect(find.text('Chế độ Focus'), findsOneWidget);
      expect(find.text('Đồng bộ tự động'), findsOneWidget);
      // Lời giải thích của «Đồng bộ tự động» (ADR-0024) vẫn ngay dưới nó.
      expect(
        find.text('Tự cuộn theo dòng đang đọc; tắt để cuộn tay.'),
        findsOneWidget,
      );

      // Mở bảng khác: chip rời, có mũi tên.
      expect(
        find.descendant(
          of: find.byKey(_guideKey),
          matching: find.text('Hướng dẫn đọc theo dòng'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_guideKey),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('chế độ màu: chạm là CHỌN THẲNG, không xoay vòng',
        (tester) async {
      final fake = _Fake();
      await _pump(tester, fake);

      await tester.tap(find.byKey(_colorKeys[ColorMode.cefrLevel]!));
      await tester.pumpAndSettle();
      expect(fake.log, ['color:cefrLevel']);
      expect(_chip(tester, _colorKeys[ColorMode.cefrLevel]!).selected, isTrue);
      expect(
          _chip(tester, _colorKeys[ColorMode.difficulty]!).selected, isFalse);

      // Từ CEFR về thẳng «Không màu» — trước đây phải bấm 2 lần qua «Độ khó».
      await tester.tap(find.byKey(_colorKeys[ColorMode.none]!));
      await tester.pumpAndSettle();
      expect(fake.log, ['color:cefrLevel', 'color:none']);
      expect(_chip(tester, _colorKeys[ColorMode.none]!).selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kiểu chạm chữ: hai lựa chọn có tên, chạm cái nào ra cái đó',
        (tester) async {
      final fake = _Fake();
      await _pump(tester, fake);

      await tester.tap(find.byKey(_boxesKey));
      await tester.pumpAndSettle();
      expect(fake.log, ['boxes:true']);
      expect(_chip(tester, _boxesKey).selected, isTrue);
      expect(_chip(tester, _multiKey).selected, isFalse);

      await tester.tap(find.byKey(_multiKey));
      await tester.pumpAndSettle();
      expect(fake.log, ['boxes:true', 'boxes:false']);
      expect(_chip(tester, _multiKey).selected, isTrue);
    });

    testWidgets('lời giải thích «Box từng từ» còn — tooltip của lựa chọn đó',
        (tester) async {
      await _pump(tester, _Fake());
      expect(find.byTooltip(_boxHint), findsOneWidget);
      expect(_chip(tester, _boxesKey).tooltip, _boxHint);
    });

    testWidgets('công tắc: chạm cả hàng hoặc chạm nút gạt đều đổi MỘT lần',
        (tester) async {
      final fake = _Fake();
      await _pump(tester, fake);

      // Chạm vào hàng (nhãn).
      await tester.tap(find.text('Thông tin màu'));
      await tester.pumpAndSettle();
      expect(fake.log, ['details:false']);
      expect(_switchIn(tester, _detailsKey).value, isFalse);

      // Chạm thẳng vào nút gạt.
      await tester.tap(
        find.descendant(
          of: find.byKey(_detailsKey),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.log, ['details:false', 'details:true']);

      await tester.tap(find.text('Màu IPA'));
      await tester.tap(find.text('Chế độ Focus'));
      await tester.pumpAndSettle();
      expect(fake.log.sublist(2), ['ipa:true', 'focus:true']);

      await tester.tap(find.text('Đồng bộ tự động'));
      await tester.pumpAndSettle();
      expect(fake.log.last, 'sync:false');
      expect(_switchIn(tester, _syncKey).value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chip «Hướng dẫn đọc theo dòng» mở bảng, không đổi trạng thái',
        (tester) async {
      final fake = _Fake();
      await _pump(tester, fake);
      await tester.tap(find.byKey(_guideKey));
      await tester.pumpAndSettle();
      expect(fake.log, ['guide']);
    });
  });

  group('PSRC-239 — mục theo ngữ cảnh tự ẩn (như trước)', () {
    testWidgets('không có controller (app bar shell): ẩn Focus + Đồng bộ tự '
        'động, phần còn lại vẫn dùng được', (tester) async {
      final fake = _Fake()
        ..focus = null
        ..autoSync = null;
      await _pump(tester, fake);

      expect(find.byKey(_focusKey), findsNothing);
      expect(find.byKey(_syncKey), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(6));
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.byKey(_guideKey), findsOneWidget);

      await tester.tap(find.byKey(_colorKeys[ColorMode.wordType]!));
      await tester.tap(find.text('Thông tin màu'));
      await tester.pumpAndSettle();
      expect(fake.log, ['color:wordType', 'details:false']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lớp IPA đang ẩn: không có công tắc «Màu IPA»',
        (tester) async {
      final fake = _Fake()..ipaLegend = null;
      await _pump(tester, fake);
      expect(find.byKey(_ipaKey), findsNothing);
      expect(find.text('Màu IPA'), findsNothing);
      expect(find.byType(Switch), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('chỉ còn một công tắc gọn: vẫn dựng được, không tràn',
        (tester) async {
      final fake = _Fake()
        ..ipaLegend = null
        ..focus = null
        ..autoSync = null;
      await _pump(tester, fake, size: const Size(320, 640));
      expect(find.byType(Switch), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PSRC-239 — bố cục: 2 cột công tắc khi đủ chỗ, không tràn', () {
    testWidgets('320 px: hai công tắc đầu nằm CÙNG hàng (2 cột)',
        (tester) async {
      await _pump(tester, _Fake(), size: const Size(320, 640));
      final details = tester.getRect(find.byKey(_detailsKey));
      final ipa = tester.getRect(find.byKey(_ipaKey));
      final focus = tester.getRect(find.byKey(_focusKey));
      expect(details.center.dy, moreOrLessEquals(ipa.center.dy, epsilon: 0.5));
      expect(ipa.left, greaterThan(details.right));
      expect(focus.top, greaterThanOrEqualTo(details.bottom - 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cỡ chữ lớn (ngoài mức app cho phép): về MỘT cột',
        (tester) async {
      await _pump(tester, _Fake(), size: const Size(320, 640), textScale: 1.6);
      final details = tester.getRect(find.byKey(_detailsKey));
      final ipa = tester.getRect(find.byKey(_ipaKey));
      expect(ipa.top, greaterThanOrEqualTo(details.bottom - 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('8 locale × (320 / 360 px, màn ngang) × lề dock / lề sheet × '
        'cỡ chữ 1.0 / 1.15: không tràn', (tester) async {
      const sizes = <Size>[Size(320, 640), Size(360, 640), Size(640, 360)];
      // 1.15 là mức trần app kẹp lại (`AppResponsive.clampTextScaler`).
      const scales = <double>[1.0, 1.15];
      // 10 px = lề panel dock; 20 px = lề sheet «Bố cục đọc».
      const paddings = <double>[10, 20];
      for (final locale in _supportedLocales) {
        for (final size in sizes) {
          for (final scale in scales) {
            for (final padding in paddings) {
              final fake = _Fake()
                ..ipaLegend = true
                ..wordTapBoxes = true;
              await _pump(
                tester,
                fake,
                size: size,
                locale: locale,
                textScale: scale,
                horizontalPadding: padding,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: 'Tràn ở locale=$locale size=$size scale=$scale '
                    'padding=$padding',
              );
              expect(find.byType(ChoiceChip), findsNWidgets(6));
              expect(find.byType(Switch), findsNWidgets(4));
            }
          }
        }
      }
    });

    testWidgets('locale khác vi: nhãn KHÔNG còn tiếng Việt (quy tắc vàng #5)',
        (tester) async {
      await _pump(tester, _Fake(), locale: const Locale('en'));
      for (final vietnamese in const [
        'Không màu',
        'Loại từ',
        'Độ khó',
        'Bôi nhiều chữ',
        'Box từng từ',
        'Thông tin màu',
        'Màu IPA',
        'Chế độ Focus',
        'Đồng bộ tự động',
        'Hướng dẫn đọc theo dòng',
        'Tùy biến chữ',
      ]) {
        final english = AppUITranslations.translate(vietnamese, 'en');
        expect(english, isNot(vietnamese), reason: 'Thiếu bản en: $vietnamese');
        expect(find.text(vietnamese), findsNothing, reason: vietnamese);
        expect(find.text(english), findsOneWidget, reason: english);
      }
    });
  });

  group('PSRC-239 — nối dây: hàm được gọi và nơi lưu KHÔNG đổi', () {
    final code = _code(_controlsPath);

    test('một quy ước: đúng 1 `ChoiceChip`, 1 `ActionChip`, công tắc là '
        '`Switch` / `SwitchListTile`', () {
      // `_Choice` là nơi DUY NHẤT dựng `ChoiceChip` ⇒ mọi lựa chọn trông
      // như nhau.
      expect(_count(code, 'ChoiceChip('), 1);
      // Chip rời chỉ còn cho việc «mở bảng khác».
      expect(_count(code, 'ActionChip('), 1);
      expect(code.contains('onPressed: onOpenLineGuide,'), isTrue);
      expect(code.contains('Icons.chevron_right'), isTrue);
      expect(_count(code, 'Switch('), 1);
      expect(_count(code, 'SwitchListTile('), 1);
      // Không còn kiểu «nhãn đổi theo trạng thái».
      expect(code.contains("? 'Box từng từ' : 'Bôi nhiều chữ'"), isFalse);
    });

    test('chế độ màu: chọn thẳng qua `setColorMode`, không xoay vòng', () {
      expect(code.contains('tp.setColorMode(mode);'), isTrue);
      expect(code.contains('if (mode == tp.colorMode) return;'), isTrue);
      expect(code.contains('cycleColorMode'), isFalse);
      expect(code.contains('for (final mode in ColorMode.values)'), isTrue);
    });

    test('các mục còn lại gọi ĐÚNG hàm cũ', () {
      for (final pin in [
        'tp.setWordTapBoxes(!tp.wordTapBoxes);',
        'if (boxes == tp.wordTapBoxes) return;',
        'tp.setShowColorModeDetails(value)',
        'tp.setIpaLegendVisible(value)',
        'ctrl.toggleFocusMode()',
        'ctrl.toggleAutoSync()',
        'ReadLineHint.showSheet(context)',
        'tp.ipaDisplayMode != IpaDisplayMode.hidden',
      ]) {
        expect(code.contains(pin), isTrue, reason: 'Thiếu $pin');
      }
    });

    test('vẫn là MỘT cụm cho cả ba lối vào (ADR-0024 D1)', () {
      expect(
        _code('lib/screens/read_mode/widgets/read_bottom_dock.dart')
            .contains('ReadDisplayControls(controller: controller)'),
        isTrue,
      );
      expect(
        _code('lib/screens/read_mode/widgets/read_top_bar.dart')
            .contains('ReadDisplayControls(controller: readController)'),
        isTrue,
      );
      // Không thêm state mới vào provider cho việc đổi hình dạng.
      expect(code.contains('StatefulWidget'), isFalse);
    });
  });

  group('PSRC-239 i18n (quy tắc vàng #5)', () {
    test('mọi nhãn của cụm có đủ 8 locale trong gói ưu tiên', () {
      const locales = ['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja'];
      for (final key in const [
        'Tùy biến chữ',
        'Không màu',
        'Loại từ',
        'Độ khó',
        'Bôi nhiều chữ',
        'Box từng từ',
        'Thông tin màu',
        'Màu IPA',
        'Chế độ Focus',
        'Đồng bộ tự động',
        'Tự cuộn theo dòng đang đọc; tắt để cuộn tay.',
        'Hướng dẫn đọc theo dòng',
        _boxHint,
      ]) {
        final entry = generatedPriorityNativePack[key];
        expect(entry, isNotNull, reason: 'Thiếu «$key» trong gói');
        for (final locale in locales) {
          expect(
            (entry![locale] ?? '').trim(),
            isNotEmpty,
            reason: '«$key» thiếu bản $locale',
          );
        }
      }
    });
  });
}
