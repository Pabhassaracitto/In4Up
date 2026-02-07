// lib/models/text_segment.dart
import 'dart:ui';
import 'package:equatable/equatable.dart';

class TextSegment extends Equatable {
  final String id;
  final String name;
  final int startLine;
  final int endLine;
  final Color color;
  final String? note;
  final DateTime createdAt;
  final int repeatCount;

  const TextSegment({
    required this.id,
    required this.name,
    required this.startLine,
    required this.endLine,
    required this.color,
    this.note,
    required this.createdAt,
    this.repeatCount = 0,
  });

  int get lineCount => endLine - startLine + 1;

  TextSegment copyWith({
    String? id,
    String? name,
    int? startLine,
    int? endLine,
    Color? color,
    String? note,
    DateTime? createdAt,
    int? repeatCount,
  }) {
    return TextSegment(
      id: id ?? this.id,
      name: name ?? this.name,
      startLine: startLine ?? this.startLine,
      endLine: endLine ?? this.endLine,
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      repeatCount: repeatCount ?? this.repeatCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startLine': startLine,
      'endLine': endLine,
      'color': color.value,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'repeatCount': repeatCount,
    };
  }

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      id: json['id'] as String,
      name: json['name'] as String,
      startLine: json['startLine'] as int,
      endLine: json['endLine'] as int,
      color: Color(json['color'] as int),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      repeatCount: json['repeatCount'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        startLine,
        endLine,
        color.value,
        note,
        createdAt,
        repeatCount,
      ];
}
