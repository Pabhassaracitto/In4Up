import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';

void main() {
  group('KnowledgeUnit — schema mục 2.1', () {
    test(
        '2 unit cùng chữ khác nghĩa ⇒ 2 unitId khác nhau (KHÔNG tự merge, chỉ gợi ý)',
        () {
      final a = KnowledgeUnit.create(
        kind: KnowledgeUnitKind.word,
        canonicalForm: 'bank',
        senseNote: 'bờ sông',
        now: DateTime.utc(2026, 1, 1),
      );
      final b = KnowledgeUnit.create(
        kind: KnowledgeUnitKind.word,
        canonicalForm: 'bank',
        senseNote: 'tổ chức tài chính',
        now: DateTime.utc(2026, 1, 1),
      );

      expect(a.unitId, isNot(b.unitId));
      // Trùng canonicalForm ⇒ chỉ GỢI Ý merge, người dùng phải xác nhận:
      expect(a.isMergeCandidateWith(b), isTrue);
    });

    test('isMergeCandidateWith: tự mình ⇒ false; khác chữ ⇒ false', () {
      final a = KnowledgeUnit.create(
          kind: KnowledgeUnitKind.word, canonicalForm: 'bank');
      final c = KnowledgeUnit.create(
          kind: KnowledgeUnitKind.word, canonicalForm: 'river');

      expect(a.isMergeCandidateWith(a), isFalse);
      expect(a.isMergeCandidateWith(c), isFalse);
    });

    test('AT4: đổi tokenizer/normalize KHÔNG làm đổi unitId', () {
      final old = KnowledgeUnit(
        unitId: 'unit-fixed-0001',
        kind: KnowledgeUnitKind.word,
        canonicalForm: "don't",
        surfaceForms: const ["don't"],
        createdAt: DateTime.utc(2025, 6, 1),
        updatedAt: DateTime.utc(2025, 6, 1),
      );

      // Tokenizer v2 normalize khác — chỉ đổi canonicalForm/surfaceForms:
      final migrated = old.copyWith(
        canonicalForm: 'dont',
        surfaceForms: const ['dont', "don't"],
        updatedAt: DateTime.utc(2026, 8, 19),
      );

      expect(migrated.unitId, old.unitId);
      expect(migrated.canonicalForm, 'dont');
      // History cũ vẫn đọc được vì id không đổi:
      expect(migrated == old, isTrue, reason: '== theo unitId');
    });

    test('withSurfaceForm: dedupe chính xác + không đột biến base', () {
      final base = KnowledgeUnit(
        unitId: 'u1',
        kind: KnowledgeUnitKind.word,
        canonicalForm: 'run',
        surfaceForms: const ['run'],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final added = base.withSurfaceForm('Running');
      expect(added.surfaceForms, ['run', 'Running']);

      final dup = added.withSurfaceForm('Running');
      expect(identical(dup, added), isTrue,
          reason: 'form đã tồn tại ⇒ trả lại chính nó');

      expect(base.surfaceForms, ['run'], reason: 'base không bị đột biến');
    });

    test('JSON round-trip giữ nguyên mọi field', () {
      final unit = KnowledgeUnit.create(
        kind: KnowledgeUnitKind.phrase,
        canonicalForm: 'take off',
        surfaceForm: 'take off',
        senseNote: 'máy bay cất cánh',
        now: DateTime.utc(2026, 3, 15, 8, 30),
      );

      final clone = KnowledgeUnit.fromJson(unit.toJson());

      expect(clone.toJson(), equals(unit.toJson()));
      expect(clone, equals(unit));
    });

    test('fromJson với kind lạ ⇒ FormatException (fail loud, không im lặng)', () {
      final json = <String, dynamic>{
        'unitId': 'u9',
        'kind': 'galaxy',
        'canonicalForm': 'x',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      expect(() => KnowledgeUnit.fromJson(json), throwsFormatException);
    });
  });
}
