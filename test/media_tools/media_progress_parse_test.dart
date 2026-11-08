// test/media_tools/media_progress_parse_test.dart
//
// AVTOOL-001 (PLAN-047 P0) — máy bắt cho việc đọc tiến trình desktop.
//
// FFmpeg ghi tiến trình theo 2 kiểu tuỳ phiên bản/tham số:
//   out_time_us=1234567   (mới, micro-giây)
//   out_time_ms=1234567   (tên gây nhầm: giá trị vẫn là micro-giây)
//   out_time=00:00:12.34  (dạng đồng hồ)
//   và log thường: time=00:00:12.34
// Đọc sai một kiểu ⇒ thanh tiến trình đứng im hoặc nhảy loạn ⇒ người dùng
// tưởng app treo và bấm Huỷ giữa đường.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/ffmpeg_process_impl.dart';

void main() {
  group('parseProgressElapsedMs', () {
    test('out_time_us là micro-giây', () {
      expect(parseProgressElapsedMs('out_time_us=1234567'), 1234567 ~/ 1000);
    });

    test('out_time_ms (tên cũ) cũng là micro-giây', () {
      expect(parseProgressElapsedMs('out_time_ms=2000000'), 2000);
    });

    test('out_time dạng đồng hồ', () {
      expect(parseProgressElapsedMs('out_time=00:00:12.34'), 12340);
      expect(parseProgressElapsedMs('out_time=01:02:03.5'), 3723500);
    });

    test('dòng log thường có time=', () {
      expect(
        parseProgressElapsedMs(
          'frame=  120 fps= 30 q=28.0 size=     256kB time=00:00:04.00 bitrate= 524.3kbits/s',
        ),
        4000,
      );
    });

    test('sentinel âm của FFmpeg bị BỎ QUA (không kéo thanh tiến trình về 0)', () {
      // FFmpeg dùng -9223372036854775808 khi chưa biết mốc ⇒ trả null để UI
      // giữ nguyên giá trị trước đó thay vì nhảy về 0.
      expect(parseProgressElapsedMs('out_time_us=-9223372036854775808'), isNull);
      expect(parseProgressElapsedMs('out_time=00:00:04.00'), 4000);
    });

    test('không phải dòng tiến trình ⇒ null', () {
      expect(parseProgressElapsedMs(''), isNull);
      expect(parseProgressElapsedMs('Press [q] to stop'), isNull);
      expect(parseProgressElapsedMs('progress=continue'), isNull);
    });
  });
}
