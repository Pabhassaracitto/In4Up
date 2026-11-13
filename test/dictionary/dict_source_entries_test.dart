import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/widgets/dict_source_entries.dart';

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
}
