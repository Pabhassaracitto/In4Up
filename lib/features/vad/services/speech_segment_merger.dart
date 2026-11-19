// lib/features/vad/services/speech_segment_merger.dart
//
// PSRC-205 (audit 1.29.0-Beta, 2026-11-15) — "tạo lời cho file âm thanh dài
// (.m4a 7 phút, .mp3 17 phút) chạy rất lâu, kết quả lắt nhắt và THIẾU ĐẦU CÂU".
//
// GỐC: VAD cắt theo *khoảng lặng* với `minSilenceDurationMs = 100` — 100 ms là
// chỗ ngắt GIỮA HAI TỪ, không phải giữa hai câu. Một câu nói bình thường có
// 3-8 khoảng ngắt như vậy ⇒ VAD trả về hàng chục đoạn 0,5-2 s. Pipeline
// transcribe TỪNG đoạn một (mỗi đoạn = một lượt `transcribeFile`, một lần
// "Đang chuẩn bị…" + "chunk 1/1", một dòng LRC) ⇒
//   * rất chậm (mỗi đoạn cõng đủ chi phí khởi động của Whisper),
//   * mỗi dòng là một MẢNH giữa câu ⇒ thiếu chủ ngữ / thiếu đầu câu,
//   * Whisper không có ngữ cảnh của câu trước nên càng dễ sai.
//
// CÁCH SỬA (ở đây):
//   1. GOM các đoạn speech liền kề có khoảng lặng nhỏ (`maxGapSeconds`, mặc
//      định 0,45 s) thành một "cụm" liên tục — cụm này mới là một câu/đoạn nói
//      thật, không phải từng mảnh VAD.
//   2. CHIA cụm thành các mảnh bằng nhau, mỗi mảnh ≤ `maxSegmentSeconds`
//      (14 s — giữ nguyên hợp đồng RAM của handover: không bao giờ đưa cả
//      file 1 h vào Whisper).
//
// Vì sao chia BẰNG NHAU chứ không phải "14 s + phần dư": cách cắt thô sinh ra
// mẩu đuôi 0,1-0,5 s (chỉ đủ một phụ âm) ⇒ vừa vô nghĩa vừa làm tăng số lượt
// transcribe. Với 1 cụm 14,3 s → 2 mảnh 7,15 s (đều dùng được).
//
// Hàm THUẦN (không I/O, không phụ thuộc Flutter) để CI khoá lại được trên
// host VM — xem `test/vad/psrc_205_segment_merger_test.dart`.

import 'dart:math' as math;

import '../models/speech_segment.dart';

/// Chặn trên cho một mảnh sau khi chia (giây) — khớp
/// `SherpaVadService.defaultMaxSpeechDurationS`.
const double kVadMaxMergedSegmentSeconds = 14.0;

/// Khoảng lặng tối đa giữa hai đoạn để vẫn coi là CÙNG một cụm (giây).
///
/// 0,45 s: đủ để gộp các từ trong cùng một câu (ngắt hơi giữa từ thường
/// < 0,3 s) mà vẫn tách được hai câu khác nhau (nghỉ > 0,5 s).
const double kVadMergeGapSeconds = 0.45;

/// Gộp các đoạn VAD thành cụm nói liên tục rồi chia đều thành mảnh ≤ chặn trên.
///
/// Quy tắc:
/// 1. Bỏ đoạn `isSpeech == false` và đoạn rỗng/âm.
/// 2. Sắp xếp theo `startTime` (VAD không bảo đảm thứ tự).
/// 3. Hai đoạn cách nhau ≤ `mergeGapSeconds` (kể cả chồng lấn, gap âm) thuộc
///    cùng một CỤM.
/// 4. Mỗi cụm được chia thành `ceil(độ dài / maxSegmentSeconds)` mảnh BẰNG
///    NHAU, nên không bao giờ có mẩu đuôi vài phần trăm giây.
///
/// `confidence` của mảnh = giá trị NHỎ NHẤT trong cụm (không thổi phồng độ
/// tin cậy của phần yếu nhất).
List<SpeechSegment> mergeSpeechSegments(
  List<SpeechSegment> segments, {
  double maxSegmentSeconds = kVadMaxMergedSegmentSeconds,
  double mergeGapSeconds = kVadMergeGapSeconds,
}) {
  if (segments.isEmpty) return const <SpeechSegment>[];
  final maxLen = maxSegmentSeconds > 0.05
      ? maxSegmentSeconds
      : kVadMaxMergedSegmentSeconds;
  final maxGap = mergeGapSeconds < 0 ? 0.0 : mergeGapSeconds;

  final speech = segments
      .where((s) => s.isSpeech && s.endTime - s.startTime > 0.0001)
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  final result = <SpeechSegment>[];
  double? clusterStart;
  double? clusterEnd;
  double clusterConfidence = 1.0;

  void flushCluster() {
    final start = clusterStart;
    final end = clusterEnd;
    if (start == null || end == null || end <= start) {
      clusterStart = null;
      clusterEnd = null;
      clusterConfidence = 1.0;
      return;
    }
    final length = end - start;
    final pieceCount = math.max(1, (length / maxLen).ceil());
    final pieceLength = length / pieceCount;
    for (var i = 0; i < pieceCount; i++) {
      final pieceStart = start + pieceLength * i;
      // Mảnh cuối bám đúng `end` để không trôi do sai số dấu phẩy động.
      final pieceEnd = i == pieceCount - 1 ? end : pieceStart + pieceLength;
      result.add(SpeechSegment(
        startTime: pieceStart,
        endTime: pieceEnd,
        confidence: clusterConfidence,
      ));
    }
    clusterStart = null;
    clusterEnd = null;
    clusterConfidence = 1.0;
  }

  for (final segment in speech) {
    if (clusterStart == null || clusterEnd == null) {
      clusterStart = segment.startTime;
      clusterEnd = segment.endTime;
      clusterConfidence = segment.confidence;
      continue;
    }
    final gap = segment.startTime - clusterEnd!;
    if (gap <= maxGap) {
      if (segment.endTime > clusterEnd!) clusterEnd = segment.endTime;
      if (segment.confidence < clusterConfidence) {
        clusterConfidence = segment.confidence;
      }
    } else {
      flushCluster();
      clusterStart = segment.startTime;
      clusterEnd = segment.endTime;
      clusterConfidence = segment.confidence;
    }
  }
  flushCluster();

  return result;
}
