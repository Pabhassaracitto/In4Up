// in4up v11.0 — Diarization interface + Heuristic Sprint 1

import 'package:flutter/foundation.dart';
import '../models/stt_result.dart';
import 'speaker_annotation.dart';

/// Interface chung — Sprint 2 thay bằng MeetilyRustDiarizationService
abstract class DiarizationService {
  Future<List<SpeakerAnnotation>> diarize(SttResult input);
}

/// Sprint 1: Heuristic dựa trên silence gap + question pattern
/// Không cần model, chạy offline ngay lập tức
class HeuristicDiarizationService implements DiarizationService {
  /// Khoảng lặng tối thiểu (giây) để xem là speaker change
  final double silenceGapSec;

  /// Số speaker tối đa (0 = không giới hạn)
  final int maxSpeakers;

  const HeuristicDiarizationService({
    this.silenceGapSec = 1.6,
    this.maxSpeakers = 4,
  });

  @override
  Future<List<SpeakerAnnotation>> diarize(SttResult input) async {
    if (input.segments.isEmpty) return const [];

    final annotations = <SpeakerAnnotation>[];
    var currentSpeaker = 1;
    var lastEndSec = input.segments.first.endSeconds;

    annotations.add(SpeakerAnnotation(
      segmentUid: input.segments.first.uid,
      joinKey: input.segments.first.joinKey,
      speakerId: currentSpeaker,
      confidence: 0.8,
      engine: 'heuristic',
    ));

    for (var i = 1; i < input.segments.length; i++) {
      final prev = input.segments[i - 1];
      final curr = input.segments[i];
      final gap = curr.startSeconds - lastEndSec;

      final isQuestion = prev.text.trim().endsWith('?');
      final isShortReply = curr.text.trim().split(RegExp(r'\s+')).length <= 5;

      final shouldChange = gap >= silenceGapSec || (isQuestion && isShortReply);

      if (shouldChange) {
        currentSpeaker = currentSpeaker == 1 ? 2 : 1;
        if (maxSpeakers > 0) {
          currentSpeaker = currentSpeaker.clamp(1, maxSpeakers);
        }
      }

      final conf =
          gap >= silenceGapSec ? 0.9 : (isQuestion && isShortReply ? 0.7 : 0.6);

      annotations.add(SpeakerAnnotation(
        segmentUid: curr.uid,
        joinKey: curr.joinKey,
        speakerId: currentSpeaker,
        confidence: conf,
        engine: 'heuristic',
      ));

      lastEndSec = curr.endSeconds;
    }

    debugPrint(
      '[HeuristicDiarization] ${input.segments.length} segments → '
      '${annotations.map((a) => a.speakerId).toSet().length} speakers',
    );

    return annotations;
  }
}

/// Sprint 2: Placeholder — drop-in khi flutter_rust_bridge sẵn sàng
class MeetilyRustDiarizationService implements DiarizationService {
  final dynamic _rustBridge; // MeetilyBridge từ Task 1

  const MeetilyRustDiarizationService(this._rustBridge);

  @override
  Future<List<SpeakerAnnotation>> diarize(SttResult input) async {
    debugPrint('[MeetilyRust] Bridge chưa sẵn sàng → fallback Heuristic');
    return const HeuristicDiarizationService().diarize(input);
  }
}
