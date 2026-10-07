import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reader_note_contract.dart';

class SharedPreferencesReaderNoteRepository implements I4uReaderNoteRepository {
  SharedPreferencesReaderNoteRepository(this.prefs);

  final SharedPreferences prefs;
  static const key = 'i4u.reader.notes.v1';

  @override
  Future<void> save(I4uReaderNoteDraft draft) async {
    final existing = prefs.getStringList(key) ?? <String>[];
    existing.add(jsonEncode({
      'sourceId': draft.sourceId,
      'text': draft.text,
      'blockId': draft.blockId,
      'characterOffset': draft.characterOffset,
      'body': draft.body,
      'createdAt': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(key, existing);
  }
}
