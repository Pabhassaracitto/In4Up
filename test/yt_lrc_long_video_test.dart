// YT-LRC-LONG-001 (2026-10-28) — máy bắt cho lỗi "phụ đề YouTube vào tab Đọc
// rồi không có gì / lệch giờ".
//
// Hai lỗi thật được khoá ở đây:
//  1. `YtCaptionLine.toLrc()` dùng `start.inMinutes.remainder(60)` ⇒ video
//     ≥ 60 phút bị QUAY VÒNG phút (1h05 → "[05:00…]").
//  2. `TextProvider._parseLrc` chỉ nhận đúng 2 chữ số phút (`\d{2}`) ⇒ mọi
//     dòng `[125:03.45]` đều trượt ⇒ 0 dòng ⇒ nạp thất bại trong im lặng.
//
// File này test THUẦN DART (không Hive, không widget) nên chạy được trên CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_video.dart';
import 'package:in4up/services/lrc_time_parser.dart';

void main() {
  group('YtCaptionLine.toLrc — video dài (> 60 phút)', () {
    test('phút KHÔNG bị quay vòng ở 1h05', () {
      const line = YtCaptionLine(
        Duration(hours: 1, minutes: 5, seconds: 3, milliseconds: 450),
        Duration(hours: 1, minutes: 5, seconds: 6),
        'Xin chào',
      );
      // Trước đây ra '[05:03.45]…' (lệch đúng 1 giờ).
      expect(line.toLrc(), '[65:03.45]Xin chào');
    });

    test('phút vượt 99 vẫn đọc lại được (2h05 → 125 phút)', () {
      const line = YtCaptionLine(
        Duration(hours: 2, minutes: 5, seconds: 3, milliseconds: 450),
        Duration(hours: 2, minutes: 5, seconds: 6),
        'Hello',
      );
      final lrc = line.toLrc();
      expect(lrc, '[125:03.45]Hello');
      final parsed = parseLrcLine(lrc)!;
      expect(parsed.start, const Duration(hours: 2, minutes: 5, seconds: 3, milliseconds: 450));
      expect(parsed.text, 'Hello');
    });

    test('video ngắn giữ nguyên định dạng cũ (không hồi quy)', () {
      const line = YtCaptionLine(
        Duration(minutes: 1, seconds: 2, milliseconds: 300),
        Duration(minutes: 1, seconds: 4),
        'Hello world',
        translation: 'Xin chào',
      );
      expect(line.toLrc(), '[01:02.30]Hello world | Xin chào');
    });
  });

  group('parseLrcLine — nới định dạng mốc thời gian', () {
    test('mm:ss.xx chuẩn', () {
      final l = parseLrcLine('[01:02.30]Hello')!;
      expect(l.start, const Duration(minutes: 1, seconds: 2, milliseconds: 300));
      expect(l.text, 'Hello');
    });

    test('phút 3 chữ số KHÔNG bị hiểu thành giờ', () {
      // Cách viết regex nhiều nhóm tham lam sẽ ra 12h05 → đây là bẫy.
      final l = parseLrcLine('[125:03.45]Dòng dài')!;
      expect(l.start, const Duration(minutes: 125, seconds: 3, milliseconds: 450));
      expect(l.start.inHours, 2);
    });

    test('hh:mm:ss.xx', () {
      final l = parseLrcLine('[01:02:03.45]Karaoke')!;
      expect(l.start,
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 450));
    });

    test('không có phần lẻ + dấu phẩy SRT-style', () {
      expect(parseLrcLine('[00:07]Bảy giây')!.start, const Duration(seconds: 7));
      expect(
        parseLrcLine('[00:07,50]Bảy rưỡi')!.start,
        const Duration(seconds: 7, milliseconds: 500),
      );
    });

    test('phần lẻ 1 / 2 / 3 chữ số', () {
      // Dùng giây 0 để chỉ đo PHẦN LẺ (nếu dùng [00:01.x] thì tổng là 1000+x).
      expect(parseLrcLine('[00:00.5]x')!.start.inMilliseconds, 500);
      expect(parseLrcLine('[00:00.05]x')!.start.inMilliseconds, 50);
      expect(parseLrcLine('[00:00.005]x')!.start.inMilliseconds, 5);
      // Và kiểm cả tổng khi đã có giây (bắt lỗi cộng dồn sai).
      expect(parseLrcLine('[00:01.5]x')!.start.inMilliseconds, 1500);
    });

    test('bỏ inline word timestamp karaoke', () {
      final l = parseLrcLine('[00:12.34]<00:12.34>Hello <00:13.00>world')!;
      expect(l.text, 'Hello  world'.replaceAll('  ', ' '));
    });

    test('bỏ header [ti:]/[ar:]/dòng trống/dòng không có chữ', () {
      expect(parseLrcLine('[ti:Bài hát]'), isNull);
      expect(parseLrcLine('[ar:Kênh]'), isNull);
      expect(parseLrcLine(''), isNull);
      expect(parseLrcLine('   '), isNull);
      expect(parseLrcLine('[00:01.00]   '), isNull);
    });
  });

  group('parseLrcContent — cả file', () {
    test('file thật do app ghi cho video 1h05 nạp được ĐỦ dòng', () {
      const lrc = '''
[ti:Bài giảng dài]
[ar:Kênh]
[by:in4up]

[00:00.00]Mở đầu
[01:02.30]Đoạn một
[65:03.45]Sau một giờ
[65:09.10]Tiếp
''';
      final lines = parseLrcContent(lrc);
      expect(lines.length, 4, reason: 'phải đọc đủ 4 dòng có mốc thời gian');
      expect(lines.last.start,
          const Duration(hours: 1, minutes: 5, seconds: 9, milliseconds: 100));
      // Thứ tự tăng dần theo thời gian (không bị đảo do quay vòng phút).
      for (var i = 1; i < lines.length; i++) {
        expect(
          lines[i].start >= lines[i - 1].start,
          isTrue,
          reason: 'dòng $i phải muộn hơn dòng ${i - 1}',
        );
      }
    });

    test('LRC rỗng/hỏng → danh sách rỗng (để nơi gọi báo lỗi rõ)', () {
      expect(parseLrcContent(''), isEmpty);
      expect(parseLrcContent('không có mốc thời gian nào'), isEmpty);
    });
  });
}
