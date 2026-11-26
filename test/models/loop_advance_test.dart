// test/models/loop_advance_test.dart
// PSRC-275 — nút "Lặp câu tiếp" / "Lặp đoạn tiếp" trong popup A–B (tab Nghe).
//
// Hợp đồng owner chốt (2026-11-23, làm rõ lần 2):
//
//   Vế 1 — CHƯA có lời: dịch thuần theo KHOẢNG THỜI GIAN, giữ NGUYÊN độ dài
//   B − A. Mỗi lần bấm trượt đúng một độ dài:
//       5–8   ⇒ 8–11  ⇒ 11–14
//       15–40 ⇒ 40–65 (1:05)
//
//   Vế 2 — CÓ lời VÀ mốc thời gian mỗi dòng khớp với vùng A–B: nhảy xuống
//   ĐÚNG dòng câu kế tiếp (theo mốc của dòng, không theo độ dài A–B).
//
// Trước bản sửa này code cũ hard-code 10 giây cho vế 1, nên 5–8 thành 8–18.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/loop_advance.dart';

Duration _s(num seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // Vế 1 — chưa có lời: giữ nguyên độ dài, trượt từng bước đúng B − A
  // ───────────────────────────────────────────────────────────────────────
  group('Vế 1 — chưa có lời: trượt đúng độ dài B − A', () {
    test('5–8 ⇒ 8–11 (đúng ví dụ owner)', () {
      final r = computeNextLoopRegion(
        a: _s(5),
        b: _s(8),
        lineStarts: const [],
      );
      expect(r.start, _s(8));
      expect(r.end, _s(11));
      expect(r.usedLyrics, isFalse);
    });

    test('bấm tiếp lần 2: 11–14 (đúng ví dụ owner)', () {
      // Mô phỏng đúng chuỗi bấm: 5–8 → 8–11 → 11–14.
      var r = computeNextLoopRegion(a: _s(5), b: _s(8), lineStarts: const []);
      expect((r.start, r.end), (_s(8), _s(11)));
      r = computeNextLoopRegion(a: r.start, b: r.end, lineStarts: const []);
      expect((r.start, r.end), (_s(11), _s(14)));
    });

    test('15–40 ⇒ 40–65 = 1:05 (đúng ví dụ owner)', () {
      final r = computeNextLoopRegion(
        a: _s(15),
        b: _s(40),
        lineStarts: const [],
      );
      expect(r.start, _s(40));
      expect(r.end, _s(65));
      // 65 giây = 1 phút 5 giây.
      expect(r.end.inMinutes, 1);
      expect(r.end.inSeconds % 60, 5);
    });

    test('10–20 ⇒ 20–30', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(20),
        lineStarts: const [],
      );
      expect((r.start, r.end), (_s(20), _s(30)));
    });

    test('độ dài lẻ giữ chính xác: 3.5–6 ⇒ 6–8.5', () {
      final r = computeNextLoopRegion(
        a: _s(3.5),
        b: _s(6),
        lineStarts: const [],
      );
      expect((r.start, r.end), (_s(6), _s(8.5)));
    });

    test('kẹp theo độ dài file: 50–58 trong file 60 s ⇒ 58–60', () {
      final r = computeNextLoopRegion(
        a: _s(50),
        b: _s(58),
        lineStarts: const [],
        duration: _s(60),
      );
      expect((r.start, r.end), (_s(58), _s(60)));
    });

    test('đã ở cuối file ⇒ reachedEnd, không tạo vùng vượt quá file', () {
      final r = computeNextLoopRegion(
        a: _s(58),
        b: _s(60),
        lineStarts: const [],
        duration: _s(60),
      );
      expect(r.reachedEnd, isTrue);
      expect(r.end, lessThanOrEqualTo(_s(60)));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Vế 2 — có lời VÀ khớp mốc dòng: nhảy xuống đúng dòng câu kế tiếp
  // ───────────────────────────────────────────────────────────────────────
  group('Vế 2 — có lời + khớp mốc dòng: nhảy xuống dòng câu kế tiếp', () {
    // Lời cách đều 10 giây — đúng kịch bản owner mô tả.
    final lines = [_s(0), _s(10), _s(20), _s(30), _s(40)];

    test('A–B 10–20 ⇒ 20–30', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(20),
        lineStarts: lines,
      );
      expect((r.start, r.end), (_s(20), _s(30)));
      expect(r.usedLyrics, isTrue);
    });

    test('A–B 0–10 ⇒ 10–20', () {
      final r = computeNextLoopRegion(
        a: _s(0),
        b: _s(10),
        lineStarts: lines,
      );
      expect((r.start, r.end), (_s(10), _s(20)));
    });

    test('bấm tiếp lần 2: 20–30 ⇒ 30–40', () {
      var r = computeNextLoopRegion(
          a: _s(10), b: _s(20), lineStarts: lines);
      r = computeNextLoopRegion(a: r.start, b: r.end, lineStarts: lines);
      expect((r.start, r.end), (_s(30), _s(40)));
    });

    test('lời không đều: 12–18 khớp mốc 12 ⇒ dòng kế tiếp theo mốc dòng', () {
      // Dòng: 0, 12, 18, 26 (không đều). A–B = 12–18 khớp 2 mốc dòng.
      final uneven = [_s(0), _s(12), _s(18), _s(26)];
      final r = computeNextLoopRegion(
        a: _s(12),
        b: _s(18),
        lineStarts: uneven,
      );
      expect(r.start, _s(18));
      expect(r.end, _s(26));
      expect(r.usedLyrics, isTrue);
    });

    test('vùng A–B dài hơn 1 câu nhưng khớp mốc ⇒ vẫn theo dòng', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(30),
        lineStarts: lines,
      );
      // Dòng sau A=10 là 20 ⇒ 20–30 (không phải 30–50 theo độ dài).
      expect((r.start, r.end), (_s(20), _s(30)));
    });

    test('sai số vài ms (LRC sinh từ STT) vẫn coi là khớp', () {
      final r = computeNextLoopRegion(
        a: _s(10) + const Duration(milliseconds: 20),
        b: _s(20) + const Duration(milliseconds: 20),
        lineStarts: lines,
      );
      expect(r.usedLyrics, isTrue);
      expect(r.start, _s(20));
    });

    test('câu cuối của bài ⇒ reachedEnd, giữ nguyên vùng cũ', () {
      final r = computeNextLoopRegion(
        a: _s(40),
        b: _s(50),
        lineStarts: lines,
      );
      expect(r.reachedEnd, isTrue);
      expect(r.start, _s(40));
      expect(r.end, _s(50));
    });

    test('câu kế tiếp là câu cuối ⇒ B = nextStart + (B − A)', () {
      final r = computeNextLoopRegion(
        a: _s(20),
        b: _s(30),
        lineStarts: lines,
      );
      expect((r.start, r.end), (_s(30), _s(40)));
      expect(r.reachedEnd, isFalse);
    });

    test('mốc dòng sát nhau (karaoke) không sinh vùng 0 ms', () {
      final r = computeNextLoopRegion(
        a: _s(1),
        b: _s(1.05),
        lineStarts: [_s(1), _s(1.05)],
      );
      expect(r.end, greaterThan(r.start));
      expect(r.end - r.start, greaterThanOrEqualTo(kMinLoopAdvanceSpan));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ranh giới: có lời nhưng A–B KHÔNG khớp mốc dòng ⇒ rơi về vế 1
  // ───────────────────────────────────────────────────────────────────────
  group('Có lời nhưng KHÔNG khớp mốc dòng ⇒ lặp theo khoảng thời gian', () {
    final lines = [_s(0), _s(10), _s(20), _s(30), _s(40)];

    test('A–B 13–18 (lệch hẳn mốc) ⇒ 18–23, không nhảy dòng', () {
      final r = computeNextLoopRegion(
        a: _s(13),
        b: _s(18),
        lineStarts: lines,
      );
      expect(r.usedLyrics, isFalse);
      expect((r.start, r.end), (_s(18), _s(23)));
    });

    test('A–B 3–7 (lệch hẳn mốc) ⇒ 7–11', () {
      final r = computeNextLoopRegion(
        a: _s(3),
        b: _s(7),
        lineStarts: lines,
      );
      expect(r.usedLyrics, isFalse);
      expect((r.start, r.end), (_s(7), _s(11)));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Vùng A–B không hợp lệ ⇒ không đoán
  // ───────────────────────────────────────────────────────────────────────
  group('A–B không hợp lệ ⇒ không đoán', () {
    test('B == A ⇒ reachedEnd', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(10),
        lineStarts: [_s(0), _s(10)],
      );
      expect(r.reachedEnd, isTrue);
    });

    test('B < A ⇒ reachedEnd', () {
      final r = computeNextLoopRegion(
        a: _s(20),
        b: _s(10),
        lineStarts: const [],
      );
      expect(r.reachedEnd, isTrue);
    });
  });
}
