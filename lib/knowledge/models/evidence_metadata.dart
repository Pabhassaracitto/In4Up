/// ═══════════════════════════════════════════════════════════════
/// EVIDENCE METADATA — chất lượng bằng chứng (ADR-0017, additive)
///
/// Mastery Vector cần biết BẰNG CHỨNG dùng để tính điểm:
///  * `assistance` — mức độ gợi ý người học (0.0 = không gợi ý, 1.0 =
///    gợi ý tối đa). Dùng cho bất đối xứng patch A′ (ADR-0016):
///    đúng (q ≥ 3) → gate = 1 - assistance; sai (q < 3) → gate = 1.
///  * `confidence` — độ tin cậy bằng chứng (0.0–1.0) → điều chỉnh alpha EMA.
///  * `gradedBy` — "<engine>/<version>" (vd "local-cloze/v1",
///    "ai-sentence/v2") → EMA online/offline không so sánh sai (ADR-0021 §4).
///
/// Additive: KHÔNG thay đổi Evidence/ReviewEvent cũ. Storage: JSON field
/// additive + string box (audit fix MED-4 — repo KHÔNG có hệ typeId số).
/// ═══════════════════════════════════════════════════════════════
library;

/// Metadata gắn vào mỗi event review — chất lượng bằng chứng.
class EvidenceMetadata {
  /// Mức độ gợi ý người học. 0.0 = tự làm, 1.0 = gợi ý toàn phần.
  final double assistance;

  /// Độ tin cậy bằng chứng. 0.0 = không đáng tin, 1.0 = chắc chắn.
  final double confidence;

  /// "<engine>/<version>" — biết điểm tính bởi engine nào (ADR-0021 §4).
  final String gradedBy;

  const EvidenceMetadata({
    required this.assistance,
    required this.confidence,
    required this.gradedBy,
  });

  /// Xây `gradedBy` đúng format — tránh concatenate sai ở call site.
  /// Vd: `EvidenceMetadata.gradedByOf('local-cloze', 'v1')` → "local-cloze/v1".
  static String gradedByOf(String engine, String version) =>
      '$engine/$version';

  /// Metadata chuẩn: không gợi ý, độ tin cao, engine local.
  /// Dùng khi bằng chứng deterministic (inflection/cloze — local-first).
  static const EvidenceMetadata local =
      EvidenceMetadata(assistance: 0.0, confidence: 1.0, gradedBy: 'local/v1');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'assistance': assistance,
        'confidence': confidence,
        'gradedBy': gradedBy,
      };

  factory EvidenceMetadata.fromJson(Map<String, dynamic> json) =>
      EvidenceMetadata(
        assistance: (json['assistance'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        gradedBy: json['gradedBy'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is EvidenceMetadata &&
      other.assistance == assistance &&
      other.confidence == confidence &&
      other.gradedBy == gradedBy;

  @override
  int get hashCode => Object.hash(assistance, confidence, gradedBy);
}
