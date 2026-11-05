/// ═══════════════════════════════════════════════════════════════
/// CONCEPT NODE — Nút Khái niệm đa ngữ (PLAN-043 mục 1, ADR-0023)
///
/// Một khái niệm KHÔNG thuộc ngôn ngữ nào (neo bằng định nghĩa trục +
/// ảnh/animation dùng chung); mỗi `WordEntry` của từng ngôn ngữ nối vào
/// bằng `WordEntry.conceptId`. Bất biến (đọc ADR-0023 trước khi sửa):
///  * `id` UUID v4 bất biến, KHÔNG dẫn xuất từ nội dung.
///  * KHÔNG chứa điểm SM-2 — điểm nằm ở từng WordEntry (quy tắc vàng #2).
///  * JSON đọc chịu thiếu trường; ghi bỏ qua trường rỗng (additive).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:uuid/uuid.dart';

/// Loại quan hệ giữa hai khái niệm (Pha A chỉ lưu/đọc; UI ở Pha E).
enum ConceptRelationType { isA, partOf, opposite, related }

class ConceptRelation {
  final ConceptRelationType type;
  final String conceptId;

  const ConceptRelation({required this.type, required this.conceptId});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'conceptId': conceptId,
      };

  factory ConceptRelation.fromJson(Map<String, dynamic> json) {
    var type = ConceptRelationType.related;
    for (final t in ConceptRelationType.values) {
      if (t.name == json['type']) type = t;
    }
    return ConceptRelation(
      type: type,
      conceptId: (json['conceptId'] ?? '').toString(),
    );
  }
}

/// Một nút khái niệm. Mutable theo lối `WordEntry` (sửa tại chỗ + persist
/// qua provider) để khớp thói quen của codebase; `id`/`createdAt` bất biến.
class ConceptNode {
  final String id;

  /// Định nghĩa trục ngắn (pivot gloss) — ngôn ngữ do người dùng chọn khi
  /// viết; chỉ là nhãn hiển thị, KHÔNG phải khoá nối.
  String gloss;

  /// Miền nghĩa tự do (vd 'động vật', 'hành động') — lọc/nhóm hiển thị.
  String? domain;

  /// Ảnh/animation DÙNG CHUNG của khái niệm (relative path local hoặc URL,
  /// cùng ngữ nghĩa `WordEntry.imageUrl`). Entry có ảnh riêng vẫn thắng
  /// khi hiển thị entry đó (ADR-0023 mục 2.3).
  String? imageRef;

  List<ConceptRelation> relations;

  /// Mã tri thức ngoài (Pha D: wikidata Q…, conceptnet…) — chỉ làm gợi ý/
  /// chứng minh nguồn, không bao giờ là khoá chính.
  Map<String, String> externalIds;

  final DateTime createdAt;
  DateTime updatedAt;

  ConceptNode({
    required this.id,
    this.gloss = '',
    this.domain,
    this.imageRef,
    List<ConceptRelation>? relations,
    Map<String, String>? externalIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : relations = relations ?? <ConceptRelation>[],
        externalIds = externalIds ?? <String, String>{},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  factory ConceptNode.create({
    String gloss = '',
    String? domain,
    String? imageRef,
  }) {
    final now = DateTime.now();
    return ConceptNode(
      id: const Uuid().v4(),
      gloss: gloss,
      domain: domain,
      imageRef: imageRef,
      createdAt: now,
      updatedAt: now,
    );
  }

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'gloss': gloss,
        if (domain != null && domain!.trim().isNotEmpty) 'domain': domain,
        if (imageRef != null && imageRef!.trim().isNotEmpty)
          'imageRef': imageRef,
        if (relations.isNotEmpty)
          'relations': relations.map((r) => r.toJson()).toList(),
        if (externalIds.isNotEmpty) 'externalIds': externalIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Đọc JSON chịu thiếu/sai kiểu từng trường — không ném vì một bản ghi lạ
  /// (chỉ `id` là bắt buộc; thiếu `id` coi như bản ghi hỏng và ném để phía
  /// tải bỏ qua đúng một bản ghi đó, như tiền lệ WordEntry corrupt-skip).
  factory ConceptNode.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('ConceptNode thiếu id');
    }
    DateTime parseDate(dynamic v, DateTime fallback) {
      if (v is String) {
        return DateTime.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    final now = DateTime.now();
    final created = parseDate(json['createdAt'], now);
    final relations = <ConceptRelation>[];
    final rawRelations = json['relations'];
    if (rawRelations is List) {
      for (final item in rawRelations) {
        if (item is Map) {
          relations.add(
              ConceptRelation.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final externalIds = <String, String>{};
    final rawExt = json['externalIds'];
    if (rawExt is Map) {
      rawExt.forEach((k, v) {
        if (v != null) externalIds[k.toString()] = v.toString();
      });
    }
    String? pickNullable(String key) {
      final v = json[key]?.toString().trim() ?? '';
      return v.isEmpty ? null : v;
    }

    return ConceptNode(
      id: id,
      gloss: json['gloss']?.toString() ?? '',
      domain: pickNullable('domain'),
      imageRef: pickNullable('imageRef'),
      relations: relations,
      externalIds: externalIds,
      createdAt: created,
      updatedAt: parseDate(json['updatedAt'], created),
    );
  }

  @override
  String toString() => 'ConceptNode($id, "$gloss")';
}
