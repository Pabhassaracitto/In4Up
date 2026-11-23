// lib/features/great_library/services/gl_catalog_file_cache.dart
//
// GLIB-004b — Thư Viện Chung I4U (PLAN-049).
// GlCatalogCacheStore bền vững trên đĩa (native): snapshot JSON ghi ra
// {dir}/catalog_cache.json → app mở lại offline vẫn có catalog phiên trước
// (stale-on-error fallback của GlCatalogService dùng được ngay).
// Web (không dart:io) giữ GlCatalogMemoryCache theo session.

import 'dart:io';

import 'gl_catalog_service.dart';

class GlCatalogFileCache implements GlCatalogCacheStore {
  GlCatalogFileCache(this.dir);

  final Directory dir;

  File get _file => File('${dir.path}/catalog_cache.json');

  @override
  Future<String?> read() async {
    try {
      final file = _file;
      if (!await file.exists()) return null;
      return await file.readAsString();
    } on Object {
      // Cache hỏng/không đọc được → coi như không có cache.
      return null;
    }
  }

  @override
  Future<void> write(String snapshotJson) async {
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
      // Ghi file tạm rồi rename — tránh đọc nửa file khi app chết giữa chừng.
      final tmp = File('${dir.path}/catalog_cache.json.tmp');
      await tmp.writeAsString(snapshotJson, flush: true);
      await tmp.rename(_file.path);
    } on Object {
      // Không ghi được cache không phải lỗi nghiệp vụ — nuốt, lần sau ghi lại.
    }
  }
}
