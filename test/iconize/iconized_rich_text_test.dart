// ICONIZE-001d — widget test tầng render IconizedRichText.
//
// Dùng [iconBuilderOverride] để khỏi decode SVG thật: test kiểm CẤU TRÚC
// (từ nào thành icon, từ nào giữ chữ, semantics đọc đúng từ gốc) chứ
// không kiểm pixel. Nguyên tắc keep-text: builder trả null → giữ chữ.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/iconize/models/iconize_span.dart';
import 'package:in4up/features/iconize/widgets/iconized_rich_text.dart';

IconizeSpan _span(int start, int end, String surface, String lemma) =>
    IconizeSpan(
      start: start,
      end: end,
      surfaceForm: surface,
      lemma: lemma,
      pos: 'NOUN',
      concreteness: 5.0,
      iconAssetRef: 'bundle:fake',
      source: IconizeSource.localTwemoji,
    );

void main() {
  const text = 'The cat drinks milk.';
  // "cat" [4,7) và "milk" [15,19)
  final result = IconizeResult(
    plainText: text,
    spans: [_span(4, 7, 'cat', 'cat'), _span(15, 19, 'milk', 'milk')],
    density: IconizeDensity.medium,
    actualIconPercent: 40,
  );

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  testWidgets('span có icon → WidgetSpan, chữ còn lại giữ nguyên',
      (tester) async {
    await tester.pumpWidget(host(IconizedRichText(
      result: result,
      iconBuilderOverride: (context, span, size) => SizedBox(
        key: ValueKey('icon-${span.lemma}'),
        width: size,
        height: size,
      ),
    )));

    expect(find.byKey(const ValueKey('icon-cat')), findsOneWidget);
    expect(find.byKey(const ValueKey('icon-milk')), findsOneWidget);
    // Văn bản hiển thị không còn "cat"/"milk" dạng chữ, phần còn lại giữ.
    final rich = tester.widget<Text>(find.byType(Text).first);
    final flat = rich.textSpan!.toPlainText(
        includeSemanticsLabels: false, includePlaceholders: false);
    expect(flat.contains('The '), isTrue);
    expect(flat.contains('drinks'), isTrue);
    expect(flat.contains('cat'), isFalse);
    expect(flat.contains('milk'), isFalse);
  });

  testWidgets('semantics đọc ĐÚNG TỪ GỐC (blueprint nguyên tắc #6)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(IconizedRichText(
      result: result,
      iconBuilderOverride: (context, span, size) =>
          SizedBox(width: size, height: size),
    )));
    expect(find.bySemanticsLabel('cat'), findsOneWidget);
    expect(find.bySemanticsLabel('milk'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('builder trả null → keep-text, câu nguyên vẹn', (tester) async {
    await tester.pumpWidget(host(IconizedRichText(
      result: result,
      iconBuilderOverride: (context, span, size) => null,
    )));
    final rich = tester.widget<Text>(find.byType(Text).first);
    expect(rich.textSpan!.toPlainText(), text);
  });

  testWidgets('không có span → Text thường với plainText', (tester) async {
    await tester.pumpWidget(host(IconizedRichText(
      result: IconizeResult.empty(text, IconizeDensity.medium),
    )));
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('span hỏng (ngoài biên) bị bỏ qua an toàn', (tester) async {
    final broken = IconizeResult(
      plainText: 'Hi.',
      spans: [_span(10, 20, 'ghost', 'ghost')],
      density: IconizeDensity.medium,
      actualIconPercent: 0,
    );
    await tester.pumpWidget(host(IconizedRichText(
      result: broken,
      iconBuilderOverride: (context, span, size) =>
          SizedBox(width: size, height: size),
    )));
    final rich = tester.widget<Text>(find.byType(Text).first);
    expect(rich.textSpan!.toPlainText(), 'Hi.');
  });
}
