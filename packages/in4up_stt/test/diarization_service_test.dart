import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/diarization/diarization_service.dart';

void main() {
  test('heuristic alternates speakers after a silence gap', () async {
    final input = SttResult(
      fullText: 'hello yes goodbye',
      segments: [
        SttSegment(id: 0, uid: 'a', startSeconds: 0, endSeconds: 1,
            text: 'hello', words: const [], avgConfidence: 1),
        SttSegment(id: 1, uid: 'b', startSeconds: 3, endSeconds: 4,
            text: 'yes', words: const [], avgConfidence: 1),
        SttSegment(id: 2, uid: 'c', startSeconds: 3.2, endSeconds: 4.2,
            text: 'goodbye', words: const [], avgConfidence: 1),
      ],
      engineUsed: SttEngineType.whisper,
      language: 'en',
      processingTime: Duration.zero,
      audioFingerprint: 'fixture',
    );

    final result = await const HeuristicDiarizationService().diarize(input);
    expect(result.map((a) => a.speakerId), [1, 2, 2]);
  });
}
