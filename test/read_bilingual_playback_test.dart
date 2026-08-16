import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/text_item.dart';
import 'package:in4up/screens/read_mode/models/playback_anchor.dart';
import 'package:in4up/screens/read_mode/models/playback_recipe.dart';
import 'package:in4up/screens/read_mode/models/playback_run_token.dart';
import 'package:in4up/screens/read_mode/services/playback_controller.dart';
import 'package:in4up/screens/read_mode/services/playback_engine.dart';
import 'package:in4up/screens/read_mode/services/tts_notification_service.dart';
import 'package:in4up/screens/read_mode/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends TtsNotificationService {
  final List<({String title, String subtitle})> activations = [];
  final List<({String title, String subtitle})> updates = [];
  var deactivateCount = 0;

  @override
  Future<void> activate({
    required String title,
    required String subtitle,
  }) async {
    activations.add((title: title, subtitle: subtitle));
  }

  @override
  Future<void> updateNotification({
    required String title,
    required String subtitle,
  }) async {
    updates.add((title: title, subtitle: subtitle));
  }

  @override
  Future<void> deactivate() async {
    deactivateCount++;
  }
}

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

  testWidgets(
      'context-free playback notifications use the selected UI locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tts = _FakeTtsService();
    final notification = _FakeNotificationService();
    final controller = PlaybackController(
      PlaybackEngine(tts),
      prefs,
      notification,
      () => 'en-US',
    );
    addTearDown(controller.dispose);

    await controller.start(
      [
        TextItem(
          id: '1',
          content: 'Hello',
          sourceLanguageCode: 'EN',
        ),
      ],
      fileId: 'file-1',
      sourceLanguageCode: 'EN',
      targetLanguageCode: 'VI',
      anchor: PlaybackAnchor(
        fileId: 'file-1',
        lineIndex: 0,
        lineRepeatIndex: 0,
        savedAt: DateTime.now(),
      ),
    );
    await tester.pump();

    expect(notification.activations, hasLength(1));
    expect(notification.activations.single.title, 'In4Up is playing');
    expect(
      notification.activations.single.subtitle,
      'Continue from sentence 1',
    );

    expect(notification.updates, isNotEmpty);
    expect(notification.updates.first.title, 'Sentence 1/1');
    expect(notification.updates.first.subtitle, contains('Sentence 1/1'));
    expect(notification.updates.first.subtitle, contains('Round 1/1'));
    expect(notification.updates.first.subtitle, isNot(contains('Câu')));
    expect(notification.updates.first.subtitle, isNot(contains('Vòng')));
  });
}
