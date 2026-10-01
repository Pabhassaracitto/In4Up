// packages/vipsound_ai/lib/src/prompts/ai_prompts_library.dart
// v11.0-final — đồng bộ hoàn toàn với AiAnalysisType enum

import '../models/ai_analysis.dart';

class AiPromptsLibrary {
  AiPromptsLibrary._();

  static String buildPrompt({
    required AiAnalysisType type,
    required String text,
    String? context,
  }) {
    switch (type) {
      case AiAnalysisType.wordLookup:
        return _wordLookupPrompt(text, context);
      case AiAnalysisType.sentenceParse:
        return _sentenceParsePrompt(text);
      case AiAnalysisType.paoGeneration:
        return _paoPrompt(text);
      case AiAnalysisType.termExtract:
        return _termExtractPrompt(text, context);
      case AiAnalysisType.summarize:
        return _summarizePrompt(text, context);
      case AiAnalysisType.conversation:
        return _conversationPrompt(text, context);
      case AiAnalysisType.error:
        return 'error';
    }
  }

  static String _wordLookupPrompt(String word, String? context) => '''
You are a language learning assistant. Analyze: "$word"${context != null ? ' in context: "$context"' : ''}.
Return ONLY valid JSON:
{
  "summary": "<Vietnamese meaning 2-5 words>",
  "topics": ["Vocabulary"],
  "technical_terms": [],
  "action_items": [],
  "language": "en",
  "word_detail": {
    "word": "$word",
    "meaning": "<Vietnamese meaning>",
    "cefr_level": "<A1-C2>",
    "word_type": "<noun/verb/adj/adv>",
    "etymology_hint": "<1 sentence>",
    "memory_hook": "<vivid image 1-2 sentences>"
  },
  "pao_suggestions": ["<PAO 1>","<PAO 2>","<PAO 3>"],
  "context_examples": ["<example 1>","<example 2>"],
  "ipa_fallback": "</.../>",
  "visual_prompt": "<concrete scene>"
}''';

  static String _sentenceParsePrompt(String sentence) {
    if (_isWriteStudioReviewPrompt(sentence)) {
      return '''
$sentence

Return ONLY one valid JSON object. Do not wrap it in markdown fences.
Required keys: summary, topics, technical_terms, action_items, language.
If grammar is useful, include grammar with subject, verb, object, pattern,
and explanation_vi.
''';
    }
    return '''
Analyze English sentence: "$sentence" using 5-finger grammar.
Return ONLY valid JSON:
{
  "summary": "<Vietnamese meaning of sentence>",
  "topics": ["Grammar"],
  "technical_terms": [],
  "action_items": [],
  "language": "en",
  "grammar": {
    "subject": "<subject>",
    "verb": "<verb>",
    "object": "<object or empty>",
    "complement": "<complement or null>",
    "adverbial": "<adverbials or null>",
    "pattern": "<S+V+O etc>",
    "explanation_vi": "<Vietnamese grammar explanation>"
  },
  "context_examples": ["<similar sentence>","<another example>"]
}''';
  }

  static bool _isWriteStudioReviewPrompt(String text) =>
      text.contains('in4up_WRITE_REVIEW') ||
      text.contains('in4up_REWRITE_REVIEW') ||
      text.contains('in4up_SUMMARY_REVIEW');

  static String _paoPrompt(String word) => '''
Create 3 PAO memory stories for: "$word".
Return ONLY valid JSON:
{
  "summary": "PAO stories for '$word'",
  "topics": ["Memory","Vocabulary"],
  "technical_terms": [],
  "action_items": [],
  "language": "en",
  "pao_suggestions": [
    "<Person + Action + Object — sounds/means like '$word'>",
    "<different PAO>",
    "<creative PAO>"
  ]
}''';

  static String _termExtractPrompt(String text, String? context) => '''
Extract technical terms from: "$text"${context != null ? '\nContext: $context' : ''}.
Return ONLY valid JSON:
{
  "summary": "<60-word summary>",
  "topics": ["<topic>"],
  "technical_terms": [
    {"text":"<term>","definition":"<Vietnamese>","importance":0.9,"sourceJoinKey":"<startMs|text>","speakerId":0}
  ],
  "action_items": [],
  "language": "en"
}''';

  static String _summarizePrompt(String text, String? context) => '''
Summarize: "$text"${context != null ? '\nContext: $context' : ''}.
Return ONLY valid JSON:
{
  "summary": "<Vietnamese summary max 120 words>",
  "topics": ["<topic>"],
  "technical_terms": [],
  "action_items": ["<action if any>"],
  "language": "vi"
}''';

  static String _conversationPrompt(String text, String? context) => '''
You are the in4up study assistant. Answer the user's latest message directly;
do NOT summarize the conversation or describe it as a task.
LATEST_USER_MESSAGE: "$text"${context != null && context.trim().isNotEmpty ? '\nRECENT_CONTEXT:\n$context' : ''}
Return ONLY valid JSON:
{
  "summary": "<direct helpful answer to the user, in Vietnamese unless the user asks for another language>",
  "topics": ["Conversation"],
  "technical_terms": [],
  "action_items": [],
  "language": "vi"
}''';
}
