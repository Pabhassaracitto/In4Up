// lib/features/pdf_reader/services/pdf_annotation_storage.dart
//
// Chỗ lưu "dữ liệu đọc" của một file PDF: highlight/ghi chú/bookmark + trang đọc
// cuối. Hive là kho; `PdfFileIdentity` mới là CHUỐI khoá (không phải đường dẫn),
// để đổi tên / chuyển thư mục không xoá sạch công sức của người đọc.
//
// migration một lượt, an toàn cho 3 thế hệ khoá:
//   1. `pdf_<hashCode>_annotations` / `last_page_<hashCode>`  (code cũ)
//   2. `ann_<md5(path)>`                                       (pathKey)
//   3. `ann_<md5(size|mtime)>`                                 (primaryKey — đích)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/pdf_annotation.dart';
import 'pdf_file_identity.dart';

class PdfAnnotationBundle {
  const PdfAnnotationBundle({
    required this.annotations,
    required this.lastPageIndex,
    required this.migrated,
  });

  final List<PdfAnnotation> annotations;
  final int lastPageIndex;

  /// `true` khi dữ liệu được lấy từ một khoá cũ và đã được copy sang khoá mới.
  final bool migrated;

  static const PdfAnnotationBundle empty =
      PdfAnnotationBundle(annotations: [], lastPageIndex: 0, migrated: false);
}

class PdfAnnotationStorage {
  static const String _boxName = 'pdf_annotations';
  static PdfAnnotationStorage? _instance;

  PdfAnnotationStorage._();
  factory PdfAnnotationStorage() => _instance ??= PdfAnnotationStorage._();

  Box<String>? _box;

  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<String>(_boxName);
    } else {
      _box = Hive.box<String>(_boxName);
    }
  }

  Box<String> get _b {
    final box = _box;
    assert(box != null, 'Call initialize() first');
    return box!;
  }

  static String _annotationsKey(String idKey) => 'ann_$idKey';
  static String _lastPageKey(String idKey) => 'page_$idKey';
  static String _legacyAnnotationsKey(String legacyHash) =>
      'pdf_${legacyHash}_annotations';
  static String _legacyLastPageKey(String legacyHash) =>
      'last_page_$legacyHash';

  /// Đọc toàn bộ dữ liệu đọc của một file, kèm migration khoá cũ → khoá mới.
  ///
  /// Ba thế hệ khoá được thử theo thứ tự ưu tiên; dữ liệu tìm thấy ở khoá cũ sẽ
  /// được copy sang khoá chính (và xoá ở nơi cũ với khoá di sản) để lần mở sau
  /// đọc thẳng, không phải dò lại.
  Future<PdfAnnotationBundle> load(PdfFileIdentity identity) async {
    try {
      final annotationKeys = <String>[
        _annotationsKey(identity.primaryKey),
        if (identity.pathKey != identity.primaryKey)
          _annotationsKey(identity.pathKey),
        _legacyAnnotationsKey(identity.legacyKey),
      ];
      final pageKeys = <String>[
        _lastPageKey(identity.primaryKey),
        if (identity.pathKey != identity.primaryKey)
          _lastPageKey(identity.pathKey),
        _legacyLastPageKey(identity.legacyKey),
      ];

      String? annotationsJson;
      int annotationsAt = -1;
      for (int i = 0; i < annotationKeys.length; i++) {
        final value = _b.get(annotationKeys[i]);
        if (value != null) {
          annotationsJson = value;
          annotationsAt = i;
          break;
        }
      }

      String? lastPageValue;
      int lastPageAt = -1;
      for (int i = 0; i < pageKeys.length; i++) {
        final value = _b.get(pageKeys[i]);
        if (value != null) {
          lastPageValue = value;
          lastPageAt = i;
          break;
        }
      }

      var migrated = false;
      final annotations = _decodeAnnotations(annotationsJson);

      if (annotationsJson != null && annotationsAt > 0) {
        await _b.put(_annotationsKey(identity.primaryKey), annotationsJson);
        // Khoá đường dẫn là "bản sao hợp lệ" (file đang thiếu stat) → giữ lại;
        // khoá di sản thì dọn sạch để không bao giờ đọc đụng nữa.
        if (annotationsAt >= 2) {
          await _b.delete(annotationKeys[annotationsAt]);
        }
        migrated = true;
      }

      final lastPage = int.tryParse(lastPageValue ?? '') ?? 0;
      if (lastPageAt > 0) {
        await _b.put(_lastPageKey(identity.primaryKey), '$lastPage');
        if (lastPageAt >= 2) {
          await _b.delete(pageKeys[lastPageAt]);
        }
        migrated = true;
      }

      return PdfAnnotationBundle(
        annotations: annotations,
        lastPageIndex: lastPage,
        migrated: migrated,
      );
    } catch (e) {
      debugPrint('PdfAnnotationStorage: load error: $e');
      return PdfAnnotationBundle.empty;
    }
  }

  /// Ghi đè toàn bộ danh sách annotation của file (nguồn sự thật nằm ở controller).
  Future<void> persist(PdfFileIdentity identity, List<PdfAnnotation> list) async {
    try {
      final json = jsonEncode(list.map((a) => a.toJson()).toList());
      await _b.put(_annotationsKey(identity.primaryKey), json);
    } catch (e) {
      debugPrint('PdfAnnotationStorage: persist error: $e');
    }
  }

  Future<void> persistLastPage(PdfFileIdentity identity, int pageIndex) async {
    try {
      await _b.put(_lastPageKey(identity.primaryKey), '$pageIndex');
    } catch (e) {
      debugPrint('PdfAnnotationStorage: last page error: $e');
    }
  }

  Future<void> clear(PdfFileIdentity identity) async {
    if (identity.primaryKey != identity.legacyKey) {
      await _b.delete(_annotationsKey(identity.primaryKey));
      await _b.delete(_lastPageKey(identity.primaryKey));
    }
    if (identity.pathKey != identity.primaryKey) {
      await _b.delete(_annotationsKey(identity.pathKey));
      await _b.delete(_lastPageKey(identity.pathKey));
    }
    await _b.delete(_legacyAnnotationsKey(identity.legacyKey));
    await _b.delete(_legacyLastPageKey(identity.legacyKey));
  }

  static List<PdfAnnotation> _decodeAnnotations(String? json) {
    if (json == null) return <PdfAnnotation>[];
    try {
      final list = jsonDecode(json);
      if (list is! List) return <PdfAnnotation>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(PdfAnnotation.fromJson)
          .toList();
    } catch (e) {
      debugPrint('PdfAnnotationStorage: decode error: $e');
      return <PdfAnnotation>[];
    }
  }
}
