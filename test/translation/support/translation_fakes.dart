import 'dart:async';

import 'package:flutter/foundation.dart';
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

  @override
  Future<bool> isAvailable() async => available;

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
