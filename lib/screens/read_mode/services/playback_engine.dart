import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/playback_anchor.dart';
import '../models/playback_event.dart';
import '../models/playback_recipe.dart';
import '../models/playback_run_token.dart';
import '../models/playback_snapshot.dart';
import '../models/text_line.dart';
import 'tts_service.dart';

typedef EngineError = ({String message, Object? cause});

class PlaybackEngine {
  final TtsService tts;
  bool _cancel = false;

  PlaybackEngine(this.tts);

  Future<void> play({
    required PlaybackRunToken token,
    required List<TextLine> lines,
    required PlaybackRecipe recipe,
    required void Function(PlaybackEvent) onEvent,
    required VoidCallback onDone,
    required void Function(EngineError) onError,
    PlaybackAnchor? resumeFrom,
  }) async {
    _cancel = false;

    try {
      await tts.setSpeechRate(recipe.speed);

      final total      = lines.length;
      final passes     = recipe.totalPasses;
      int   startLine  = resumeFrom?.lineIndex ?? 0;
      int   pass       = 0;

      while (!_cancel && (passes == 0 || pass < passes)) {
        final fromLine = pass == 0 ? startLine : 0;

        for (int i = fromLine; i < total; i++) {
          final fromLR = (pass == 0 && i == startLine)
              ? (resumeFrom?.lineRepeatIndex ?? 0)
              : 0;

          for (int lr = fromLR; lr < recipe.lineRepeats; lr++) {
            if (_cancel) return;

            // ── lineStart event ─────────────────────────────
            onEvent(PlaybackEvent(
              type:     PlaybackEventType.lineStart,
              snapshot: _snap(i, total, pass, recipe, lr, true),
            ));

            // ── EN phase ────────────────────────────────────
            if (recipe.mode != PlaybackMode.viOnly) {
              for (int e = 0; e < recipe.enRepeats; e++) {
                if (_cancel) return;
                onEvent(PlaybackEvent(
                  type:     PlaybackEventType.phase,
                  snapshot: _snap(i, total, pass, recipe, lr, true),
                ));
                await tts.speak(lines[i].content);
              }
            }

            // ── Rhythm Gap + language switch ─────────────────
            final hasVI = recipe.mode != PlaybackMode.enOnly &&
                (lines[i].translation?.isNotEmpty ?? false);

            if (!_cancel &&
                recipe.mode == PlaybackMode.interleaved &&
                hasVI) {
              onEvent(PlaybackEvent(
                type:     PlaybackEventType.languageSwitch,
                snapshot: _snap(i, total, pass, recipe, lr, false),
              ));
              await Future.delayed(
                Duration(milliseconds: recipe.silenceGap.ms),
              );
            }

            // ── VI phase ─────────────────────────────────────
            if (!_cancel && recipe.mode != PlaybackMode.enOnly && hasVI) {
              for (int v = 0; v < recipe.viRepeats; v++) {
                if (_cancel) return;
                onEvent(PlaybackEvent(
                  type:     PlaybackEventType.phase,
                  snapshot: _snap(i, total, pass, recipe, lr, false),
                ));
                await tts.speak(lines[i].translation!);
              }
            }
          }
          if (_cancel) return;
        }
        pass++;
        startLine = 0;
      }

      onDone();
    } catch (e, st) {
      debugPrint('[PlaybackEngine] error: $e\n$st');
      onError((message: 'Playback failed', cause: e));
    }
  }

  Future<void> updateSpeed(double speed) async {
    await tts.setSpeechRate(speed.clamp(0.5, 2.0));
  }

  void stop() {
    _cancel = true;
    tts.stop();
  }

  // ── Helper ──────────────────────────────────────────────
  PlaybackSnapshot _snap(
    int line, int total, int pass,
    PlaybackRecipe r, int lr, bool isEN,
  ) =>
      PlaybackSnapshot(
        line:             line,
        totalLines:       total,
        pass:             pass,
        totalPasses:      r.totalPasses,
        lineRepeat:       lr,
        totalLineRepeats: r.lineRepeats,
        isEN:             isEN,
        enRepeats:        r.enRepeats,
        viRepeats:        r.viRepeats,
      );
}
