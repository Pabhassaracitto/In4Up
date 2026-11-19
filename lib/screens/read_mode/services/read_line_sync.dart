// lib/screens/read_mode/services/read_line_sync.dart
//
// PSRC-233 — tab Đọc «tự động đồng bộ» sai đoạn đang phát.
//
// Audit v1.28.0: bật «Đồng bộ tự động» nhưng vị trí hiển thị KHÔNG nhảy đúng
// đoạn đang đọc. Ba nguyên nhân, cả ba đều nằm ở phép chọn dòng:
//
//  1. `ReadModeController.checkAudioSync` coi `endTime` ĐÃ LƯU là cửa sổ phát
//     của câu: `position >= start && (end == null || position <= end)`. Nhưng
//     `TextProvider._parseLrc` gán `endTime` của dòng i = `startTime` của dòng
//     i+1 ⇒ dòng CUỐI của mỗi mốc có cửa sổ bằng 0 khi LRC song ngữ phát ra
//     2 dòng cùng mốc (`[00:12.00]Hello` + `[00:12.00]Xin chào`):
//       • dòng đầu: start = 12s, end = 12s ⇒ khớp chỉ đúng 1 khoảnh khắc,
//         trong khi player cập nhật vị trí mỗi 100–250 ms ⇒ gần như KHÔNG
//         BAO GIỜ khớp (câu bị bỏ qua, «nhảy cóc»);
//       • dòng thứ hai: start = 12s, end = 17s ⇒ chiếm trọn khoảng ⇒
//         highlight rơi vào BẢN DỊCH trong khi tai nghe câu nguồn.
//     Cách đúng: cửa sổ của dòng i là [start_i, start_{i+1}) — đúng như định
//     nghĩa LRC/SRT — nên `endTime` đã lưu KHÔNG được dùng để quyết định.
//
//  2. Guard `_isScrolling` (đặt true suốt 400 ms của animation tự cuộn) làm
//     `checkAudioSync` trả -1 ⇒ câu tiếp theo bị bỏ qua, highlight đứng yên.
//     Cuộn và highlight là hai việc khác nhau: highlight KHÔNG được phụ thuộc
//     vào animation cuộn.
//
//  3. Vị trí cuộn được tính bằng `index * 85.0` — hằng số không liên quan gì
//     tới chiều cao THẬT của item (dòng xuống hàng, song ngữ, phiên âm IPA,
//     LRC…). Dòng 40 cao gấp đôi dòng 3 ⇒ càng về sau sai càng nhiều.
//
// File này giữ phần THUẦN DART (chọn dòng theo thời gian) để test được trên
// CI không cần thiết bị; phần cuộn chính xác theo `GlobalKey` nằm trong
// `ReadModeController` (cần widget tree nên chỉ pin source).

/// Dòng đang phát tại [position].
///
/// Luật:
///  * dòng không có mốc thời gian (`start == null`) bị bỏ qua — nó là dòng
///    tiêu đề / chú thích, không thuộc dòng thời gian phát;
///  * cửa sổ của dòng i là `[start_i, start_{i+1})`, KHÔNG dùng `ends` để
///    chặn (xem ghi chú đầu file) — tham số [ends] chỉ dùng cho dòng cuối
///    khi file là SRT và có mốc kết thúc thật;
///  * nhiều dòng cùng một mốc (LRC song ngữ) ⇒ trả dòng ĐẦU TIÊN của nhóm:
///    đó là câu gốc, câu được đọc;
///  * trước mốc đầu tiên ⇒ -1 (chưa tới chỗ nào để highlight);
///  * sau mốc cuối ⇒ vẫn là dòng cuối trong [lastLineHold], quá hạn ⇒ -1 để
///    highlight tắt khi nhạc đã hết.
int lineIndexForPosition({
  required List<Duration?> starts,
  required List<Duration?> ends,
  required Duration position,
  Duration lastLineHold = const Duration(seconds: 5),
}) {
  if (starts.isEmpty) return -1;

  var chosen = -1;
  for (var i = 0; i < starts.length; i++) {
    final start = starts[i];
    if (start == null) continue;
    if (start > position) break; // đã sắp xếp theo thời gian
    chosen = i;
  }
  if (chosen < 0) return -1;

  // Lùi về dòng ĐẦU của nhóm cùng mốc (LRC song ngữ: nguồn rồi bản dịch).
  final startOfChosen = starts[chosen];
  while (chosen > 0 && starts[chosen - 1] == startOfChosen) {
    chosen--;
  }

  // Dòng cuối: tôn trọng `end` nếu có (SRT), nếu không thì giữ thêm
  // `lastLineHold` rồi tắt highlight để không "dính" câu cuối mãi mãi.
  final isLastTimed = !_hasTimedAfter(starts, chosen);
  if (isLastTimed) {
    final declaredEnd = ends.length > chosen ? ends[chosen] : null;
    final holdUntil = declaredEnd != null && declaredEnd > startOfChosen!
        ? declaredEnd
        : startOfChosen! + lastLineHold;
    if (position > holdUntil) return -1;
  }

  return chosen;
}

bool _hasTimedAfter(List<Duration?> starts, int from) {
  for (var i = from + 1; i < starts.length; i++) {
    if (starts[i] != null) return true;
  }
  return false;
}

/// Vị trí cuộn (px) để dòng [index] nằm ở [alignment] chiều cao viewport,
/// khi CHƯA đo được item thật (item ngoài vùng build của ListView).
///
/// Đây chỉ là **ước lượng** để ListView dựng tới đúng chỗ; ngay frame sau
/// `ReadModeController` tinh chỉnh lại bằng `RenderAbstractViewport`.
double estimatedLineOffset({
  required int index,
  required double lineHeight,
  required double viewportHeight,
  required double maxScrollExtent,
  double alignment = 0.28,
}) {
  final raw = index * lineHeight - viewportHeight * alignment;
  return raw.clamp(0.0, maxScrollExtent);
}
