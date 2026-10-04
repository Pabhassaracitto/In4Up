import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/widgets/pdf_jump_to_page_dialog.dart';

void main() {
  group('showPdfJumpToPageDialog', () {
    testWidgets('returns only after dialog route has fully settled', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: _DialogHost()));

      await tester.tap(find.byKey(const Key('open_jump_dialog')));
      await tester.pumpAndSettle();

      expect(find.byType(PdfJumpToPageDialog), findsOneWidget);
      expect(find.byKey(const Key('dialog_result')), findsOneWidget);
      expect(find.text('opening'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pdf_jump_page_field')), '7');
      await tester.tap(find.byKey(const Key('pdf_jump_go_button')));
      await tester.pump();

      expect(find.text('opening'), findsOneWidget,
          reason: 'caller chỉ nhận kết quả sau khi route.completed xong');

      await tester.pumpAndSettle();
      expect(find.byType(PdfJumpToPageDialog), findsNothing);
      expect(find.text('page:7'), findsOneWidget);
    });

    testWidgets('cancel also resolves after dialog is gone', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _DialogHost()));

      await tester.tap(find.byKey(const Key('open_jump_dialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pdf_jump_cancel_button')));
      await tester.pump();
      expect(find.text('opening'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(PdfJumpToPageDialog), findsNothing);
      expect(find.text('cancelled'), findsOneWidget);
    });
  });
}

class _DialogHost extends StatefulWidget {
  const _DialogHost();

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  String _result = 'idle';

  Future<void> _open() async {
    setState(() => _result = 'opening');
    final page = await showPdfJumpToPageDialog(
      context: context,
      currentPage: 3,
      totalPages: 80,
    );
    if (!mounted) return;
    setState(() => _result = page == null ? 'cancelled' : 'page:$page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_result, key: const Key('dialog_result')),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('open_jump_dialog'),
              onPressed: _open,
              child: const Text('open'),
            ),
          ],
        ),
      ),
    );
  }
}
