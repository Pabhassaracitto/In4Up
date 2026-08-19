// Test Migration Adapter — Task 3 DoD (mục 8):
//   "Chạy trên 100% dữ liệu test hiện có, không mất từ nào,
//    review due date không đổi bất ngờ."
//
// LƯU Ý: KHÔNG import trực tiếp skill_review_data.dart — SkillReviewData
// lấy qua export của word_entry.dart (tránh tổ hợp import từng làm CI
// analyzer gãy — xem postmortem bisect B1–B7 trong word_entry_migrator.dart).

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/migration/word_entry_migrator.dart';
import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';

SkillReviewData _skill({
  double easeFactor = 2.2,
  int interval = 6,
  int repetitions = 2,
  DateTime? nextReview,
  int totalReviews = 4,
}) {
  return SkillReviewData(
    easeFactor: easeFactor,
    interval: interval,
    repetitions: repetitions,
    nextReview: nextReview,
    totalReviews: totalReviews,
    correctReviews: 3,
  );
}

WordEntry _entry(
  String id,
  String word, {
  List<VocabContext>? contexts,
  SkillReviewData? u,
  SkillReviewData? l,
  SkillReviewData? r,
  bool unborn = false,
  List<String>? tags,
  String? topic,
  VocabularyType? vocabType,
}) {
  return WordEntry(
    id: id,
    word: word,
    meaning: 'nghĩa của $word',
    understandData: u,
    listenData: l,
    readData: r,
    lastReviewed: DateTime.utc(2026, 2, 20, 9),
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 2, 20, 9),
    contexts: contexts,
    isUnborn: unborn,
    tags: tags,
    topic: topic,
    vocabType: vocabType,
  );
}

void main() {
  final at = DateTime.utc(2026, 8, 20, 12);

  group('WordEntryMigrator — DoD Task 3', () {
    test('1:1 KHÔNG MẤT TỪ NÀO — mọi id cũ thành unitId (giữ FK lịch sử)', () {
      final result = WordEntryMigrator.migrate(
        [
          _entry('v_100_0', 'bank'),
          _entry('v_200_1', 'river'),
          _entry('w_300_2', 'run'),
        ],
        now: at,
      );

      expect(result.report.isLossless, isTrue);
      expect(result.report.inputCount, 3);
      expect(result.report.unitsCreated, 3);
      expect(result.report.statesCreated, 3);
      expect(
        result.units.map((u) => u.unitId).toSet(),
        {'v_100_0', 'v_200_1', 'w_300_2'},
      );
    });

    test('AT2: cùng chữ khác nghĩa ⇒ 2 unit riêng biệt, chỉ GỢI Ý merge', () {
      final result = WordEntryMigrator.migrate(
        [
          _entry('v_1_0', 'bank', topic: 'bờ sông'),
          _entry('v_2_0', 'bank', topic: 'ngân hàng'),
        ],
        now: at,
      );

      expect(result.units.length, 2);
      expect(result.units[0].unitId, isNot(result.units[1].unitId));
      expect(result.units[0].isMergeCandidateWith(result.units[1]), isTrue);
    });

    test(
        'VocabContext ⇒ Evidence: đủ số lượng, đúng FK, hash/locator reopen được',
        () {
      final contexts = <VocabContext>[
        VocabContext(
          id: 'ctx_pdf',
          sourceType: 'pdf',
          sourceName: 'ML_101.pdf',
          pageOrPosition: 'trang 42',
          sourceRef: '/docs/ML_101.pdf',
          sourceRefType: 'pdfPath',
          surroundingText: 'The bank of the river was muddy.',
          encounteredAt: DateTime.utc(2026, 2, 1),
          pageIndexHint: 42,
          rectHint: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.05),
        ),
        VocabContext(
          id: 'ctx_web',
          sourceType: 'web',
          sourceName: 'example.com/article',
          sourceRef: 'https://example.com/article',
          sourceRefType: 'webUrl',
          surroundingText: 'He sat on the river bank.',
          encounteredAt: DateTime.utc(2026, 2, 5),
          scrollProgressHint: 0.42,
        ),
        VocabContext(
          id: 'ctx_yt',
          sourceType: 'youtube',
          sourceName: 'TED Talk',
          sourceRef: 'https://youtu.be/abc',
          sourceRefType: 'webUrl',
          pageOrPosition: '02:15',
          surroundingText: 'the muddy bank of the river',
          encounteredAt: DateTime.utc(2026, 2, 9),
        ),
      ];
      final result = WordEntryMigrator.migrate(
          [_entry('v_9_0', 'bank', contexts: contexts)],
          now: at);

      expect(result.evidence.length, 3);
      expect(result.report.evidenceCreated, 3);
      for (final e in result.evidence) {
        expect(e.unitId, 'v_9_0', reason: 'FK phải trỏ đúng unit');
        // snapshotHash khớp excerpt ⇒ reopen có thể phát hiện nguồn đổi:
        expect(e.verifyAgainst(e.excerpt), isTrue);
      }

      final pdf = result.evidence[0];
      expect(pdf.sourceType, EvidenceSourceType.pdf);
      expect(pdf.locator.page, 42);
      expect(pdf.locator.rect,
          const LocatorRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05));

      final web = result.evidence[1];
      expect(web.sourceType, EvidenceSourceType.web);
      expect(web.locator.url, 'https://example.com/article');
      expect(web.locator.scrollPercent, closeTo(42.0, 0.001));

      final yt = result.evidence[2];
      expect(yt.sourceType, EvidenceSourceType.youtube);
      expect(yt.locator.timestampStart, 135.0); // 02:15

      // Producer version bắt buộc — truy vết được nguồn gốc dữ liệu:
      expect(pdf.producerVersion.extractorVersion, 'migration-1');
    });

    test(
        'DUE DATE KHÔNG ĐỔI: snapshot byte-đồng nhất nextReview cũ cả 3 skill',
        () {
      final u = _skill(
          easeFactor: 2.4,
          interval: 3,
          repetitions: 1,
          nextReview: DateTime.utc(2026, 9, 1));
      final l = _skill(
          easeFactor: 1.8,
          interval: 21,
          repetitions: 4,
          nextReview: DateTime.utc(2026, 8, 25));
      final r = _skill(totalReviews: 0); // chưa từng review lần nào

      final result = WordEntryMigrator.migrate(
          [_entry('v_due_0', 'bank', u: u, l: l, r: r)],
          now: at);
      final state = result.states.single;

      expect(state.understanding.dueDate, u.nextReview);
      expect(state.understanding.easeFactor, 2.4);
      expect(state.understanding.interval, 3);
      expect(state.understanding.repetitions, 1);

      expect(state.listening.dueDate, l.nextReview);
      expect(state.listening.easeFactor, 1.8);
      expect(state.listening.interval, 21);

      // Chưa từng review (nextReview null) = "due ngay" ⇒ due = mốc migration:
      expect(r.nextReview, isNull);
      expect(state.reading.dueDate, at);
      expect(state.reading.lastReviewedAt, isNull);
      expect(state.understanding.lastReviewedAt, DateTime.utc(2026, 2, 20, 9));

      // 3 skill vẫn TÁCH BIỆT sau migration:
      expect(state.understanding.dueDate, isNot(state.listening.dueDate));
    });

    test('THUẦN: không đột biến dữ liệu cũ (KHÔNG xóa/sửa WordEntry nguồn)', () {
      final entries = [
        _entry('v_pure_0', 'bank', tags: ['finance'], topic: 'money'),
      ];
      final before = entries.map((e) => e.toJson()).toList();

      WordEntryMigrator.migrate(entries, now: at);

      expect(entries.map((e) => e.toJson()).toList(), equals(before));
    });

    test('IDEMPOTENT: chạy 2 lần cho kết quả giống hệt', () {
      final entries = [
        _entry('v_idem_0', 'bank', contexts: [
          VocabContext(
            id: 'ctx_1',
            sourceType: 'pdf',
            sourceName: 'a.pdf',
            surroundingText: 'text',
            encounteredAt: DateTime.utc(2026, 2, 1),
          ),
        ]),
      ];

      final r1 = WordEntryMigrator.migrate(entries, now: at);
      final r2 = WordEntryMigrator.migrate(entries, now: at);

      expect(r2.units.map((u) => u.toJson()).toList(),
          equals(r1.units.map((u) => u.toJson()).toList()));
      expect(r2.evidence.map((e) => e.toJson()).toList(),
          equals(r1.evidence.map((e) => e.toJson()).toList()));
      expect(r2.states.map((s) => s.toJson()).toList(),
          equals(r1.states.map((s) => s.toJson()).toList()));
    });

    test('ID trùng (dữ liệu lỗi) ⇒ remap UUID, không vỡ FK, ghi report', () {
      var counter = 0;
      final result = WordEntryMigrator.migrate(
        [
          _entry('dup-1', 'bank', contexts: [
            VocabContext(
              id: 'ctx_a',
              sourceType: 'manual',
              surroundingText: 'a',
              encounteredAt: DateTime.utc(2026, 2, 1),
            ),
          ]),
          _entry('dup-1', 'Bank', contexts: [
            VocabContext(
              id: 'ctx_b',
              sourceType: 'manual',
              surroundingText: 'b',
              encounteredAt: DateTime.utc(2026, 2, 2),
            ),
          ]),
        ],
        now: at,
        newUnitId: () => 'fresh-uuid-${counter++}',
      );

      expect(result.units.length, 2, reason: 'không mất từ nào');
      expect(result.units.map((u) => u.unitId).toSet().length, 2);
      expect(result.report.duplicateIdsRemapped, ['dup-1']);
      // Evidence của entry bị remap trỏ ĐÚNG unit mới:
      expect(result.evidence[1].unitId, 'fresh-uuid-0');
      expect(result.evidence[1].evidenceId, 'mig-fresh-uuid-0-ctx0');
      expect(result.states[1].unitId, 'fresh-uuid-0');
    });

    test('Legacy JSON (không understandData) migrate được', () {
      final legacyJson = <String, dynamic>{
        'id': 'w_legacy_1',
        'word': 'run',
        'meaning': 'chạy',
        'understand': 0.5,
        'listen': 0.2,
        'read': 0.3,
        'lastReviewed': '2026-02-01T10:00:00.000Z',
        'createdAt': '2026-01-05T08:00:00.000Z',
        'updatedAt': '2026-02-01T10:00:00.000Z',
      };
      final legacy = WordEntry.fromJson(legacyJson);

      final result = WordEntryMigrator.migrate([legacy], now: at);

      expect(result.report.isLossless, isTrue);
      final state = result.states.single;
      // Dữ liệu cũ chưa có SM-2 ⇒ due ngay (ngữ nghĩa "chưa lên lịch"):
      expect(state.understanding.dueDate, at);
      expect(result.units.single.canonicalForm, 'run');
      expect(result.units.single.surfaceForms, ['run']);
    });

    test('isUnborn vẫn tạo unit — không mất từ; report đếm rõ', () {
      final result = WordEntryMigrator.migrate(
        [_entry('v_unborn_0', 'zzz', unborn: true)],
        now: at,
      );

      expect(result.report.isLossless, isTrue);
      expect(result.report.unbornUnits, 1);
      expect(result.units.single.unitId, 'v_unborn_0');
    });

    test('Trường không có trong schema v1 được LIỆT KÊ (không mất âm thầm)', () {
      final result = WordEntryMigrator.migrate(
        [_entry('v_meta_0', 'bank', tags: ['finance'], topic: 'money')],
        now: at,
      );

      expect(result.report.fieldsNotRepresentedInV1,
          containsAll(['tags', 'topic', 'meaning']));
      // ...và dữ liệu đó vẫn nguyên vẹn trong WordEntry cũ (test purity ở trên).
    });

    test('kind mapping: word/phrase/sentence/paragraph đúng loại unit', () {
      final result = WordEntryMigrator.migrate(
        [
          // k1: không truyền vocabType — mặc định đã là VocabularyType.word
          // (chính là điều test cần chứng minh).
          _entry('k1', 'bank'),
          _entry('k2', 'look up', vocabType: VocabularyType.phrase),
          _entry('k3', 'I look up.', vocabType: VocabularyType.sentence),
          _entry('k4', 'A paragraph.', vocabType: VocabularyType.paragraph),
        ],
        now: at,
      );

      expect(result.units[0].kind, KnowledgeUnitKind.word);
      expect(result.units[1].kind, KnowledgeUnitKind.phrase);
      expect(result.units[2].kind, KnowledgeUnitKind.sentence);
      expect(result.units[3].kind, KnowledgeUnitKind.paragraph);
    });

    test('Report toJson: baseline JSON hợp lệ để log/audit', () {
      final result = WordEntryMigrator.migrate(
        [_entry('v_rep_0', 'bank', tags: ['finance'])],
        now: at,
      );

      final json = result.report.toJson();
      expect(json['inputCount'], 1);
      expect(json['unitsCreated'], 1);
      expect(json['fieldsNotRepresentedInV1'], contains('tags'));
    });
  });
}
