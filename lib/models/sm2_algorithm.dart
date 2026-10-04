/// ═══════════════════════════════════════════════════════════════
/// SM-2 ALGORITHM — HÀM TÍNH SM-2 DUY NHẤT CỦA TOÀN BỘ CODEBASE
///
/// Handoff MVA v2.0 — Task 2 + ADR-0001 (duyệt 2026-08-19):
///  * Ngữ nghĩa chuẩn = bản "SkillReviewData" cũ (trước đây inline trong
///    lib/models/word_entry.dart) — vì đó là đường GHI dữ liệu review thật
///    của người dùng. Chuẩn hóa về nó để "due date không đổi bất ngờ"
///    (DoD Task 3, AT mục 9).
///  * Bỏ thưởng/phạt interval của bản cũ (×1.3 cho Easy, ×0.8 cho Hard):
///    nó chưa bao giờ được ghi vào dữ liệu — chỉ làm preview trên UI
///    nói sai so với thực tế.
///  * EF cập nhật theo công thức chuẩn cho MỌI quality (kể cả khi fail) —
///    không phải trừ phẳng −0.2 như bản cũ.
///  * Memory Mode (memory_item.dart) dùng engine stage/giờ riêng —
///    ngoài phạm vi hàm này theo ADR-0001 mục 3.
///
/// BẤT KỂ ai cần tính SM-2 (UI preview, review flow 3 skill, compaction
/// Task 5, migration Task 3) ĐỀU phải gọi hàm này — không tự viết lại
/// công thức ở nơi khác.
/// ═══════════════════════════════════════════════════════════════
library;

/// Version công thức SM-2 mà hàm này phát hành (schema mục 2.3 — bắt buộc
/// ghi trong SM2Snapshot.algorithmVersion).
/// 'srd' = SkillReviewData — đường 3-skill đã chạy thật trước chuẩn hóa.
const String kSm2AlgorithmVersion = 'sm2-srd-v1';

class SM2Result {
  final double easeFactor;
  final int interval;

  /// Số ngày đến lần review tiếp.
  final int repetitions;
  final DateTime nextReview;

  const SM2Result({
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
  });
}

class SM2Algorithm {
  /// Quality (q): 0–5 — 0–2 fail, 3 hard, 4 good, 5 easy.
  ///
  /// [now] cho phép tiêm thời gian (compaction Task 5, test) — mặc định
  /// thời điểm hiện tại.
  static SM2Result calculate({
    required int quality,
    double currentEF = 2.5,
    int currentInterval = 0,
    int currentReps = 0,
    DateTime? now,
  }) {
    assert(quality >= 0 && quality <= 5, 'quality phải nằm trong 0..5');

    final double newEF;
    final int newInterval;
    final int newReps;

    if (quality >= 3) {
      // ══ PASS: nhịp chuẩn 1 → 6 → interval × EF ══
      newReps = currentReps + 1;
      if (currentReps == 0) {
        newInterval = 1;
      } else if (currentReps == 1) {
        newInterval = 6;
      } else {
        newInterval = (currentInterval * currentEF).round();
      }
    } else {
      // ══ FAIL: reset về đầu ══
      newReps = 0;
      newInterval = 1;
    }

    // EF chuẩn SuperMemo — áp cho MỌI quality, kể cả fail (ngữ nghĩa Bản 2).
    newEF = (currentEF + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
        .clamp(1.3, 2.5)
        .toDouble();

    final nextReview =
        (now ?? DateTime.now()).add(Duration(days: newInterval));

    return SM2Result(
      easeFactor: newEF,
      interval: newInterval,
      repetitions: newReps,
      nextReview: nextReview,
    );
  }
}
