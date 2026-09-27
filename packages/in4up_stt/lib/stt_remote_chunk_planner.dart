// packages/in4up_stt/lib/stt_remote_chunk_planner.dart
//
// Chia thời lượng file dài thành các cửa sổ (chunk) ~10-15 phút để gửi
// từng phần lên API STT (giới hạn upload ~25MB của OpenAI-compatible) —
// WP2 (API-003) mục 3.
//
// Bất biến quan trọng (cùng kỷ luật `hymt_chunking`): danh sách window trả
// về là một **phân hoạch chính xác** của [0, totalMs) — window liên tiếp
// nối khít nhau (`windows[i].endMs == windows[i+1].startMs`), window đầu
// bắt đầu ở 0, window cuối kết thúc đúng ở totalMs. Không lặp, không mất
// đoạn thời gian.
//
// Chiến lược: ưu tiên cắt tại khoảng lặng (giữa 2 đoạn speech VAD) gần mốc
// mục tiêu nhất; không có khoảng lặng phù hợp trong tầm thì cắt cứng ở
// mốc mục tiêu (KHÔNG vượt quá [maxChunkMs] — an toàn payload).
//
// Pure (không Flutter/IO) — test bằng `flutter test` không cần thiết bị,
// không cần model VAD/ffmpeg thật.
library;

import 'dart:math' as math;

/// Một khoảng speech do VAD phát hiện (mili-giây, trong toạ độ file gốc).
class SttSpeechSpan {
  final int startMs;
  final int endMs;

  const SttSpeechSpan(this.startMs, this.endMs);

  @override
  String toString() => 'SttSpeechSpan($startMs-$endMs)';
}

/// Một cửa sổ (chunk) sẽ được cắt ra và gửi API riêng.
class SttChunkWindow {
  final int startMs;
  final int endMs;

  const SttChunkWindow(this.startMs, this.endMs);

  int get durationMs => endMs - startMs;

  @override
  bool operator ==(Object other) =>
      other is SttChunkWindow &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);

  @override
  String toString() => 'SttChunkWindow($startMs-$endMs, ${durationMs}ms)';
}

class SttRemoteChunkPlanner {
  SttRemoteChunkPlanner._();

  /// Mục tiêu ~12 phút/chunk — dưới giới hạn upload an toàn.
  static const int targetChunkMs = 12 * 60 * 1000;

  /// Trần cứng — KHÔNG chunk nào vượt quá (an toàn payload ~25MB @16k mono).
  static const int maxChunkMs = 15 * 60 * 1000;

  /// Chunk đuôi quá ngắn (do rơi đúng vào 1 khoảng lặng gần cuối file) thì
  /// gộp vào chunk liền trước thay vì gửi 1 request cho vài giây.
  static const int minTailChunkMs = 5 * 1000;

  /// Chia [totalMs] thành các [SttChunkWindow] liên tiếp.
  ///
  /// [speechSegments] rỗng (không có VAD hoặc VAD lỗi) → cắt theo lưới cố
  /// định ở mốc [targetChunkMs] (vẫn đúng — chỉ là không né được ranh giới
  /// câu).
  static List<SttChunkWindow> plan({
    required int totalMs,
    List<SttSpeechSpan> speechSegments = const <SttSpeechSpan>[],
  }) {
    if (totalMs <= 0) return const <SttChunkWindow>[];
    if (totalMs <= maxChunkMs) {
      return <SttChunkWindow>[SttChunkWindow(0, totalMs)];
    }

    final cutCandidates = _silenceMidpoints(totalMs, speechSegments);

    final windows = <SttChunkWindow>[];
    var cursor = 0;
    while (cursor < totalMs) {
      final searchLimit = math.min(cursor + maxChunkMs, totalMs);
      if (searchLimit >= totalMs) {
        windows.add(SttChunkWindow(cursor, totalMs));
        break;
      }

      final target = cursor + targetChunkMs;
      int? chosen;
      var bestDist = 1 << 62;
      for (final c in cutCandidates) {
        if (c <= cursor || c > searchLimit) continue;
        final dist = (c - target).abs();
        if (dist < bestDist) {
          bestDist = dist;
          chosen = c;
        }
      }

      final end = chosen ?? target;
      windows.add(SttChunkWindow(cursor, end));
      cursor = end;
    }

    // Chunk cuối quá ngắn → gộp vào chunk liền trước (vẫn 1 phân hoạch
    // đúng, chỉ giảm số window).
    if (windows.length > 1 && windows.last.durationMs < minTailChunkMs) {
      final tail = windows.removeLast();
      final prev = windows.removeLast();
      windows.add(SttChunkWindow(prev.startMs, tail.endMs));
    }

    return windows;
  }

  /// Điểm giữa của mỗi khoảng lặng (khoảng KHÔNG nằm trong bất kỳ
  /// speech span nào) — ứng viên điểm cắt an toàn (không cắt giữa câu).
  static List<int> _silenceMidpoints(int totalMs, List<SttSpeechSpan> spans) {
    // Không có dữ liệu VAD (chưa có model / VAD lỗi) → không có ứng viên
    // nào — planner dùng lưới cố định. Phân biệt với "VAD chạy và không
    // thấy speech nào" là không cần thiết ở đây: cả 2 trường hợp đều
    // không có ranh giới câu đáng tin để né, lưới cố định là lựa chọn an
    // toàn nhất.
    if (spans.isEmpty) return const <int>[];

    final sorted = List<SttSpeechSpan>.from(spans)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    final candidates = <int>[];
    var prevEnd = 0;
    for (final span in sorted) {
      final start = span.startMs < 0 ? 0 : span.startMs;
      final end = span.endMs < start ? start : span.endMs;
      if (start > prevEnd) {
        candidates.add(((prevEnd + start) / 2).round());
      }
      if (end > prevEnd) prevEnd = end;
    }
    if (prevEnd < totalMs) {
      candidates.add(((prevEnd + totalMs) / 2).round());
    }
    candidates.sort();
    return candidates;
  }
}
