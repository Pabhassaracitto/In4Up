import 'package:flutter/material.dart';

enum AnnotationType { highlight, note, bookmark }

class PdfAnnotation {
  final String id;
  final int pageIndex;
  final Rect bounds;           // Tọa độ trên PDF page (PDF units)
  final String selectedText;
  final String? note;
  final Color color;
  final AnnotationType type;
  final DateTime createdAt;

  const PdfAnnotation({
    required this.id,
    required this.pageIndex,
    required this.bounds,
    required this.selectedText,
    this.note,
    this.color = const Color(0xFFFFD54F),
    this.type = AnnotationType.highlight,
    required this.createdAt,
  });

  PdfAnnotation copyWith({String? note, Color? color}) {
    return PdfAnnotation(
      id: id,
      pageIndex: pageIndex,
      bounds: bounds,
      selectedText: selectedText,
      note: note ?? this.note,
      color: color ?? this.color,
      type: type,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageIndex': pageIndex,
        'bounds': {
          'left': bounds.left,
          'top': bounds.top,
          'right': bounds.right,
          'bottom': bounds.bottom,
        },
        'selectedText': selectedText,
        'note': note,
        'color': color.value,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) {
    final b = json['bounds'] as Map;
    return PdfAnnotation(
      id: json['id'],
      pageIndex: json['pageIndex'],
      bounds: Rect.fromLTRB(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['right'] as num).toDouble(),
        (b['bottom'] as num).toDouble(),
      ),
      selectedText: json['selectedText'] ?? '',
      note: json['note'],
      color: Color(json['color'] as int),
      type: AnnotationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AnnotationType.highlight,
      ),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
