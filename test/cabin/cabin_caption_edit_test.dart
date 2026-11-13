import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_recorder.dart';
import 'package:in4up/features/cabin/services/cabin_session_store.dart';
import 'package:in4up/features/cabin/services/cabin_transcript_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = CabinSessionStore.instance;
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('cabin_edit_');
    store.debugRootOverride = root.path;
  });
  tearDown(() {
    store.debugRootOverride = null;
    root.deleteSync(recursive: true);
  });

  test('live edits and deletes survive finish and reopen', () async {
    final recorder = await CabinSessionRecorder.begin(
      sourceLang: 'en', targetLang: 'vi', engine: 'test', recordAudio: false,
    );
    recorder.addEntry(const CabinTranscriptEntry(
        id: 'one', offset: Duration(seconds: 1), sourceText: 'old', translatedText: 'cu'));
    recorder.addEntry(const CabinTranscriptEntry(
        id: 'two', offset: Duration(seconds: 2), sourceText: 'remove'));
    expect(recorder.mutateEntry('one', sourceText: 'corrected', translatedText: 'moi'), isTrue);
    expect(recorder.mutateEntry('two', delete: true), isTrue);
    final session = (await recorder.finish())!;
    final entries = await store.loadEntries(session);
    expect(entries.length, 1);
    expect(entries.single.id, 'one');
    expect(entries.single.sourceText, 'corrected');
    expect(entries.single.translatedText, 'moi');
    expect(session.entryCount, 1);
    expect(await File(session.lrcPath).readAsString(), contains('corrected'));
    expect(await File(session.lrcPath).readAsString(), isNot(contains('remove')));
  });

  test('saved edits preserve metadata and legacy/corrupt journal entries', () async {
    final recorder = await CabinSessionRecorder.begin(
      sourceLang: 'en', targetLang: 'vi', engine: 'test', recordAudio: false,
    );
    recorder.addEntry(const CabinTranscriptEntry(
        id: 'one', offset: Duration(seconds: 1), sourceText: 'old'));
    final finished = (await recorder.finish())!;
    final saved = (await store.save(finished, title: 'Saved', textMode: CabinTextMode.bilingual))!;
    // Recovery can encounter a truncated final record from an interrupted app.
    await File(saved.journalPath).writeAsString(
      '${jsonEncode(const CabinTranscriptEntry(offset: Duration.zero, sourceText: 'legacy').toJson())}\n{"ms":',
      mode: FileMode.append,
    );
    expect(await store.mutateEntry(finished, 'one', sourceText: 'new'), isTrue);
    var entries = await store.loadEntries(saved);
    expect(entries.map((entry) => entry.sourceText), ['new', 'legacy']);
    expect((await store.readMeta(Directory(saved.dirPath)))!.status, CabinSessionStatus.saved);
    expect(await File(saved.txtPath).readAsString(), contains('new'));
    expect(await store.mutateEntry(saved, 'one', delete: true), isTrue);
    entries = await store.loadEntries(saved);
    expect(entries.map((entry) => entry.sourceText), ['legacy']);
    expect(await File(saved.lrcPath).readAsString(), isNot(contains('new')));
  });
  test('overlapping saved edits and deletes preserve journal and exports', () async {
    final recorder = await CabinSessionRecorder.begin(
      sourceLang: 'en', targetLang: 'vi', engine: 'test', recordAudio: false,
    );
    for (var i = 0; i < 50; i++) {
      recorder.addEntry(CabinTranscriptEntry(
        id: 'row-$i', offset: Duration(seconds: i), sourceText: 'before-$i',
      ));
    }
    final finished = (await recorder.finish())!;
    final saved = (await store.save(finished, title: 'Saved',
      textMode: CabinTextMode.source))!;

    final results = await Future.wait([
      for (var i = 0; i < 50; i++)
        store.mutateEntry(saved, 'row-$i', sourceText: 'after-$i'),
      store.mutateEntry(saved, 'row-7', delete: true),
      store.mutateEntry(saved, 'row-7', sourceText: 'must-not-return'),
    ]);
    expect(results.take(51), everyElement(isTrue));
    expect(results.last, isFalse);
    final entries = await store.loadEntries(saved);
    expect(entries.length, 49);
    for (final entry in entries) {
      final number = int.parse(entry.id!.substring(4));
      expect(entry.sourceText, 'after-$number');
    }
    final metadata = (await store.readMeta(Directory(saved.dirPath)))!;
    expect(metadata.entryCount, 49);
    expect(metadata.status, CabinSessionStatus.saved);
    final lrc = await File(saved.lrcPath).readAsString();
    final txt = await File(saved.txtPath).readAsString();
    expect(lrc, CabinTranscriptExporter.buildLrc(entries, saved.textMode, title: saved.title));
    expect(txt, CabinTranscriptExporter.buildTxt(entries, saved.textMode));
  });

  test('failed saved edit does not block a later retry', () async {
    final recorder = await CabinSessionRecorder.begin(
      sourceLang: 'en', targetLang: 'vi', engine: 'test', recordAudio: false,
    );
    recorder.addEntry(const CabinTranscriptEntry(
      id: 'row', offset: Duration.zero, sourceText: 'before',
    ));
    final finished = (await recorder.finish())!;
    final saved = (await store.save(finished, title: 'Saved',
      textMode: CabinTextMode.source))!;
    final blocker = Directory('${saved.metaPath}.tmp');
    await blocker.create();
    await expectLater(store.mutateEntry(saved, 'row', sourceText: 'first'), throwsA(isA<FileSystemException>()));
    await blocker.delete();
    expect(await store.mutateEntry(saved, 'row', sourceText: 'retry'), isTrue);
    expect((await store.loadEntries(saved)).single.sourceText, 'retry');
    expect(await File(saved.txtPath).readAsString(), 'retry');
  });

}
