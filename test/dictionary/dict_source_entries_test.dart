import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/widgets/dict_source_entries.dart';
import 'package:in4up/features/dictionary/widgets/dict_definition_view.dart';

void main() {
  test('safe text view retains long entries, examples and source metadata', () {
    final examples = List.generate(20, (i) => '<li>example $i</li>').join();
    final span = dictionaryTextSpans(
      '<div><b>Head</b><p>etymology: origin</p><ul>$examples</ul></div>',
    );
    final text = span.toPlainText();
    expect(text, contains('etymology: origin'));
    expect(text, contains('example 19'));
    expect(text, contains('• example 0'));
  });

  test('ordered meanings are numbered and nested bullets remain separate', () {
    final text = dictionaryTextSpans(
      '<ol><li>first<ul><li>example</li></ul></li><li>second</li></ol>',
    ).toPlainText();
    expect(text, contains('1. first'));
    expect(text, contains('• example'));
    expect(text, contains('2. second'));
  });

  test('table cells remain separated and active content stays blocked', () {
    final text = dictionaryTextSpans(
      '<table><tr><th>form</th><th>meaning</th></tr>'
      '<tr><td>retains</td><td>keeps<script>bad</script></td></tr></table>',
    ).toPlainText();
    expect(text, contains('form  |  meaning'));
    expect(text, contains('retains  |  keeps'));
    expect(text, isNot(contains('bad')));
  });

  test('only inert inline typography declarations are applied', () {
    final safe = safeDictionaryInlineStyle(
      'font-weight: bold; font-style: italic; text-decoration: underline; '
      'color: red; background: url(https://example.com/x); display:none');
    expect(safe.fontWeight, material.FontWeight.bold);
    expect(safe.fontStyle, material.FontStyle.italic);
    expect(safe.decoration, material.TextDecoration.underline);
    expect(safe.color, isNull);
    final malicious = safeDictionaryInlineStyle('font-weight: url(file:///x); font-style: italic!important');
    expect(malicious.fontWeight, isNull);
    expect(malicious.fontStyle, isNull);
    expect(safeDictionaryInlineStyle('font-weight:bold;${'x' * 1024}').fontWeight, isNull);
    final span = dictionaryTextSpans('<span style="font-weight:bold">styled</span>');
    expect((span.children!.first as material.TextSpan).style!.fontWeight, material.FontWeight.bold);
  });

  test('removes MDX terminator from already imported text', () {
    expect(dictionaryTextSpans('nghĩa gốc\u0000').toPlainText(), 'nghĩa gốc');
    expect(dictionaryTextSpans('<p>definition</p>\u0000').toPlainText(),
        isNot(contains('\u0000')));
  });

  test('does not render active content or fetch anything', () {
    final text = dictionaryTextSpans(
      '<script>bad()</script><style>badcss</style>'
      '<iframe src="https://example.com">bad frame</iframe>'
      '<img src="https://example.com/a.png"><a href="javascript:bad()">word</a>',
    ).toPlainText();
    expect(text, contains('word'));
    expect(text, isNot(contains('bad')));
    expect(text, isNot(contains('example.com')));
  });

  testWidgets('safe internal links call back with the originating dictionary', (tester) async {
    String? selected;
    String? source;
    await tester.pumpWidget(material.MaterialApp(
      home: material.Scaffold(
        body: material.SingleChildScrollView(
          child: DictSourceEntries(
            initiallyExpanded: true,
            entries: const [DictEntry(
              headword: 'a',
              definition: '<a href="entry://look%20up">see also</a>'
                  '<a href="https://example.com">external</a>',
              dictId: 'dict-one',
            )],
            onLookupWord: (word, dictId) { selected = word; source = dictId; },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('look up'));
    expect(selected, 'look up');
    expect(source, 'dict-one');
    expect(find.text('https://example.com'), findsNothing);
  });

  testWidgets('each dictionary retains its own content even when duplicate', (tester) async {
    const entries = <DictEntry>[
      DictEntry(headword: 'a', definition: '<b>same</b> first', dictId: 'one'),
      DictEntry(headword: 'a', definition: '<b>same</b> second', dictId: 'two'),
    ];
    await tester.pumpWidget(const material.MaterialApp(
      home: material.Scaffold(
        body: material.SingleChildScrollView(
          child: DictSourceEntries(entries: entries, initiallyExpanded: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    final texts = tester.widgetList<material.SelectableText>(
      find.byType(material.SelectableText),
    ).map((w) => w.textSpan!.toPlainText()).toList();
    expect(texts, contains('same first'));
    expect(texts, contains('same second'));
  });
  testWidgets('empty cleaned preview still offers full source', (tester) async {
    var opened = false;
    await tester.pumpWidget(material.MaterialApp(home: material.Scaffold(
      body: DictDefinitionView(groups: const [], compact: true,
        onOpenFull: () { opened = true; }),
    )));
    await tester.tap(find.text('Open full dictionary'));
    expect(opened, isTrue);
  });

}
