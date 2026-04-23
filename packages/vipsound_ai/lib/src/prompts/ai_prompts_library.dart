import '../models/ai_analysis.dart';

/// Thư viện prompt - đây là "bộ não" quyết định chất lượng output
/// Mọi prompt PHẢI yêu cầu JSON output để AiModelMapper parse được
class AiPromptsLibrary {

  static String buildPrompt({
    required AiAnalysisType type,
    required String text,
    String? context,
  }) {
    switch (type) {
      case AiAnalysisType.wordLookup:
        return _wordLookupPrompt(text, context);
      case AiAnalysisType.sentenceAnalysis:
        return _sentenceAnalysisPrompt(text);
      case AiAnalysisType.paoGeneration:
        return _paoPrompt(text);
      default:
        return _wordLookupPrompt(text, context);
    }
  }

  // ── Word Lookup ──────────────────────────────────────────

  static String _wordLookupPrompt(String word, String? context) => '''
You are a language learning assistant. Analyze the English word "$word"${context != null ? ' used in: "$context"' : ''}.

IMPORTANT: Return ONLY valid JSON, no other text.

{
  "type": "wordLookup",
  "word_detail": {
    "word": "$word",
    "meaning": "<Vietnamese meaning, 2-5 words>",
    "cefr_level": "<A1/A2/B1/B2/C1/C2>",
    "word_type": "<noun/verb/adjective/adverb/preposition/conjunction/pronoun>",
    "etymology_hint": "<brief etymology in English, 1 sentence>",
    "memory_hook": "<vivid visual description to remember this word, 1-2 sentences>"
  },
  "visual_prompt": "<describe a concrete scene or image that represents this word, NO translation>",
  "pao_suggestions": [
    "<PAO story option 1: Person + Action + Object format>",
    "<PAO story option 2>",
    "<PAO story option 3>"
  ],
  "context_examples": [
    "<example sentence 1 using $word naturally>",
    "<example sentence 2>"
  ],
  "ipa_fallback": "<IPA pronunciation in format /.../>  "
}
''';

  // ── Sentence Analysis (5 Fingers) ───────────────────────

  static String _sentenceAnalysisPrompt(String sentence) => '''
Analyze this English sentence using the 5-finger grammar model.
Sentence: "$sentence"

Return ONLY valid JSON:

{
  "type": "sentenceAnalysis",
  "grammar": {
    "subject": "<subject part of sentence>",
    "verb": "<verb part>",
    "object": "<object part, empty string if none>",
    "complement": "<complement if any, null if none>",
    "adverbial": "<time/place/manner adverbials if any, null if none>",
    "pattern": "<pattern like S+V+O or S+V+C>",
    "explanation_vi": "<explain the grammar pattern in Vietnamese, 1-2 sentences>"
  },
  "visual_prompt": "<describe a scene that represents this sentence>",
  "context_examples": [
    "<similar sentence using same pattern>",
    "<another example>"
  ]
}
''';

  // ── PAO Generation ───────────────────────────────────────

  static String _paoPrompt(String word) => '''
Create 3 PAO (Person-Action-Object) memory stories for the word "$word".
Each story must help remember the MEANING and SOUND of the word.

Return ONLY valid JSON:

{
  "type": "paoGeneration",
  "pao_suggestions": [
    "<Famous person + vivid action + memorable object that sounds like or represents '$word'>",
    "<Different person + action + object>",
    "<Third option, more creative>"
  ]
}
''';
}
