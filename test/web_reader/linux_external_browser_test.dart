import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/web_core/linux_external_browser_screen.dart';
import 'package:in4up/features/web_reader/web_reader_controller.dart';
import 'package:in4up/features/web_reader/web_reader_screen.dart';

void main() {
  testWidgets('Linux web route avoids an unsupported WebView even in writing mode',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WebReaderScreen(initialUrl: 'https://example.com', writingMode: true),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(LinuxExternalBrowserScreen), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.textContaining('in-app reading and writing tools'), findsOneWidget);
  });

  testWidgets('external browser receives normalized URL and searches', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(MaterialApp(
      home: LinuxExternalBrowserScreen(
        initialInput: 'example.com',
        normalizeInput: WebReaderController.normalizeUrl,
        launch: (uri) async { opened.add(uri); return true; },
      ),
    ));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(opened.single.toString(), 'https://example.com');
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(opened.last.queryParameters['q'], 'hello world');
  });

  testWidgets('failed or invalid launches show a retryable error', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: LinuxExternalBrowserScreen(
        normalizeInput: (input) => input,
        launch: (_) async { attempts++; throw Exception('no browser'); },
      ),
    ));
    await tester.enterText(find.byType(TextField), 'file:///etc/passwd');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(attempts, 0);
    expect(find.textContaining('Could not open the browser'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(attempts, 1);
    expect(find.textContaining('Could not open the browser'), findsOneWidget);
  });
}
