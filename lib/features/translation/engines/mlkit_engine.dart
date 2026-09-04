// lib/features/translation/engines/mlkit_engine.dart
//
// ML Kit On-Device Translation (Android/iOS) — engine dịch CÂU offline.
//
// Luật phiên (bắt buộc):
// - CẤM tải model lúc bootstrap / ensureModel / main(). Model chỉ tải khi
//   user bấm "Tải về" trong màn Cài đặt engine dịch (cùng quy tắc Whisper).
// - Thiếu model → TranslationResult.failure RÕ ràng ("Chưa tải gói dịch
//   Hindi") — KHÔNG im lặng rơi về ráp từ điển.
// - Desktop (Windows/Linux) + web: isAvailable() == false; import không
//   crash (plugin chỉ là MethodChannel wrapper).
//
// Cặp hỗ trợ: EN ↔ VI, EN ↔ HI. HI ↔ VI do TranslationService pivot qua
// EN (2 bước + glossary hai đầu).
//
// API package `google_mlkit_translation` (0.14.x — pin vì 0.15.x đòi
// Dart SDK 3.12, CI là 3.11.5; API 0.14 == 0.15, đã đối chiếu source):
//   OnDeviceTranslator(sourceLanguage, targetLanguage).translateText(text)
//   OnDeviceTranslatorModelManager: isModelDownloaded / downloadModel /
//   deleteModel (bcpCode: 'en', 'vi', 'hi', ...)

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'translation_engine.dart';

class MlKitEngine extends TranslationEngine {
  MlKitEngine({OnDeviceTranslatorModelManager? modelManager})
      : _modelManager = modelManager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _modelManager;

  @override
  String get name => 'ML Kit On-Device';

  @override
  String get id => 'mlkit';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 50);

  /// ML Kit on-device translation chỉ tồn tại trên Android/iOS.
  static bool get platformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<bool> isAvailable() async => platformSupported;

  /// Map mã ngôn ngữ của app ("EN", "VI", "HI", "ZH-TW", ...) →
  /// [TranslateLanguage] của ML Kit, hoặc null nếu không hỗ trợ.
  static TranslateLanguage? languageForCode(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return BCP47Code.fromRawValue(normalized);
  }

  /// UI dùng: ngôn ngữ này có thể tải model ML Kit không.
  static bool supportsTranslationCode(String code) =>
      languageForCode(code) != null;

  /// bcpCode ML Kit từ mã ngôn ngữ app ('EN' → 'en'), hoặc null nếu
  /// không hỗ trợ.
  /// UI gọi cái này thay vì `language.bcpCode` trực tiếp: extension
  /// BCP47Code CHỈ áp dụng trong file import package google_mlkit_
  /// translation — import của file khác (vd toolbar) KHÔNG kéo theo
  /// extension đó theo (Dart không re-export qua import transit).
  static String? bcpCodeFor(String code) {
    final language = languageForCode(code);
    return language == null ? null : language.bcpCode;
  }

  Future<bool> isModelDownloaded(String bcpCode) async {
    if (!platformSupported) return false;
    try {
      return await _modelManager.isModelDownloaded(bcpCode);
    } catch (_) {
      return false;
    }
  }

  /// Cặp (source, target) có đủ model chưa (cả hai phía).
  Future<bool> isPairReady({
    required String sourceCode,
    required String targetCode,
  }) async {
    final source = languageForCode(sourceCode);
    final target = languageForCode(targetCode);
    if (source == null || target == null) return false;
    if (!await isModelDownloaded(source.bcpCode)) return false;
    return await isModelDownloaded(target.bcpCode);
  }

  /// Tải model một ngôn ngữ. CHỈ gọi sau khi user bấm trong UI.
  Future<bool> downloadModel(String bcpCode) {
    // isWifiRequired: false — user chủ động bấm (cùng quy tắc STT),
    // tránh ML Kit từ chối khi đang dùng mobile data.
    return _modelManager.downloadModel(bcpCode, isWifiRequired: false);
  }

  Future<bool> deleteModel(String bcpCode) =>
      _modelManager.deleteModel(bcpCode);

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    final source = sourceLang.trim().toUpperCase();
    final target = targetLang.trim().toUpperCase();

    if (!platformSupported) {
      return TranslationResult.failure(
        original: text,
        error: 'ML Kit chỉ chạy trên Android/iOS',
        engine: name,
        detectedLang: source,
        targetLang: target,
      );
    }
    if (source.isEmpty || source == 'AUTO') {
      // OnDeviceTranslator không có source "auto" — service luôn truyền
      // ngôn ngữ nguồn đã detect/đã chọn.
      return TranslationResult.failure(
        original: text,
        error: 'ML Kit cần ngôn ngữ nguồn xác định (không hỗ trợ auto)',
        engine: name,
        targetLang: target,
      );
    }

    final sourceLangEnum = languageForCode(source);
    final targetLangEnum = languageForCode(target);
    if (sourceLangEnum == null || targetLangEnum == null) {
      return TranslationResult.failure(
        original: text,
        error: 'ML Kit không hỗ trợ cặp $source → $target',
        engine: name,
        detectedLang: source,
        targetLang: target,
      );
    }

    final sourceReady = await isModelDownloaded(sourceLangEnum.bcpCode);
    final targetReady = await isModelDownloaded(targetLangEnum.bcpCode);
    if (!sourceReady || !targetReady) {
      final missing = _nativeNames(<TranslateLanguage>[
        if (!sourceReady) sourceLangEnum,
        if (!targetReady) targetLangEnum,
      ]);
      return TranslationResult.failure(
        original: text,
        error:
            'Chưa tải gói dịch $missing — vào Cài đặt engine dịch để tải về',
        engine: name,
        detectedLang: source,
        targetLang: target,
      );
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLangEnum,
      targetLanguage: targetLangEnum,
    );
    final stopwatch = Stopwatch()..start();
    try {
      final translated = await translator.translateText(text);
      stopwatch.stop();
      if (translated.trim().isEmpty) {
        return TranslationResult.failure(
          original: text,
          error: 'ML Kit trả về kết quả rỗng',
          engine: name,
          detectedLang: source,
          targetLang: target,
        );
      }
      return TranslationResult.success(
        original: text,
        translated: translated,
        engine: name,
        responseTime: stopwatch.elapsed,
        detectedLang: source,
        targetLang: target,
      );
    } catch (e) {
      debugPrint('❌ ML Kit translate: $e');
      return TranslationResult.failure(
        original: text,
        error: 'Lỗi ML Kit: $e',
        engine: name,
        detectedLang: source,
        targetLang: target,
      );
    } finally {
      await translator.close().catchError((_) {});
    }
  }

  String _nativeNames(List<TranslateLanguage> languages) {
    final names = <String>[];
    for (final language in languages) {
      switch (language) {
        case TranslateLanguage.english:
          names.add('English');
          break;
        case TranslateLanguage.vietnamese:
          names.add('Vietnamese');
          break;
        case TranslateLanguage.hindi:
          names.add('Hindi');
          break;
        default:
          names.add(language.name);
      }
    }
    return names.join(', ');
  }
}
