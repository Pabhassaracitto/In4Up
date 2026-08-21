// packages/vipsound_ai/lib/src/engine/ai_engine_mock.dart
// v11.0-final — fix AiAnalysis() constructor (required fields)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ai_engine.dart';

/// Mock engine dùng cho test / offline fallback khi chưa có model thật
class AiEngineMock implements AiEngine {
  @override
  AiEngineState get state => AiEngineState.ready;

  @override
  Future<bool> initialize({required String modelPath}) async {
    debugPrint('[AiEngineMock] initialized (mock)');
    return true;
  }

  @override
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
  }) async* {
    await Future.delayed(const Duration(milliseconds: 300));

    yield AiAnalysis(
      summary: _mockSummary(type, text),
      topics: _mockTopics(type),
      terms: _mockTerms(type, text),
      success: true,
      actionItems: const [],
      language: 'en',
      analysisType: type,
      generatedAt: DateTime.now(),
      wordDetail: type == AiAnalysisType.wordLookup
          ? WordDetail(
              word: text,
              meaning: 'nghĩa mock của "$text"',
              cefrLevel: 'B2',
              wordType: 'noun',
              etymologyHint: 'Mock etymology',
              memoryHook: 'Hình dung $text trong cuộc sống hàng ngày',
            )
          : null,
      paoSuggestions: type == AiAnalysisType.paoGeneration
          ? [
              'Einstein (P) khám phá (A) $text (O)',
              'Hermione (P) đọc (A) cuốn sách về $text (O)',
              'Bạn (P) nhớ mãi (A) ý nghĩa của $text (O)',
            ]
          : const [],
      isPartial: false,
    );
  }

  @override
  Future<void> warmUp() async {
    debugPrint('[AiEngineMock] warm-up (no-op)');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[AiEngineMock] disposed');
  }

  // ── Mock helpers ──────────────────────────────────────────

  String _mockSummary(AiAnalysisType type, String text) {
    switch (type) {
      case AiAnalysisType.wordLookup:
        return 'Tra cứu từ: "$text"';
      case AiAnalysisType.sentenceParse:
        return 'Phân tích câu: "$text"';
      case AiAnalysisType.summarize:
        return 'Tóm tắt nội dung transcript.';
      case AiAnalysisType.termExtract:
        return 'Trích xuất thuật ngữ từ transcript.';
      case AiAnalysisType.conversation:
        return 'Phân tích hội thoại.';
      case AiAnalysisType.paoGeneration:
        return 'Tạo PAO memory story cho "$text".';
      case AiAnalysisType.error:
        return 'Có lỗi xảy ra.';
    }
  }

  List<String> _mockTopics(AiAnalysisType type) {
    switch (type) {
      case AiAnalysisType.wordLookup:
        return ['Vocabulary'];
      case AiAnalysisType.sentenceParse:
        return ['Grammar'];
      case AiAnalysisType.summarize:
        return ['Summary'];
      case AiAnalysisType.termExtract:
        return ['Terminology'];
      case AiAnalysisType.conversation:
        return ['Conversation'];
      case AiAnalysisType.paoGeneration:
        return ['Memory', 'Vocabulary'];
      case AiAnalysisType.error:
        return ['Error'];
    }
  }

  List<AiTerm> _mockTerms(AiAnalysisType type, String text) {
    if (type == AiAnalysisType.termExtract ||
        type == AiAnalysisType.conversation) {
      return [
        AiTerm(
          text: text.split(' ').first,
          definition: 'Thuật ngữ mock',
          importance: 0.8,
          sourceJoinKey: '0|${text.split(' ').first.toLowerCase()}',
          speakerId: 0,
        ),
      ];
    }
    return const [];
  }
}
