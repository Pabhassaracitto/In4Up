// lib/models/loop_advance.dart
// PSRC-275 — tính vùng lặp KẾ TIẾP khi bấm nút "Lặp câu tiếp" / "Lặp đoạn tiếp".
//
// Trước đây logic này nằm inline trong `_advanceToNextSentence`
// (`lib/widgets/ab_loop_controls.dart`) nên KHÔNG test được ở host VM, và có
// hai lỗi thời gian:
//
//   1. File ĐÃ có lời nhưng vùng A–B nằm gọn trong MỘT câu ⇒ không có "câu
//      kế tiếp" nên rơi về nhánh cắt 10 giây tuỳ tiện, lệch hẳn mốc câu.
//   2. File CHƯA có lời ⇒ độ dài đoạn mới hard-code 10 giây thay vì giữ đúng
//      B − A. Ví dụ A = 10 s, B = 20 s phải ra 20 → 30 s.
//
// Hàm dưới đây THUẦN (không I/O, không state) nên test được.

/// Kết quả tính vùng lặp kế tiếp.
class LoopAdvanceResult {
  const LoopAdvanceResult({
    required this.start,
    required this.end,
    required this.usedLyrics,
    required this.reachedEnd,
  });

  /// Mốc A mới.
  final Duration start;

  /// Mốc B mới.
  final Duration end;

  /// `true` khi vùng mới lấy từ mốc câu lời (LRC), `false` khi suy ra từ độ
  /// dài A–B (chưa có lời).
  final bool usedLyrics;

  /// `true` khi đã ở câu cuối và không thể tiến thêm (caller nên báo người
  /// dùng thay vì lặng lẽ cắt một đoạn bịa).
  final bool reachedEnd;

  @override
  String toString() =>
      'LoopAdvanceResult($start → $end, usedLyrics=$usedLyrics, '
      'reachedEnd=$reachedEnd)';
}

/// Độ dài tối thiểu của một vùng lặp — chặn mốc câu quá sát nhau (karaoke
/// từng từ, hoặc 2 dòng LRC cùng giây) sinh ra vùng 0 ms làm app nhảy liên tục.
const Duration kMinLoopAdvanceSpan = Duration(milliseconds: 400);

/// Trần độ dài khi phải suy ra vùng từ A–B mà A–B quá dài (người dùng kéo
/// nhầm cả bài). Không cắt nhỏ hơn `b - a`, chỉ dùng khi `b - a` vô lý.
const Duration kMaxLoopAdvanceSpan = Duration(minutes: 10);

/// Sai số cho phép khi so vùng A–B với mốc dòng lời. LRC sinh từ STT có thể
/// lệch vài ms so với mốc người dùng bấm, nên so tuyệt đối sẽ trượt.
const Duration kLineMatchTolerance = Duration(milliseconds: 50);

/// PSRC-275 — tính vùng lặp kế tiếp.
///
/// Quy tắc ưu tiên (đúng như PSRC-178 đã chốt, nay làm rõ phần "đã tạo lời"):
///
///   • CÓ lời (`lineStarts` không rỗng): bám **mốc câu**.
///     - Mốc xuất phát = dòng CUỐI bắt đầu **nghiêm ngặt trước B** (`< b`), vì
///       người dùng thường đặt A/B đúng ranh giới câu.
///     - Vùng mới = câu kế tiếp: từ mốc dòng sau tới mốc dòng sau nữa; nếu là
///       câu cuối thì `nextStart + (b − a)`.
///     - Ví dụ lời 10 s / 20 s / 30 s, A = 10 s, B = 20 s ⇒ vùng mới 20 → 30 s
///       (KHÔNG nhảy 30 → 40 như bản dùng `<=`).
///     - Hết câu ⇒ `reachedEnd = true`, giữ nguyên vùng cũ để caller báo người
///       dùng thay vì lặng lẽ cắt một đoạn bịa.
///
///   • KHÔNG có lời: giữ **đúng độ dài** `B - A`, bắt đầu tại B.
///     Ví dụ A = 10 s, B = 20 s ⇒ 20 → 30 s.
///
/// [lineStarts] phải đã sắp xếp tăng dần (UnderstandProvider đã sort).
/// [duration] là tổng độ dài file (nếu biết) để không đặt mốc B vượt quá file.
LoopAdvanceResult computeNextLoopRegion({
  required Duration a,
  required Duration b,
  required List<Duration> lineStarts,
  Duration? duration,
}) {
  // Đã chạm cuối file ⇒ không còn đoạn nào để lặp.
  if (duration != null && b >= duration) {
    return LoopAdvanceResult(
      start: a,
      end: b,
      usedLyrics: lineStarts.isNotEmpty,
      reachedEnd: true,
    );
  }

  // Vùng A–B chưa hợp lệ ⇒ không đoán, trả lại đúng vùng cũ.
  if (b <= a) {
    return LoopAdvanceResult(
      start: a,
      end: b <= a ? a : b,
      usedLyrics: false,
      reachedEnd: true,
    );
  }

  final span = b - a;

  // ── Vế 2: CHỈ dùng mốc dòng khi vùng A–B THẬT SỰ KHỚP mốc thời gian của
  // một dòng lời (owner: "có lời **và mốc thời gian tương ứng** thì dựa vào
  // dòng câu"). Không khớp ⇒ rơi xuống vế 1 (dịch theo khoảng thời gian).
  //
  // "Khớp" = A hoặc B trùng mốc bắt đầu của một dòng (sai số [kLineMatchTolerance]
  // để chịu được làm tròn ms khi LRC được tạo từ STT).
  if (lineStarts.isNotEmpty && loopRegionAlignsWithLines(a, b, lineStarts)) {
    // Dòng kế tiếp = dòng đầu tiên bắt đầu SAU A (nghiêm ngặt, có sai số).
    // Với lời 10/20/30 và A–B 10–20 ⇒ dòng sau A=10 là 20 ⇒ vùng 20–30.
    int nextIdx = -1;
    for (int i = 0; i < lineStarts.length; i++) {
      if (lineStarts[i] > a + kLineMatchTolerance) {
        nextIdx = i;
        break;
      }
    }

    if (nextIdx < 0) {
      // A đã ở dòng cuối của bài — không còn câu nào để nhảy.
      return LoopAdvanceResult(
        start: a,
        end: b,
        usedLyrics: true,
        reachedEnd: true,
      );
    }

    final nextStart = lineStarts[nextIdx];
    final nextEnd = (nextIdx + 1 < lineStarts.length)
        ? lineStarts[nextIdx + 1]
        : nextStart + span;

    return LoopAdvanceResult(
      start: nextStart,
      end: _clampEnd(nextStart, nextEnd, duration),
      usedLyrics: true,
      reachedEnd: false,
    );
  }

  // ── Vế 1: CHƯA có lời (hoặc A–B không khớp mốc dòng nào) ⇒ dịch thuần theo
  // khoảng thời gian: mốc A mới = B, giữ NGUYÊN độ dài B − A.
  //   5–8   ⇒ 8–11   ⇒ 11–14
  //   15–40 ⇒ 40–65  (1:05)
  final advanceSpan = span > kMaxLoopAdvanceSpan ? kMaxLoopAdvanceSpan : span;
  final nextStart = b;
  return LoopAdvanceResult(
    start: nextStart,
    end: _clampEnd(nextStart, nextStart + advanceSpan, duration),
    usedLyrics: false,
    reachedEnd: false,
  );
}

/// A hoặc B có trùng mốc bắt đầu của một dòng lời không (trong sai số
/// [kLineMatchTolerance]). Public để UI chọn nhãn nút cho khớp hành vi.
bool loopRegionAlignsWithLines(Duration a, Duration b, List<Duration> lineStarts) {
  for (final line in lineStarts) {
    if ((line - a).abs() <= kLineMatchTolerance) return true;
    if ((line - b).abs() <= kLineMatchTolerance) return true;
  }
  return false;
}

/// Bảo đảm vùng mới dài tối thiểu [kMinLoopAdvanceSpan] và không vượt quá độ
/// dài file khi đã biết độ dài.
///
/// Thứ tự quan trọng: kẹp theo độ dài file TRƯỚC, rồi mới nới tối thiểu — nếu
/// làm ngược, vùng sát cuối file sẽ bị nới vượt khỏi file (lỗi tìm thấy khi
/// mô phỏng: A=58 s, B=60 s, file 60 s ⇒ B mới = 62 s).
Duration _clampEnd(Duration start, Duration end, Duration? duration) {
  var result = end;
  if (duration != null && duration > start && result > duration) {
    result = duration;
  }
  if (result - start < kMinLoopAdvanceSpan) {
    result = start + kMinLoopAdvanceSpan;
  }
  return result;
}
