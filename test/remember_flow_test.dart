import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/remember/remember_flow.dart';
import 'package:in4up/models/remember_workspace_state.dart';

void main() {
  test('review flow reveals, rates and completes cards', () {
    final flow = I4uRememberFlowController();
    flow.load(totalCount: 1);
    flow.startReview('card-1');
    flow.reveal();
    flow.rate(I4uReviewRating.remembered);
    flow.nextCard('unused');
    expect(flow.value.sessionState, I4uReviewSessionState.completed);
    expect(flow.value.completedCount, 1);
  });

  test('rating before reveal is ignored', () {
    final flow = I4uRememberFlowController();
    flow.load(totalCount: 1);
    flow.startReview('card-1');
    flow.rate(I4uReviewRating.difficult);
    expect(flow.value.sessionState, I4uReviewSessionState.active);
  });
}
