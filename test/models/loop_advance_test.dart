// test/models/loop_advance_test.dart
// PSRC-275 — nút "Lặp câu tiếp" / "Lặp đoạn tiếp" trong popup A–B.
//
// Lỗi owner báo: "khi chọn lặp AB thì nhấn lặp câu tiếp theo thì nó đã không
// canh đúng khoảng thời gian đúng... Ví dụ AB ở giây 10 - 20 thì khi nhấn lặp
// câu tiếp theo thì phải chuyển tới đoạn 20 - 30."
//
// Hai hợp đồng được pin ở đây:
//   1. ĐÃ tạo lời ⇒ lặp ĐÚNG câu đã tạo kế tiếp theo mốc thời gian của câu.
//   2. CHƯA tạo lời ⇒ giữ đúng độ dài B − A, bắt đầu tại B (AB 10–20 ⇒ 20–30).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/loop_advance.dart';

Duration _s(num seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

void main() {
  group('chưa có lời ⇒ giữ đúng độ dài A–B, bắt đầu tại B', () {
    test('AB 10–20 ⇒ 20–30 (đúng ví dụ owner nêu)', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(20),
        lineStarts: const [],
      );
      expect(r.start, _s(20));
      expect(r.end, _s(30));
      expect(r.usedLyrics, isFalse);
      expect(r.reachedEnd, isFalse);
    });

    test('AB 5–10 ⇒ 10–15 (ví dụ trong PSRC-178)', () {
      final r = computeNextLoopRegion(
        a: _s(5),
        b: _s(10),
        lineStarts: const [],
      );
      expect(r.start, _s(10));
      expect(r.end, _s(15));
    });

    test('độ dài lẻ vẫn giữ chính xác (2.5 s ⇒ 2.5 s)', () {
      final r = computeNextLoopRegion(
        a: _s(3.5),
        b: _s(6),
        lineStarts: const [],
      );
      expect(r.start, _s(6));
      expect(r.end, _s(8.5));
    });

    test('không vượt quá độ dài file', () {
      final r = computeNextLoopRegion(
        a: _s(50),
        b: _s(58),
        lineStarts: const [],
        duration: _s(60),
      );
      expect(r.start, _s(58));
      expect(r.end, _s(60));
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

  group('đã có lời ⇒ lặp đúng từng câu đã tạo', () {
    // Lời cách đều 10 giây — đúng kịch bản owner mô tả.
    final lines = [_s(0), _s(10), _s(20), _s(30), _s(40)];

    test('AB 10–20 ⇒ câu kế tiếp 20–30 (KHÔNG nhảy 30–40)', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(20),
        lineStarts: lines,
      );
      expect(r.start, _s(20));
      expect(r.end, _s(30));
      expect(r.usedLyrics, isTrue);
    });

    test('AB 0–10 ⇒ 10–20', () {
      final r = computeNextLoopRegion(
        a: _s(0),
        b: _s(10),
        lineStarts: lines,
      );
      expect(r.start, _s(10));
      expect(r.end, _s(20));
    });

    test('AB nằm GIỮA một câu vẫn tiến đúng 1 câu', () {
      // A = 12 s, B = 18 s (cả hai trong câu 10–20) ⇒ câu kế tiếp 20–30.
      final r = computeNextLoopRegion(
        a: _s(12),
        b: _s(18),
        lineStarts: lines,
      );
      expect(r.start, _s(20));
      expect(r.end, _s(30));
    });

    test('câu cuối cùng ⇒ reachedEnd, giữ nguyên vùng cũ', () {
      // `lines` có 5 câu (0/10/20/30/40) nên câu CUỐI là 40 → 50.
      final r = computeNextLoopRegion(
        a: _s(40),
        b: _s(50),
        lineStarts: lines,
      );
      expect(r.reachedEnd, isTrue);
      expect(r.start, _s(40));
      expect(r.end, _s(50));
    });

    test('câu cuối của file 30–40 ⇒ reachedEnd', () {
      // File chỉ có 4 câu ⇒ 30–40 là câu cuối.
      final r = computeNextLoopRegion(
        a: _s(30),
        b: _s(40),
        lineStarts: [_s(0), _s(10), _s(20), _s(30)],
      );
      expect(r.reachedEnd, isTrue);
    });

    test('câu kế tiếp là câu cuối ⇒ B = nextStart + (B − A)', () {
      final r = computeNextLoopRegion(
        a: _s(20),
        b: _s(30),
        lineStarts: lines,
      );
      expect(r.start, _s(30));
      expect(r.end, _s(40));
      expect(r.reachedEnd, isFalse);
    });

    test('B trước câu đầu tiên ⇒ về câu đầu', () {
      final r = computeNextLoopRegion(
        a: _s(0),
        b: _s(2),
        lineStarts: [_s(5), _s(15)],
      );
      expect(r.start, _s(5));
      expect(r.end, _s(15));
    });

    test('mốc câu sát nhau (karaoke) không sinh vùng 0 ms', () {
      final r = computeNextLoopRegion(
        a: _s(1),
        b: _s(1.05),
        lineStarts: [_s(1), _s(1.05)],
      );
      expect(r.end, greaterThan(r.start));
      expect(r.end - r.start, greaterThanOrEqualTo(kMinLoopAdvanceSpan));
    });

    test('câu kế tiếp là câu cuối + không biết duration ⇒ +span', () {
      // Lời 0/10/20, AB 10–20 ⇒ câu kế tiếp là 20 tới hết bài (chưa biết
      // duration) nên B = 20 + (20 − 10) = 30.
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(20),
        lineStarts: [_s(0), _s(10), _s(20)],
      );
      expect(r.start, _s(20));
      expect(r.end, _s(30));
      expect(r.reachedEnd, isFalse);
    });
  });

  group('vùng A–B không hợp lệ ⇒ không đoán', () {
    test('B == A ⇒ reachedEnd, không seek loạn', () {
      final r = computeNextLoopRegion(
        a: _s(10),
        b: _s(10),
        lineStarts: [_s(0), _s(10)],
      );
      expect(r.reachedEnd, isTrue);
      expect(r.start, _s(10));
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
