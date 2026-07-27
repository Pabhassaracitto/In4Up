// VipSound v11.0 — MemoryBridge: UI không ghi DB trực tiếp

import 'package:flutter/foundation.dart';
import 'package:vipsound_stt/vipsound_stt.dart';

abstract class MemoryBridge {
  Future<void> ingestTranscript({
    required String audioPath,
    required SttResult transcript,
    required List<SpeakerAnnotation> speakers,
  });

  Future<void> ingestSummary({
    required String audioPath,
    required String summaryJson,
  });

  Future<void> ingestVocabulary({
    required String audioPath,
    required List<Map<String, dynamic>> terms,
  });
}

class LiveMemoryBridge implements MemoryBridge {
  static final LiveMemoryBridge _instance = LiveMemoryBridge._();
  factory LiveMemoryBridge() => _instance;
  LiveMemoryBridge._();

  @override
  Future<void> ingestTranscript({
    required String audioPath,
    required SttResult transcript,
    required List<SpeakerAnnotation> speakers,
  }) async {
    debugPrint(
      '[MemoryBridge] ingestTranscript: '
      '${transcript.segments.length} segments, '
      '${speakers.length} annotations → $audioPath',
    );
    // TODO Sprint 1.5: Hive.box('transcripts').put(fp, data)
  }

  @override
  Future<void> ingestSummary({
    required String audioPath,
    required String summaryJson,
  }) async {
    debugPrint(
        '[MemoryBridge] ingestSummary → $audioPath');
    // TODO Sprint 1.5: Hive.box('summaries').put(fp, summaryJson)
  }

  @override
  Future<void> ingestVocabulary({
    required String audioPath,
    required List<Map<String, dynamic>> terms,
  }) async {
    debugPrint(
      '[MemoryBridge] ingestVocabulary: '
      '${terms.length} terms → WordEntry pipeline',
    );
    // TODO Sprint 1.5: terms → AiTerm → WordEntry → VocabularyBridge
  }
}
