// packages/vipsound_stt/lib/stt_engine_whisper.dart

import 'package:vipsound_stt/models/stt_model_info.dart';
import 'package:vipsound_stt/models/stt_result.dart';
import 'package:vipsound_stt/models/stt_config.dart';
import 'package:vipsound_stt/models/content_id.dart';
// Note: In real setup, you should expose AudioFingerprintUtil via a proper package dependency or shared utils.
// Temporarily handled via dynamic call or copying logic if we need it standalone, but for now we will remove the invalid package path.

class SttEngineWhisper {
  // Mock implementation for demonstration
  Future<SttResult> transcribe(
    String audioPath, {
    required WhisperModelLevel level,
    required String language,
    required bool wordTimestamps,
  }) async {
    final output = "mock whisper output";
    return _parseWhisperResult(
      output,
      audioPath: audioPath,
      engineType: SttEngineType.whisper,
      processingTime: const Duration(seconds: 2),
      language: language,
      hasWordTimestamps: wordTimestamps,
    );
  }

  SttResult _parseWhisperResult(
    dynamic whisperOutput, {
    required String audioPath,
    required SttEngineType engineType,
    required Duration processingTime,
    required String language,
    required bool hasWordTimestamps,
  }) {
    final fingerprint = "fp_${audioPath.hashCode}"; // Mock placeholder for missing AudioFingerprintUtil; 
    final List<dynamic> rawSegments = [];
    
    final segments = rawSegments.asMap().entries.map((entry) {
      final idx = entry.key;
      final seg = entry.value;
      final text = seg['text'] as String? ?? '';
      final start = (seg['start'] as num?)?.toDouble() ?? 0.0;
      final segmentUid = ContentId.segmentUid(audioFingerprint: fingerprint, startMs: (start * 1000).toInt(), text: text);

      return SttSegment(
        id: idx,
        uid: segmentUid,
        startSeconds: start,
        endSeconds: (seg['end'] as num?)?.toDouble() ?? 0.0,
        text: text,
        words: [],       // Fixed: Added empty list for words
        avgConfidence: 1.0, // Fixed: Added default confidence
      );
    }).toList();

    return SttResult(
      audioFingerprint: fingerprint,
      fullText: whisperOutput.toString(),
      segments: segments,
      engineUsed: engineType,
      language: language,
      processingTime: processingTime,
      hasWordTimestamps: hasWordTimestamps,
    );
  }

  void dispose() {}
}
