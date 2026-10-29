//phoneme_models.dart
// NEW - Mô hình dữ liệu cho phiên âm, bao gồm cả phiên âm IPA và CMU
// lib/models/phoneme_models.dart

import 'package:flutter/material.dart';

/// Nguồn dữ liệu IPA
enum PhonemeSource {
  cmuDictionary, // Từ CMU Dict (chính xác 100%)
  g2pRules, // Từ rules (chính xác ~80%)
  g2pML, // Từ ML model (chính xác ~90%)
}

/// Loại phoneme
enum PhonemeType {
  vowel,
  consonant,
  diphthong,
}

/// Trạng thái đánh giá phoneme
enum PhonemeStatus {
  correct, // >= 85%
  acceptable, // 70-85%
  needsWork, // 50-70%
  missed, // < 50% hoặc không phát âm
}

/// Trạng thái từ
enum WordStatus {
  correct,
  substituted,
  missed,
}

/// Thông tin chi tiết một phoneme
class PhonemeInfo {
  final String symbol;
  final PhonemeType type;
  final int position;
  final bool isStressed;
  final String description;
  final List<String> examples;

  const PhonemeInfo({
    required this.symbol,
    required this.type,
    required this.position,
    this.isStressed = false,
    this.description = '',
    this.examples = const [],
  });

  Color get typeColor {
    switch (type) {
      case PhonemeType.vowel:
        return const Color(0xFFFF5722);
      case PhonemeType.consonant:
        return const Color(0xFF2196F3);
      case PhonemeType.diphthong:
        return const Color(0xFF9C27B0);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case PhonemeType.vowel:
        return Icons.circle;
      case PhonemeType.consonant:
        return Icons.blur_circular;
      case PhonemeType.diphthong:
        return Icons.trip_origin;
    }
  }
}

/// Kết quả phân tích phonemes của một từ
class PhonemeResult {
  final String word;
  final List<String> phonemes;
  final PhonemeSource source;
  final double confidence;

  const PhonemeResult({
    required this.word,
    required this.phonemes,
    required this.source,
    required this.confidence,
  });

  String get ipaString => '/${phonemes.join(".")}/';

  bool get isFromDictionary => source == PhonemeSource.cmuDictionary;
}

/// Điểm số một phoneme
class PhonemeScore {
  final String phoneme;
  final PhonemeType type;
  final double score; // 0.0 - 1.0
  final PhonemeStatus status;
  final String? feedback;

  const PhonemeScore({
    required this.phoneme,
    required this.type,
    required this.score,
    required this.status,
    this.feedback,
  });

  int get scorePercent => (score * 100).round();

  Color get scoreColor {
    if (score >= 0.85) return const Color(0xFF4CAF50);
    if (score >= 0.70) return const Color(0xFFFFB300);
    if (score >= 0.50) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String get grade {
    if (score >= 0.95) return 'A+';
    if (score >= 0.90) return 'A';
    if (score >= 0.85) return 'B+';
    if (score >= 0.80) return 'B';
    if (score >= 0.75) return 'C+';
    if (score >= 0.70) return 'C';
    if (score >= 0.60) return 'D';
    return 'F';
  }
}

/// Kết quả từ
class WordResult {
  final String expectedWord;
  final String? recognizedWord;
  final WordStatus status;
  final double score;
  final List<PhonemeScore> phonemeScores;
  final PhonemeResult? phonemeResult;

  const WordResult({
    required this.expectedWord,
    this.recognizedWord,
    required this.status,
    required this.score,
    required this.phonemeScores,
    this.phonemeResult,
  });

  int get scorePercent => (score * 100).round();
}

/// Phân tích acoustic
class AcousticAnalysis {
  final double pitchScore;
  final double energyScore;
  final double rhythmScore;
  final double spectralScore;

  const AcousticAnalysis({
    required this.pitchScore,
    required this.energyScore,
    required this.rhythmScore,
    required this.spectralScore,
  });

  double get overallScore =>
      (pitchScore + energyScore + rhythmScore + spectralScore) / 4;
}
