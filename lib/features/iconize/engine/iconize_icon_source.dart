// lib/features/iconize/engine/iconize_icon_source.dart
//
// ICONIZE-001c — tầng nguồn icon cắm thêm vào engine (fallback 4 tầng,
// blueprint mục 3.6): user vocab_image > core bundle > CDN > giữ chữ.
//
// Engine kiểm [IconizeIconSource] theo thứ tự TRƯỚC core bundle; nguồn nào
// trả ref khác null thì thắng. Icon user KHÔNG cần có trong icon_index —
// cổng chất lượng với icon cá nhân là concreteness + POS (người dùng đã
// tự xác nhận nghĩa khi gán ảnh cho từ).
//
// Adapter thật nối vào kho WordEntry/vocab_image được wire ở lane 001d
// (cần context màn hình); CDN resolver dời sang gói mở rộng Model Centre
// (ghi vết tại card KANBAN ICONIZE-001).

import '../models/iconize_span.dart';

abstract class IconizeIconSource {
  /// Trả iconAssetRef cho (lemma, pos) — ví dụ "file:/…/cat.webp" — hoặc
  /// null nếu nguồn này không có icon riêng. PHẢI nhanh (gọi trong vòng
  /// lặp token) và thuần bộ nhớ: I/O chuẩn bị sẵn từ trước.
  String? resolve(String lemma, IconizePos pos);

  /// Loại nguồn để UI biết cách render (ảnh user vs SVG bundle).
  IconizeSource get sourceKind;
}
