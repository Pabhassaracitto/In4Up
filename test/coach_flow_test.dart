import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/understand/coach_flow.dart';
import 'package:in4up/models/i4u_shell_contracts.dart';
import 'package:in4up/models/understand_workspace_state.dart';

void main() {
  test('coach flow progresses from source to feedback and next step', () {
    final flow = I4uCoachFlowController();
    const source = I4uSourceFingerprint(
      sourceType: I4uSourceType.document,
      sourceId: 'book',
      returnPath: '/read/book',
    );
    flow.loadSource(source);
    flow.start(I4uCoachTask.ask);
    flow.updateDraft('Câu trả lời');
    flow.submit();
    expect(flow.value.sessionState, I4uCoachSessionState.submitting);
    flow.showFeedback();
    flow.nextStep();
    expect(flow.value.step, 1);
    expect(flow.value.sessionState, I4uCoachSessionState.active);
  });

  test('coach cannot start without source', () {
    final flow = I4uCoachFlowController();
    flow.start(I4uCoachTask.explain);
    expect(flow.value.sessionState, I4uCoachSessionState.idle);
  });
}
