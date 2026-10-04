import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/screens/workspace_screen.dart';

void main() {
  testWidgets('two discourse tabs retain reader state through tabs and split',
      (tester) async {
    const book = TipitakaBook(
      id: 7,
      collectionId: 1,
      code: 'MN01M_MUL',
      namePali: 'Majjhima Nikāya',
      nameEn: 'Middle Length Discourses',
      nameVi: 'Trung Bộ Kinh',
      orderIndex: 0,
    );
    const first = TipitakaWorkspaceTab(
      book: book,
      title: 'Kinh Thứ Nhất',
      initialSegmentId: 11,
    );
    const second = TipitakaWorkspaceTab(
      book: book,
      title: 'Kinh Thứ Hai',
      initialSegmentId: 22,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TipitakaWorkspaceScreen(
          initialTab: first,
          additionalTabs: const [second],
          readerBuilder: (context, tab) => _ReaderProbe(
            key: ValueKey('probe-${tab.id}'),
            id: tab.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstProbe = find.byKey(ValueKey('probe-${first.id}'));
    final firstState = tester.state<_ReaderProbeState>(firstProbe);
    await tester.drag(
      find.byKey(ValueKey('probe-scroll-${first.id}')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    final firstOffset = firstState.offset;
    expect(firstOffset, greaterThan(0));

    await tester.tap(find.byKey(ValueKey('tipitaka-tab-${second.id}')));
    await tester.pumpAndSettle();
    final secondProbe = find.byKey(ValueKey('probe-${second.id}'));
    final secondState = tester.state<_ReaderProbeState>(secondProbe);
    await tester.drag(
      find.byKey(ValueKey('probe-scroll-${second.id}')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    final secondOffset = secondState.offset;
    expect(secondOffset, greaterThan(0));

    await tester.tap(find.byKey(ValueKey('tipitaka-tab-${first.id}')));
    await tester.pumpAndSettle();
    expect(tester.state<_ReaderProbeState>(firstProbe), same(firstState));
    expect(firstState.offset, closeTo(firstOffset, 1));

    await tester.tap(find.byKey(const ValueKey('tipitaka-toggle-split')));
    await tester.pumpAndSettle();
    expect(tester.state<_ReaderProbeState>(firstProbe), same(firstState));
    expect(tester.state<_ReaderProbeState>(secondProbe), same(secondState));
    expect(firstState.offset, closeTo(firstOffset, 1));
    expect(secondState.offset, closeTo(secondOffset, 1));
  });
}

class _ReaderProbe extends StatefulWidget {
  final String id;

  const _ReaderProbe({super.key, required this.id});

  @override
  State<_ReaderProbe> createState() => _ReaderProbeState();
}

class _ReaderProbeState extends State<_ReaderProbe> {
  final ScrollController controller = ScrollController();

  double get offset => controller.hasClients ? controller.offset : 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: ValueKey('probe-scroll-${widget.id}'),
      controller: controller,
      itemExtent: 56,
      itemCount: 100,
      itemBuilder: (context, index) => Text('${widget.id} · $index'),
    );
  }
}
