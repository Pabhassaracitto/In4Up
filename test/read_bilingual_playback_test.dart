import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in2up/models/text_item.dart';
import 'package:in2up/screens/read_mode/models/playback_recipe.dart';
import 'package:in2up/screens/read_mode/models/playback_run_token.dart';
import 'package:in2up/screens/read_mode/services/playback_engine.dart';
import 'package:in2up/screens/read_mode/services/tts_service.dart';

class _FakeTtsService implements TtsService {
  final List<String> actions = [];
  String activeLocale = '';

  @override
  Future<void> setLanguage(String locale) async {
    activeLocale = locale;
    actions.add('language:$locale');
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    actions.add('rate:$rate');
  }

  @override
  Future<void> speak(String text) async {
    actions.add('speak:$activeLocale:$text');
  }

  @override
  void stop() => actions.add('stop');

  @override
  Future<void> dispose() async {}

  @override
  set onComplete(VoidCallback? callback) {}

  @override
  set onError(void Function(String error)? callback) {}

  @override
  set onStart(VoidCallback? callback) {}
}

void main() {
  test('bilingual playback switches source and target voices explicitly',
      () async {
    final tts = _FakeTtsService();
    final engine = PlaybackEngine(tts);
    Object? error;
    var completed = false;

    await engine.play(
      token: const PlaybackRunToken(1),
      lines: [
        TextItem(
          id: '1',
          content: 'Hello',
          translation: 'Bonjour',
          sourceLanguageCode: 'EN',
          translationLanguageCode: 'FR',
        ),
      ],
      recipe: const PlaybackRecipe(
        mode: PlaybackMode.interleaved,
        silenceGap: SilenceGap.relax,
      ),
      sourceLanguageCode: 'EN',
      targetLanguageCode: 'FR',
      onEvent: (_) {},
      onDone: () => completed = true,
      onError: (value) => error = value,
    );

    expect(error, isNull);
    expect(completed, isTrue);
    expect(
      tts.actions,
      containsAllInOrder([
        'language:en-US',
        'speak:en-US:Hello',
        'language:fr-FR',
        'speak:fr-FR:Bonjour',
      ]),
    );
  });

  test('never reads a stale translation tagged for another target', () async {
    final tts = _FakeTtsService();
    final engine = PlaybackEngine(tts);

    await engine.play(
      token: const PlaybackRunToken(2),
      lines: [
        TextItem(
          id: '1',
          content: 'Hello',
          translation: 'Xin chào',
          translationLanguageCode: 'VI',
        ),
      ],
      recipe: PlaybackRecipe.viOnly,
      sourceLanguageCode: 'EN',
      targetLanguageCode: 'FR',
      onEvent: (_) {},
      onDone: () {},
      onError: (_) {},
    );

    expect(tts.actions.where((entry) => entry.startsWith('speak:')), isEmpty);
  });
}
