// test/media_tools/lrc_time_shifter_test.dart
//
// AVTOOL-003 (PLAN-046 P2) — máy bắt cho "giữ lời (LRC) khi xuất".
//
// Vì sao đây là phần dễ sai nhất của cả tính năng: nếu mốc lệch, người dùng
// nghe clip karaoke mà chữ chạy sai → tính năng "giữ lời" thành tác hại. Ba
// tình huống thật đã gặp: (a) câu nói đúng mốc cắt bị bỏ mất, (b) hai dòng kéo
// về 0.00 đè nhau, (c) LRC của video > 100 phút bị hiểu sai phút/giờ.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/services/lrc_time_shifter.dart';
import 'package:in4up/services/lrc_time_parser.dart';

List<LrcLine> _lines(Map<String, String> raw) {
  final list = <LrcLine>[];
  raw.forEach((stamp, text) {
    final parsed = parseLrcLine('$stamp$text');
    if (parsed != null) list.add(parsed);
  });
  list.sort((a, b) => a.start.compareTo(b.start));
  return list;
}

void main() {
  group('formatTimestamp', () {
    test('mm:ss.cc, phút không bị chia thành giờ', () {
      expect(
        LrcTimeShifter.formatTimestamp(const Duration(minutes: 1, seconds: 2, milliseconds: 340)),
        '[01:02.34]',
      );
      expect(LrcTimeShifter.formatTimestamp(Duration.zero), '[00:00.00]');
    });

    test('phút > 59 vẫn là phút (video dài)', () {
      expect(
        LrcTimeShifter.formatTimestamp(
          const Duration(hours: 2, minutes: 5, seconds: 3),
        ),
        '[125:03.00]',
      );
    });
  });

  group('shiftForClip', () {
    test('bỏ dòng trước mốc cắt, dịch dòng trong đoạn', () {
      final lines = _lines({
        '[00:00.00]': 'câu 0',
        '[00:10.00]': 'câu 1',
        '[00:20.00]': 'câu 2',
        '[00:40.00]': 'câu 3',
      });
      final shifted = LrcTimeShifter.shiftForClip(
        lines,
        start: const Duration(seconds: 10),
        duration: const Duration(seconds: 20),
      );
      expect(shifted.map((l) => l.text), ['câu 1', 'câu 2']);
      expect(shifted.first.start, Duration.zero);
      expect(shifted.last.start, const Duration(seconds: 10));
    });

    test('dòng nằm sát mốc cắt trong dung sai vẫn được giữ và kéo về 0', () {
      final lines = _lines({
        '[00:09.90]': 'sát mốc',
        '[00:12.00]': 'bên trong',
      });
      final shifted = LrcTimeShifter.shiftForClip(
        lines,
        start: const Duration(seconds: 10),
        duration: const Duration(seconds: 10),
      );
      expect(shifted.map((l) => l.text), ['sát mốc', 'bên trong']);
      expect(shifted.first.start, Duration.zero);
    });

    test('nhiều dòng cùng kéo về 0 không đè nhau (cách nhau 10ms)', () {
      final lines = _lines({
        '[00:09.80]': 'a',
        '[00:09.90]': 'b',
        '[00:10.00]': 'c',
      });
      final shifted = LrcTimeShifter.shiftForClip(
        lines,
        start: const Duration(seconds: 10),
        duration: const Duration(seconds: 5),
      );
      final ms = shifted.map((l) => l.start.inMilliseconds).toList();
      expect(ms, orderedEquals([0, 10, 20]));
    });

    test('duration null ⇒ lấy tới hết file', () {
      final lines = _lines({
        '[00:05.00]': 'a',
        '[10:00.00]': 'b',
      });
      final shifted = LrcTimeShifter.shiftForClip(
        lines,
        start: const Duration(seconds: 5),
      );
      expect(shifted, hasLength(2));
    });

    test('clip không có dòng nào ⇒ danh sách rỗng (không ghi LRC rác)', () {
      final lines = _lines({'[00:00.00]': 'x'});
      final shifted = LrcTimeShifter.shiftForClip(
        lines,
        start: const Duration(minutes: 1),
        duration: const Duration(seconds: 30),
      );
      expect(shifted, isEmpty);
    });
  });

  group('shiftForSlices', () {
    test('mỗi chặng nhận đúng phần lời của mình', () {
      final lines = _lines({
        '[00:00.00]': 'p1',
        '[00:30.00]': 'p2',
        '[01:00.00]': 'p3',
      });
      final groups = LrcTimeShifter.shiftForSlices(
        lines,
        slices: const [
          (start: Duration.zero, duration: Duration(seconds: 30)),
          (start: Duration(seconds: 30), duration: Duration(seconds: 30)),
          (start: Duration(seconds: 60), duration: null),
        ],
      );
      expect(groups, hasLength(3));
      expect(groups[0].map((l) => l.text), ['p1']);
      expect(groups[1].map((l) => l.text), ['p2']);
      expect(groups[2].map((l) => l.text), ['p3']);
    });
  });

  group('buildLrc', () {
    test('có header + length, bỏ dòng rỗng', () {
      final content = LrcTimeShifter.buildLrc(
        [
          ShiftedLrcLine(Duration.zero, 'xin chào'),
          ShiftedLrcLine(const Duration(seconds: 1), '   '),
        ],
        title: 'Bài [hay]',
        totalDuration: const Duration(seconds: 12),
      );
      // `]` trong tiêu đề bị thay bằng khoảng trắng để không phá cú pháp thẻ.
      expect(content, contains('[ti:Bài  hay]'));
      expect(content, contains('[length:00:12.00]'));
      expect(content, contains('[by:In4Up]'));
      expect(content, contains('[00:00.00]xin chào'));
      expect(content.trim().split('\n').where((l) => l.trim().isEmpty), isEmpty);
    });

    test('dựng xong đọc lại bằng parser chung ra đúng mốc (vòng tròn kín)', () {
      final content = LrcTimeShifter.buildLrc([
        ShiftedLrcLine(const Duration(milliseconds: 12500), 'dòng 1'),
      ]);
      final parsed = LrcTimeShifter.parse(content);
      expect(parsed, hasLength(1));
      expect(parsed.first.start, const Duration(milliseconds: 12500));
      expect(parsed.first.text, 'dòng 1');
    });
  });

  group('parse', () {
    test('đọc được mốc phút > 59 và dấu phẩy kiểu SRT', () {
      final lines = LrcTimeShifter.parse(
        '[125:03.45]phút dài\n[00:01,50]dấu phẩy\nkhông phải mốc',
      );
      expect(lines, hasLength(2));
      expect(lines.first.start, const Duration(hours: 2, minutes: 5, seconds: 3, milliseconds: 450));
      expect(lines.last.start, const Duration(milliseconds: 1500));
    });
  });
}
