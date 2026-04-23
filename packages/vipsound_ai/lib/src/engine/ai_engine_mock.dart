import 'dart:async';
import '../models/ai_analysis.dart';
import 'ai_engine.dart';

/// Mock engine cho testing và khi không có model file
/// Trả về data mẫu ngay lập tức, không cần llama.cpp
class AiEngineMock implements AiEngine {
  @override
  AiEngineState get state => AiEngineState.ready;

  @override
  Future<bool> initialize({required String modelPath}) async => true;

  @override
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
  }) async* {
    // Simulate delay của real AI
    await Future.delayed(const Duration(milliseconds: 500));

    yield AiAnalysis(
      inputText: text,
      type: type,
      wordDetail: WordAnalysis(
        word: text,
        meaning: '[Mock] nghĩa của "$text"',
        phonetic: '/mɒk/',
        cefrLevel: 'B2',
        wordTypeLabel: 'noun',
        memoryHook: 'Hình dung một cảnh sinh động về "$text"',
      ),
      visualPrompt: 'Một cảnh sinh động thể hiện "$text"',
      paoSuggestions: [
        'Einstein (P) khám phá (A) "$text" (O)',
        'Bạn (P) nhớ mãi (A) "$text" (O)',
        'Sherlock (P) suy luận (A) "$text" (O)',
      ],
      contextExamples: [
        'This sentence uses $text correctly.',
        'Another example with $text in context.',
      ],
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.gemma,
      isPartial: false,
    );
  }

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}
}
