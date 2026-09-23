import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/widgets/pdf_reader_viewport_shell.dart';

void main() {
  group('PdfReaderViewportShell', () {
    testWidgets('keeps viewer state alive while side panel opens and closes', (
      tester,
    ) async {
      _RetainedViewerState.initCount = 0;
      _RetainedViewerState.disposeCount = 0;

      await tester.pumpWidget(const MaterialApp(home: _ViewportHost()));
      expect(_RetainedViewerState.initCount, 1);
      expect(_RetainedViewerState.disposeCount, 0);

      await tester.tap(find.byKey(const Key('viewer_inc')));
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('toggle_panel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('side_panel')), findsOneWidget);
      expect(find.text('count:1'), findsOneWidget);
      expect(_RetainedViewerState.initCount, 1);
      expect(_RetainedViewerState.disposeCount, 0);

      await tester.tap(find.byKey(const Key('toggle_panel')));
      await tester.pumpAndSettle();
      expect(find.text('count:1'), findsOneWidget);
      expect(_RetainedViewerState.initCount, 1);
      expect(_RetainedViewerState.disposeCount, 0,
          reason: 'viewer phải còn sống, không remount khi chỉ bật/tắt panel');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(_RetainedViewerState.disposeCount, 1);
    });
  });
}

class _ViewportHost extends StatefulWidget {
  const _ViewportHost();

  @override
  State<_ViewportHost> createState() => _ViewportHostState();
}

class _ViewportHostState extends State<_ViewportHost> {
  bool _showPanel = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('toggle_panel'),
            onPressed: () => setState(() => _showPanel = !_showPanel),
            child: const Text('toggle'),
          ),
          Expanded(
            child: PdfReaderViewportShell(
              showSidePanel: _showPanel,
              viewer: const ColoredBox(
                color: Colors.black,
                child: Center(child: _RetainedViewer()),
              ),
              sidePanel: Container(
                key: const Key('side_panel'),
                color: Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetainedViewer extends StatefulWidget {
  const _RetainedViewer();

  @override
  State<_RetainedViewer> createState() => _RetainedViewerState();
}

class _RetainedViewerState extends State<_RetainedViewer> {
  static int initCount = 0;
  static int disposeCount = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    initCount += 1;
  }

  @override
  void dispose() {
    disposeCount += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('count:$_count'),
        const SizedBox(height: 8),
        ElevatedButton(
          key: const Key('viewer_inc'),
          onPressed: () => setState(() => _count += 1),
          child: const Text('inc'),
        ),
      ],
    );
  }
}
