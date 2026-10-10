import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/reader/reader_contextual_flow.dart';
import 'package:in4up/models/reader_contextual_panel_state.dart';

void main() {
  test('vertical slice preserves selection through capability and return', () {
    final flow = I4uReaderContextualFlowController();
    const selection = I4uReaderSelectionContext(
      text: 'tri giác', sourceId: 'book', blockId: 'para-14', characterOffset: 12,
    );

    flow.select(selection);
    expect(flow.value.step, I4uReaderContextualFlowStep.panel);
    flow.run(I4uReaderContextAction.remember);
    expect(flow.value.step, I4uReaderContextualFlowStep.capability);
    expect(flow.value.selection?.text, 'tri giác');
    flow.returnToReader();
    expect(flow.value.step, I4uReaderContextualFlowStep.returning);
    flow.completeReturn();
    expect(flow.value.step, I4uReaderContextualFlowStep.reader);
    expect(flow.value.selection?.blockId, 'para-14');
  });

  test('cannot run an action without selected text', () {
    final flow = I4uReaderContextualFlowController();
    flow.run(I4uReaderContextAction.dictionary);
    expect(flow.value.step, I4uReaderContextualFlowStep.reader);
  });
}
