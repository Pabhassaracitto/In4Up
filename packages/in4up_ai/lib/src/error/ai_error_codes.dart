// YT-AUDIT-05 (IN4-105) — Mã lỗi MÁY cho `AiAnalysis.errorReason`.
//
// Trước đây `errorReason` chứa câu tiếng Anh thô của engine, ví dụ
// `'No local dict entry and engine not ready'`. Chuỗi đó bị hiện thẳng lên
// màn hình ⇒ người dùng đọc được một câu tiếng Anh vô nghĩa, và không dịch
// được (rule i18n: locale ≠ vi thì chrome không được còn tiếng Việt, nhưng
// chuỗi này lại là tiếng Anh cứng ⇒ sai cả hai chiều).
//
// Quy ước: facade/engine chỉ phát **mã**; lớp UI map mã → chuỗi đã bản địa
// hoá + nút hành động tương ứng.

/// Không có nghĩa từ điển offline VÀ engine chưa sẵn sàng ⇒ không có gì để trả.
const String kAiErrLocalDictMissing = 'local_dict_missing';

/// Engine chưa nạp model (hoặc đang bận) — khác với lỗi, có thể chờ / cài.
const String kAiErrEngineNotReady = 'engine_not_ready';

/// Hết giờ (engine local 30 s / remote 45 s / panel 90 s).
const String kAiErrTimeout = 'timeout';

/// Lỗi mạng khi gọi remote (socket / host lookup / connection).
const String kAiErrNetwork = 'network';

/// Từ rỗng — lỗi lập trình, không phải lỗi người dùng.
const String kAiErrEmptyWord = 'empty_word';

/// Không phân loại được — UI nên hiện nguyên văn làm bằng chứng.
const String kAiErrUnknown = 'unknown';

/// Chuẩn hoá một thông báo lỗi (từ engine, từ `toString()` của exception, hoặc
/// đã là mã) về đúng một mã trong tập trên.
///
/// Nhận CẢ MÃ LẪN CÂU TIẾNG ANH CŨ — để máy đang chạy bản cũ vẫn map được.
/// Không bao giờ trả `null`/rỗng: UI luôn có mã mà hiển thị.
String aiErrorCode(String? rawMessage) {
  final s = (rawMessage ?? '').trim().toLowerCase();
  if (s.isEmpty) return kAiErrUnknown;
  // Đã là mã (từ bản mới).
  if (s == kAiErrLocalDictMissing ||
      s == kAiErrEngineNotReady ||
      s == kAiErrTimeout ||
      s == kAiErrNetwork ||
      s == kAiErrEmptyWord) {
    return s;
  }
  // Timeout: `TimeoutException after 0:00:30.000000: Future not completed`.
  if (s.contains('timeoutexception') ||
      s.contains('timed out') ||
      s.contains('hết giờ')) {
    return kAiErrTimeout;
  }
  if (s.contains('no local dict entry')) return kAiErrLocalDictMissing;
  if (s.contains('engine not ready') || s.contains('chưa sẵn sàng')) {
    return kAiErrEngineNotReady;
  }
  if (s.contains('socketexception') ||
      s.contains('host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection refused') ||
      s.contains('failed host lookup')) {
    return kAiErrNetwork;
  }
  if (s.contains('empty word')) return kAiErrEmptyWord;
  return kAiErrUnknown;
}
