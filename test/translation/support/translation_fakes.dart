import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up/features/translation/engines/llm_mt_engine.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';
import 'package:in4up/features/translation/text_provider_translation.dart';
import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/models/text_item.dart';

class RecordingTranslationEngine extends TranslationEngine {
  RecordingTranslationEngine(this.id,
      {this.succeeds = true, this.available = true});

  @override
  final String id;
  @override
  String get name => switch (id) {
        'google_free' => 'Google Translate',
        'mlkit' => 'ML Kit On-Device',
        'offline' => 'Offline Dictionary',
        _ => id,
      };
  bool succeeds;
  bool available;
  bool throwError = false;
  bool echoSource = false;
  int calls = 0;
  List<String>? missingModels;
  final List<String> log = [];
  Future<void>? waitFor;
  void Function()? onCall;
  Future<void>? availabilityWaitFor;
  void Function()? onAvailabilityCheck;

  @override
  Future<bool> isAvailable() async {
    onAvailabilityCheck?.call();
    await availabilityWaitFor;
    return available;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    calls++;
    log.add('$sourceLang>$targetLang:$text');
    onCall?.call();
    await waitFor;
    if (throwError) throw StateError('engine exception');
    return succeeds
        ? TranslationResult.success(
            original: text,
            translated: echoSource ? text : 'Bản dịch $id.',
            engine: name,
            detectedLang: sourceLang,
            targetLang: targetLang,
          )
        : TranslationResult.failure(
            original: text,
            error: 'model unavailable',
            errorCode: 'missing_models',
            missingModelCodes: missingModels,
            engine: name,
          );
  }
}

class TranslationTestDocument extends ChangeNotifier with TranslationMixin {
  @override
  final List<TextItem> lines = [];

  Future<void> prepare(TranslationService service, {int count = 1}) async {
    translationServiceForTest = service;
    restoreTranslationTargetLanguage('VI');
    await setTranslationSourceLanguage('EN', retranslateExisting: false);
    lines.addAll(List.generate(
        count,
        (index) => TextItem(
              id: '$index',
              content: 'Hello world, this is sentence number $index.',
            )));
  }
}

TranslationService translationTestService({
  RecordingTranslationEngine? google,
  RecordingTranslationEngine? mlkit,
  RecordingTranslationEngine? dictionary,
  bool network = true,
}) =>
    TranslationService.forTest(
      onlineEngines: [if (google != null) google],
      mlkitEngine: mlkit ??
          RecordingTranslationEngine('mlkit',
              succeeds: false, available: false),
      offlineEngine:
          dictionary ?? RecordingTranslationEngine('offline', succeeds: false),
      networkAvailable: network,
    );

/// Exercise the real LLM engine's availability/policy gates without network,
/// credentials or registering a provider in application settings.
class TranslationTestLlmEnv implements LlmMtEnv {
  TranslationTestLlmEnv({this.mode = AiRouteMode.onlineFirst});
  AiRouteMode mode;
  AiProviderConfig? provider = const AiProviderConfig(
    id: 'translation-test',
    label: 'Test server',
    baseUrl: 'http://192.168.1.10:11434/v1',
    translationModel: 'test-mt',
  );

  @override
  Future<AiProviderConfig?> resolveProvider() async =>
      mode == AiRouteMode.offlineOnly ? null : provider;
  @override
  Future<AiRouteMode> routeMode() async => mode;
  @override
  Future<bool> hasNetwork() async => true;
}

class TranslationTestLlmBackend implements LlmMtBackend {
  int calls = 0;
  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required Duration timeout,
  }) async {
    calls++;
    return 'Bản dịch LLM.';
  }
}
