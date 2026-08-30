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

  static String _sentenceParsePrompt(String sentence) => '''
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

  // AI-CHAT-01 (v2): bọc theo chat template gemma-3 (<start_of_turn>…
  // <end_of_turn> + mở turn "model") — model được huấn luyện để KẾT THÚC
  // turn bằng <end_of_turn> (EOS) sau khi trả lời ĐỦ, thay vì sinh liên tục
  // tới maxTokens. Trên tablet ~1.5–2 token/s, trả lời 100–200 token kết
  // thúc sớm ≈ 1–2 phút thay vì 3+ phút cho 320 token chạy hết trần.
  // Giữ nguyên "Analyze conversation:" + schema JSON (mock matcher + rescue
  // _rescueSummary đều dựa vào nó).
  static String _conversationPrompt(String text, String? context) => '''
<start_of_turn>user
Analyze conversation: "$text"${context != null ? '\nContext: $context' : ''}.
Return ONLY valid JSON, nothing else:
{
  "summary": "<Vietnamese 60-word summary>",
  "topics": ["Conversation"],
  "technical_terms": [
    {"text":"<phrase>","definition":"<Vietnamese>","importance":0.8,"sourceJoinKey":"","speakerId":0}
  ],
  "action_items": [],
  "language": "en"
}
<end_of_turn>
<start_of_turn>model
''';
}
