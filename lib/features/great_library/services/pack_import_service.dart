// lib/features/great_library/services/pack_import_service.dart
//
// GLIB-005 — Thư Viện Chung I4U (PLAN-049).
// Điều phối import pack đã tải vào Studio — THUẦN Dart, mọi side-effect đi
// qua sink inject (vocab/audio/image) + InstalledPackStore → test bằng mock,
// production wiring ở pack_import_sinks_io.dart.
//
// Hợp đồng ADDITIVE (KANBAN GLIB-005): update version mới KHÔNG được ghi đè
// tiến độ SM-2 / chỉnh sửa của user — sink chỉ thêm mục mới và điền field còn
// trống, không reset dữ liệu hiện có.

import 'dart:typed_data';

import 'pack_content.dart';
import 'pack_file.dart';

/// Tra cứu media bytes theo tên tương đối (media/<name>) trong pack.
class PackMediaLookup {
  const PackMediaLookup(this._mediaFiles);

  final Map<String, Uint8List> _mediaFiles;

  bool has(String name) => _mediaFiles.containsKey(name);
  Uint8List? bytes(String name) => _mediaFiles[name];
}

/// Kết quả một sink trả về sau import.
class PackSinkResult {
  const PackSinkResult({this.added = 0, this.merged = 0, this.skipped = 0});

  /// Mục mới tạo.
  final int added;

  /// Mục đã có, được bổ sung field còn trống (additive merge).
  final int merged;

  /// Mục bỏ qua (trùng hoàn toàn / không hợp lệ ở tầng sink).
  final int skipped;
}

abstract class PackVocabSink {
  Future<PackSinkResult> importVocab(
    VocabPackPlan plan,
    PackMediaLookup media, {
    required bool isUpdate,
  });
}

abstract class PackAudioSink {
  Future<PackSinkResult> importAudio(
    AudioPackPlan plan,
    PackMediaLookup media,
    Map<String, Uint8List> dataFiles, {
    required bool isUpdate,
  });
}

abstract class PackImageSink {
  Future<PackSinkResult> importImages(
    ImagePackPlan plan,
    PackMediaLookup media, {
    required bool isUpdate,
  });
}

/// Lưu `installedPack {packId → version}` local (KANBAN GLIB-005) — phục vụ
/// chip "Có bản mới" và chặn import lặp cùng version.
abstract class InstalledPackStore {
  Future<Map<String, int>> readAll();
  Future<void> writeAll(Map<String, int> versions);
}

/// InstalledPackStore in-memory — dùng cho test + wiring web (session-scoped).
class MemoryInstalledPackStore implements InstalledPackStore {
  MemoryInstalledPackStore([Map<String, int>? seed])
      : _versions = Map<String, int>.from(seed ?? const {});

  final Map<String, int> _versions;

  @override
  Future<Map<String, int>> readAll() async => Map<String, int>.from(_versions);

  @override
  Future<void> writeAll(Map<String, int> versions) async {
    _versions
      ..clear()
      ..addAll(versions);
  }
}

enum PackImportStatus { imported, updated, alreadyInstalled, failed }

class PackImportResult {
  const PackImportResult._({
    required this.status,
    this.added = 0,
    this.merged = 0,
    this.skipped = 0,
    this.errorMessage,
  });

  final PackImportStatus status;
  final int added;
  final int merged;
  final int skipped;
  final String? errorMessage;

  bool get isSuccess =>
      status == PackImportStatus.imported ||
      status == PackImportStatus.updated ||
      status == PackImportStatus.alreadyInstalled;

  /// Tổng mục có hiệu lực (mới + merge) — cho nhãn "Đã nhập N mục".
  int get affected => added + merged;

  factory PackImportResult.imported(PackSinkResult sink) =>
      PackImportResult._(
          status: PackImportStatus.imported,
          added: sink.added,
          merged: sink.merged,
          skipped: sink.skipped);

  factory PackImportResult.updated(PackSinkResult sink) =>
      PackImportResult._(
          status: PackImportStatus.updated,
          added: sink.added,
          merged: sink.merged,
          skipped: sink.skipped);

  factory PackImportResult.alreadyInstalled() =>
      const PackImportResult._(status: PackImportStatus.alreadyInstalled);

  factory PackImportResult.failed(String message) =>
      PackImportResult._(status: PackImportStatus.failed, errorMessage: message);
}

class PackImportService {
  PackImportService({
    required PackVocabSink vocabSink,
    required PackAudioSink audioSink,
    required PackImageSink imageSink,
    required InstalledPackStore installedStore,
  })  : _vocabSink = vocabSink,
        _audioSink = audioSink,
        _imageSink = imageSink,
        _installedStore = installedStore;

  final PackVocabSink _vocabSink;
  final PackAudioSink _audioSink;
  final PackImageSink _imageSink;
  final InstalledPackStore _installedStore;

  /// Catalog có version mới hơn bản đã cài không (chip "Có bản mới").
  static bool needsUpdate({required int? installedVersion, required int catalogVersion}) =>
      installedVersion != null && catalogVersion > installedVersion;

  /// Import một pack đã giải nén. Không ném — lỗi nằm trong kết quả.
  ///
  /// - Cùng version đã cài + không force → [PackImportStatus.alreadyInstalled]
  ///   (không gọi sink, không ghi store).
  /// - Version mới hơn bản cài → route sink với `isUpdate: true`, sink giữ
  ///   nguyên SM-2/user edits (additive).
  Future<PackImportResult> importPack(PackContents contents,
      {bool force = false}) async {
    final manifest = contents.manifest;
    final installed = (await _installedStore.readAll())[manifest.id];
    if (!force && installed != null && installed >= manifest.version) {
      return PackImportResult.alreadyInstalled();
    }

    final PackContentPlan plan;
    try {
      plan = PackContent.parse(contents);
    } on FormatException catch (e) {
      return PackImportResult.failed(e.message);
    }

    final media = PackMediaLookup(contents.mediaFiles);
    final isUpdate = installed != null;
    try {
      final PackSinkResult sinkResult = switch (plan) {
        VocabPackPlan vocab =>
          await _vocabSink.importVocab(vocab, media, isUpdate: isUpdate),
        AudioPackPlan audio => await _audioSink.importAudio(
            audio, media, contents.dataFiles,
            isUpdate: isUpdate),
        ImagePackPlan image =>
          await _imageSink.importImages(image, media, isUpdate: isUpdate),
      };
      final versions = await _installedStore.readAll();
      versions[manifest.id] = manifest.version;
      await _installedStore.writeAll(versions);
      return isUpdate
          ? PackImportResult.updated(sinkResult)
          : PackImportResult.imported(sinkResult);
    } on Object catch (e) {
      return PackImportResult.failed('$e');
    }
  }
}
