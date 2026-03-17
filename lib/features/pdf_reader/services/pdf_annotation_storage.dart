import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/pdf_annotation.dart';

/// Lưu trữ annotations per PDF file vào Hive
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
    assert(_box != null, 'Call initialize() first');
    return _box!;
  }

  /// Key = hash của PDF path để tránh special chars
  String _keyFor(String pdfPath) =>
      'pdf_${pdfPath.hashCode.abs()}_annotations';

  /// Load tất cả annotations của một file PDF
  List<PdfAnnotation> loadAnnotations(String pdfPath) {
    try {
      final json = _b.get(_keyFor(pdfPath));
      if (json == null) return [];
      final list = jsonDecode(json) as List;
      return list
          .map((e) => PdfAnnotation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PdfAnnotationStorage: load error: $e');
      return [];
    }
  }

  /// Lưu danh sách annotations
  Future<void> saveAnnotations(
    String pdfPath,
    List<PdfAnnotation> annotations,
  ) async {
    try {
      final json = jsonEncode(annotations.map((a) => a.toJson()).toList());
      await _b.put(_keyFor(pdfPath), json);
    } catch (e) {
      debugPrint('PdfAnnotationStorage: save error: $e');
    }
  }

  /// Thêm một annotation mới
  Future<void> addAnnotation(String pdfPath, PdfAnnotation annotation) async {
    final existing = loadAnnotations(pdfPath);
    existing.add(annotation);
    await saveAnnotations(pdfPath, existing);
  }

  /// Cập nhật annotation (thêm note)
  Future<void> updateAnnotation(
    String pdfPath,
    PdfAnnotation updated,
  ) async {
    final existing = loadAnnotations(pdfPath);
    final idx = existing.indexWhere((a) => a.id == updated.id);
    if (idx >= 0) {
      existing[idx] = updated;
      await saveAnnotations(pdfPath, existing);
    }
  }

  /// Xóa annotation
  Future<void> deleteAnnotation(String pdfPath, String annotationId) async {
    final existing = loadAnnotations(pdfPath);
    existing.removeWhere((a) => a.id == annotationId);
    await saveAnnotations(pdfPath, existing);
  }

  /// Xóa tất cả annotations của một file
  Future<void> clearAll(String pdfPath) async {
    await _b.delete(_keyFor(pdfPath));
  }

  /// Lưu vị trí đọc cuối cùng (page index)
  Future<void> saveLastPage(String pdfPath, int pageIndex) async {
    await _b.put('last_page_${pdfPath.hashCode.abs()}', pageIndex.toString());
  }

  int loadLastPage(String pdfPath) {
    final val = _b.get('last_page_${pdfPath.hashCode.abs()}');
    return int.tryParse(val ?? '0') ?? 0;
  }
}
