// lib/screens/read_mode/services/read_auto_scroll_policy.dart
//
// READ-UI-121 — chính sách «Đồng bộ tự động» / tự cuộn theo dòng đang đọc.
//
// Tách riêng thành hàm THUẦN DART để test được trên CI không cần widget tree.
// Màn Đọc chỉ gọi hàm này khi `PlaybackController.activeLineNotifier` đổi;
// chính sách KHÔNG tự ý cuộn khi:
//   * người dùng đã tắt «Đồng bộ tự động» (có thể tắt, lưu `read_auto_sync`);
//   * không có phiên phát cả bài đang chạy;
//   * đang ở chế độ «Một dòng» (không có danh sách để cuộn);
//   * người dùng vừa kéo tay (nhường quyền 5 giây rồi tự động nối lại);
//   * chỉ số dòng ngoài biên (dữ liệu cũ / listener báo -1 lúc dọn phiên).
//
// Xem docs/adr/0024-doc-tab-khoi-phuc-thanh-cong-cu-va-tu-cuon.md.

/// Có nên tự cuộn danh sách tới [lineIndex] ở thời điểm hiện tại không.
bool shouldAutoFollowPlayback({
  required bool autoSyncEnabled,
  required bool isRunning,
  required bool singleLineMode,
  required bool manualScrollActive,
  required int lineIndex,
  required int lineCount,
}) {
  if (!autoSyncEnabled) return false;
  if (!isRunning) return false;
  if (singleLineMode) return false;
  if (manualScrollActive) return false;
  if (lineIndex < 0 || lineCount <= 0) return false;
  return lineIndex < lineCount;
}

/// Khoảng thời gian nhường quyền cuộn cho người dùng sau một cú kéo tay.
/// Đủ ngắn để bài đọc tiếp tục bám dòng, đủ dài để đọc lén vài dòng phía sau.
const Duration readAutoScrollManualPause = Duration(seconds: 5);
