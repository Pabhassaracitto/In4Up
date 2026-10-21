import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/tts_candidate_router.dart';
import 'package:in4up/features/tts/tts_settings.dart';

void main() {
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
}
