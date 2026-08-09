// lib/features/translation/engines/gemma_translation_engine.dart
//
// STUB for Branch B — Hybrid Tier 3: Gemma 2B wrapper (đã có sẵn in2up_ai)
// Branch B điền để tận dụng AiServiceFacade, không tạo Isolate mới
// Tham chiếu: docs/DICTIONARY_SPEC.md

import 'translation_engine.dart';
// import 'package:in2up_ai/in2up_ai.dart'; // Branch B uncomment khi dùng

/// Tier 3 — Dịch có giữ thuật ngữ bằng Gemma 2B (đã có trong packages/in2up_ai)
/// Chỉ chạy khi AiServiceFacade.hasModel == true (user đã tải gemma-2b-it-q4_k_m.gguf)
class GemmaTranslationEngine implements TranslationEngine {
  // TODO(Branch B): inject facade từ Provider
  // final AiServiceFacade _facade;
  // GemmaTranslationEngine(this._facade);

  @override
  String get name => 'Gemma Phật Học';

  @override
  String get id => 'gemma';

  @override
  int get maxCharsPerRequest => 2000; // Gemma chậm, nên chunk nhỏ

  @override
  Duration get requestDelay => const Duration(milliseconds: 300);

  @override
  Future<bool> isAvailable() async {
    // TODO(Branch B):
    // return _facade.hasModel && _facade.facadeState != AiFacadeState.loading;
    return false; // stub: chưa có model nên skip
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    // TODO(Branch B):
    // final glossary = await DictionaryEngine().lookupRelevant(text); // lấy thuật ngữ liên quan
    // final prompt = '''
    // Bạn là dịch giả Phật học. Dịch sang ${targetLang == 'VI' ? 'tiếng Việt' : targetLang},
    // giữ nguyên thuật ngữ: ${glossary.map((g) => "${g.term}→${g.translation}").join(", ")}.
    // Chỉ trả bản dịch, không giải thích thêm.
    // Text: $text
    // ''';
    // final stream = _facade.analyzeSentence(sentence: prompt);
    // await for (final analysis in stream) { ... return success ... }

    return TranslationResult.failure(
      original: text,
      error: 'Gemma not yet implemented (Branch B TODO)',
      engine: name,
    );
  }
}

// Cách dùng trong TranslationService (Branch B):
// Provider<GemmaTranslationEngine>(
//   create: (ctx) => GemmaTranslationEngine(ctx.read<AiServiceFacade>()),
// )
