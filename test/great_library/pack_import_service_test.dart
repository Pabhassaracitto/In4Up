// test/great_library/pack_import_service_test.dart
//
// GLIB-005 — PackImportService: route theo loại, ghi installed version,
// chặn import lặp cùng version, update additive (isUpdate), lỗi parse không
// ghi store. Sinks = mock ghi nhận tham số (test thuần, không IO).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_content.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';
import 'package:in4up/features/great_library/services/pack_import_service.dart';

PackManifest _manifest(PackType type, {int version = 1, String id = 'p1'}) =>
    PackManifest(
      id: id,
      type: type,
      title: 'Pack $id',
      srcLang: 'en',
      dstLang: 'vi',
      license: PackLicense.ccBy,
      version: version,
    );

PackContents _vocabContents({int version = 1, String id = 'p1'}) =>
    PackContents(
      manifest: _manifest(PackType.vocab, version: version, id: id),
      dataFiles: {
        'entries.json': Uint8List.fromList(utf8.encode(jsonEncode([
          {'word': 'apple', 'meaning': 'quả táo'},
          {'word': 'run', 'meaning': 'chạy'},
        ]))),
      },
      mediaFiles: const {},
    );

class _RecordingVocabSink implements PackVocabSink {
  final List<VocabPackPlan> calls = [];
  final List<bool> updateFlags = [];
  PackSinkResult result = const PackSinkResult(added: 2);
  Object? error;

  @override
  Future<PackSinkResult> importVocab(VocabPackPlan plan, PackMediaLookup media,
      {required bool isUpdate}) async {
    calls.add(plan);
    updateFlags.add(isUpdate);
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

class _RecordingAudioSink implements PackAudioSink {
  final List<AudioPackPlan> calls = [];

  @override
  Future<PackSinkResult> importAudio(AudioPackPlan plan, PackMediaLookup media,
      Map<String, Uint8List> dataFiles,
      {required bool isUpdate}) async {
    calls.add(plan);
    return const PackSinkResult(added: 1);
  }
}

class _RecordingImageSink implements PackImageSink {
  final List<ImagePackPlan> calls = [];

  @override
  Future<PackSinkResult> importImages(ImagePackPlan plan, PackMediaLookup media,
      {required bool isUpdate}) async {
    calls.add(plan);
    return const PackSinkResult(added: 1);
  }
}

class _Rig {
  _Rig({Map<String, int>? installed}) {
    store = MemoryInstalledPackStore(installed);
    service = PackImportService(
      vocabSink: vocab,
      audioSink: audio,
      imageSink: image,
      installedStore: store,
    );
  }

  late final MemoryInstalledPackStore store;
  late final PackImportService service;
  final vocab = _RecordingVocabSink();
  final audio = _RecordingAudioSink();
  final image = _RecordingImageSink();
}

void main() {
  test('import lần đầu → imported, ghi version vào store', () async {
    final rig = _Rig();
    final result = await rig.service.importPack(_vocabContents());
    expect(result.status, PackImportStatus.imported);
    expect(result.added, 2);
    expect(rig.vocab.calls.single.manifest.id, 'p1');
    expect(rig.vocab.updateFlags.single, isFalse);
    expect((await rig.store.readAll())['p1'], 1);
  });

  test('cùng version đã cài → alreadyInstalled, KHÔNG gọi sink', () async {
    final rig = _Rig(installed: {'p1': 1});
    final result = await rig.service.importPack(_vocabContents());
    expect(result.status, PackImportStatus.alreadyInstalled);
    expect(result.isSuccess, isTrue);
    expect(rig.vocab.calls, isEmpty);
  });

  test('version mới → updated, sink nhận isUpdate=true, store nâng version',
      () async {
    final rig = _Rig(installed: {'p1': 1});
    rig.vocab.result = const PackSinkResult(added: 1, merged: 1);
    final result = await rig.service.importPack(_vocabContents(version: 2));
    expect(result.status, PackImportStatus.updated);
    expect(result.affected, 2);
    expect(rig.vocab.updateFlags.single, isTrue);
    expect((await rig.store.readAll())['p1'], 2);
  });

  test('force=true → import lại dù cùng version', () async {
    final rig = _Rig(installed: {'p1': 1});
    final result =
        await rig.service.importPack(_vocabContents(), force: true);
    expect(result.status, PackImportStatus.updated);
    expect(rig.vocab.calls, isNotEmpty);
  });

  test('route đúng sink theo loại pack (audio)', () async {
    final rig = _Rig();
    final contents = PackContents(
      manifest: _manifest(PackType.audio, id: 'a1'),
      dataFiles: {
        'tracks.json': Uint8List.fromList(utf8.encode(jsonEncode([
          {'file': 't.mp3'}
        ]))),
      },
      mediaFiles: {'t.mp3': Uint8List.fromList([1, 2])},
    );
    final result = await rig.service.importPack(contents);
    expect(result.status, PackImportStatus.imported);
    expect(rig.audio.calls.single.manifest.id, 'a1');
    expect(rig.vocab.calls, isEmpty);
  });

  test('route đúng sink theo loại pack (image)', () async {
    final rig = _Rig();
    final contents = PackContents(
      manifest: _manifest(PackType.image, id: 'i1'),
      dataFiles: {
        'items.json': Uint8List.fromList(utf8.encode(jsonEncode([
          {'image': 'x.jpg'}
        ]))),
      },
      mediaFiles: {'x.jpg': Uint8List.fromList([1])},
    );
    await rig.service.importPack(contents);
    expect(rig.image.calls.single.manifest.id, 'i1');
  });

  test('parse lỗi → failed, KHÔNG ghi store', () async {
    final rig = _Rig();
    final bad = PackContents(
      manifest: _manifest(PackType.vocab),
      dataFiles: const {}, // thiếu entries.json
      mediaFiles: const {},
    );
    final result = await rig.service.importPack(bad);
    expect(result.status, PackImportStatus.failed);
    expect(result.errorMessage, contains('content-missing-data'));
    expect(await rig.store.readAll(), isEmpty);
  });

  test('sink ném → failed, KHÔNG ghi store', () async {
    final rig = _Rig();
    rig.vocab.error = StateError('disk full');
    final result = await rig.service.importPack(_vocabContents());
    expect(result.status, PackImportStatus.failed);
    expect(await rig.store.readAll(), isEmpty);
  });

  test('needsUpdate: chỉ khi catalog mới hơn bản cài', () {
    expect(
        PackImportService.needsUpdate(installedVersion: 1, catalogVersion: 2),
        isTrue);
    expect(
        PackImportService.needsUpdate(installedVersion: 2, catalogVersion: 2),
        isFalse);
    expect(
        PackImportService.needsUpdate(installedVersion: null, catalogVersion: 5),
        isFalse);
  });
}
