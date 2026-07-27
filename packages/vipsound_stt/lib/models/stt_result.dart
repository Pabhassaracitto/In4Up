// VipSound v11.0 — Immutable transcript model
// KHÔNG chứa speakerId — diarization là overlay riêng

import 'content_id.dart';

class SttWord {
  final String word;
  final double startSeconds;
  final double endSeconds;
  final double confidence;

  const SttWord({
    required this.word,
    required this.startSeconds,
    required this.endSeconds,
    this.confidence = 1.0,
  });

  Duration get startDuration =>
      Duration(milliseconds: (startSeconds * 1000).round());
  Duration get endDuration =>
      Duration(milliseconds: (endSeconds * 1000).round());

  Map<String, dynamic> toJson() => {
        'word': word,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'confidence': confidence,
      };

  factory SttWord.fromJson(Map<String, dynamic> j) => SttWord(
        word: j['word'] as String,
        startSeconds: (j['startSeconds'] as num).toDouble(),
        endSeconds: (j['endSeconds'] as num).toDouble(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  String toString() =>
      'SttWord("$word", ${startSeconds.toStringAsFixed(2)}s-'
      '${endSeconds.toStringAsFixed(2)}s)';
}

class SttSegment {
  final int id;

  /// Content-Anchored UID — bất biến dù layout thay đổi
  final String uid;

  final double startSeconds;
  final double endSeconds;
  final String text;

  /// Rỗng nếu engine không hỗ trợ word-level timestamps
  /// (Meetily Rust → words = [])
  final List<SttWord> words;

  final double avgConfidence;

  SttSegment({
    required this.id,
    required this.uid,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    required this.words,
    required this.avgConfidence,
  });

  int get startMs => (startSeconds * 1000).round();
  int get endMs => (endSeconds * 1000).round();

  /// Join key để liên kết với SpeakerAnnotation sidecar
  String get joinKey =>
      ContentId.joinKey(startMs: startMs, text: text);

  Duration get startDuration => Duration(milliseconds: startMs);
  Duration get endDuration => Duration(milliseconds: endMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'text': text,
        'avgConfidence': avgConfidence,
        'words': words.map((w) => w.toJson()).toList(),
      };

  factory SttSegment.fromJson(
    Map<String, dynamic> j,
    String audioFingerprint,
  ) {
    final text = j['text'] as String;
    final startSec = (j['startSeconds'] as num).toDouble();
    final startMs = (startSec * 1000).round();

    return SttSegment(
      id: j['id'] as int,
      uid: j['uid'] as String? ??
          ContentId.segmentUid(
            audioFingerprint: audioFingerprint,
            startMs: startMs,
            text: text,
          ),
      startSeconds: startSec,
      endSeconds: (j['endSeconds'] as num).toDouble(),
      text: text,
      avgConfidence: (j['avgConfidence'] as num).toDouble(),
      words: (j['words'] as List<dynamic>? ?? [])
          .map((w) => SttWord.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() =>
      'SttSegment(id=$id, uid=$uid, '
      '${startSeconds.toStringAsFixed(2)}s-'
      '${endSeconds.toStringAsFixed(2)}s, '
      '"${text.length > 30 ? '${text.substring(0, 30)}…' : text}")';
}

class SttResult {
  final String fullText;
  final List<SttSegment> segments;
  final SttEngineType engineUsed;
  final String language;
  final Duration processingTime;
  final bool hasWordTimestamps;

  /// Audio fingerprint — cần để tạo UID cross-file
  final String audioFingerprint;

  const SttResult({
    required this.fullText,
    required this.segments,
    required this.engineUsed,
    required this.language,
    required this.processingTime,
    required this.audioFingerprint,
    this.hasWordTimestamps = false,
  });

  List<SttWord> get allWords =>
      segments.expand((s) => s.words).toList();

  static SttResult empty(SttEngineType engine) => SttResult(
        fullText: '',
        segments: const [],
        engineUsed: engine,
        language: 'en',
        processingTime: Duration.zero,
        audioFingerprint: '',
      );

  @override
  String toString() =>
      'SttResult(engine=$engineUsed, segments=${segments.length}, '
      'words=${allWords.length}, fp=$audioFingerprint)';
}

enum SttEngineType { native, whisper }
