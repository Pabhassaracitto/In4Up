import 'dart:io';

/// Snapshot of the index file only; WAL, SHM, bundle and source are excluded.
/// An absent/inaccessible/non-file is unknown, not a misleading zero.
Future<int?> dictionaryDatabaseFileBytes(String path) async {
  if (path.isEmpty) return null;
  try {
    final stat = await File(path).stat();
    return stat.type == FileSystemEntityType.file ? stat.size : null;
  } catch (_) {
    return null;
  }
}
