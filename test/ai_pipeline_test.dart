// test/ai_pipeline_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:vipsound_ai/vipsound_ai.dart';
import 'package:vipsound_ai/src/mapper/ai_model_mapper.dart';
import 'package:vipsound_ai/src/error/ai_error_handler.dart';
import 'package:vipsound_ai/src/models/ai_analysis.dart';

void main() {
  group('AiModelMapper', () {
    test('Parse valid JSON thành công', () {
      const rawJson = '''
{
  "type": "wordLookup",
  "word_detail": {
    "word": "breakthrough",
    "meaning": "đột phá",
    "cefr_level": "B2",
    "word_type": "noun"
  },
  "visual_prompt": "người đấm xuyên tường",
  "pao_suggestions": ["Option A", "Option B", "Option C"],
  "ipa_fallback": "/ˈbreɪkˌθruː/"
}''';

      final result = AiModelMapper.parse(
        rawOutput: rawJson,
        inputText: 'breakthrough',
        type: AiAnalysisType.wordLookup,
      );

      expect(result.type, isNot(AiAnalysisType.error));
      expect(result.wordDetail?.meaning, equals('đột phá'));
      expect(result.wordDetail?.cefrLevel, equals('B2'));
      expect(result.paoSuggestions.length, equals(3));
      expect(result.ipaFallback, equals('/ˈbreɪkˌθruː/'));
    });

    test('JSON có text thừa vẫn parse được', () {
      const rawOutput = '''
Here is my analysis:
{"type":"wordLookup","word_detail":{"word":"test","meaning":"kiểm tra"}}
Hope this helps!''';

      final result = AiModelMapper.parse(
        rawOutput: rawOutput,
        inputText: 'test',
        type: AiAnalysisType.wordLookup,
      );

      expect(result.type, isNot(AiAnalysisType.error));
      expect(result.wordDetail?.meaning, equals('kiểm tra'));
    });

    test('JSON rỗng trả về fallback', () {
      final result = AiModelMapper.parse(
        rawOutput: '',
        inputText: 'test',
        type: AiAnalysisType.wordLookup,
      );

      expect(result.type, equals(AiAnalysisType.error));
    });
  });

  group('HallucinationCheck', () {
    test('IPA format hợp lệ', () {
      final analysis = AiAnalysis(
        inputText: 'test',
        type: AiAnalysisType.wordLookup,
        ipaFallback: '/tɛst/',
        generatedAt: DateTime.now(),
      );

      final check = AiErrorHandler.checkForHallucination(analysis);
      expect(check.isClean, isTrue);
    });

    test('IPA format sai bị detect', () {
      final analysis = AiAnalysis(
        inputText: 'test',
        type: AiAnalysisType.wordLookup,
        ipaFallback: 'test', // Thiếu //
        generatedAt: DateTime.now(),
      );

      final check = AiErrorHandler.checkForHallucination(analysis);
      expect(check.isClean, isFalse);
    });

    test('CEFR level không hợp lệ bị detect', () {
      final analysis = AiAnalysis(
        inputText: 'test',
        type: AiAnalysisType.wordLookup,
        wordDetail: WordAnalysis(
          word: 'test',
          cefrLevel: 'X9', // Không hợp lệ
        ),
        generatedAt: DateTime.now(),
      );

      final check = AiErrorHandler.checkForHallucination(analysis);
      expect(check.isClean, isFalse);
    });
  });
}
