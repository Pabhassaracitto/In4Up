// lib/services/lrc_time_parser.dart
//
// YT-LRC-LONG-001 (2026-10-28) — TÁCH phần đọc mốc thời gian LRC thành hàm
// THUẦN để có máy bắt (test) và để mọi nơi đọc LRC dùng CÙNG một luật.
//
// Vì sao phải nới: bản cũ dùng `\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)` — cứng
// đúng 2 chữ số phút. Phụ đề lấy từ YouTube về tab Đọc của video **≥ 60 phút**
// có mốc `[125:03.45]` (phút tuyệt đối) ⇒ regex trượt ⇒ KHÔNG dòng nào được
// nạp ⇒ `loadTextFile` trả `false` ⇒ người dùng thấy "bấm xong không có gì".
//
// Luật hiện tại:
//   * `[mm:ss]`, `[mm:ss.cs]`, `[mm:ss.xxx]`, `[mm:ss,xx]` (SRT-style phẩy)
//   * `[mmm:ss.xx]` — phút > 59 (video dài, LRC do app tự ghi)
//   * `[hh:mm:ss.xx]` — một số bộ xuất karaoke
//   * dấu `.` hoặc `,` trước phần lẻ; phần lẻ 1–3 chữ số
//
// Tách theo NHÁNH ':' thay vì đặt nhiều nhóm regex: với `[125:03.45]` cách
// viết nhóm tham lam sẽ hiểu thành 12 giờ 5 phút (sai 1 giờ).
library;

import 'dart:isolate';

/// Một dòng LRC đã tách: mốc bắt đầu + chữ hiển thị (chưa lọc `<...>`).
class LrcLine {
  const LrcLine({required this.start, required this.text});

  final Duration start;
  final String text;

  @override
  String toString() => 'LrcLine($start, "$text")';
}

final RegExp _stampRe = RegExp(
  r'^\[([0-9]{1,3}(?::[0-9]{1,2}){1,2}(?:[.,][0-9]{1,3})?)\]',
);

/// Bỏ inline word-timestamp kiểu `<00:12.34>` (karaoke) khỏi chữ hiển thị.
final RegExp _inlineWordStampRe = RegExp(r'<\d{2}:\d{2}\.\d{2,3}>');

/// Đọc MỘT dòng LRC. Trả `null` khi dòng không phải dòng có mốc thời gian
/// (vd `[ti:…]`, `[ar:…]`, dòng trống) hoặc không còn chữ sau khi làm sạch.
///
/// Hàm THUẦN: không I/O, không state ⇒ test được ở host VM.
LrcLine? parseLrcLine(String rawLine) {
  final raw = rawLine.trim();
  if (raw.isEmpty) return null;

  final match = _stampRe.firstMatch(raw);
  if (match == null) return null;

  final stamp = match.group(1)!.replaceAll(',', '.');
  final dot = stamp.indexOf('.');
  final clock = dot >= 0 ? stamp.substring(0, dot) : stamp;
  final fraction = dot >= 0 ? stamp.substring(dot + 1) : '';

  final parts = clock.split(':').map((p) => int.tryParse(p) ?? 0).toList();
  if (parts.length < 2) return null;
  // 2 nhánh = mm:ss · 3 nhánh = hh:mm:ss
  final hours = parts.length >= 3 ? parts[0] : 0;
  final minutes = parts.length >= 3 ? parts[1] : parts[0];
  final seconds = parts.length >= 3 ? parts[2] : parts[1];

  var text = raw.substring(match.end).trim();
  text = text.replaceAll(_inlineWordStampRe, '').trim();
  if (text.isEmpty) return null;

  // `cs` (1–2 số) = phần trăm giây; 3 số = mili giây.
  final ms = fraction.length >= 3
      ? int.tryParse(fraction.substring(0, 3)) ?? 0
      : (int.tryParse(fraction) ?? 0) * (fraction.length <= 1 ? 100 : 10);

  return LrcLine(
    start: Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: ms,
    ),
    text: text,
  );
}

/// Đọc cả nội dung LRC → danh sách dòng có mốc thời gian (giữ thứ tự file).
List<LrcLine> parseLrcContent(String content) {
  final out = <LrcLine>[];
  for (final raw in content.split('\n')) {
    final line = parseLrcLine(raw);
    if (line != null) out.add(line);
  }
  return out;
}

// ── PERF-001-D — parse ngoài luồng UI ───────────────────────────────────────
//
// File LRC 2 giờ (~5.000 dòng) hiện được parse NGAY TRONG `TextProvider
// ._parseLrc()` trên isolate UI ⇒ khung hình rơi ("Nó cứ xoay hoài"). Cùng
// thuật toán, chỉ đổi CHỖ chạy: `parseLrcContent()` là hàm THUẦN (không I/O,
// không state) nên gửi nguyên sang isolate được.
//
// ⚠ Không được đưa gì khác vào isolate: `SharedPreferences`, `path_provider`,
// `MethodChannel`, `ChangeNotifier`, `BuildContext` đều không dùng được ở
// isolate mới. `LrcLine` chỉ có `Duration` + `String` ⇒ gửi về an toàn.

/// Dưới ngưỡng này thì parse ĐỒNG BỘ: spawn isolate (~1–3 ms + copy dữ liệu)
/// đắt hơn chính việc parse.
const int lrcIsolateThresholdChars = 64 * 1024;

/// Số lần thực sự đi đường isolate — test pin NGƯỠNG bằng counter này (không
/// đo thời gian nên không flaky).
int lrcOffThreadParseCount = 0;

/// Reset counter (test).
void resetLrcOffThreadParseCount() => lrcOffThreadParseCount = 0;

/// Như [parseLrcContent] nhưng chạy ở isolate riêng khi nội dung lớn.
///
/// Kết quả **giống hệt** đường đồng bộ (golden test
/// `test/perf/parse_isolate_equivalence_test.dart`).
Future<List<LrcLine>> parseLrcContentOffThread(
  String content, {
  int thresholdChars = lrcIsolateThresholdChars,
}) async {
  if (content.length < thresholdChars) return parseLrcContent(content);
  lrcOffThreadParseCount++;
  return Isolate.run(() => parseLrcContent(content));
}
