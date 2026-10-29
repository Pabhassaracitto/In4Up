// lib/models/sound_mark.dart
// Soundlist – "Điểm đánh dấu âm thanh" (cue point / bookmark)
//
// Một điểm = một mốc thời gian trong file audio + nhãn + ghi chú + tag + loại.
// Đây là đơn vị nhỏ nhất của Âm mục — tương đương "đánh dấu trang" trong sách.

import 'package:flutter/material.dart';

enum SoundMarkKind {
  important, // ⭐ Quan trọng
  hard, // 💪 Khó
  question, // ❓ Chưa hiểu
  favorite, // ❤️ Yêu thích
  quote, // 💬 Câu hay
  other, // 📌 Khác
}

extension SoundMarkKindX on SoundMarkKind {
  String get label {
    switch (this) {
      case SoundMarkKind.important:
        return 'Quan trọng';
      case SoundMarkKind.hard:
        return 'Khó';
      case SoundMarkKind.question:
        return 'Chưa hiểu';
      case SoundMarkKind.favorite:
        return 'Yêu thích';
      case SoundMarkKind.quote:
        return 'Câu hay';
      case SoundMarkKind.other:
        return 'Khác';
    }
  }

  IconData get icon {
    switch (this) {
      case SoundMarkKind.important:
        return Icons.star_rounded;
      case SoundMarkKind.hard:
        return Icons.fitness_center_rounded;
      case SoundMarkKind.question:
        return Icons.help_outline_rounded;
      case SoundMarkKind.favorite:
        return Icons.favorite_rounded;
      case SoundMarkKind.quote:
        return Icons.format_quote_rounded;
      case SoundMarkKind.other:
        return Icons.push_pin_rounded;
    }
  }

  Color get color {
    switch (this) {
      case SoundMarkKind.important:
        return const Color(0xFFFFB300); // vàng hổ phách
      case SoundMarkKind.hard:
        return const Color(0xFFEF5350); // đỏ
      case SoundMarkKind.question:
        return const Color(0xFF42A5F5); // xanh dương
      case SoundMarkKind.favorite:
        return const Color(0xFFEC407A); // hồng
      case SoundMarkKind.quote:
        return const Color(0xFF66BB6A); // xanh lá
      case SoundMarkKind.other:
        return const Color(0xFF90A4AE); // xám
    }
  }
}

class SoundMark {
  final String id;
  final String audioPath;
  final Duration position;
  String label;
  String? note;
  List<String> tags;
  SoundMarkKind kind;
  final DateTime createdAt;

  SoundMark({
    required this.id,
    required this.audioPath,
    required this.position,
    required this.label,
    this.note,
    this.tags = const [],
    this.kind = SoundMarkKind.other,
    required this.createdAt,
  });

  /// Nhãn mặc định nếu người dùng chưa đặt: chính là mốc thời gian (VD "12:34").
  static String defaultLabel(Duration position) => formatTime(position);

  static String formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  String get timeLabel => formatTime(position);

  SoundMark copyWith({
    String? label,
    String? note,
    List<String>? tags,
    SoundMarkKind? kind,
  }) {
    return SoundMark(
      id: id,
      audioPath: audioPath,
      position: position,
      label: label ?? this.label,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      kind: kind ?? this.kind,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audioPath': audioPath,
      'position': position.inMilliseconds,
      'label': label,
      'note': note,
      'tags': tags,
      'kind': kind.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SoundMark.fromJson(Map<String, dynamic> json) {
    return SoundMark(
      id: json['id'] as String,
      audioPath: json['audioPath'] as String,
      position: Duration(milliseconds: (json['position'] as num).toInt()),
      label: (json['label'] as String?) ?? '',
      note: json['note'] as String?,
      tags: List<String>.from(json['tags'] ?? const []),
      kind: SoundMarkKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => SoundMarkKind.other,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
