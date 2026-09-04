import 'package:flutter/foundation.dart';

/// Chế độ hiển thị chữ trong Live Cabin (theo WP1 / PLAN-008).
enum CabinDisplayMode {
  /// 1 chữ hiện thời (Focus karaoke word)
  oneWord,

  /// 1 dòng hiện thời (Single sentence line)
  oneLine,

  /// Toàn bộ lịch sử hội thoại (Full rolling transcript)
  fullTranscript,
}

/// Trạng thái hoạt động của Live Cabin STS.
enum CabinState {
  idle,
  listening,
  translating,
  speaking,
  paused,
  error,
}

/// Một phân đoạn phụ đề song ngữ trong phiên dịch Cabin.
@immutable
class CabinCaption {
  final String id;
  final DateTime timestamp;
  final String sourceText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final String engineUsed;
  final bool isFinal;
  final bool isSpeaking;

  const CabinCaption({
    required this.id,
    required this.timestamp,
    required this.sourceText,
    this.translatedText = '',
    required this.sourceLang,
    required this.targetLang,
    this.engineUsed = '',
    this.isFinal = false,
    this.isSpeaking = false,
  });

  CabinCaption copyWith({
    String? id,
    DateTime? timestamp,
    String? sourceText,
    String? translatedText,
    String? sourceLang,
    String? targetLang,
    String? engineUsed,
    bool? isFinal,
    bool? isSpeaking,
  }) {
    return CabinCaption(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      sourceText: sourceText ?? this.sourceText,
      translatedText: translatedText ?? this.translatedText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      engineUsed: engineUsed ?? this.engineUsed,
      isFinal: isFinal ?? this.isFinal,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  @override
  String toString() =>
      'CabinCaption(id: $id, src: "$sourceText", tgt: "$translatedText", final: $isFinal)';
}
