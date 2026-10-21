import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/remember/remember_flow.dart';
import 'package:in4up/models/i4u_shell_contracts.dart';
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

  // C-31 — state preservation QA: phiên đang làm dở không được mất chỗ.
  test('pause giữ thẻ, tầng học thuộc, rating và nguồn', () {
    final flow = I4uRememberFlowController();
    flow.loadSource(const I4uSourceFingerprint(
      sourceType: I4uSourceType.document,
      sourceId: 'book-1',
      returnPath: '/read/book-1',
    ));
    flow.load(totalCount: 3);
    flow.startStage(I4uMemorizationStage.recall, 'card-1');
    flow.reveal();
    flow.rate(I4uReviewRating.difficult);
    flow.pause();

    expect(flow.value.sessionState, I4uReviewSessionState.paused);
    expect(flow.value.currentCardId, 'card-1');
    expect(flow.value.stage, I4uMemorizationStage.recall);
    expect(flow.value.rating, I4uReviewRating.difficult);
    expect(flow.value.source?.sourceId, 'book-1');
  });

  test('sang thẻ kế tiếp giữ tầng học thuộc nhưng xoá rating thẻ cũ', () {
    final flow = I4uRememberFlowController();
    flow.load(totalCount: 3);
    flow.startStage(I4uMemorizationStage.recite, 'card-1');
    flow.reveal();
    flow.rate(I4uReviewRating.remembered);
    flow.nextCard('card-2');

    expect(flow.value.currentCardId, 'card-2');
    expect(flow.value.stage, I4uMemorizationStage.recite);
    expect(flow.value.rating, isNull);
  });

  test('nguồn đang ôn sống suốt phiên kể cả khi hoàn thành', () {
    final flow = I4uRememberFlowController();
    flow.loadSource(const I4uSourceFingerprint(
      sourceType: I4uSourceType.audio,
      sourceId: 'audio-1',
      timestampMs: 84000,
      returnPath: '/listen/audio-1',
    ));
    flow.load(totalCount: 1);
    flow.startReview('card-1');
    flow.reveal();
    flow.rate(I4uReviewRating.mastered);
    flow.nextCard('unused');

    expect(flow.value.sessionState, I4uReviewSessionState.completed);
    expect(flow.value.source?.sourceId, 'audio-1');
    expect(flow.value.source?.timestampMs, 84000);
    expect(flow.value.source?.returnPath, '/listen/audio-1');
  });
}
