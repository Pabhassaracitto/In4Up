/// ═══════════════════════════════════════════════════════════════
/// KNOWLEDGE UNIT — đơn vị tri thức bất biến
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — schema mục 2.1.
///
/// Quy tắc cứng (KHÔNG được vi phạm khi bảo trì):
///  * `unitId` sinh ngẫu nhiên (UUID v4), KHÔNG dẫn xuất từ raw text
///    ⇒ đổi tokenizer KHÔNG làm đổi unitId (AT4 — mục 9).
///  * Trùng `canonicalForm` KHÔNG tự động merge — chỉ là "đề xuất trùng"
///    (`isMergeCandidateWith`) cho người dùng xác nhận.
///  * Merge/split phải hoàn tác được — xem `MergeSplitService` +
///    `UnitMergeRecord` (models/merge_record.dart).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:uuid/uuid.dart';

/// Loại đơn vị tri thức.
enum KnowledgeUnitKind { word, phrase, sentence, paragraph, note }

class KnowledgeUnit {
  /// ID bất biến — KHÔNG đổi sau khi tạo, KHÔNG sinh từ raw text,
  /// KHÔNG dùng canonicalForm làm primary key.
  final String unitId;

  final KnowledgeUnitKind kind;

  /// Dạng chuẩn — chỉ dùng để TÌM candidate trùng, không phải khóa.
  final String canonicalForm;

  /// Các biến thể chữ viết đã gặp (giữ nguyên như gặp: viết hoa, số nhiều…).
  final List<String> surfaceForms;

  final String language;

  /// Phân biệt nghĩa khi 2 unit cùng chữ
  /// (vd "bank" ngân hàng vs "bank" bờ sông ⇒ 2 unitId, senseNote khác nhau).
  final String? senseNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  KnowledgeUnit({
    required this.unitId,
    required this.kind,
    required this.canonicalForm,
    List<String>? surfaceForms,
    this.language = 'en',
    this.senseNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : surfaceForms = List.unmodifiable(surfaceForms ?? const <String>[]),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  /// Tạo unit mới với unitId ngẫu nhiên (UUID v4 — không phụ thuộc nội dung).
  factory KnowledgeUnit.create({
    required KnowledgeUnitKind kind,
    required String canonicalForm,
    String? surfaceForm,
    String language = 'en',
    String? senseNote,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return KnowledgeUnit(
      unitId: const Uuid().v4(),
      kind: kind,
      canonicalForm: canonicalForm,
      surfaceForms:
          surfaceForm == null ? const <String>[] : <String>[surfaceForm],
      language: language,
      senseNote: senseNote,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Thêm một surface form mới (dedupe chính xác, trim khoảng trắng).
  /// Trả về bản copy — không đột biến `this`.
  KnowledgeUnit withSurfaceForm(String form) {
    final trimmed = form.trim();
    if (trimmed.isEmpty || surfaceForms.contains(trimmed)) return this;
    return KnowledgeUnit(
      unitId: unitId,
      kind: kind,
      canonicalForm: canonicalForm,
      surfaceForms: [...surfaceForms, trimmed],
      language: language,
      senseNote: senseNote,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Đề xuất merge: KHÔNG tự động gộp — chỉ gợi ý cho người dùng xác nhận
  /// (quy tắc cứng mục 2.1: trùng canonicalForm KHÔNG tự merge).
  bool isMergeCandidateWith(KnowledgeUnit other) {
    if (unitId == other.unitId) return false;
    return canonicalForm.trim().toLowerCase() ==
        other.canonicalForm.trim().toLowerCase();
  }

  KnowledgeUnit copyWith({
    KnowledgeUnitKind? kind,
    String? canonicalForm,
    List<String>? surfaceForms,
    String? language,
    String? senseNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnowledgeUnit(
      unitId: unitId,
      kind: kind ?? this.kind,
      canonicalForm: canonicalForm ?? this.canonicalForm,
      surfaceForms: surfaceForms ?? this.surfaceForms,
      language: language ?? this.language,
      senseNote: senseNote ?? this.senseNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Đồng nhất theo unitId: cùng unitId ⇒ cùng một đơn vị tri thức
  /// (dùng cho so khớp khi lưu trữ/sync, không so field — field đổi theo thời gian).
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is KnowledgeUnit && other.unitId == unitId);
  }

  @override
  int get hashCode => unitId.hashCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'kind': kind.name,
        'canonicalForm': canonicalForm,
        'surfaceForms': surfaceForms,
        'language': language,
        'senseNote': senseNote,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory KnowledgeUnit.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String;
    return KnowledgeUnit(
      unitId: json['unitId'] as String,
      kind: KnowledgeUnitKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () =>
            throw FormatException('KnowledgeUnitKind không hợp lệ: $kindName'),
      ),
      canonicalForm: json['canonicalForm'] as String,
      surfaceForms:
          (json['surfaceForms'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      language: json['language'] as String? ?? 'en',
      senseNote: json['senseNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'KnowledgeUnit($unitId, ${kind.name}, "$canonicalForm")';
}
// trigger CI
// fix lint
