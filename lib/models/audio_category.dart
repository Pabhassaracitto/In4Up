import 'package:flutter/material.dart';

enum AudioCategory {
  dharma('Content', '☸️', Color(0xFFFFD700)),
  english('Content', '🇬🇧', Color(0xFF4CAF50)),
  meditation('Content', '🧘', Color(0xFF9C27B0)),
  music('Content', '🎵', Color(0xFF2196F3)),
  podcast('Podcast', '🎙️', Color(0xFFFF5722)),
  other('Content', '📁', Color(0xFF9E9E9E));

  const AudioCategory(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;
}