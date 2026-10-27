import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/listen_mode/models/recent_audio.dart';
import 'package:in4up/screens/listen_mode/services/recent_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = RecentAudioService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.invalidateCache();
    await service.clearAll();
  });

  test('queue opening at zero preserves saved progress and serialized writes', () async {
    final audio = RecentAudio.fromLocalFile(path: '/music/a.mp3', title: 'A');
    await service.addOrUpdate(audio.copyWith(
      lastPosition: const Duration(seconds: 30),
      totalDuration: const Duration(minutes: 2),
    ));
    final positionWrite = service.updatePosition(
      audio.id,
      position: const Duration(seconds: 45),
      totalDuration: const Duration(minutes: 2),
    );
    final queueWrite = service.addOrUpdate(audio, preservePositionIfZero: true);
    await Future.wait([positionWrite, queueWrite]);
    final saved = (await service.getAll()).single;
    expect(saved.lastPosition, const Duration(seconds: 45));
    expect(saved.totalDuration, const Duration(minutes: 2));
  });

  test('overlapping insertions do not discard another item', () async {
    final a = RecentAudio.fromLocalFile(path: '/music/a.mp3');
    final b = RecentAudio.fromLocalFile(path: '/music/b.mp3');
    await Future.wait([service.addOrUpdate(a), service.addOrUpdate(b)]);
    expect((await service.getAll()).map((e) => e.id).toSet(), {a.id, b.id});
  });

  test('case-sensitive local paths retain separate histories', () async {
    final upper = RecentAudio.fromLocalFile(path: '/music/Lesson.mp3');
    final lower = RecentAudio.fromLocalFile(path: '/music/lesson.mp3');
    expect(upper.id, isNot(lower.id));
    await service.addOrUpdate(upper.copyWith(lastPosition: const Duration(seconds: 31)));
    await service.addOrUpdate(lower.copyWith(lastPosition: const Duration(seconds: 72)));
    final items = await service.getAll();
    expect(items, hasLength(2));
    expect(items.firstWhere((e) => e.localPath == upper.localPath).lastPosition,
        const Duration(seconds: 31));
    expect(items.firstWhere((e) => e.localPath == lower.localPath).lastPosition,
        const Duration(seconds: 72));
  });

  test('legacy folded ID migrates only with an exact matching path', () async {
    final old = RecentAudio(
      id: 'legacy-folded-id', title: 'Old', type: RecentAudioType.local,
      localPath: '/music/Lesson.mp3', lastOpened: DateTime(2026),
      lastPosition: const Duration(seconds: 30),
    );
    await service.addOrUpdate(old);
    final newRecord = RecentAudio.fromLocalFile(path: '/music/Lesson.mp3');
    await service.addOrUpdate(newRecord, preservePositionIfZero: true);
    final migrated = (await service.getAll()).single;
    expect(migrated.id, newRecord.id);
    expect(migrated.lastPosition, const Duration(seconds: 30));
    final different = RecentAudio.fromLocalFile(path: '/music/lesson.mp3');
    await service.addOrUpdate(different);
    expect(await service.getAll(), hasLength(2));
  });

  test('Windows drive paths keep case-insensitive identity', () {
    final first = RecentAudio.fromLocalFile(path: r'C:\Music\Lesson.mp3');
    final second = RecentAudio.fromLocalFile(path: 'c:/music/lesson.mp3');
    expect(first.id, second.id);
  });

  test('case-sensitive content URIs have separate identities and history', () async {
    final upper = RecentAudio.fromLocalFile(path: 'content://provider/Audio/A');
    final lower = RecentAudio.fromLocalFile(path: 'content://provider/Audio/a');
    expect(upper.id, isNot(lower.id));
    await service.addOrUpdate(upper.copyWith(lastPosition: const Duration(seconds: 33)));
    await service.addOrUpdate(lower.copyWith(lastPosition: const Duration(seconds: 70)));
    final items = await service.getAll();
    expect(items, hasLength(2));
    expect(items.firstWhere((e) => e.localPath == upper.localPath).lastPosition,
        const Duration(seconds: 33));
    expect(items.firstWhere((e) => e.localPath == lower.localPath).lastPosition,
        const Duration(seconds: 70));
  });
}
