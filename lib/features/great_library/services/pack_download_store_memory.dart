// lib/features/great_library/services/pack_download_store_memory.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049).
// PackDownloadStore in-memory: dùng cho web (không có dart:io), cho test, và
// làm fallback khi wiring file store chưa sẵn. Dữ liệu MẤT khi đóng app —
// wiring nền tảng native dùng pack_download_store_file.dart.

import 'dart:typed_data';

import 'pack_download_manager.dart';

class MemoryPackDownloadStore implements PackDownloadStore {
  final Map<String, List<int>> _partials = <String, List<int>>{};
  final Map<String, Uint8List> _finals = <String, Uint8List>{};

  @override
  Future<int> partialLength(String packId) async =>
      _partials[packId]?.length ?? 0;

  @override
  Future<void> appendPartial(String packId, List<int> chunk) async {
    _partials.putIfAbsent(packId, () => <int>[]).addAll(chunk);
  }

  @override
  Future<Uint8List?> readPartial(String packId) async {
    final partial = _partials[packId];
    return partial == null ? null : Uint8List.fromList(partial);
  }

  @override
  Future<void> saveFinal(String packId, Uint8List bytes) async {
    _finals[packId] = bytes;
  }

  @override
  Future<Uint8List?> readFinal(String packId) async => _finals[packId];

  @override
  Future<void> clearPartial(String packId) async {
    _partials.remove(packId);
  }
}
