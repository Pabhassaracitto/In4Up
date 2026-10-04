// lib/features/shadowing/services/lrc_ab_suggestions.dart
// SHADOW-FILE-001 — Gợi ý đoạn A-B theo câu từ LRC cho shadowing.
//
// Logic THUẦN (pure, không Flutter) để unit test được:
//  - buildSentenceSuggestions: mỗi câu LRC = 1 gợi ý A-B
//    (A = timestamp câu; B = timestamp câu kế − pad; câu cuối = duration).
//  - nudgeLoop: chỉnh tay A/B ±delta có clamp (không vỡ 0..duration,
//    B > A + minLength).
//  - suggestionAtPosition: câu chứa vị trí đang phát (nút "Dùng câu đang phát").

import 'package:in4up_stt/stt_lrc_converter.dart' show LrcLine;

/// Một gợi ý A-B loop tương ứng với 1 câu lyrics.
class AbSuggestion {
  /// Index của câu trong list đã lọc/sort.
  final int index;
  final Duration start;
  final Duration end;
  final String text;

  const AbSuggestion({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });

  Duration get duration => end - start;
}

class LrcAbSuggestions {
  LrcAbSuggestions._();

  /// Đoạn tối thiểu hợp lệ cho shadowing.
  static const Duration minSegmentLength = Duration(milliseconds: 800);

  /// Khoảng đệm cuối câu (để không cắt mất đuôi âm cuối câu).
  static const Duration trailingPad = Duration(milliseconds: 150);

  /// Câu cuối (không có câu kế) kéo dài ít nhất mức này nếu chưa biết duration.
  static const Duration lastLineFallbackSpan = Duration(seconds: 4);

  /// Suy ra (start, end) cho câu [index] trong [lines].
  ///
  /// [lines] được sort lại theo timestamp ở đây (defensive), caller không cần
  /// tự sort. Trả null nếu index ngoài phạm vi hoặc câu rỗng text.
  static AbSuggestion? suggestionForLine({
    required List<LrcLine> lines,
    required int index,
    Duration? trackDuration,
  }) {
    final sorted = _sortedMeaningful(lines);
    if (index < 0 || index >= sorted.length) return null;

    final start = sorted[index].timestamp < Duration.zero
        ? Duration.zero
        : sorted[index].timestamp;

    Duration end;
    if (index + 1 < sorted.length) {
      // B = đầu câu kế (trừ pad nhẹ để không sướt sang câu sau).
      final next = sorted[index + 1].timestamp;
      end = next - const Duration(milliseconds: 50);
      if (end < start + minSegmentLength) {
        // Câu kế quá sát → dùng mốc tối thiểu để đoạn luyện được.
        end = start + minSegmentLength;
      }
    } else if (trackDuration != null && trackDuration > start) {
      end = trackDuration;
    } else {
      end = start + lastLineFallbackSpan;
    }

    if (trackDuration != null && end > trackDuration) end = trackDuration;
    if (end <= start) end = start + minSegmentLength;

    return AbSuggestion(
      index: index,
      start: start,
      end: end,
      text: sorted[index].text.trim(),
    );
  }

  /// Toàn bộ gợi ý theo câu (bỏ câu rỗng; sort theo thứ tự phát).
  static List<AbSuggestion> buildSentenceSuggestions({
    required List<LrcLine> lines,
    Duration? trackDuration,
  }) {
    final sorted = _sortedMeaningful(lines);
    return [
      for (var i = 0; i < sorted.length; i++)
        suggestionForLine(
          lines: sorted,
          index: i,
          trackDuration: trackDuration,
        )!,
    ];
  }

  /// Gợi ý cho câu ĐANG PHÁT tại [position] (dùng cho nút "Dùng câu đang
  /// phát"). Trả null khi không có LRC hoặc vị trí trước câu đầu tiên.
  static AbSuggestion? suggestionAtPosition({
    required List<LrcLine> lines,
    required Duration position,
    Duration? trackDuration,
  }) {
    final sorted = _sortedMeaningful(lines);
    if (sorted.isEmpty) return null;

    var index = -1;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].timestamp <= position) {
        index = i;
      } else {
        break;
      }
    }
    if (index < 0) {
      // Trước câu đầu tiên → gợi ý câu đầu (tiện hơn là không gợi gì).
      index = 0;
    }
    return suggestionForLine(
      lines: sorted,
      index: index,
      trackDuration: trackDuration,
    );
  }

  /// Chỉnh tay A hoặc B ±[delta], clamp để đoạn luôn hợp lệ:
  /// 0 ≤ A < B − minSegmentLength; B ≤ trackDuration (nếu biết).
  static ({Duration start, Duration end}) nudgeLoop({
    required Duration start,
    required Duration end,
    required bool moveStart,
    required Duration delta,
    Duration? trackDuration,
    Duration minLength = minSegmentLength,
  }) {
    var a = start < Duration.zero ? Duration.zero : start;
    var b = end;
    if (b <= a) b = a + minLength;

    if (moveStart) {
      a += delta;
      if (a < Duration.zero) a = Duration.zero;
      if (a > b - minLength) a = b - minLength;
    } else {
      b += delta;
      if (b <= a) b = a + minLength;
      if (trackDuration != null && b > trackDuration) b = trackDuration;
      if (b <= a) {
        // trackDuration quá ngắn — giữ đoạn tối thiểu tính từ A.
        b = a + minLength;
      }
    }
    return (start: a, end: b);
  }

  static List<LrcLine> _sortedMeaningful(List<LrcLine> lines) {
    final kept =
        lines.where((l) => l.text.trim().isNotEmpty).toList(growable: false);
    final sorted = List<LrcLine>.from(kept)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }
}
