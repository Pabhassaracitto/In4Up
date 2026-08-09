// lib/features/translation/engines/mlkit_engine.dart
//
// STUB for Branch B — Hybrid Tier 2: ML Kit Offline Translation
// Branch B điền khi thêm google_mlkit_translation
// Tham chiếu: docs/DICTIONARY_SPEC.md

import 'translation_engine.dart';

/// Tier 2 — ML Kit Offline (11MB/cặp ngôn ngữ, tải động)
/// Nếu chưa muốn thêm dependency ngay, giữ stub này, TranslationService sẽ skip khi isAvailable==false
class MlKitEngine implements TranslationEngine {
  @override
  String get name => 'ML Kit Offline';

  @override
  String get id => 'mlkit';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 50);

  @override
  Future<bool> isAvailable() async {
    // TODO(Branch B): sau khi thêm google_mlkit_translation
    // final manager = OnDeviceTranslatorModelManager();
    // return await manager.isModelDownloaded(sourceLang, targetLang);
    return false; // stub: chưa có model nên skip, giữ app không vỡ
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    // TODO(Branch B): 
    // final translator = OnDeviceTranslator(
    //   sourceLanguage: TranslateLanguage.english,
    //   targetLanguage: TranslateLanguage.vietnamese,
    // );
    // final result = await translator.translateText(text);
    // translator.close();
    // return TranslationResult.success(original: text, translated: result, engine: name);

    return TranslationResult.failure(
      original: text,
      error: 'ML Kit not yet implemented (Branch B TODO)',
      engine: name,
    );
  }

  /// Branch B: tải model động (gọi khi user bấm "Tải bộ dịch offline")
  Future<bool> downloadModelIfNeeded({
    required String sourceLang,
    required String targetLang,
    void Function(double progress)? onProgress,
  }) async {
    // TODO(Branch B):
    // final manager = OnDeviceTranslatorModelManager();
    // return await manager.downloadModel(TranslateLanguage.vietnamese);
    return false;
  }

  Future<bool> deleteModel({
    required String sourceLang,
    required String targetLang,
  }) async {
    // TODO(Branch B): manager.deleteModel(...)
    return false;
  }
}

// pubspec.yaml (Branch B thêm):
// dependencies:
//   google_mlkit_translation: ^0.13.0
