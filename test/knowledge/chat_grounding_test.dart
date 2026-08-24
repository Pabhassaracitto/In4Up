// Test Task 8 — DoD (mục 8 bàn giao):
//   "Mọi câu trả lời có nguồn đều trỏ về evidenceId reopen được đúng vị trí"
// + pipeline 6 bước mục 7 + validator + offline quote-first.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/chat/chat_grounding.dart';
import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/learning_state.dart';

Evidence _ev(
  String id,
  String unitId,
  String excerpt, {
  EvidenceSourceType type = EvidenceSourceType.pdf,
}) {
  return Evidence.record(
    evidenceId: id,
    unitId: unitId,
    sourceType: type,
    sourceId: 'src-$id',
    locator: EvidenceLocator(
      page: type == EvidenceSourceType.pdf ? 3 : null,
      url: type == EvidenceSourceType.web ? 'https://x/$id' : null,
      timestampStart:
          type == EvidenceSourceType.audio || type == EvidenceSourceType.youtube
              ? 12.0
              : null,
    ),
    excerpt: excerpt,
    producerVersion: const ProducerVersion(
      splitterVersion: 'test',
      extractorVersion: 'test',
    ),
  );
}

SM2Snapshot _snap(int interval) => SM2Snapshot(
      easeFactor: 2.5,
      interval: interval,
      repetitions: interval < 7 ? 1 : 5,
      dueDate: DateTime.utc(2026, 9, 1),
    );

LearningState _mastery(int interval) => LearningState(
      unitId: 'u',
      understanding: _snap(interval),
      listening: _snap(interval),
      reading: _snap(interval),
    );

/// Model bịa citation — để test cờ unverified qua service end-to-end.
class LyingModel implements ChatModel {
  const LyingModel();

  @override
  Future<ChatModelReply> reply({
    required GroundingContext context,
    required String question,
  }) async {
    return ChatModelReply(
      answerText: 'Tôi bịa một câu trả lời.',
      citations: const [
        RawCitation(
          evidenceId: 'ev-khong-ton-tai',
          quoteExcerpt: 'đoạn bịa đặt hoàn toàn',
        ),
      ],
    );
  }
}

void main() {
  final current = _ev('ev-current', 'u-current', 'Nội dung đang đọc hiện tại.');

  group('GroundingContextBuilder — bước 2 (top-5, ưu tiên topic/mastery)', () {
    test('chặn trên 5 evidence liên quan, loại current', () {
      final pool = [
        for (var i = 0; i < 30; i++) _ev('ev-$i', 'u-$i', 'Excerpt số $i.'),
        current,
      ];
      final ctx = const GroundingContextBuilder()
          .build(current: current, pool: pool);
      expect(ctx.related.length, 5);
      expect(
        ctx.related.any((e) => e.evidenceId == 'ev-current'),
        isFalse,
      );
    });

    test('cùng topic (resolver) được ưu tiên cao nhất', () {
      final pool = [
        _ev('ev-a', 'u-a', 'A.'),
        _ev('ev-b', 'u-b', 'B.'),
        _ev('ev-topic', 'u-topic', 'Cùng chủ đề.'),
      ];
      final ctx = GroundingContextBuilder(
        topicResolver: (unitId) =>
            unitId == 'u-current' || unitId == 'u-topic' ? 'finance' : null,
      ).build(current: current, pool: pool);
      expect(ctx.related.first.evidenceId, 'ev-topic');
    });

    test('unit mastery thấp được ưu tiên', () {
      final pool = [
        _ev('ev-strong', 'u-strong', 'Vững.'),
        _ev('ev-weak', 'u-weak', 'Yếu.'),
      ];
      final ctx = GroundingContextBuilder(
        learningStates: {
          'u-strong': _mastery(30),
          'u-weak': _mastery(2),
        },
      ).build(current: current, pool: pool);
      expect(ctx.related.first.evidenceId, 'ev-weak');
    });

    test('tie-break theo evidenceId — deterministic', () {
      final pool = [
        for (var i = 0; i < 8; i++) _ev('ev-$i', 'u-x', 'Giống hệt nhau $i.'),
      ];
      final a = const GroundingContextBuilder()
          .build(current: current, pool: pool);
      final b = const GroundingContextBuilder()
          .build(current: current, pool: pool);
      expect(
        [for (final e in b.related) e.evidenceId],
        equals([for (final e in a.related) e.evidenceId]),
      );
    });
  });

  group('GroundingContext.toInjectedPrompt — bước 3 (có chặn)', () {
    test('chỉ chứa current + top-5; KHÔNG chứa evidence ngoài', () {
      final pool = [
        for (var i = 0; i < 30; i++) _ev('ev-$i', 'u-$i', 'Excerpt hiếm $i.'),
      ];
      final ctx = const GroundingContextBuilder()
          .build(current: current, pool: pool);
      final prompt = ctx.toInjectedPrompt();
      expect(prompt, contains('ev-current'));
      expect(prompt, contains('Nội dung đang đọc hiện tại.'));
      for (final e in ctx.related) {
        expect(prompt, contains(e.evidenceId));
      }
      expect(prompt, isNot(contains('Excerpt hiếm 29')),
          reason: '29 không nằm top-5 (mã ưu tiên thấp, id trễ)');
    });
  });

  group('CitationValidator — bước 5', () {
    final store = {
      'ev-1': _ev('ev-1', 'u-1', 'The bank of the river was muddy.'),
      'ev-2': _ev('ev-2', 'u-2', 'Ông Bean đến từ U.S. hôm qua.'),
    };
    final validator =
        CitationValidator(lookup: (id) => store[id]!);

    test('substring nguyên văn ⇒ verified + locator reopen', () {
      final result = validator.validate(
          const RawCitation(evidenceId: 'ev-1', quoteExcerpt: 'bank of the river'));
      expect(result.verdict, CitationVerdict.verified);
      expect(result.locator.page, 3);
    });

    test('near-match: hoa thường + space + dấu câu ⇒ nearMatch', () {
      final result = validator.validate(const RawCitation(
          evidenceId: 'ev-1', quoteExcerpt: '  BANK of the RIVER...  '));
      expect(result.verdict, CitationVerdict.nearMatch);
    });

    test('quote bịa ⇒ unverified + lý do', () {
      final result = validator.validate(const RawCitation(
          evidenceId: 'ev-1', quoteExcerpt: 'stock market crashed'));
      expect(result.verdict, CitationVerdict.unverified);
      expect(result.note, contains('không có trong excerpt'));
    });

    test('evidenceId không tồn tại ⇒ unverified "không tồn tại"', () {
      final result = validator.validate(const RawCitation(
          evidenceId: 'ev-ghost', quoteExcerpt: 'gì đó'));
      expect(result.verdict, CitationVerdict.unverified);
      expect(result.note, contains('không tồn tại'));
    });
  });

  group('OfflineQuoteFirstModel — mục 7 (không tự sinh)', () {
    test('trả lời chỉ gồm quote thật của context', () async {
      final pool = [_ev('ev-a', 'u-a', 'Câu A nguyên văn.')];
      final ctx =
          const GroundingContextBuilder().build(current: current, pool: pool);
      final reply = await const OfflineQuoteFirstModel()
          .reply(context: ctx, question: 'Từ này nghĩa gì?');
      expect(reply.citations.length, 2);
      expect(reply.citations.first.evidenceId, 'ev-current');
      expect(reply.answerText, contains('Câu A nguyên văn.'));
      expect(reply.answerText, contains('Chế độ offline'));
    });
  });

  group('GroundedChatService — end-to-end DoD bước 6', () {
    test('mọi citation được tin trỏ về evidence reopen ĐÚNG vị trí', () async {
      final pool = [
        for (var i = 0; i < 12; i++)
          _ev('ev-$i', 'u-$i', 'Excerpt liên quan $i.'),
      ];
      final store = {
        'ev-current': current,
        for (final e in pool) e.evidenceId: e,
      };
      final service = GroundedChatService(
        model: const OfflineQuoteFirstModel(),
        contextBuilder: const GroundingContextBuilder(),
        validator: CitationValidator(lookup: (id) => store[id]!),
      );
      final answer = await service.answer(
        current: current,
        pool: pool,
        question: 'Ngữ cảnh là gì?',
      );

      expect(answer.citations, isNotEmpty);
      expect(answer.hasUnverified, isFalse);
      for (final c in answer.reopenableCitations) {
        final source = store[c.evidenceId]!;
        // DoD: locator của citation phải trỏ ĐÚNG vị trí evidence gốc:
        expect(c.locator.toJson(), equals(source.locator.toJson()));
      }
    });

    test('model bịa ⇒ cờ unverified bật, UI có dữ liệu cảnh báo', () async {
      final service = GroundedChatService(
        model: const LyingModel(),
        contextBuilder: const GroundingContextBuilder(),
        validator: CitationValidator(
          lookup: (id) =>
              id == 'ev-current' ? current : throw StateError('thiếu $id'),
        ),
      );
      final answer = await service.answer(
        current: current,
        pool: const [],
        question: 'Gì đó?',
      );
      expect(answer.hasUnverified, isTrue);
      expect(answer.reopenableCitations, isEmpty);
      expect(answer.citations.single.note, contains('không tồn tại'));
    });
  });

  group('JSON round-trip', () {
    test('RawCitation + VerifiedCitation', () {
      const raw = RawCitation(evidenceId: 'e', quoteExcerpt: 'q');
      expect(RawCitation.fromJson(raw.toJson()).toJson(), equals(raw.toJson()));

      const verified = VerifiedCitation(
        evidenceId: 'e',
        quoteExcerpt: 'q',
        verdict: CitationVerdict.nearMatch,
        note: 'gần đúng',
        locator: EvidenceLocator(page: 7),
      );
      final json = verified.toJson();
      expect(json['verdict'], 'nearMatch');
      expect(json['locator'], isMap);
    });
  });
}
