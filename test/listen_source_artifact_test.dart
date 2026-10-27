import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/source_artifact_store.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late SourceArtifactStore store;
  late String lrcDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('in4up_queue_lrc_');
    lrcDir = p.join(root.path, 'lrc');
    store = SourceArtifactStore.forTesting(lrcDir);
    await Directory(lrcDir).create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> audio(String folder, String name) async {
    final dir = Directory(p.join(root.path, folder));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes([1, 2, 3, 4]);
    return file.path;
  }

  Future<String> lrc(String name, String text) async {
    final file = File(p.join(lrcDir, name));
    await file.writeAsString('[00:00.00]$text');
    return file.path;
  }

  test('same-named sources keep distinct bound transcripts', () async {
    final first = await audio('one', 'lesson.mp3');
    final second = await audio('two', 'lesson.mp3');
    final firstLrc = await lrc('one.lrc', 'first');
    final secondLrc = await lrc('two.lrc', 'second');

    // Concurrent writes must not lose one path when the fingerprint collides.
    await Future.wait([
      store.rememberLrc(audioPath: first, lrcPath: firstLrc),
      store.rememberLrc(audioPath: second, lrcPath: secondLrc),
    ]);
    expect((await store.findLrc(first))?.lrcPath, firstLrc);
    expect((await store.findLrc(second))?.lrcPath, secondLrc);
    expect((await store.findLrc(first))?.audioPath, first);
  });

  test('legacy indexed path is restored, not another folder’s fingerprint', () async {
    final first = await audio('one', 'lesson.mp3');
    final second = await audio('two', 'lesson.mp3');
    final oldLrc = await lrc('old.lrc', 'legacy');
    final normalized = SourceArtifactStore.normalizePath(first);
    final fp = await SourceArtifactStore.fingerprint(first);
    final oldEntry = {'audioPath': normalized, 'lrcPath': oldLrc};
    await File(p.join(lrcDir, 'index.json')).writeAsString(jsonEncode({
      normalized: oldEntry,
      fp: oldEntry,
    }));

    expect((await store.findLrc(first))?.lrcPath, oldLrc);
    expect(await store.findLrc(second), isNull);
    expect(await File(oldLrc).exists(), isTrue);
  });

  test('orphan LRC is preserved and needs an explicit association', () async {
    final source = await audio('one', 'lesson.mp3');
    final orphan = await lrc('lesson.lrc', 'old');
    expect(await store.findLrc(source), isNull);
    expect(await store.hasUnverifiedLrc(source), isTrue);
    expect(await store.bindSingleUnverifiedLrc(source), isTrue);
    expect((await store.findLrc(source))?.lrcPath, orphan);
  });

  test('multiple orphan LRC candidates are not guessed or deleted', () async {
    final source = await audio('one', 'lesson.mp3');
    final fp = await SourceArtifactStore.fingerprint(source);
    final first = await lrc('lesson.lrc', 'old');
    final second = await lrc('$fp.lrc', 'other');
    expect(await store.bindSingleUnverifiedLrc(source), isFalse);
    expect(await store.findLrc(source), isNull);
    expect(await File(first).exists(), isTrue);
    expect(await File(second).exists(), isTrue);
    final choices = await store.unverifiedLrcCandidates(source);
    expect(choices, hasLength(2));
    final selected = choices.firstWhere((hit) => hit.lrcPath == second);
    expect(await store.bindUnverifiedLrc(selected), isTrue);
    expect((await store.findLrc(source))?.lrcPath, second);
    expect(await File(first).exists(), isTrue);
  });

  test('an LRC bound to another source is not offered as an orphan', () async {
    final first = await audio('one', 'lesson.mp3');
    final second = await audio('two', 'lesson.mp3');
    final lrcPath = await lrc('lesson.lrc', 'first');
    await store.rememberLrc(audioPath: first, lrcPath: lrcPath);
    expect(await store.unverifiedLrcCandidates(second), isEmpty);
    expect((await store.findLrc(first))?.lrcPath, lrcPath);
  });

  test('new LRC filenames distinguish same names without overwriting legacy', () async {
    final first = await audio('one', 'lesson.mp3');
    final second = await audio('two', 'lesson.mp3');
    final legacy = await lrc('lesson.lrc', 'legacy');
    final converter = SttLrcConverter();
    final result = SttResult.empty(SttEngineType.native);
    final firstOutput = await converter.saveLrcFile(result, first, outputDirectory: lrcDir);
    final secondOutput = await converter.saveLrcFile(result, second, outputDirectory: lrcDir);
    expect(firstOutput, isNotNull);
    expect(secondOutput, isNotNull);
    expect(firstOutput, isNot(secondOutput));
    expect(await File(legacy).readAsString(), '[00:00.00]legacy');
  });
}
