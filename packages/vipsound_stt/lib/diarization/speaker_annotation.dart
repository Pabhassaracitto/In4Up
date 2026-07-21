// VipSound v11.0 — Diarization overlay (không mutate SttSegment)

class SpeakerAnnotation {
  /// = SttSegment.uid — Content-Anchored
  final String segmentUid;

  /// = startMs|textNorm — bridge LRC ↔ sidecar khi không có uid
  final String joinKey;

  /// 0 = unknown, 1+ = speaker index
  final int speakerId;

  /// 0.0–1.0
  final double confidence;

  /// 'heuristic' | 'meetily_rust'
  final String engine;

  final String pipelineVersion;

  const SpeakerAnnotation({
    required this.segmentUid,
    required this.joinKey,
    required this.speakerId,
    required this.confidence,
    required this.engine,
    this.pipelineVersion = 'diar-v11',
  });

  Map<String, dynamic> toJson() => {
        'segmentUid': segmentUid,
        'joinKey': joinKey,
        'speakerId': speakerId,
        'confidence': confidence,
        'engine': engine,
        'pipelineVersion': pipelineVersion,
      };

  factory SpeakerAnnotation.fromJson(Map<String, dynamic> j) =>
      SpeakerAnnotation(
        segmentUid: j['segmentUid'] as String,
        joinKey: j['joinKey'] as String,
        speakerId: j['speakerId'] as int? ?? 0,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        engine: j['engine'] as String? ?? 'heuristic',
        pipelineVersion:
            j['pipelineVersion'] as String? ?? 'diar-v11',
      );

  @override
  String toString() =>
      'SpeakerAnnotation(uid=$segmentUid, '
      'speaker=$speakerId, conf=${confidence.toStringAsFixed(2)}, '
      'engine=$engine)';
}
