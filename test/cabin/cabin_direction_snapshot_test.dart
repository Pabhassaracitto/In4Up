import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_recorder.dart';
import 'package:in4up/features/cabin/services/cabin_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finalization freezes direction before asynchronous translation', () {
    final source = File('lib/features/cabin/services/stts_cabin_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> _finalizeCurrentChunk(');
    final end = source.indexOf('String _mapToSttLocale(', start);
    final body = source.substring(start, end);
    final snapshot = body.indexOf('final chunkSourceLang = sourceLanguage;');
    final target = body.indexOf('final chunkTargetLang = _targetLanguage;');
    final translation = body.indexOf('await _translator.translateText(');
    expect(snapshot, greaterThanOrEqualTo(0));
    expect(target, greaterThan(snapshot));
    expect(translation, greaterThan(target));
    expect(RegExp('sourceLang: chunkSourceLang').allMatches(body).length, 3);
    expect(RegExp('targetLang: chunkTargetLang').allMatches(body).length, 3);
    expect(body, contains('_tts.configure(language: chunkTargetLang)'));
  });

  test('per-entry direction survives edit, finish and saved journal reload', () async {
    final root = Directory.systemTemp.createTempSync('cabin_direction_');
    final store = CabinSessionStore.instance;
    store.debugRootOverride = root.path;
    try {
      final recorder = await CabinSessionRecorder.begin(
        sourceLang: 'en', targetLang: 'vi', engine: 'test', recordAudio: false,
      );
      recorder.addEntry(const CabinTranscriptEntry(
        id: 'a', offset: Duration.zero, sourceText: 'hello',
        translatedText: 'xin chào', sourceLang: 'en', targetLang: 'vi',
      ));
      recorder.addEntry(const CabinTranscriptEntry(
        id: 'b', offset: Duration(seconds: 1), sourceText: 'xin chào',
        translatedText: 'hello', sourceLang: 'vi', targetLang: 'en',
      ));
      expect(recorder.mutateEntry('a', sourceText: 'hello!'), isTrue);
      final session = (await recorder.finish())!;
      expect(await store.mutateEntry(session, 'b', translatedText: 'hello!'), isTrue);
      final entries = await store.loadEntries(session);
      expect(entries.map((e) => (e.sourceLang, e.targetLang)),
          [('en', 'vi'), ('vi', 'en')]);
      expect(entries.map((e) => e.sourceText), ['hello!', 'xin chào']);
      expect(entries.last.translatedText, 'hello!');
      final legacy = CabinTranscriptEntry.fromJson({'ms': 0, 'src': 'legacy'});
      expect(legacy.sourceLang, isNull);
      expect(legacy.targetLang, isNull);
    } finally {
      store.debugRootOverride = null;
      root.deleteSync(recursive: true);
    }
  });
}
