import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/tts_service.dart';
import 'package:in4up/features/tts/engines/edge_tts_engine.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/screens/tools/word_list/wordlist_playback_service.dart';
import 'package:in4up/screens/tools/word_list/wordlist_read_sequence.dart';
import 'package:shared_preferences/shared_preferences.dart';

WordEntry _word(String word, String meaning, {String language = 'en'}) =>
    WordEntry(id: word, word: word, meaning: meaning, language: language);

const _settings = WordlistReadSettings(
  wordRepeats: 1,
  meaningRepeats: 1,
  gapBetweenSidesMs: 0,
  gapBetweenRepeatsMs: 0,
  gapBetweenWordsMs: 0,
  meaningLanguage: 'vi',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('single and play all use persisted order and separate languages', () async {
    SharedPreferences.setMockInitialValues({
      'wordlist_read_settings_v1': jsonEncode(_settings.toJson()),
    });
    final calls = <String>[];
    final service = WordlistPlaybackService.test(
      speak: (text, lang) async => calls.add('$text:$lang'),
      stop: () async {},
    );
    final dog = _word('dog', 'con chó');
    await service.playSingle(dog);
    expect(calls, ['dog:en', 'con chó:vi']);
    calls.clear();
    await service.playAll([dog, _word('cat', 'mèo')]);
    expect(calls, ['dog:en', 'con chó:vi', 'cat:en', 'mèo:vi']);
    service.dispose();
  });

  test('meaning first, auto detection and missing meaning', () async {
    final calls = <String>[];
    final service = WordlistPlaybackService.test(
      speak: (text, lang) async => calls.add('$text:$lang'),
      stop: () async {},
    );
    await service.updateReadSettings(_settings.copyWith(
        mode: WordlistReadMode.meaningThenWord, meaningLanguage: 'auto'));
    await service.playAll([_word('dog', 'chó'), _word('cat', '')]);
    expect(calls, ['chó:auto', 'dog:en', 'cat:en']);
    service.dispose();
  });

  test('new single cancels list; stale completion cannot reset new run', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    final startedFirst = Completer<void>();
    final startedSecond = Completer<void>();
    final calls = <String>[];
    final service = WordlistPlaybackService.test(
      speak: (text, lang) {
        calls.add(text);
        if (text == 'dog') {
          startedFirst.complete();
          return first.future;
        }
        if (text == 'cat') {
          startedSecond.complete();
          return second.future;
        }
        return Future.value();
      },
      stop: () async {},
    );
    await service.updateReadSettings(_settings);
    final list = service.playAll([_word('dog', 'chó'), _word('bird', 'chim')]);
    await startedFirst.future;
    final single = service.playSingle(_word('cat', 'mèo'));
    first.complete();
    await startedSecond.future;
    await list;
    expect(service.isPlaying, isTrue);
    expect(service.currentWord?.word, 'cat');
    second.complete();
    await single;
    expect(calls, ['dog', 'cat', 'mèo']);
    expect(service.isPlaying, isFalse);
    service.dispose();
  });

  test('stop invalidates the remaining sequence and allows a fresh run', () async {
    final first = Completer<void>();
    final started = Completer<void>();
    final calls = <String>[];
    final service = WordlistPlaybackService.test(
      speak: (text, lang) {
        calls.add(text);
        if (text == 'dog') {
          started.complete();
          return first.future;
        }
        return Future.value();
      },
      stop: () async {},
    );
    await service.updateReadSettings(_settings);
    final oldRun = service.playAll([_word('dog', 'chó')]);
    await started.future;
    final stopping = service.stopPlayback();
    expect(service.isPlaying, isFalse);
    first.complete();
    await stopping;
    await oldRun;
    await service.playSingle(_word('cat', 'mèo'));
    expect(calls, ['dog', 'cat', 'mèo']);
    service.dispose();
  });

  test('voice language matching rejects pinned Vietnamese voice for English', () {
    expect(TtsService.voiceMatchesLanguage('vi-VN-HoaiMyNeural', 'en-US'), isFalse);
    expect(TtsService.voiceMatchesLanguage('en-GB-RyanNeural', 'en-US'), isTrue);
  });

  test('Wordlist voice resolution keeps Edge cache identity language matched', () {
    const viVoice = 'vi-VN-HoaiMyNeural';
    const enVoice = 'en-US-GuyNeural';
    String? resolve({String? override, String? selected, bool strict = true}) =>
        TtsService.resolveOnlineVoice(
          engineId: 'edge_tts',
          language: 'en-US',
          voiceOverride: override,
          selectedVoiceId: selected,
          matchVoiceLanguage: strict,
        );
    expect(resolve(selected: viVoice), EdgeTtsEngine.defaultVoiceForLanguage('en-US'));
    expect(resolve(override: viVoice), EdgeTtsEngine.defaultVoiceForLanguage('en-US'));
    expect(resolve(override: enVoice, selected: viVoice), enVoice);
    expect(resolve(selected: viVoice, strict: false), viVoice);
    expect(TtsService.resolveOnlineVoice(
      engineId: 'google_tts', language: 'en-US', selectedVoiceId: viVoice,
      matchVoiceLanguage: true,
    ), isNull);
    expect(TtsService.resolveOnlineVoice(
      engineId: 'google_tts', language: 'en-US', selectedVoiceId: viVoice,
    ), viVoice);
  });

  test('Edge synthesis speed is not applied a second time by player', () {
    expect(TtsService.onlinePlaybackSpeed('edge_tts', 0.82), 1.0);
    expect(TtsService.onlinePlaybackSpeed('google_tts', 0.82), 0.82);
  });

}
