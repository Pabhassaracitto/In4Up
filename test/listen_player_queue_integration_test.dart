import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_queue_item.dart';
import 'package:in4up/models/playback_state.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/screens/listen_mode/services/recent_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_queue_player.dart';

AudioQueueItem track(String name) => AudioQueueItem(
      source: 'https://example.test/$name.mp3',
      title: name,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeQueueAudio audio;
  late FakeQueueStorage storage;
  late PlayerProvider player;
  var playerDisposed = false;

  Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

  Future<void> settleQueue() async {
    // Completion/error events are delivered asynchronously by the audio port.
    await flushEvents();
    await player.queueIdle;
    await flushEvents();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final recent = RecentAudioService();
    recent.invalidateCache();
    await recent.clearAll();
    audio = FakeQueueAudio();
    storage = FakeQueueStorage();
    playerDisposed = false;
    player = PlayerProvider(
      audioService: audio,
      storage: storage,
      initializeSttService: false,
      loadCachedLrc: false,
    );
  });

  tearDown(() async {
    if (!playerDisposed) player.dispose();
    await Future<void>.delayed(Duration.zero);
    await RecentAudioService().clearAll();
  });

  test('completion advances once from zero and stops at the last item', () async {
    final a = track('a');
    final b = track('b');
    storage.positions[b.source] = 43000;
    expect(await player.startQueue([a, b]), isTrue);
    expect(audio.plays, [a.source]);
    await flushEvents();
    audio.complete();
    audio.complete(); // duplicate event must not advance twice
    await settleQueue();
    expect(player.queueIndex, 1);
    expect(player.currentSongPath, b.source);
    expect(audio.currentState.position, Duration.zero);
    expect(audio.plays, [a.source, b.source]);
    audio.complete();
    await settleQueue();
    expect(player.queueIndex, 1);
    expect(player.canGoNextTrack, isFalse);
    expect(player.wantsPlayback, isFalse);
    expect(audio.plays, [a.source, b.source]);
  });

  test('manual neighbours preserve paused/playing state and save outgoing progress', () async {
    final a = track('a');
    final b = track('b');
    await player.startQueue([a, b], autoPlay: false);
    expect(audio.plays, isEmpty);
    audio.position(const Duration(seconds: 31));
    await flushEvents();
    await player.nextTrack();
    expect(storage.positions[a.source], 31000);
    expect(player.queueIndex, 1);
    expect(player.wantsPlayback, isFalse);
    expect(audio.plays, isEmpty);
    expect(audio.currentState.position, Duration.zero);

    await player.play();
    await player.previousTrack();
    expect(player.queueIndex, 0);
    expect(audio.currentState.position, Duration.zero);
    expect(audio.plays, [b.source, a.source]);

    // Explicitly reopening the same source restores progress without losing the queue.
    await player.loadSong(path: a.source, autoPlay: false);
    expect(player.queueItems.length, 2);
    expect(audio.currentState.position, const Duration(seconds: 31));
    expect(audio.currentState.status, PlaybackStatus.paused);
  });

  test('reopening waits for an in-flight position save before resuming', () async {
    final a = track('a');
    await player.startQueue([a], autoPlay: false);
    audio.position(const Duration(seconds: 31));
    await flushEvents();
    final gate = Completer<void>();
    final entered = Completer<void>();
    storage.savePositionGate = gate;
    storage.savePositionEntered = entered;
    final reopening = player.loadSong(path: a.source, autoPlay: false);
    await entered.future;
    expect(audio.loads, [a.source]); // second load has not begun
    gate.complete();
    expect(await reopening, isTrue);
    expect(audio.currentState.position, const Duration(seconds: 31));
  });

  test('another direct source replaces the queue; explicit recent position precedes play', () async {
    final a = track('a');
    final b = track('b');
    final c = track('c');
    await player.startQueue([a, b]);
    await player.loadSong(
      path: c.source,
      title: c.title,
      autoPlay: true,
      initialPosition: const Duration(seconds: 27),
    );
    expect(player.queueItems.map((item) => item.source), [c.source]);
    expect(player.canGoNextTrack, isFalse);
    expect(audio.seeks.last, const Duration(seconds: 27));
    expect(audio.plays.last, c.source);
  });

  test('missing and decoder failures are bounded and visible', () async {
    final a = track('a');
    final b = track('b');
    final c = track('c');
    audio.failures.add(b.source);
    await player.startQueue([a, b, c]);
    await flushEvents();
    audio.complete();
    await settleQueue();
    expect(player.queueIndex, 2);
    expect(player.queueFailedIndices, {1});
    expect(audio.loads, [a.source, b.source, c.source]);
    expect(audio.plays, [a.source, c.source]);

    audio.playbackError();
    await settleQueue();
    expect(player.queueFailedIndices, {1, 2});
    expect(player.wantsPlayback, isFalse);
  });

  test('a missing local source is not replaced by a same-named import', () async {
    const missing = AudioQueueItem(source: '/definitely-missing/lesson.mp3', title: 'Missing');
    final available = track('available');
    expect(await player.startQueue([missing, available], skipFailures: true), isTrue);
    expect(player.queueFailedIndices, {0});
    expect(player.queueIndex, 1);
    expect(audio.loads, [available.source]);
  });

  test('pause during a pending load does not resume the new track', () async {
    final a = track('a');
    final b = track('b');
    await player.startQueue([a, b]);
    final gate = Completer<void>();
    final entered = Completer<void>();
    audio.waits[b.source] = gate;
    audio.entered[b.source] = entered;
    final pending = player.nextTrack();
    await entered.future;
    await player.pause();
    gate.complete();
    expect(await pending, isTrue);
    expect(player.currentSongPath, b.source);
    expect(player.wantsPlayback, isFalse);
    expect(audio.plays, [a.source]);
    expect(audio.currentState.status, PlaybackStatus.paused);
  });

  test('stop invalidates and waits for an in-flight load', () async {
    final a = track('a');
    final b = track('b');
    await player.startQueue([a, b]);
    final gate = Completer<void>();
    final entered = Completer<void>();
    audio.waits[b.source] = gate;
    audio.entered[b.source] = entered;
    final pending = player.nextTrack();
    await entered.future;
    final stopped = player.stop();
    gate.complete();
    expect(await pending, isFalse);
    await stopped;
    expect(audio.plays, [a.source]);
    expect(audio.stops, 1);
    expect(player.wantsPlayback, isFalse);
    expect(player.queueItems.length, 2);
  });

  test('a newer queue request is not stopped by an older stop', () async {
    final a = track('a');
    final b = track('b');
    final c = track('c');
    await player.startQueue([a, b]);
    final gate = Completer<void>();
    final entered = Completer<void>();
    audio.waits[b.source] = gate;
    audio.entered[b.source] = entered;
    final oldLoad = player.nextTrack();
    await entered.future;
    final oldStop = player.stop();
    final replacement = player.startQueue([c]);
    gate.complete();
    expect(await oldLoad, isFalse);
    await oldStop;
    expect(await replacement, isTrue);
    expect(audio.stops, 0);
    expect(player.currentSongPath, c.source);
    expect(audio.plays.last, c.source);
  });

  test('finite track repeat completes before the next queue item', () async {
    final a = track('a');
    final b = track('b');
    await player.startQueue([a, b]);
    await flushEvents();
    player.setLoopCount(2);
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(player.queueIndex, 0);
    expect(audio.plays, [a.source, a.source]);
    audio.complete();
    await Future<void>.delayed(Duration.zero);
    await settleQueue();
    expect(player.queueIndex, 1);
    expect(audio.plays.last, b.source);
  });

  test('A–B loop has priority and pausing a gap never restarts it', () async {
    final a = track('a');
    final b = track('b');
    await player.startQueue([a, b]);
    player.setLoop(const Duration(seconds: 10), const Duration(seconds: 20),
        gapSeconds: .04, startImmediately: false);
    await flushEvents();
    audio.position(const Duration(seconds: 21));
    await flushEvents();
    expect(player.isWaitingGap, isTrue);
    await player.pause();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(player.queueIndex, 0);
    expect(audio.plays, [a.source]);
    expect(player.wantsPlayback, isFalse);
    await player.play();
    expect(audio.seeks.last, const Duration(seconds: 10));
  });

  test('disposing while loading never starts the stale source', () async {
    final a = track('a');
    final b = track('b');
    await player.startQueue([a, b]);
    final gate = Completer<void>();
    final entered = Completer<void>();
    audio.waits[b.source] = gate;
    audio.entered[b.source] = entered;
    final pending = player.nextTrack();
    await entered.future;
    player.dispose();
    playerDisposed = true;
    gate.complete();
    expect(await pending, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(audio.plays, [a.source]);
    expect(audio.disposed, isTrue);
  });
}
