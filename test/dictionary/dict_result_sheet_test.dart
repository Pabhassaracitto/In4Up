// DICT-001 §8 — Widget test: DictResultSheet (hiển thị kết quả tra từ).

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/widgets/dict_result_sheet.dart';

DictEntry entry({
  required String word,
  String definition = '<b>xin chào</b>',
  String? pos,
}) =>
    DictEntry(
      headword: word,
      definition: definition,
      partOfSpeech: pos,
      dictId: 'test-dict',
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
  testWidgets('hiển thị headword + plain definition + số kết quả',
      (tester) async {
    await pumpSheet(
      tester,
      word: 'hello',
      entries: [
        entry(word: 'hello', definition: '<b>xin chào</b> — lời chào'),
        entry(word: 'hello', definition: 'chào hỏi'),
      ],
    );

    expect(find.text('hello'), findsNWidgets(2)); // 2 entry card cùng headword
    // plainDefinition đã strip HTML.
    expect(find.textContaining('xin chào'), findsOneWidget);
    expect(find.textContaining('chào hỏi'), findsOneWidget);
    // Locale mặc định trong test = en → template dịch 'Từ điển: {value0}'
    // thành 'Dictionary: hello' (rule #5: không fallback tiếng Việt).
    expect(find.text('Dictionary: hello'), findsOneWidget);
    expect(find.text('2 results'), findsOneWidget);
  });

  testWidgets('part of speech hiển thị dạng chip khi có', (tester) async {
    await pumpSheet(
      tester,
      word: 'book',
      entries: [entry(word: 'book', definition: 'quyển sách', pos: 'noun')],
    );
    expect(find.text('noun'), findsOneWidget);
  });

  testWidgets('không có kết quả → empty state với từ đã tra', (tester) async {
    await pumpSheet(tester, word: 'zzzz', entries: const []);
    // Locale en: 'Không tìm thấy "{value0}"' → '"zzzz" not found'.
    expect(find.text('"zzzz" not found'), findsOneWidget);
    expect(find.text('0 results'), findsOneWidget);
  });
}
