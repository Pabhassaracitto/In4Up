// packages/in4up_stt/test/stt_remote_chunk_planner_test.dart
//
// WP2 (API-003) mục 3 — Chia file dài thành chunk ~10-15 phút để gửi API.
// Bất biến bắt buộc (cùng kỷ luật hymt_chunking): danh sách window là một
// PHÂN HOẠCH CHÍNH XÁC của [0,totalMs) — không lặp/mất đoạn thời gian.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/stt_remote_chunk_planner.dart';

/// Kiểm tra bất biến phân hoạch: liên tục, không lặp/mất, phủ đúng [0,total).
void _expectExactPartition(List<SttChunkWindow> windows, int totalMs) {
  expect(windows, isNotEmpty);
  expect(windows.first.startMs, 0);
  expect(windows.last.endMs, totalMs);
  for (var i = 0; i < windows.length; i++) {
    expect(windows[i].endMs, greaterThan(windows[i].startMs),
        reason: 'window $i rỗng/ngược: ${windows[i]}');
    if (i > 0) {
      expect(windows[i].startMs, windows[i - 1].endMs,
          reason: 'khoảng hở/chồng lấp giữa window ${i - 1} và $i');
    }
  }
}

void main() {
  group('SttRemoteChunkPlanner.plan', () {
    test('file ngắn hơn maxChunkMs → 1 chunk duy nhất', () {
      final windows = SttRemoteChunkPlanner.plan(totalMs: 5 * 60 * 1000);
      expect(windows, [const SttChunkWindow(0, 5 * 60 * 1000)]);
    });

    test('file dài đúng bằng maxChunkMs → vẫn 1 chunk (không tách thừa)', () {
      final windows = SttRemoteChunkPlanner.plan(
        totalMs: SttRemoteChunkPlanner.maxChunkMs,
      );
      expect(windows, [
        SttChunkWindow(0, SttRemoteChunkPlanner.maxChunkMs),
      ]);
    });

    test('totalMs = 0 hoặc âm → không chunk nào (không bịa dữ liệu)', () {
      expect(SttRemoteChunkPlanner.plan(totalMs: 0), isEmpty);
      expect(SttRemoteChunkPlanner.plan(totalMs: -100), isEmpty);
    });

    test('file dài không có VAD (fallback lưới cố định) — phân hoạch đúng, '
        'mỗi chunk <= maxChunkMs', () {
      const totalMs = 60 * 60 * 1000; // 60 phút
      final windows = SttRemoteChunkPlanner.plan(totalMs: totalMs);
      _expectExactPartition(windows, totalMs);
      for (final w in windows) {
        expect(w.durationMs, lessThanOrEqualTo(SttRemoteChunkPlanner.maxChunkMs));
      }
      // Không có VAD → cắt ở đúng mốc targetChunkMs (trừ chunk cuối).
      for (var i = 0; i < windows.length - 1; i++) {
        expect(windows[i].durationMs, SttRemoteChunkPlanner.targetChunkMs);
      }
    });

    test('có VAD: ưu tiên cắt tại khoảng lặng gần mốc mục tiêu nhất', () {
      const totalMs = 20 * 60 * 1000; // 20 phút — buộc phải chia 2 chunk
      // 1 khoảng lặng ở phút thứ 11 (gần mốc mục tiêu 12 phút hơn là biên).
      final speech = [
        const SttSpeechSpan(0, 11 * 60 * 1000 - 500),
        SttSpeechSpan(11 * 60 * 1000 + 500, totalMs),
      ];
      final windows = SttRemoteChunkPlanner.plan(
        totalMs: totalMs,
        speechSegments: speech,
      );
      _expectExactPartition(windows, totalMs);
      expect(windows.length, 2);
      // Điểm cắt phải nằm đúng giữa khoảng lặng (silence midpoint).
      expect(windows.first.endMs, 11 * 60 * 1000);
    });

    test('không tách khi khoảng lặng nằm ngoài tầm maxChunkMs của chunk đó',
        () {
      const totalMs = 40 * 60 * 1000; // 40 phút
      // Khoảng lặng duy nhất ở phút 39 — quá xa mốc 12p đầu tiên nên chunk
      // đầu vẫn phải cắt cứng ở targetChunkMs, KHÔNG kéo dài đến tận phút 39
      // (sẽ vượt quá maxChunkMs nếu làm vậy).
      final speech = [
        const SttSpeechSpan(0, 39 * 60 * 1000 - 500),
        SttSpeechSpan(39 * 60 * 1000 + 500, totalMs),
      ];
      final windows = SttRemoteChunkPlanner.plan(
        totalMs: totalMs,
        speechSegments: speech,
      );
      _expectExactPartition(windows, totalMs);
      for (final w in windows) {
        expect(w.durationMs, lessThanOrEqualTo(SttRemoteChunkPlanner.maxChunkMs));
      }
    });

    test('chunk cuối quá ngắn được gộp vào chunk liền trước (không gửi API '
        'request cho vài giây lẻ)', () {
      // File dài 902s (> maxChunkMs nên chắc chắn phải chia nhiều chunk).
      // Khoảng lặng duy nhất bắt đầu ở giây 896 và kéo dài đến hết file →
      // ứng viên điểm cắt rơi vào giây 899, chỉ cách cuối file 3 giây. Nếu
      // không gộp, chunk cuối sẽ chỉ dài 3s (< minTailChunkMs).
      const totalMs = 902000;
      final speech = [const SttSpeechSpan(0, 896000)];
      final windows = SttRemoteChunkPlanner.plan(
        totalMs: totalMs,
        speechSegments: speech,
      );
      _expectExactPartition(windows, totalMs);
      expect(windows.length, 1,
          reason: 'chunk đuôi 3s phải được gộp vào chunk trước, không tách '
              'riêng: $windows');
    });

    test('nhiều khoảng lặng rải rác — vẫn là 1 phân hoạch đúng cho file dài',
        () {
      const totalMs = 90 * 60 * 1000; // 90 phút — nhiều chunk
      final speech = <SttSpeechSpan>[];
      var cursor = 0;
      var isSpeech = true;
      // Xen kẽ speech 90s / silence 10s cho hết file — mô phỏng VAD thật.
      while (cursor < totalMs) {
        final len = isSpeech ? 90000 : 10000;
        final end = (cursor + len).clamp(0, totalMs);
        if (isSpeech) speech.add(SttSpeechSpan(cursor, end));
        cursor = end;
        isSpeech = !isSpeech;
      }

      final windows = SttRemoteChunkPlanner.plan(
        totalMs: totalMs,
        speechSegments: speech,
      );
      _expectExactPartition(windows, totalMs);
      for (final w in windows) {
        expect(w.durationMs, lessThanOrEqualTo(SttRemoteChunkPlanner.maxChunkMs));
      }
    });

    test('speechSegments không sắp xếp / chồng lấn nhẹ vẫn xử lý an toàn '
        '(không crash, vẫn phân hoạch đúng)', () {
      const totalMs = 30 * 60 * 1000;
      final speech = [
        const SttSpeechSpan(5 * 60 * 1000, 6 * 60 * 1000),
        const SttSpeechSpan(0, 5 * 60 * 1000 + 1000), // chồng lấn nhẹ
        const SttSpeechSpan(20 * 60 * 1000, 21 * 60 * 1000),
      ];
      final windows = SttRemoteChunkPlanner.plan(
        totalMs: totalMs,
        speechSegments: speech,
      );
      _expectExactPartition(windows, totalMs);
    });
  });
}
