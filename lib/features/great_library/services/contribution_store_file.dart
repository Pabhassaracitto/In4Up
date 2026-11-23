// lib/features/great_library/services/contribution_store_file.dart
//
// GLIB-006 — ContributionStore persist bằng JSON file (native, dart:io).
// Web dùng MemoryContributionStore (stub wiring). Ghi atomic tmp+rename,
// lỗi đọc/ghi nuốt êm (quota local là best-effort — server vẫn chặn thật).

import 'dart:convert';
import 'dart:io';

import 'contribution_store.dart';

class FileContributionStore implements ContributionStore {
  FileContributionStore(this._dir);

  final Directory _dir;

  File get _file => File('${_dir.path}/gl_contributions.json');

  List<ContributionRecord> _readAll() {
    try {
      if (!_file.existsSync()) return <ContributionRecord>[];
      final raw = jsonDecode(_file.readAsStringSync());
      if (raw is! List) return <ContributionRecord>[];
      return raw
          .whereType<Map>()
          .map((e) => ContributionRecord.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <ContributionRecord>[];
    }
  }

  Future<void> _writeAll(List<ContributionRecord> records) async {
    try {
      if (!await _dir.exists()) await _dir.create(recursive: true);
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(
          jsonEncode(records.map((r) => r.toJson()).toList()));
      await tmp.rename(_file.path);
    } catch (_) {
      // Nuốt êm — quota local chỉ là rào sớm.
    }
  }

  @override
  int countInMonth(int nowMs) {
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    var n = 0;
    for (final r in _readAll()) {
      final t = DateTime.fromMillisecondsSinceEpoch(r.submittedAtMs);
      if (t.year == now.year && t.month == now.month) n++;
    }
    return n;
  }

  @override
  void add(ContributionRecord record) {
    final all = _readAll()..add(record);
    _writeAll(all);
  }

  @override
  List<ContributionRecord> all() => _readAll();
}
