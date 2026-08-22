// packages/in4up_ai/lib/src/engine/ai_engine_mock.dart
// Offline fallback when no real .gguf is loaded.

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
      inputText: text,
      summary: _mockSummary(type, text),
      topics: _mockTopics(type, text),
      terms: _mockTerms(type, text),
      success: true,
      actionItems: _mockActions(text),
      language: 'vi',
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

  String _mockSummary(AiAnalysisType type, String text) {
    if (text.contains('in4up_WRITE_REVIEW')) {
      return 'Tầng 2 đã nhận bài chép. Đây là phản hồi mẫu khi chưa có model .gguf — điểm Tầng 1 ở phía trên; import model để AI chấm thật.';
    }
    if (text.contains('in4up_REWRITE_REVIEW')) {
      return 'Tầng 2 đã nhận bài viết lại. Phản hồi mẫu: giữ ý chính, đổi cấu trúc câu, tránh chép sát câu gốc.';
    }
    if (text.contains('in4up_SUMMARY_REVIEW')) {
      return 'Tầng 2 đã nhận bản tóm tắt. Phản hồi mẫu: giữ 2–3 từ khóa cốt lõi và rút gọn thành một câu rõ.';
    }
    switch (type) {
      case AiAnalysisType.wordLookup:
        return 'Tra cứu từ: "$text"';
      case AiAnalysisType.sentenceParse:
        return 'Phân tích câu đã nhận. Import model .gguf để có nhận xét ngữ pháp sâu hơn.';
      case AiAnalysisType.summarize:
        return 'Tóm tắt nội dung transcript.';
      case AiAnalysisType.termExtract:
        return 'Trích xuất thuật ngữ từ transcript.';
      case AiAnalysisType.conversation:
        return 'Mình đã nhận tin nhắn. Import model .gguf để chat bằng model thật.';
      case AiAnalysisType.paoGeneration:
        return 'Tạo PAO memory story cho "$text".';
      case AiAnalysisType.error:
        return 'Có lỗi xảy ra.';
    }
  }

  List<String> _mockTopics(AiAnalysisType type, [String text = '']) {
    if (text.contains('in4up_WRITE_REVIEW')) return ['Writing', 'Recall'];
    if (text.contains('in4up_REWRITE_REVIEW')) return ['Rewrite', 'Output'];
    if (text.contains('in4up_SUMMARY_REVIEW')) {
      return ['Summary', 'Compression'];
    }
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

  List<String> _mockActions(String text) {
    if (text.contains('in4up_WRITE_REVIEW') ||
        text.contains('in4up_REWRITE_REVIEW') ||
        text.contains('in4up_SUMMARY_REVIEW')) {
      return [
        'Xem điểm Tầng 1 (Chấm nhanh) ngay phía trên.',
        'Import file .gguf trong Cài AI local để Tầng 2 dùng model thật.',
      ];
    }
    return const [];
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
