// lib/features/great_library/services/pack_file.dart
//
// GLIB-001 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D1).
// Build / đọc / verify gói `.i4upack` (ZIP: manifest.json + data/ + media/).
//
// Thuần Dart + `archive`/`crypto` (đã có trong pubspec) — chạy được trong test
// thuần và tool seed. Không dùng dart:io, không Flutter.
//
// Quy ước tên entry trong ZIP:
//   manifest.json        — bắt buộc, duy nhất ở gốc
//   data/<name>          — dữ liệu cấu trúc (vocab.json, transcript.lrc, …)
//   media/<name>         — nhị phân (mp3, jpg, …)
// Entry gốc khác manifest.json được BỎ QUA khi đọc (forward-compat) nhưng bị
// cấm khi build. Tên có '..', '/', '\' ở đầu, rỗng → từ chối (chống zip-slip).

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../models/pack_manifest.dart';

const String kPackExtension = '.i4upack';
const String kPackManifestEntry = 'manifest.json';
const String kPackDataPrefix = 'data/';
const String kPackMediaPrefix = 'media/';

/// Quota mặc định 50 MB/pack (ideation v1.2 §6.2 — owner có thể đổi).
const int kPackMaxBytesDefault = 50 * 1024 * 1024;

/// Giới hạn phòng thủ khi giải nén (chống zip bomb / file lỗi).
const int kPackMaxEntries = 5000;
const int kPackMaxManifestBytes = 256 * 1024;

/// Kết quả build: bytes zip + checksum file (đưa lên catalog) + manifest đã
/// được inject `payloadSha256` + `sizeBytes`.
class PackBuildResult {
  const PackBuildResult({
    required this.bytes,
    required this.fileSha256,
    required this.manifest,
  });

  final Uint8List bytes;
  final String fileSha256;
  final PackManifest manifest;
}

/// Nội dung giải nén từ một pack.
class PackContents {
  const PackContents({
    required this.manifest,
    required this.dataFiles,
    required this.mediaFiles,
  });

  final PackManifest manifest;

  /// Key là tên tương đối sau prefix `data/`.
  final Map<String, Uint8List> dataFiles;

  /// Key là tên tương đối sau prefix `media/`.
  final Map<String, Uint8List> mediaFiles;
}

/// Sink nhỏ bắt Digest từ chunked conversion của crypto (tránh kéo
/// package:convert chỉ vì AccumulatorSink).
class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class PackFile {
  PackFile._();

  // ------------------------------------------------------------------ build

  /// Build `.i4upack`. Ném [FormatException] kèm mã lỗi đầu tiên khi manifest
  /// hoặc tên file không hợp lệ; ném [StateError] khi vượt quota.
  ///
  /// [maxPayloadBytes]: mặc định 50 MB; tool seed/moderator có thể nâng cho
  /// AudioPack dài (không vượt [kPackHardCeilingBytes]).
  static PackBuildResult build({
    required PackManifest manifest,
    Map<String, List<int>> dataFiles = const <String, List<int>>{},
    Map<String, List<int>> mediaFiles = const <String, List<int>>{},
    int maxPayloadBytes = kPackMaxBytesDefault,
  }) {
    final errors = manifest.validate();
    if (errors.isNotEmpty) {
      throw FormatException('manifest invalid: ${errors.join(',')}');
    }
    _assertValidNames(dataFiles.keys, 'data');
    _assertValidNames(mediaFiles.keys, 'media');
    final overlap = dataFiles.keys.toSet().intersection(mediaFiles.keys.toSet());
    if (overlap.isNotEmpty) {
      throw FormatException('entry-duplicate: ${overlap.first}');
    }
    if (dataFiles.length + mediaFiles.length > kPackMaxEntries) {
      throw FormatException('entry-too-many');
    }

    var payloadBytes = 0;
    for (final bytes in dataFiles.values) {
      payloadBytes += bytes.length;
    }
    for (final bytes in mediaFiles.values) {
      payloadBytes += bytes.length;
    }
    if (payloadBytes > maxPayloadBytes) {
      throw StateError('payload-over-quota: $payloadBytes > $maxPayloadBytes');
    }
    if (payloadBytes > kPackHardCeilingBytes) {
      throw StateError('payload-over-ceiling: $payloadBytes');
    }

    // payloadSha256: hash theo thứ tự tên đã sắp xếp, gồm tên + độ dài + bytes
    // → bất biến theo cách nén ZIP, đổi khi nội dung đổi.
    final payloadSha = _hashPayload(dataFiles, mediaFiles);
    final effective = manifest.copyWith(
      payloadSha256: payloadSha,
      sizeBytes: payloadBytes,
      entryCount: manifest.entryCount > 0
          ? manifest.entryCount
          : dataFiles.length + mediaFiles.length,
    );

    final archive = Archive();
    final manifestBytes = utf8.encode(effective.toJsonString());
    if (manifestBytes.length > kPackMaxManifestBytes) {
      throw StateError('manifest-too-large: ${manifestBytes.length}');
    }
    archive.addFile(
        ArchiveFile(kPackManifestEntry, manifestBytes.length, manifestBytes));
    final names = <String>[
      ...dataFiles.keys.map((n) => '$kPackDataPrefix$n'),
      ...mediaFiles.keys.map((n) => '$kPackMediaPrefix$n'),
    ]..sort();
    for (final fullName in names) {
      final bytes = fullName.startsWith(kPackDataPrefix)
          ? dataFiles[fullName.substring(kPackDataPrefix.length)]!
          : mediaFiles[fullName.substring(kPackMediaPrefix.length)]!;
      archive.addFile(ArchiveFile(fullName, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('zip-encode-failed');
    }
    final zipBytes = Uint8List.fromList(encoded);
    return PackBuildResult(
      bytes: zipBytes,
      fileSha256: sha256.convert(zipBytes).toString(),
      manifest: effective,
    );
  }

  // ------------------------------------------------------------------- read

  /// Đọc chỉ manifest (không giải nén media) — dùng cho preview/kiểm tra nhanh.
  static PackManifest readManifest(List<int> packBytes) {
    final archive = _decode(packBytes);
    final manifestFile = _findManifest(archive);
    final raw = manifestFile.content as List<int>;
    if (raw.length > kPackMaxManifestBytes) {
      throw const FormatException('manifest-too-large');
    }
    return PackManifest.fromJsonString(utf8.decode(raw));
  }

  /// Giải nén đầy đủ. Entry gốc lạ (không phải manifest/data/media) bị bỏ qua
  /// (forward-compat); tên nguy hiểm bị từ chối.
  static PackContents extract(List<int> packBytes) {
    final archive = _decode(packBytes);
    if (archive.files.length > kPackMaxEntries) {
      throw const FormatException('entry-too-many');
    }
    final manifest = readManifest(packBytes);
    final dataFiles = <String, Uint8List>{};
    final mediaFiles = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name == kPackManifestEntry) continue;
      _assertSafeEntryName(name);
      final content = file.content as List<int>;
      if (name.startsWith(kPackDataPrefix)) {
        dataFiles[name.substring(kPackDataPrefix.length)] =
            Uint8List.fromList(content);
      } else if (name.startsWith(kPackMediaPrefix)) {
        mediaFiles[name.substring(kPackMediaPrefix.length)] =
            Uint8List.fromList(content);
      }
      // Entry gốc khác: bỏ qua (forward-compat).
    }
    return PackContents(
      manifest: manifest,
      dataFiles: dataFiles,
      mediaFiles: mediaFiles,
    );
  }

  // ----------------------------------------------------------------- verify

  /// Kiểm chứng toàn vẹn. Trả về danh sách mã lỗi (rỗng = hợp lệ):
  ///  - 'corrupt-zip' / 'manifest-missing' / 'manifest-invalid:*'
  ///  - 'payload-mismatch' (nội dung lệch manifest)
  ///  - 'file-sha256-mismatch' (khi truyền [expectedFileSha256])
  ///  - 'entry-too-many' / 'entry-unsafe'
  static List<String> verify(
    List<int> packBytes, {
    String? expectedFileSha256,
  }) {
    if (expectedFileSha256 != null &&
        sha256.convert(packBytes).toString() != expectedFileSha256) {
      return <String>['file-sha256-mismatch'];
    }
    final PackContents contents;
    try {
      contents = extract(packBytes);
    } on FormatException catch (e) {
      return <String>['corrupt-zip:${e.message}'];
    } on Object catch (e) {
      // archive ném ArchiveException khi giải nén vùng dữ liệu hỏng.
      return <String>['corrupt-zip:$e'];
    }
    final manifestErrors = contents.manifest.validate();
    if (manifestErrors.isNotEmpty) {
      return <String>['manifest-invalid:${manifestErrors.join(',')}'];
    }
    final declared = contents.manifest.payloadSha256;
    if (declared == null) return <String>['payload-sha256-missing'];
    final actual = _hashPayload(contents.dataFiles, contents.mediaFiles);
    if (actual != declared) return <String>['payload-mismatch'];
    return const <String>[];
  }

  // ---------------------------------------------------------------- helpers

  static Archive _decode(List<int> packBytes) {
    try {
      return ZipDecoder().decodeBytes(packBytes);
    } on Object {
      throw const FormatException('corrupt-zip');
    }
  }

  static ArchiveFile _findManifest(Archive archive) {
    for (final file in archive.files) {
      if (file.isFile && file.name == kPackManifestEntry) return file;
    }
    throw const FormatException('manifest-missing');
  }

  static void _assertValidNames(Iterable<String> names, String kind) {
    for (final name in names) {
      if (name.isEmpty || name.contains('..') || name.startsWith('/') ||
          name.contains('\\')) {
        throw FormatException('entry-unsafe($kind): $name');
      }
      if (name == kPackManifestEntry) {
        throw FormatException('entry-reserved($kind): $name');
      }
    }
  }

  static void _assertSafeEntryName(String name) {
    if (name.isEmpty || name.contains('..') || name.startsWith('/') ||
        name.contains('\\')) {
      throw FormatException('entry-unsafe: $name');
    }
  }

  static String _hashPayload(
    Map<String, List<int>> dataFiles,
    Map<String, List<int>> mediaFiles,
  ) {
    final names = <String>[
      ...dataFiles.keys.map((n) => '$kPackDataPrefix$n'),
      ...mediaFiles.keys.map((n) => '$kPackMediaPrefix$n'),
    ]..sort();
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    for (final fullName in names) {
      final bytes = fullName.startsWith(kPackDataPrefix)
          ? dataFiles[fullName.substring(kPackDataPrefix.length)]!
          : mediaFiles[fullName.substring(kPackMediaPrefix.length)]!;
      input
        ..add(utf8.encode('$fullName\n${bytes.length}\n'))
        ..add(bytes);
    }
    input.close();
    return sink.value!.toString();
  }
}
