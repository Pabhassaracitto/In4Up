import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/reader/reader_contextual_action_orchestrator.dart';
import 'package:in4up/models/reader_contextual_panel_state.dart';

void main() {
  test('dispatches a capability without owning its presentation', () async {
    I4uReaderSelectionContext? received;
    final orchestrator = I4uReaderContextualActionOrchestrator(
      onDictionary: (context) async => received = context,
    );
    const selection = I4uReaderSelectionContext(
      text: 'tri giác',
      sourceId: 'book-1',
      blockId: 'para-14',
    );

    expect(
      await orchestrator.dispatch(I4uReaderContextAction.dictionary, selection),
      isTrue,
    );
    expect(received?.text, 'tri giác');
    expect(received?.sourceId, 'book-1');
  });

  test('missing capability callback is a safe no-op', () async {
    const orchestrator = I4uReaderContextualActionOrchestrator();
    const selection = I4uReaderSelectionContext(text: 'word', sourceId: 'book');
    expect(
      await orchestrator.dispatch(I4uReaderContextAction.explain, selection),
      isFalse,
    );
  });
}
