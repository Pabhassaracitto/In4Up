import 'package:flutter/foundation.dart';

@immutable
class I4uReaderNoteDraft {
  const I4uReaderNoteDraft({
    required this.sourceId,
    required this.text,
    this.blockId,
    this.characterOffset,
    this.body = '',
  });

  final String sourceId;
  final String text;
  final String? blockId;
  final int? characterOffset;
  final String body;
}

abstract interface class I4uReaderNoteRepository {
  Future<void> save(I4uReaderNoteDraft draft);
}
