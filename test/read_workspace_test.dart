// test/read_workspace_test.dart
//
// I4U-READ-UX-001 — kiểm thử lớp UX tab Đọc:
//   Mode (Đọc/Viết) → Source (Tài liệu/Web/Tam tạng) → Tool (Dịch/Ngữ
//   pháp/Phát âm/Từ điển).
//
// Phạm vi: chỉ kiểm thử các thành phần mới trong
// lib/screens/read_mode/widgets/read_source_picker.dart,
// lib/screens/read_mode/widgets/read_text_action_hooks.dart và enum
// lib/models/read_content_source.dart. Không dựng lại toàn bộ
// ReadModeScreen (cần Provider tree lớn không thuộc phạm vi agent này).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/read_content_source.dart';
import 'package:in4up/models/workspace_navigation.dart';
import 'package:in4up/screens/read_mode/widgets/read_source_picker.dart';
import 'package:in4up/screens/read_mode/widgets/read_text_action_hooks.dart';
import 'package:in4up/widgets/workspace_navigation/workspace_mode_bar.dart';

/// Lựa chọn Mode cục bộ dùng riêng cho test — không phải enum thật của
/// main_shell (nằm ngoài phạm vi file được giao), chỉ để xác nhận Source
/// picker không vô tình đụng vào trạng thái Mode khi dùng chung một màn
/// hình.
enum _ReadModeChoice { read, write }

const _supportedTestLocales = [Locale('vi'), Locale('en')];
const _testLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Host mặc định khoá locale 'vi' — `ReadSourcePicker`/`ReadTextActionBar`
/// dịch nhãn qua `context.uiText(...)` tại nơi hiển thị (Quy tắc vàng #5,
/// AGENTS.md); ở locale 'vi' hàm dịch luôn trả nguyên văn, nên các assertion
/// `find.text('Tài liệu')`, `find.text('Dịch')`,… ở các nhóm test khác vẫn
/// đúng và không phụ thuộc catalog dịch có đủ hay chưa.
Widget _host(
  Widget child, {
  double width = 800,
  double height = 600,
  Locale locale = const Locale('vi'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: _supportedTestLocales,
    localizationsDelegates: _testLocalizationsDelegates,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

void main() {
  group('ReadContentSource enum/labels', () {
    test('has exactly document, web, tipitaka in that order', () {
      expect(ReadContentSource.values, [
        ReadContentSource.document,
        ReadContentSource.web,
        ReadContentSource.tipitaka,
      ]);
    });

    test('exposes a distinct, non-empty Vietnamese label per source', () {
      final labels = ReadContentSource.values.map((s) => s.label).toSet();
      expect(labels.length, ReadContentSource.values.length);
      for (final source in ReadContentSource.values) {
        expect(source.label, isNotEmpty);
      }
      expect(ReadContentSource.document.label, 'Tài liệu');
      expect(ReadContentSource.web.label, 'Web');
      expect(ReadContentSource.tipitaka.label, 'Tam tạng');
    });

    test('exposes a distinct icon per source', () {
      final icons = ReadContentSource.values.map((s) => s.icon).toSet();
      expect(icons.length, ReadContentSource.values.length);
    });
  });

  group('ReadSourcePicker callback contract', () {
    testWidgets('renders a chip for every ReadContentSource value',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.document,
            onSourceChanged: (_) {},
          ),
        ),
      );

      for (final source in ReadContentSource.values) {
        expect(find.text(source.label), findsOneWidget);
      }
    });

    testWidgets('marks the selected source as the active chip',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.web,
            onSourceChanged: (_) {},
          ),
        ),
      );

      final webChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Web'),
      );
      expect(webChip.selected, isTrue);
    });

    testWidgets('always reports the picked source via onSourceChanged',
        (tester) async {
      ReadContentSource? reported;
      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.document,
            onSourceChanged: (value) => reported = value,
          ),
        ),
      );

      await tester.tap(find.text('Tam tạng'));
      expect(reported, ReadContentSource.tipitaka);
    });

    testWidgets(
        'onOpenDocumentLibrary fires only for the document source and never '
        'the others', (tester) async {
      var documentOpened = 0;
      var webOpened = 0;
      var tipitakaOpened = 0;

      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.web,
            onSourceChanged: (_) {},
            callbacks: ReadSourceCallbacks(
              onOpenDocumentLibrary: () => documentOpened++,
              onOpenWebReader: () => webOpened++,
              onOpenTipitakaLibrary: () => tipitakaOpened++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tài liệu'));
      expect(documentOpened, 1);
      expect(webOpened, 0);
      expect(tipitakaOpened, 0);
    });

    testWidgets(
        'onOpenWebReader and onOpenTipitakaLibrary each fire exactly once '
        'for their own source', (tester) async {
      var webOpened = 0;
      var tipitakaOpened = 0;

      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.document,
            onSourceChanged: (_) {},
            callbacks: ReadSourceCallbacks(
              onOpenWebReader: () => webOpened++,
              onOpenTipitakaLibrary: () => tipitakaOpened++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Web'));
      await tester.tap(find.text('Tam tạng'));

      expect(webOpened, 1);
      expect(tipitakaOpened, 1);
    });

    testWidgets('missing callbacks stay safe no-ops (no throw)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.document,
            onSourceChanged: (_) {},
            // callbacks intentionally left at default (all null) —
            // simulates the integration agent not having wired navigation
            // yet.
          ),
        ),
      );

      await tester.tap(find.text('Web'));
      expect(tester.takeException(), isNull);
    });
  });

  group('Mode vs Source isolation', () {
    testWidgets('selecting a source does not change the mode selection',
        (tester) async {
      _ReadModeChoice mode = _ReadModeChoice.read;
      ReadContentSource source = ReadContentSource.document;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WorkspaceModeBar<_ReadModeChoice>(
                    items: const [
                      WorkspaceNavigationItem(
                        value: _ReadModeChoice.read,
                        label: 'Đọc',
                        icon: Icons.menu_book,
                      ),
                      WorkspaceNavigationItem(
                        value: _ReadModeChoice.write,
                        label: 'Viết',
                        icon: Icons.edit,
                      ),
                    ],
                    selectedValue: mode,
                    onChanged: (value) => setState(() => mode = value),
                    presentation: WorkspaceNavigationPresentation.chips,
                  ),
                  ReadSourcePicker(
                    selectedSource: source,
                    onSourceChanged: (value) =>
                        setState(() => source = value),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Tam tạng'));
      await tester.pump();

      expect(source, ReadContentSource.tipitaka);
      expect(mode, _ReadModeChoice.read, reason: 'mode must stay untouched');

      final readChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Đọc'),
      );
      expect(readChip.selected, isTrue);
    });

    testWidgets('selecting a mode does not change the source selection',
        (tester) async {
      _ReadModeChoice mode = _ReadModeChoice.read;
      ReadContentSource source = ReadContentSource.document;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WorkspaceModeBar<_ReadModeChoice>(
                    items: const [
                      WorkspaceNavigationItem(
                        value: _ReadModeChoice.read,
                        label: 'Đọc',
                        icon: Icons.menu_book,
                      ),
                      WorkspaceNavigationItem(
                        value: _ReadModeChoice.write,
                        label: 'Viết',
                        icon: Icons.edit,
                      ),
                    ],
                    selectedValue: mode,
                    onChanged: (value) => setState(() => mode = value),
                    presentation: WorkspaceNavigationPresentation.chips,
                  ),
                  ReadSourcePicker(
                    selectedSource: source,
                    onSourceChanged: (value) =>
                        setState(() => source = value),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Viết'));
      await tester.pump();

      expect(mode, _ReadModeChoice.write);
      expect(source, ReadContentSource.document,
          reason: 'source must stay untouched');
    });
  });

  group('ReadTextActionBar hooks', () {
    testWidgets('renders nothing when no action callback is wired',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ReadTextActionBar(
            selectedText: 'anicca',
            callbacks: ReadTextActionCallbacks(),
          ),
        ),
      );

      expect(find.byKey(const Key('read-text-action-bar')), findsNothing);
      expect(find.text('Dịch'), findsNothing);
    });

    testWidgets('renders nothing when there is no selected text',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadTextActionBar(
            selectedText: '   ',
            callbacks: ReadTextActionCallbacks(onTranslate: (_) {}),
          ),
        ),
      );

      expect(find.byKey(const Key('read-text-action-bar')), findsNothing);
    });

    testWidgets('only shows buttons for the actions that have a callback',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadTextActionBar(
            selectedText: 'dukkha',
            callbacks: ReadTextActionCallbacks(
              onTranslate: (_) {},
              onDictionary: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Dịch'), findsOneWidget);
      expect(find.text('Từ điển'), findsOneWidget);
      expect(find.text('Ngữ pháp'), findsNothing);
      expect(find.text('Phát âm'), findsNothing);
    });

    testWidgets('tapping an action invokes its callback with the selection',
        (tester) async {
      String? translated;
      String? dictionaryLookup;

      await tester.pumpWidget(
        _host(
          ReadTextActionBar(
            selectedText: 'anatta',
            callbacks: ReadTextActionCallbacks(
              onTranslate: (text) => translated = text,
              onDictionary: (text) => dictionaryLookup = text,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dịch'));
      await tester.tap(find.text('Từ điển'));

      expect(translated, 'anatta');
      expect(dictionaryLookup, 'anatta');
    });
  });

  group('Rule #5 (AGENTS.md) — chrome dịch tại nơi hiển thị', () {
    testWidgets(
        'ReadTextActionBar dịch nhãn Tool đã có trong catalog khi locale=en',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadTextActionBar(
            selectedText: 'sati',
            callbacks: ReadTextActionCallbacks(
              onTranslate: (_) {},
              onGrammar: (_) {},
              onPronounce: (_) {},
              onDictionary: (_) {},
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      // Các nhãn Tool (Dịch/Ngữ pháp/Phát âm/Từ điển) đã có trong
      // AppUITranslations catalog → phải hiện English, không còn tiếng Việt.
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Grammar'), findsOneWidget);
      expect(find.text('Pronunciation'), findsOneWidget);
      expect(find.text('Dictionary'), findsOneWidget);
      expect(find.text('Dịch'), findsNothing);
      expect(find.text('Ngữ pháp'), findsNothing);
      expect(find.text('Phát âm'), findsNothing);
      expect(find.text('Từ điển'), findsNothing);
    });

    testWidgets('ReadSourcePicker vẫn hiển thị đúng ở locale vi (mặc định)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.document,
            onSourceChanged: (_) {},
          ),
        ),
      );

      for (final source in ReadContentSource.values) {
        expect(find.text(source.label), findsOneWidget);
      }
    });
  });

  group('Small-mobile layout safety', () {
    testWidgets('ReadSourcePicker does not overflow on a narrow phone width',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReadSourcePicker(
            selectedSource: ReadContentSource.document,
            onSourceChanged: (_) {},
          ),
          width: 300,
          height: 56,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ReadSourcePicker + ReadTextActionBar stacked do not overflow on a '
        'small phone (320x480)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: _supportedTestLocales,
          localizationsDelegates: _testLocalizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 480)),
            child: Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReadSourcePicker(
                    selectedSource: ReadContentSource.tipitaka,
                    onSourceChanged: (_) {},
                  ),
                  ReadTextActionBar(
                    selectedText: 'A very long selected passage of text '
                        'that could otherwise force a row to overflow '
                        'its bounds on a small screen',
                    callbacks: ReadTextActionCallbacks(
                      onTranslate: (_) {},
                      onGrammar: (_) {},
                      onPronounce: (_) {},
                      onDictionary: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
