import 'package:flutter/foundation.dart';

import '../../models/i4u_shell_contracts.dart';
import '../../models/remember_workspace_state.dart';

/// Luồng Ôn tập / Học thuộc của workspace Nhớ.
///
/// C-31 (state preservation QA) — luật bảo toàn trạng thái áp cho controller
/// này: mỗi bước chuyển CHỈ được đổi trường thuộc về bước đó.
///
/// * `source` (nguồn đang ôn) sống suốt phiên — kể cả khi pause/completed —
///   để còn mở lại đúng vị trí nguồn (rule vàng #3).
/// * `stage` (nhận biết → nhớ lại → tái tạo → đọc thuộc → tích hợp) là lựa
///   chọn của người học cho phiên, không bị xoá khi sang thẻ kế tiếp; muốn
///   đổi tầng thì gọi [startStage].
/// * `rating` thuộc về thẻ ĐANG mở: giữ khi pause (chưa bấm "tiếp"), xoá khi
///   đã sang thẻ mới.
///
/// Ghi chú triển khai: [I4uRememberWorkspaceState] là immutable và không có
/// `copyWith`, nên mỗi hàm dựng state mới bằng cách liệt kê tường minh các
/// trường được giữ — chính sự tường minh đó là thứ test C-31 kiểm.
class I4uRememberFlowController extends ValueNotifier<I4uRememberWorkspaceState> {
  I4uRememberFlowController() : super(const I4uRememberWorkspaceState());

  /// Nạp nguồn đang ôn (Đọc/Nghe/Xem → Nhớ). Giữ nguyên tải/thẻ hiện tại.
  void loadSource(I4uSourceFingerprint source) => value = I4uRememberWorkspaceState(
        loadState: value.loadState,
        sessionState: value.sessionState,
        stage: value.stage,
        source: source,
        currentCardId: value.currentCardId,
        rating: value.rating,
        completedCount: value.completedCount,
        totalCount: value.totalCount,
      );

  /// Nạp hàng đợi mới: phiên mới ⇒ thẻ/điểm/rating cũ được trả về mặc định,
  /// nhưng `source` vẫn giữ nếu host đã gắn nguồn trước đó.
  void load({required int totalCount}) => value = I4uRememberWorkspaceState(
        loadState: totalCount > 0 ? I4uRememberLoadState.ready : I4uRememberLoadState.empty,
        source: value.source,
        totalCount: totalCount,
      );

  void startReview(String cardId) {
    if (!value.canStart) return;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: I4uReviewSessionState.active,
      stage: value.stage,
      source: value.source,
      currentCardId: cardId,
      completedCount: value.completedCount,
      totalCount: value.totalCount,
    );
  }

  void reveal() => value = I4uRememberWorkspaceState(
        loadState: value.loadState,
        sessionState: I4uReviewSessionState.revealed,
        stage: value.stage,
        source: value.source,
        currentCardId: value.currentCardId,
        rating: value.rating,
        completedCount: value.completedCount,
        totalCount: value.totalCount,
      );

  void rate(I4uReviewRating rating) {
    if (value.sessionState != I4uReviewSessionState.revealed) return;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: I4uReviewSessionState.rating,
      stage: value.stage,
      source: value.source,
      currentCardId: value.currentCardId,
      rating: rating,
      completedCount: value.completedCount,
      totalCount: value.totalCount,
    );
  }

  void nextCard(String cardId) {
    final completed = value.completedCount + 1;
    final isComplete = completed >= value.totalCount;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: isComplete
          ? I4uReviewSessionState.completed
          : I4uReviewSessionState.active,
      // Tầng học thuộc là lựa chọn của phiên — không tự rơi về null khi sang
      // thẻ kế tiếp (C-31: mất tầng = UI quên mất người học đang ở đâu).
      stage: value.stage,
      source: value.source,
      currentCardId: isComplete ? null : cardId,
      // rating thuộc thẻ cũ ⇒ về mặc định khi đã sang thẻ mới.
      completedCount: completed,
      totalCount: value.totalCount,
    );
  }

  /// Tạm dừng giữa phiên: KHÔNG mất thẻ đang mở, tầng học thuộc, rating đã
  /// chọn hay nguồn đang ôn — người học quay lại là tiếp đúng chỗ cũ.
  void pause() => value = I4uRememberWorkspaceState(
        loadState: value.loadState,
        sessionState: I4uReviewSessionState.paused,
        stage: value.stage,
        source: value.source,
        currentCardId: value.currentCardId,
        rating: value.rating,
        completedCount: value.completedCount,
        totalCount: value.totalCount,
      );

  void startStage(I4uMemorizationStage stage, String cardId) {
    if (!value.canStart) return;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: I4uReviewSessionState.active,
      stage: stage,
      source: value.source,
      currentCardId: cardId,
      completedCount: value.completedCount,
      totalCount: value.totalCount,
    );
  }
}
