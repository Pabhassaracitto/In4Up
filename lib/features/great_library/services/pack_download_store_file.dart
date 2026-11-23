// lib/features/great_library/services/pack_download_store_file.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049).
// PackDownloadStore trên đĩa (dart:io — chỉ nền tảng native; web đi qua
// memory store ở great_library_wiring_stub.dart).
//
// Layout: {dir}/{packId}.part (đang tải dở — resume) + {dir}/{packId}.i4upack
// (hoàn chỉnh, đã verify checksum).

import 'dart:io';
import 'dart:typed_data';

import 'pack_download_manager.dart';

class FilePackDownloadStore implements PackDownloadStore {
  FilePackDownloadStore(this.dir);

  final Directory dir;

  File _partial(String packId) => File('${dir.path}/$packId.part');
  File _final(String packId) => File('${dir.path}/$packId$i4uExt');

  static const String i4uExt = '.i4upack';

  Future<void> _ensureDir() async {
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  @override
  Future<int> partialLength(String packId) async {
    final file = _partial(packId);
    return await file.exists() ? await file.length() : 0;
  }

  @override
  Future<void> appendPartial(String packId, List<int> chunk) async {
    await _ensureDir();
    final file = _partial(packId);
    final sink = file.openWrite(mode: FileMode.append);
    try {
      sink.add(chunk);
    } finally {
      await sink.close();
    }
  }

  @override
  Future<Uint8List?> readPartial(String packId) async {
    final file = _partial(packId);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> saveFinal(String packId, Uint8List bytes) async {
    await _ensureDir();
    await _final(packId).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> readFinal(String packId) async {
    final file = _final(packId);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> clearPartial(String packId) async {
    final file = _partial(packId);
    if (await file.exists()) await file.delete();
  }
}
