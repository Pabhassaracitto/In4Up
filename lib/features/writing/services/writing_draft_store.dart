import 'dart:async';

import '../models/writing_assignment.dart';
import '../models/writing_source_request.dart';
import '../../../services/storage_service.dart';

class WritingDraftKey {
  final String sourceKey;
  final WritingTaskType task;
  final String assignmentId;

  const WritingDraftKey({
    required this.sourceKey,
    required this.task,
    required this.assignmentId,
  });

  String get storageId => _stableHash(
        '$sourceKey\u0000${task.name}\u0000$assignmentId',
      );

  static String _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// Lưu draft workspace theo `(sourceKey, task, assignmentId)`.
///
/// Drill không đi qua store này; chỉ Rewrite/Summary được khôi phục tự động.
class WritingDraftStore {
  final StorageService _storage;

  WritingDraftStore({StorageService? storage})
      : _storage = storage ?? StorageService();

  String read(WritingDraftKey key) {
    return _storage.getWritingDraft(key.storageId) ?? '';
  }

  void save(WritingDraftKey key, String text) {
    unawaited(_storage.saveWritingDraft(key.storageId, text));
  }

  void clear(WritingDraftKey key) {
    unawaited(_storage.deleteWritingDraft(key.storageId));
  }

  WritingDraftKey keyFor({
    required String sourceKey,
    required WritingAssignment assignment,
  }) {
    return WritingDraftKey(
      sourceKey: sourceKey,
      task: assignment.task,
      assignmentId: assignment.id,
    );
  }
}
