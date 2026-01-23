import 'package:flutter/material.dart';

/// Marker là một điểm hoặc đoạn trên waveform
class AudioMarker {
  final String id;
  final Duration startTime;
  Duration? endTime; // null = điểm, có giá trị = đoạn
  String label;
  Color color;
  MarkerType type;
  final DateTime createdAt;

  AudioMarker({
    required this.id,
    required this.startTime,
    this.endTime,
    this.label = '',
    this.color = const Color(0xFF6C63FF),
    this.type = MarkerType.point,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Đây là điểm hay đoạn?
  bool get isPoint => endTime == null;
  bool get isRegion => endTime != null;

  /// Thời lượng của đoạn
  Duration? get duration {
    if (endTime == null) return null;
    return endTime! - startTime;
  }

  /// Copy với các giá trị mới
  AudioMarker copyWith({
    String? id,
    Duration? startTime,
    Duration? endTime,
    String? label,
    Color? color,
    MarkerType? type,
  }) {
    return AudioMarker(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      label: label ?? this.label,
      color: color ?? this.color,
      type: type ?? this.type,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.inMilliseconds,
      'endTime': endTime?.inMilliseconds,
      'label': label,
      'color': color.value,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AudioMarker.fromJson(Map<String, dynamic> json) {
    return AudioMarker(
      id: json['id'],
      startTime: Duration(milliseconds: json['startTime']),
      endTime: json['endTime'] != null
          ? Duration(milliseconds: json['endTime'])
          : null,
      label: json['label'] ?? '',
      color: Color(json['color'] ?? 0xFF6C63FF),
      type: MarkerType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => MarkerType.point,
      ),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

enum MarkerType {
  point,      // Điểm đánh dấu
  region,     // Đoạn
  word,       // Từ (cho transcript)
  sentence,   // Câu
  difficult,  // Đoạn khó
  important,  // Quan trọng
}

extension MarkerTypeExtension on MarkerType {
  String get displayName {
    switch (this) {
      case MarkerType.point: return 'Điểm';
      case MarkerType.region: return 'Đoạn';
      case MarkerType.word: return 'Từ';
      case MarkerType.sentence: return 'Câu';
      case MarkerType.difficult: return 'Khó';
      case MarkerType.important: return 'Quan trọng';
    }
  }

  Color get defaultColor {
    switch (this) {
      case MarkerType.point: return const Color(0xFF6C63FF);
      case MarkerType.region: return const Color(0xFF4CAF50);
      case MarkerType.word: return const Color(0xFF2196F3);
      case MarkerType.sentence: return const Color(0xFFFF9800);
      case MarkerType.difficult: return const Color(0xFFF44336);
      case MarkerType.important: return const Color(0xFFFFD700);
    }
  }

  IconData get icon {
    switch (this) {
      case MarkerType.point: return Icons.location_on;
      case MarkerType.region: return Icons.select_all;
      case MarkerType.word: return Icons.text_fields;
      case MarkerType.sentence: return Icons.short_text;
      case MarkerType.difficult: return Icons.warning;
      case MarkerType.important: return Icons.star;
    }
  }
}