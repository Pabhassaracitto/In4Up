// lib/features/pdf_reader/models/pdf_annotation.dart
import 'dart:ui' show Color, Rect;

/// loại annotation người dùng tạo trên PDF.
enum AnnotationType { highlight, note, bookmark }

/// Một lần người dùng "đánh dấu" trên PDF: highlight, ghi chú, hoặc bookmark.
///
/// Hợp đồng dữ liệu (quy tắc vàng #3 của repo): một annotation PHẢI mở lại
/// đúng chỗ nó được tạo. Ngoài `bounds` ta giữ thêm
/// `textStartOffset/textEndOffset` (offset trong `fullText` thô của trang) —
/// toạ độ có thể lệch theo engine text, offset thì không.
class PdfAnnotation {
  const PdfAnnotation({
    required this.id,
    required this.pageIndex,
    required this.bounds,
    required this.selectedText,
    required this.createdAt,
    this.note,
    this.color = const Color(0xFFFFD54F),
    this.type = AnnotationType.highlight,
    this.lineRects = const [],
    this.textStartOffset,
    this.textEndOffset,
  });

  final String id;
  final int pageIndex;

  /// Rect bao trọn vùng chọn, theo không gian trang PDF (gốc dưới-trái).
  final Rect bounds;

  /// Rect theo TỪNG DÒNG của vùng chọn. Có thì highlight dài quá một dòng vẽ
  /// đúng hình dạng câu thay vì phủ cả khoảng trắng cuối dòng.
  final List<Rect> lineRects;

  final String selectedText;
  final String? note;
  final Color color;
  final AnnotationType type;
  final DateTime createdAt;

  /// Offset trong `fullText` thô của trang — để reopened về đúng ký tự.
  final int? textStartOffset;
  final int? textEndOffset;

  /// Chiều cao hình học thật của `bounds` (rect PDF space có `top > bottom`,
  /// nên KHÔNG được dùng `bounds.height` — nó âm).
  double get boundsHeight => (bounds.top - bounds.bottom).abs();

  bool get hasValidBounds =>
      bounds != Rect.zero && bounds.width > 0 && boundsHeight > 0;

  bool get canReopenToPosition =>
      hasValidBounds || (textStartOffset != null && textEndOffset != null);

  List<Rect> get rectsForPainting =>
      lineRects.isNotEmpty ? lineRects : (hasValidBounds ? [bounds] : const []);

  PdfAnnotation copyWith({
    String? note,
    Color? color,
    AnnotationType? type,
    Rect? bounds,
    List<Rect>? lineRects,
    int? textStartOffset,
    int? textEndOffset,
  }) {
    return PdfAnnotation(
      id: id,
      pageIndex: pageIndex,
      bounds: bounds ?? this.bounds,
      lineRects: lineRects ?? this.lineRects,
      selectedText: selectedText,
      note: note ?? this.note,
      color: color ?? this.color,
      type: type ?? this.type,
      createdAt: createdAt,
      textStartOffset: textStartOffset ?? this.textStartOffset,
      textEndOffset: textEndOffset ?? this.textEndOffset,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageIndex': pageIndex,
        'bounds': <String, double>{
          'left': bounds.left,
          'top': bounds.top,
          'right': bounds.right,
          'bottom': bounds.bottom,
        },
        if (lineRects.isNotEmpty)
          'lineRects': lineRects
              .map((r) => <String, double>{
                    'left': r.left,
                    'top': r.top,
                    'right': r.right,
                    'bottom': r.bottom,
                  })
              .toList(growable: false),
        'selectedText': selectedText,
        'note': note,
        'color': color.toARGB32(),
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        if (textStartOffset != null) 'textStartOffset': textStartOffset,
        if (textEndOffset != null) 'textEndOffset': textEndOffset,
      };

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) {
    return PdfAnnotation(
      id: json['id'] as String,
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      bounds: _readRect(json['bounds']),
      lineRects: (json['lineRects'] as List?)
              ?.map(_readRect)
              .where((r) => r != Rect.zero)
              .toList(growable: false) ??
          const [],
      selectedText: json['selectedText'] as String? ?? '',
      note: json['note'] as String?,
      color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFD54F),
      type: AnnotationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AnnotationType.highlight,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      textStartOffset: (json['textStartOffset'] as num?)?.toInt(),
      textEndOffset: (json['textEndOffset'] as num?)?.toInt(),
    );
  }

  /// Accepts both the legacy `{'left':..,'top':..}` map and a compact list.
  static Rect _readRect(Object? raw) {
    if (raw is Map) {
      return Rect.fromLTRB(
        _num(raw['left']),
        _num(raw['top']),
        _num(raw['right']),
        _num(raw['bottom']),
      );
    }
    if (raw is List && raw.length >= 4) {
      return Rect.fromLTRB(
        _num(raw[0]),
        _num(raw[1]),
        _num(raw[2]),
        _num(raw[3]),
      );
    }
    return Rect.zero;
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0.0;
}
