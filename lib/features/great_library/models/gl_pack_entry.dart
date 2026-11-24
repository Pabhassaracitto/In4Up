// lib/features/great_library/models/gl_pack_entry.dart
//
// GLIB-003 — Thư Viện Chung I4U (PLAN-049, ADR-0036 D2).
// Một mục trong catalog công khai: metadata pack (PackManifest) + thông tin
// file để tải/verify (fileSha256, fileBytes) + publishedAt.
//
// Layout doc Firestore `gl_packs/{packId}`: các field của PackManifest trải
// phẳng ở top-level (để query theo status/type/ngôn ngữ) + 3 field riêng:
//   fileSha256 (string)  — sha256 nguyên file .i4upack
//   fileBytes  (int)     — dung lượng file zip thật (khác sizeBytes = payload)
//   publishedAt (timestamp)
//
// Thuần Dart — test chạy mọi nơi.

import 'pack_manifest.dart';

class GlPackEntry {
  const GlPackEntry({
    required this.manifest,
    required this.fileSha256,
    required this.fileBytes,
    this.publishedAt,
  });

  final PackManifest manifest;
  final String fileSha256;
  final int fileBytes;
  final DateTime? publishedAt;

  String get packId => manifest.id;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'manifest': manifest.toJson(),
        'fileSha256': fileSha256,
        'fileBytes': fileBytes,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
      };

  factory GlPackEntry.fromJson(Map<String, dynamic> json) {
    return GlPackEntry(
      manifest: PackManifest.fromJson(
          (json['manifest'] as Map<String, dynamic>?) ??
              const <String, dynamic>{}),
      fileSha256: (json['fileSha256'] as String?) ?? '',
      fileBytes: (json['fileBytes'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse((json['publishedAt'] as String?) ?? ''),
    );
  }

  /// Parse từ fields của doc Firestore (đã decode về Dart thường): manifest
  /// nằm trải phẳng top-level, 3 field riêng tách ra.
  factory GlPackEntry.fromCatalogDoc(Map<String, dynamic> fields) {
    final manifestFields = Map<String, dynamic>.from(fields)
      ..remove('fileSha256')
      ..remove('fileBytes')
      ..remove('publishedAt');
    return GlPackEntry(
      manifest: PackManifest.fromJson(manifestFields),
      fileSha256: (fields['fileSha256'] as String?) ?? '',
      fileBytes: (fields['fileBytes'] as num?)?.toInt() ?? 0,
      publishedAt: fields['publishedAt'] is DateTime
          ? fields['publishedAt'] as DateTime
          : DateTime.tryParse('${fields['publishedAt'] ?? ''}'),
    );
  }
}
