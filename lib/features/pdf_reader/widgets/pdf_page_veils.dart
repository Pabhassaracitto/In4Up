// Nối `PdfPageVeil` (pure, ở service) sang callback mà pdfrx gọi sau khi render
// trang. Tách riêng một file vì đây là chỗ DUY NHẤT trong tính năng đọc theme
// phải biết `BlendMode` của dart:ui — service giữ nguyên không phụ thuộc Flutter.
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_reader_theme.dart';

/// Mỗi veil một callback, giữ nguyên thứ tự: veil nào đứng trước vẽ trước, nên
/// chỗ gọi phải đặt danh sách này TRƯỚC callback tô sáng kết quả tìm kiếm.
List<PdfViewerPagePaintCallback> pdfPageVeilPainters(List<PdfPageVeil> veils) {
  if (veils.isEmpty) return const <PdfViewerPagePaintCallback>[];
  return <PdfViewerPagePaintCallback>[
    for (final veil in veils) _pdfPageVeilPainter(veil),
  ];
}

PdfViewerPagePaintCallback _pdfPageVeilPainter(PdfPageVeil veil) {
  return (canvas, pageRect, page) {
    canvas.drawRect(
      pageRect,
      Paint()
        ..color = Color(veil.colorArgb).withValues(
          alpha: veil.alpha.clamp(0.0, 1.0).toDouble(),
        )
        ..blendMode = switch (veil.blend) {
          PdfVeilBlend.multiply => BlendMode.multiply,
          PdfVeilBlend.over => BlendMode.srcOver,
          PdfVeilBlend.plus => BlendMode.plus,
          PdfVeilBlend.difference => BlendMode.difference,
        },
    );
  };
}
