// lib/features/great_library/services/pack_storage_supabase.dart
//
// GLIB-002 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D3, ideation D4).
// STUB cho backend Supabase Storage — chỉ khai báo để khóa interface + điểm
// cắm; implement khi Firebase Storage sắp hết quota (cảnh báo 80% ở GLIB-007).
//
// Khi implement:
//  - publicUrl: https://{project}.supabase.co/storage/v1/object/public/{bucket}/{path}
//  - upload/download: .../object/{bucket}/{path} (+ Range header cho resume)
//  - auth: apikey + bearer token; bucket public-read cho pack published (D5).

import 'dart:typed_data';

import '../models/pack_manifest.dart';
import 'pack_storage_backend.dart';

class SupabasePackStorage implements PackStorageBackend {
  const SupabasePackStorage({
    required this.projectUrl,
    required this.bucket,
  });

  final String projectUrl;
  final String bucket;

  @override
  String get backendId => 'supabase';

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) {
    throw UnimplementedError(
        'GLIB-002 stub: implement Supabase download khi cần backend dự phòng');
  }

  @override
  Future<int> contentLength(PackStorageRef ref) {
    throw UnimplementedError(
        'GLIB-002 stub: implement Supabase contentLength khi cần');
  }

  @override
  Future<void> upload(
    PackStorageRef ref,
    List<int> bytes, {
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) {
    throw UnimplementedError(
        'GLIB-002 stub: implement Supabase upload khi cần');
  }

  @override
  Uri publicUrl(PackStorageRef ref) => Uri.parse(
      '$projectUrl/storage/v1/object/public/$bucket/${ref.path}');
}
