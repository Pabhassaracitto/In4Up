import 'dart:async';

// DICT-001 §8 — Widget test: DictResultSheet (hiển thị kết quả tra từ).
//
// DICT-CLEAN-001: sheet nay là một "trang từ điển" — nhiều bộ từ điển cho cùng
// một từ được GỘP, nghĩa trùng bị khử, nội dung đã làm sạch HTML.

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/widgets/dictionary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in4up/features/dictionary/services/dictionary_service.dart';
import 'package:in4up/features/dictionary/widgets/dict_result_sheet.dart';

DictEntry entry({
  required String word,
  String definition = '<b>xin chào</b>',
  String? pos,
  String dictId = 'test-dict',
}) =>
    DictEntry(
      headword: word,
      definition: definition,
      partOfSpeech: pos,
      dictId: dictId,
    );

Future<void> pumpSheet(
  WidgetTester tester, {
  required String word,
  required List<DictEntry> entries,
}) async {
  await tester.pumpWidget(
    material.MaterialApp(
      home: material.Scaffold(
        body: material.Column(
          children: [
            material.Expanded(
              child: DictResultSheet(word: word, entries: entries),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiển thị headword + nghĩa đã làm sạch + số kết quả',
      (tester) async {
    await pumpSheet(
      tester,
      word: 'hello',
      entries: [
        entry(word: 'hello', definition: '<b>xin chào</b> — lời chào'),
        entry(word: 'hello', definition: 'chào hỏi'),
      ],
    );

    // Một headword duy nhất (gộp nhiều bộ từ điển), không lặp khối nghĩa.
    expect(find.text('hello'), findsOneWidget);
    // plainDefinition đã strip HTML.
    expect(find.textContaining('xin chào'), findsOneWidget);
    expect(find.textContaining('chào hỏi'), findsOneWidget);
    // Locale mặc định trong test = en → template dịch 'Từ điển: {value0}'
    // thành 'Dictionary: hello' (rule #5: không fallback tiếng Việt).
    expect(find.text('Dictionary: hello'), findsOneWidget);
    expect(find.text('2 results'), findsOneWidget);
  });

  testWidgets('nghĩa trùng giữa nhiều từ điển chỉ hiện một lần',
      (tester) async {
    await pumpSheet(
      tester,
      word: 'book',
      entries: [
        entry(word: 'book', definition: 'quyển sách', dictId: 'a'),
        entry(word: 'book', definition: '<div>quyển sách</div>', dictId: 'b'),
        entry(word: 'book', definition: 'đặt vé', dictId: 'b'),
      ],
    );

    expect(find.text('quyển sách'), findsOneWidget);
    expect(find.text('đặt vé'), findsOneWidget);
  });

  // DICT-VIEW-003: chip hiện TÊN loại từ đã dịch, không in mã `noun`.
  testWidgets('part of speech hiển thị dạng chip khi có', (tester) async {
    await pumpSheet(
      tester,
      word: 'book',
      entries: [entry(word: 'book', definition: 'quyển sách', pos: 'noun')],
    );
    // Locale mặc định trong test = en → 'Danh từ' → 'Noun'.
    expect(find.text('Noun'), findsOneWidget);
    expect(find.text('noun'), findsNothing);
  });

  // DICT-VIEW-003: `partOfSpeech` của nhiều bộ MDX là viết tắt `n.`/`(adj)`.
  testWidgets('part of speech viết tắt cũng ra tên loại từ', (tester) async {
    await pumpSheet(
      tester,
      word: 'quick',
      entries: [entry(word: 'quick', definition: 'nhanh', pos: 'adj.')],
    );
    expect(find.text('Adjective'), findsOneWidget);
    expect(find.text('adj.'), findsNothing);
  });

  testWidgets('không có kết quả → empty state với từ đã tra', (tester) async {
    await pumpSheet(tester, word: 'zzzz', entries: const []);
    // Locale en: 'Không tìm thấy "{value0}"' → '"zzzz" not found'.
    expect(find.text('"zzzz" not found'), findsOneWidget);
    expect(find.text('0 results'), findsOneWidget);
  });
  testWidgets('DB failure is not presented as a missing word', (tester) async {
    await tester.pumpWidget(const material.MaterialApp(home: material.Scaffold(
      body: material.Column(children: [material.Expanded(child: DictResultSheet(
        word: 'hello', entries: [], report: DictLookupReport(entries: [],
          failedSources: ['broken dictionary']))) ]),
    )));
    expect(find.text('broken dictionary'), findsOneWidget);
    expect(find.text('"hello" not found'), findsNothing);
  });

  testWidgets('late lookup cannot overwrite the newer word', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final first = Completer<DictLookupReport>();
    final second = Completer<DictLookupReport>();
    final dict = DictInfo(id: 'd', name: 'test', entryCount: 2, dbPath: '',
      importedAt: DateTime(2026));
    await tester.pumpWidget(material.MaterialApp(home: DictionaryScreen(
      initialQuery: 'first',
      loadDictionariesForTest: () async => [dict],
      lookupForTest: (word, _) => word == 'first' ? first.future : second.future,
    )));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(material.TextField), 'second');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    second.complete(DictLookupReport(entries: [entry(word: 'second', definition: 'new meaning')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('new meaning'), findsOneWidget);
    first.complete(DictLookupReport(entries: [entry(word: 'first', definition: 'old meaning')]));
    await tester.pump();
    expect(find.textContaining('new meaning'), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(find.textContaining('old meaning'), findsNothing);
  });

}
