import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/services/lrc_ab_suggestions.dart';
import 'package:in4up/features/shadowing/services/shadowing_sample_player.dart';
import 'package:in4up_stt/stt_lrc_converter.dart' show LrcLine;

class _FakeSampleAudio implements ShadowingSampleAudio {
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(seconds: 60);
  Duration? loadedDuration = const Duration(seconds: 60);
  Future<Duration?> Function(int call)? onLoad;
  Future<void> Function()? onPlay;
  final loads = <String>[];
  final seeks = <Duration>[];
  final speeds = <double>[];
  int plays = 0;
  int stops = 0;
  int pauses = 0;

  @override
  Future<Duration?> setFilePath(String path) async {
    loads.add(path);
    if (onLoad != null) return onLoad!(loads.length);
    return loadedDuration;
  }

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    this.position = position;
  }

  @override
  Future<void> play() async {
    plays++;
    if (onPlay != null) {
      await onPlay!();
    } else {
      position += const Duration(seconds: 30);
    }
  }

  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> stop() async => stops++;
}

void main() {
  final sentences = LrcAbSuggestions.buildSentenceSuggestions(
    lines: [
      for (var i = 0; i < 12; i++)
        LrcLine(
          timestamp: Duration(seconds: i * 5),
          text: 'Sentence $i.',
        ),
    ],
    trackDuration: const Duration(seconds: 60),
  );

  ShadowingSamplePlayer build(_FakeSampleAudio audio) =>
      ShadowingSamplePlayer(audio: audio, sourceExists: (_) => true)
        ..configure(audioPath: 'lesson.mp3', sentences: sentences);

  test('speakSentence(2) selects only sentence #3 and plays it once', () async {
    final audio = _FakeSampleAudio();
    final player = build(audio);
    addTearDown(player.dispose);
    final repeats = <int>[];
    var finished = 0;
    await player.speakSentence(
      2,
      speed: 0.8,
      onRepeat: repeats.add,
      onFinished: () => finished++,
    );

    expect(player.selectedSentence!.text, 'Sentence 2.');
    expect(audio.loads, ['lesson.mp3']);
    expect(audio.seeks, [const Duration(seconds: 10), const Duration(seconds: 15)]);
    expect(audio.speeds, [0.8]);
    expect(audio.plays, 1);
    expect(repeats, [1]);
    expect(finished, 1);
    expect(audio.stops, greaterThanOrEqualTo(1));
  });

  test('ten rapid sentence changes: only the newest load may play', () async {
    final audio = _FakeSampleAudio();
    final gate = Completer<Duration?>();
    audio.onLoad = (_) => gate.future;
    final player = build(audio);
    addTearDown(player.dispose);
    final futures = [for (var i = 0; i < 10; i++) player.speakSentence(i)];
    await Future<void>.delayed(Duration.zero);
    expect(audio.loads, ['lesson.mp3']);
    expect(audio.plays, 0);
    gate.complete(const Duration(seconds: 60));
    await Future.wait(futures);

    expect(player.selectedIndex, 9);
    expect(player.selectedSentence!.text, 'Sentence 9.');
    expect(audio.plays, 1);
    expect(audio.seeks, [const Duration(seconds: 45), const Duration(seconds: 50)]);
  });

  test('a stale load failure cannot stop or report on the current sample', () async {
    final audio = _FakeSampleAudio();
    final stale = Completer<Duration?>();
    audio.onLoad = (call) => call == 1 ? stale.future : Future.value(const Duration(seconds: 60));
    final player = build(audio);
    addTearDown(player.dispose);
    final errors = <String>[];
    final old = player.speakSentence(0, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
    await player.speakSentence(1, onError: errors.add);
    final stopsAfterNewSample = audio.stops;
    stale.completeError(StateError('old source failed'));
    await old;

    expect(errors, isEmpty);
    expect(audio.stops, stopsAfterNewSample);
    expect(player.selectedIndex, 1);
  });

  test('stop during play invalidates the remaining repetitions', () async {
    final audio = _FakeSampleAudio();
    final gate = Completer<void>();
    final entered = Completer<void>();
    audio.onPlay = () {
      if (!entered.isCompleted) entered.complete();
      return gate.future;
    };
    final player = build(audio);
    addTearDown(player.dispose);
    var finished = 0;
    final future = player.playOriginal(
      start: Duration.zero,
      end: const Duration(seconds: 5),
      repeatCount: 3,
      onFinished: () => finished++,
    );
    await entered.future;
    await player.stop();
    gate.complete();
    await future;
    expect(audio.plays, 1);
    expect(finished, 0);
  });

  test('missing position ticks still hit the bounded-sample deadline', () async {
    final audio = _FakeSampleAudio()..onPlay = () async {};
    final player = build(audio);
    addTearDown(player.dispose);
    var finished = 0;
    await player.playOriginal(
      start: Duration.zero,
      end: const Duration(milliseconds: 100),
      onFinished: () => finished++,
    );
    expect(finished, 1);
    expect(audio.pauses, 1);
    expect(audio.seeks.last, const Duration(milliseconds: 100));
  });

  test('invalid and out-of-range indices never start audio', () async {
    final audio = _FakeSampleAudio();
    final player = build(audio);
    addTearDown(player.dispose);
    await player.speakSentence(-1);
    await player.speakSentence(sentences.length);
    expect(audio.loads, isEmpty);
    expect(audio.plays, 0);
  });

  test('a zero-length lyric interval is not expanded into the next sentence', () async {
    final audio = _FakeSampleAudio();
    final player = ShadowingSamplePlayer(audio: audio, sourceExists: (_) => true)
      ..configure(
        audioPath: 'tight.mp3',
        sentences: LrcAbSuggestions.buildSentenceSuggestions(lines: [
          LrcLine(timestamp: const Duration(seconds: 10), text: 'A'),
          LrcLine(timestamp: const Duration(seconds: 10), text: 'B'),
          LrcLine(timestamp: const Duration(seconds: 20), text: 'C'),
        ]),
      );
    addTearDown(player.dispose);
    final errors = <String>[];
    await player.speakSentence(0, onError: errors.add);
    expect(errors, ['invalid_range']);
    expect(audio.plays, 0);
    await player.speakSentence(1);
    expect(player.selectedSentence!.text, 'B');
    expect(audio.seeks, [const Duration(seconds: 10), const Duration(seconds: 20)]);
  });

  test('missing files report an error without loading the player', () async {
    final audio = _FakeSampleAudio();
    final player = ShadowingSamplePlayer(audio: audio, sourceExists: (_) => false)
      ..configure(audioPath: 'deleted.mp3', sentences: sentences);
    addTearDown(player.dispose);
    final errors = <String>[];
    await player.speakSentence(0, onError: errors.add);
    expect(errors, ['file_missing']);
    expect(audio.loads, isEmpty);
  });
}
