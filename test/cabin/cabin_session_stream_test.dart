import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/models/cabin_session.dart';
import 'package:in4up/features/cabin/services/cabin_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stream all 50 effective rows, retaining edits and old entries', () async {
    final dir = Directory.systemTemp.createTempSync('cabin_stream_');
    final store = CabinSessionStore.instance;
    final session = CabinSession(
      id: 'one', dirPath: dir.path, title: 'Test', createdAt: DateTime(2026),
      sourceLang: 'en', targetLang: 'vi', status: CabinSessionStatus.saved,
    );
    try {
      final records = <Map<String, dynamic>>[
        for (var i = 0; i < 51; i++)
          CabinTranscriptEntry(
            id: 'id-$i', offset: Duration(seconds: i), sourceText: 'line $i',
            translatedText: 'dịch $i', sourceLang: 'en', targetLang: 'vi',
          ).toJson(),
        {'id': 'broken', 'ms': 'not a number', 'src': 'bad'},
        {'op': 'edit', 'id': 'id-0', 'src': 'corrected'},
        {'op': 'delete', 'id': 'id-20'},
        {'op': 'edit', 'id': 'id-30', 'tgt': 'updated'},
      ];
      await File(session.journalPath).writeAsString(
          '${records.map(jsonEncode).join('\n')}\n{"broken"');
      final pages = <List<CabinTranscriptEntry>>[];
      var page = <CabinTranscriptEntry>[];
      await for (final entry in store.streamEntries(session)) {
        page.add(entry);
        if (page.length == 7) {
          pages.add(page);
          page = [];
        }
      }
      if (page.isNotEmpty) pages.add(page);
      final all = pages.expand((p) => p).toList();
      expect(all.length, 50);
      expect(all.first.sourceText, 'corrected');
      expect(all.any((e) => e.id == 'id-20'), isFalse);
      expect(all.singleWhere((e) => e.id == 'id-30').translatedText, 'updated');
      expect(all.last.sourceText, 'line 50');
      expect(all.first.sourceLang, 'en');
      final oldReader = await store.loadEntries(session);
      expect(all.map((e) => e.toJson()).toList(),
          oldReader.map((e) => e.toJson()).toList());
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('does not stream an active recording', () async {
    final session = CabinSession(
      id: 'active', dirPath: '.', title: '', createdAt: DateTime(2026),
      sourceLang: 'en', targetLang: 'vi',
    );
    expect(CabinSessionStore.instance.streamEntries(session),
        emitsError(isA<StateError>()));
  });
}
