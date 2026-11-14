import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_listen_bridge.dart';
import 'package:in4up/screens/listen_mode/services/recent_audio_service.dart';
import 'package:in4up/services/source_artifact_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late CabinSession session;
  late CabinListenBridge bridge;
  final recent = RecentAudioService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    recent.invalidateCache();
    await recent.clearAll();
    root = await Directory.systemTemp.createTemp('cabin_listen_');
    final original = Directory('${root.path}/original');
    await original.create();
    session = CabinSession(
      id: 's1', dirPath: original.path, title: 'Test Cabin',
      createdAt: DateTime(2026), sourceLang: 'en', targetLang: 'vi',
      status: CabinSessionStatus.saved, hasAudio: true,
      duration: const Duration(seconds: 50), entryCount: 50,
    );
    await File(session.audioPath).writeAsBytes([1, 2, 3, 4]);
    await File(session.lrcPath).writeAsString(
      List.generate(50, (i) => '[00:${i.toString().padLeft(2, '0')}.00]line $i').join('\n'),
    );
    bridge = CabinListenBridge(documentsDir: () async => root);
  });
  tearDown(() async {
    recent.invalidateCache();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('copies a saved session with all 50 timed lines and is repeatable', () async {
    final path = await bridge.sync(session);
    expect(path, await bridge.sync(session));
    expect((await recent.getAll()).length, 1);
    expect((await recent.getAll()).single.title, 'Test Cabin');
    final sidecar = File(SourceArtifactStore.sidecarLrcPath(path));
    expect((await sidecar.readAsLines()).length, 50);
    expect((await sidecar.readAsLines()).last, contains('line 49'));
    await Directory(session.dirPath).delete(recursive: true);
    expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
    expect(await sidecar.exists(), isTrue);
  });

  test('missing audio never creates a recent item', () async {
    await File(session.audioPath).delete();
    await expectLater(bridge.sync(session), throwsStateError);
    expect(await recent.getAll(), isEmpty);
  });

  test('audio-only save does not recreate discarded transcript', () async {
    await File(session.lrcPath).delete();
    final path = await bridge.sync(session);
    expect(await File(SourceArtifactStore.sidecarLrcPath(path)).exists(), isFalse);
  });
  test('concurrent syncs publish a single complete snapshot', () async {
    final paths = await Future.wait(List.generate(4, (_) => bridge.sync(session)));
    expect(paths.toSet().length, 1);
    expect((await recent.getAll()).length, 1);
    final sidecar = File(SourceArtifactStore.sidecarLrcPath(paths.first));
    expect((await sidecar.readAsLines()).length, 50);
  });

  test('a corrupt existing copy is not published to recent', () async {
    final path = await bridge.sync(session);
    await recent.clearAll();
    await File(path).writeAsBytes([0]);
    await expectLater(bridge.sync(session), throwsStateError);
    expect(await recent.getAll(), isEmpty);
    expect(await File(session.audioPath).readAsBytes(), [1, 2, 3, 4]);
  });

  test('a failed optional sync leaves the saved session available to retry', () async {
    var calls = 0;
    Future<String> fail(CabinSession value) async {
      calls++;
      expect(value, same(session));
      throw StateError('disk full');
    }
    expect(await syncSavedCabinForListen(session, enabled: true, sync: fail), isFalse);
    expect(await File(session.audioPath).exists(), isTrue);
    expect(await syncSavedCabinForListen(session, enabled: false, sync: fail), isTrue);
    expect(await syncSavedCabinForListen(null, enabled: true, sync: fail), isTrue);
    expect(await syncSavedCabinForListen(
      session.copyWith(hasAudio: false), enabled: true, sync: fail), isTrue);
    expect(calls, 1);
    expect(await syncSavedCabinForListen(session, enabled: true, sync: bridge.sync), isTrue);
  });

}
