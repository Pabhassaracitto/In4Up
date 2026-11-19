import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in4up/features/tts/reader_voice_preference.dart';
import 'package:in4up/features/tts/tts_candidate_router.dart';
import 'package:in4up/features/tts/tts_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const engines = <TtsEngineInfo>[
    TtsEngineInfo(
      id: 'piper_tts',
      name: 'Piper',
      description: 'offline neural',
      isOnline: false,
      priority: 0,
    ),
    TtsEngineInfo(
      id: 'offline_tts',
      name: 'System voice',
      description: 'offline',
      isOnline: false,
      priority: 1,
    ),
    TtsEngineInfo(
      id: 'edge_tts',
      name: 'Microsoft Edge TTS',
      description: 'online neural',
      priority: 2,
    ),
    TtsEngineInfo(
      id: 'google_tts',
      name: 'Google TTS',
      description: 'online',
      priority: 3,
    ),
  ];

  List<String> ids(TtsPriority priority, {String? preferredEngineId}) =>
      orderTtsCandidates(
        engines: engines,
        priority: priority,
        preferredEngineId: preferredEngineId,
      ).map((engine) => engine.id).toList();

  test('default offline-first keeps the existing engine groups', () {
    expect(ids(TtsPriority.offlineFirst), [
      'piper_tts',
      'offline_tts',
      'edge_tts',
      'google_tts',
    ]);
  });

  test('an explicitly selected Edge voice makes Edge the first attempt', () {
    expect(
      ids(TtsPriority.offlineFirst, preferredEngineId: 'edge_tts'),
      ['edge_tts', 'piper_tts', 'offline_tts', 'google_tts'],
    );
  });

  test('online-first and offline-only remain authoritative', () {
    expect(ids(TtsPriority.onlineFirst), [
      'edge_tts',
      'google_tts',
      'piper_tts',
      'offline_tts',
    ]);
    expect(
      ids(TtsPriority.offlineOnly, preferredEngineId: 'edge_tts'),
      ['piper_tts', 'offline_tts'],
    );
  });

  test('disabled preferred engine is never reintroduced', () {
    final disabled = engines
        .map((engine) => engine.id == 'edge_tts'
            ? engine.copyWith(isEnabled: false)
            : engine)
        .toList();
    expect(
      orderTtsCandidates(
        engines: disabled,
        priority: TtsPriority.offlineFirst,
        preferredEngineId: 'edge_tts',
      ).map((engine) => engine.id).toList(),
      ['piper_tts', 'offline_tts', 'google_tts'],
    );
  });

  test('reader preference survives reload; reset resumes live inheritance',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (final reader in TtsReader.values) {
      expect(ReaderVoicePreference.load(prefs, reader), isNull);
    }
    await ReaderVoicePreference.save(
        prefs,
        TtsReader.pdf,
        const ReaderVoicePreference('piper_tts',
            voice: 'alan', locale: 'en-GB'));
    await prefs.reload();
    final pdf = ReaderVoicePreference.load(prefs, TtsReader.pdf)!;
    expect(pdf.engine, 'piper_tts');
    expect(pdf.voiceFor('piper_tts', 'en-US'), 'alan');
    expect(pdf.voiceFor('piper_tts', 'vi-VN'), isNull);
    expect(pdf.voiceFor('edge_tts', 'en-GB'), isNull);
    expect(ReaderVoicePreference.load(prefs, TtsReader.web), isNull);
    await ReaderVoicePreference.save(prefs, TtsReader.pdf, null);
    await prefs.reload();
    expect(ReaderVoicePreference.load(prefs, TtsReader.pdf), isNull);
  });

  test('local engine first, then shared Edge voice and enabled fallback order',
      () async {
    final route = orderTtsCandidates(
        engines: engines,
        priority: TtsPriority.offlineFirst,
        preferredEngineId: 'edge_tts',
        readerEngineId: 'offline_tts');
    final attempts = <String>[];
    expect(
        await playFirstAvailable(route,
            cancelled: () => false,
            play: (engine) async {
              attempts.add(engine.id);
              return engine.id == 'piper_tts';
            }),
        isTrue);
    expect(attempts, ['offline_tts', 'edge_tts', 'piper_tts']);
  });

  test(
      'offline-only permits local system override but not a local online engine',
      () {
    for (final choice in ['offline_tts', 'edge_tts']) {
      final route = orderTtsCandidates(
          engines: engines,
          priority: TtsPriority.offlineOnly,
          readerEngineId: choice);
      expect(route.first.id, choice == 'offline_tts' ? choice : 'piper_tts');
      expect(route.any((e) => e.isOnline), isFalse);
    }
  });

  test('no enabled engine: no forced system fallback', () async {
    final route = orderTtsCandidates(
        engines: engines.map((e) => e.copyWith(isEnabled: false)),
        priority: TtsPriority.offlineFirst,
        readerEngineId: 'piper_tts');
    expect(
        await playFirstAvailable(route,
            cancelled: () => false,
            play: (_) async => fail('nothing is enabled')),
        isFalse);
  });
}
