import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/language/app_language.dart';
import '../../../models/text_item.dart';
import '../models/playback_anchor.dart';
import '../models/playback_event.dart';
import '../models/playback_recipe.dart';
import '../models/playback_run_token.dart';
import '../models/playback_snapshot.dart';
import 'tts_service.dart';

typedef EngineError = ({String message, Object? cause});

class PlaybackEngine {
  final TtsService tts;
  bool _cancel = false;

  PlaybackEngine(this.tts);

  Future<void> play({
    required PlaybackRunToken token,
    required List<TextItem> lines,
    required PlaybackRecipe recipe,
    required String sourceLanguageCode,
    required String targetLanguageCode,
    required void Function(PlaybackEvent) onEvent,
    required VoidCallback onDone,
    required void Function(EngineError) onError,
    PlaybackAnchor? resumeFrom,
  }) async {
    _cancel = false;

    final sourceLanguage = AppLanguageCatalog.fromCode(sourceLanguageCode);
    final targetLanguage = AppLanguageCatalog.fromCode(targetLanguageCode);

    try {
      await tts.setSpeechRate(recipe.speed);

      final total = lines.length;
      final passes = recipe.totalPasses;
      var startLine = resumeFrom?.lineIndex ?? 0;
      var pass = 0;

      while (!_cancel && (passes == 0 || pass < passes)) {
        final fromLine = pass == 0 ? startLine : 0;

        for (var index = fromLine; index < total; index++) {
          final fromRepeat = pass == 0 && index == startLine
              ? resumeFrom?.lineRepeatIndex ?? 0
              : 0;
          final lineSourceLanguage = AppLanguageCatalog.fromCode(
            lines[index].sourceLanguageCode,
            fallback: sourceLanguage,
          );

          for (var lineRepeat = fromRepeat;
              lineRepeat < recipe.lineRepeats;
              lineRepeat++) {
            if (_cancel) return;

            onEvent(PlaybackEvent(
              type: PlaybackEventType.lineStart,
              snapshot: _snapshot(
                index,
                total,
                pass,
                recipe,
                lineRepeat,
                true,
                lineSourceLanguage,
                targetLanguage,
              ),
            ));

            // Original/source phase. Always set the concrete locale before
            // speaking so a voice from the previous phase can never leak.
            if (recipe.mode != PlaybackMode.viOnly && recipe.enRepeats > 0) {
              await tts.setLanguage(lineSourceLanguage.ttsLocale);
              for (var repeat = 0; repeat < recipe.enRepeats; repeat++) {
                if (_cancel) return;
                onEvent(PlaybackEvent(
                  type: PlaybackEventType.phase,
                  snapshot: _snapshot(
                    index,
                    total,
                    pass,
                    recipe,
                    lineRepeat,
                    true,
                    lineSourceLanguage,
                    targetLanguage,
                  ),
                ));
                await tts.speak(lines[index].content);
              }
            }

            final translation = lines[index].translation?.trim() ?? '';
            final storedTarget = lines[index].translationLanguageCode == null
                ? 'VI'
                : AppLanguageCatalog.normalizeTranslationCode(
                    lines[index].translationLanguageCode,
                  );
            final hasCurrentTarget = translation.isNotEmpty &&
                storedTarget == targetLanguage.translationCode;

            final switchesLanguage = recipe.mode != PlaybackMode.enOnly &&
                recipe.mode != PlaybackMode.viOnly &&
                recipe.enRepeats > 0 &&
                recipe.viRepeats > 0;
            if (!_cancel && switchesLanguage && hasCurrentTarget) {
              onEvent(PlaybackEvent(
                type: PlaybackEventType.languageSwitch,
                snapshot: _snapshot(
                  index,
                  total,
                  pass,
                  recipe,
                  lineRepeat,
                  false,
                  lineSourceLanguage,
                  targetLanguage,
                ),
              ));
              await Future<void>.delayed(
                Duration(milliseconds: recipe.silenceGap.ms),
              );
            }

            // Translation/target phase, again with an explicit locale switch.
            // If the user asked for target-only but the line is not translated
            // yet, speak the source so Play is never silent.
            if (!_cancel &&
                recipe.mode != PlaybackMode.enOnly &&
                recipe.viRepeats > 0) {
              if (hasCurrentTarget) {
                await tts.setLanguage(targetLanguage.ttsLocale);
                for (var repeat = 0; repeat < recipe.viRepeats; repeat++) {
                  if (_cancel) return;
                  onEvent(PlaybackEvent(
                    type: PlaybackEventType.phase,
                    snapshot: _snapshot(
                      index,
                      total,
                      pass,
                      recipe,
                      lineRepeat,
                      false,
                      lineSourceLanguage,
                      targetLanguage,
                    ),
                  ));
                  await tts.speak(translation);
                }
              } else if (recipe.mode == PlaybackMode.viOnly) {
                await tts.setLanguage(lineSourceLanguage.ttsLocale);
                await tts.speak(lines[index].content);
              }
            }
          }
          if (_cancel) return;
        }
        pass++;
        startLine = 0;
      }

      onDone();
    } catch (error, stackTrace) {
      debugPrint('[PlaybackEngine] error: $error\n$stackTrace');
      onError((
        message:
            'Không thể phát ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}',
        cause: error,
      ));
    }
  }

  Future<void> updateSpeed(double speed) async {
    await tts.setSpeechRate(speed.clamp(0.5, 2.0));
  }

  void stop() {
    _cancel = true;
    tts.stop();
  }

  PlaybackSnapshot _snapshot(
    int line,
    int total,
    int pass,
    PlaybackRecipe recipe,
    int lineRepeat,
    bool isSource,
    AppLanguage source,
    AppLanguage target,
  ) =>
      PlaybackSnapshot(
        line: line,
        totalLines: total,
        pass: pass,
        totalPasses: recipe.totalPasses,
        lineRepeat: lineRepeat,
        totalLineRepeats: recipe.lineRepeats,
        isEN: isSource,
        enRepeats: recipe.enRepeats,
        viRepeats: recipe.viRepeats,
        sourceLanguageCode: source.translationCode,
        targetLanguageCode: target.translationCode,
      );
}
