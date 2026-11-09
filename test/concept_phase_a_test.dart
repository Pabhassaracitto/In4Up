// PLAN-043 Pha A (ADR-0023) — pin ba bất biến bằng test thuần:
//  1) ConceptNode JSON round-trip + chịu thiếu trường; id thiếu thì ném.
//  2) WordEntry.conceptId additive: JSON cũ (không key) đọc null; ghi chỉ
//     khi có giá trị; copyWith không đánh rơi móc nối.
//  3) Bộ gợi ý nối: cặp dịch / trùng ảnh / trùng gloss được đề xuất kèm
//     điểm; không gợi ý cặp đã cùng khái niệm / đã bỏ qua / hai khái niệm
//     khác nhau.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/concept_node.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/screens/tools/word_list/concept_link_suggestions.dart';

WordEntry _entry(String id, String word, String meaning,
        {String language = 'en', String? conceptId}) =>
    WordEntry(
      id: id,
      word: word,
      meaning: meaning,
      language: language,
      conceptId: conceptId,
    );

void main() {
  group('ConceptNode JSON', () {
    test('round-trip giữ đủ trường, quan hệ và mã ngoài', () {
      final node = ConceptNode.create(gloss: 'con chó', domain: 'động vật')
        ..imageRef = 'vocabulary_images/abc.webp'
        ..relations.add(const ConceptRelation(
            type: ConceptRelationType.isA, conceptId: 'c-pet'))
        ..externalIds['wikidata'] = 'Q144';
      final back = ConceptNode.fromJson(node.toJson());
      expect(back.id, node.id);
      expect(back.gloss, 'con chó');
      expect(back.domain, 'động vật');
      expect(back.imageRef, 'vocabulary_images/abc.webp');
      expect(back.relations.single.type, ConceptRelationType.isA);
      expect(back.relations.single.conceptId, 'c-pet');
      expect(back.externalIds['wikidata'], 'Q144');
    });

    test('JSON tối thiểu (chỉ id) vẫn đọc được với mặc định an toàn', () {
      final back = ConceptNode.fromJson({'id': 'c1'});
      expect(back.gloss, '');
      expect(back.domain, isNull);
      expect(back.relations, isEmpty);
      // toJson bỏ qua trường rỗng để file gọn.
      expect(back.toJson().containsKey('relations'), isFalse);
    });

    test('thiếu id thì ném FormatException (phía tải bỏ qua 1 bản ghi)', () {
      expect(() => ConceptNode.fromJson({'gloss': 'x'}),
          throwsA(isA<FormatException>()));
    });

    test('create() sinh id khác nhau mỗi lần (không dẫn xuất từ nội dung)', () {
      final a = ConceptNode.create(gloss: 'mèo');
      final b = ConceptNode.create(gloss: 'mèo');
      expect(a.id, isNot(b.id));
    });
  });

  group('WordEntry.conceptId additive', () {
    test('không có conceptId → toJson KHÔNG có key; đọc lại ra null', () {
      final e = _entry('w1', 'dog', 'con chó');
      final json = e.toJson();
      expect(json.containsKey('conceptId'), isFalse);
      expect(WordEntry.fromJson(json).conceptId, isNull);
    });

    test('có conceptId → round-trip giữ nguyên', () {
      final e = _entry('w1', 'dog', 'con chó', conceptId: 'c-dog');
      final back = WordEntry.fromJson(e.toJson());
      expect(back.conceptId, 'c-dog');
    });

    test('JSON cũ mô phỏng (xóa key khỏi bản mới) vẫn đọc bình thường', () {
      final json = _entry('w1', 'dog', 'con chó', conceptId: 'c-dog').toJson()
        ..remove('conceptId');
      final back = WordEntry.fromJson(json);
      expect(back.word, 'dog');
      expect(back.conceptId, isNull);
    });

    test('copyWith không đánh rơi conceptId', () {
      final e = _entry('w1', 'dog', 'con chó', conceptId: 'c-dog');
      expect(e.copyWith(meaning: 'chó nhà').conceptId, 'c-dog');
    });
  });

  group('buildConceptLinkSuggestions', () {
    const words = [
      ConceptCandidateWord(
          id: 'en-dog', word: 'dog', meaning: 'con chó', language: 'en',
          imageUrl: 'vocabulary_images/dog.webp'),
      ConceptCandidateWord(
          id: 'vi-cho', word: 'chó', meaning: 'dog', language: 'vi',
          imageUrl: 'vocabulary_images/dog.webp'),
      ConceptCandidateWord(
          id: 'zh-gou', word: '狗', meaning: 'con chó', language: 'zh'),
      ConceptCandidateWord(
          id: 'en-cat', word: 'cat', meaning: 'con mèo', language: 'en'),
    ];

    test('cặp dịch + trùng ảnh được điểm cao nhất và đứng đầu', () {
      final s = buildConceptLinkSuggestions(words);
      expect(s, isNotEmpty);
      final top = s.first;
      expect(top.wordIds, ['en-dog', 'vi-cho']);
      expect(top.reasons,
          containsAll([ConceptLinkReason.translationPair, ConceptLinkReason.sameImage]));
      expect(top.score, 5);
    });

    test('trùng gloss khác ngôn ngữ cũng được gợi ý (điểm thấp hơn)', () {
      final s = buildConceptLinkSuggestions(words);
      final zhVi = s.where((x) => x.wordIds.contains('zh-gou')).toList();
      expect(zhVi, isNotEmpty);
      expect(zhVi.every((x) => x.score < 5), isTrue);
    });

    test('cặp không liên quan (cat) không bị gợi ý với dog/chó', () {
      final s = buildConceptLinkSuggestions(words);
      expect(s.where((x) => x.wordIds.contains('en-cat')), isEmpty);
    });

    test('cặp đã bỏ qua (dismissed) không xuất hiện lại', () {
      final s = buildConceptLinkSuggestions(
        words,
        dismissedPairKeys: {'en-dog|vi-cho'},
      );
      expect(s.where((x) => x.pairKey == 'en-dog|vi-cho'), isEmpty);
    });

    test('đã cùng một khái niệm thì không gợi ý; hai khái niệm khác nhau cũng không (ngoài Pha A)', () {
      const linked = [
        ConceptCandidateWord(
            id: 'a', word: 'dog', meaning: 'con chó', language: 'en',
            conceptId: 'c1'),
        ConceptCandidateWord(
            id: 'b', word: 'chó', meaning: 'dog', language: 'vi',
            conceptId: 'c1'),
        ConceptCandidateWord(
            id: 'c', word: 'Hund', meaning: 'con chó', language: 'de',
            conceptId: 'c2'),
      ];
      expect(buildConceptLinkSuggestions(linked), isEmpty);
    });

    test('một bên đã có khái niệm, bên kia chưa → vẫn gợi ý để nối vào', () {
      const partial = [
        ConceptCandidateWord(
            id: 'a', word: 'dog', meaning: 'con chó', language: 'en',
            conceptId: 'c1'),
        ConceptCandidateWord(
            id: 'b', word: 'chó', meaning: 'dog', language: 'vi'),
      ];
      final s = buildConceptLinkSuggestions(partial);
      expect(s.single.wordIds, ['a', 'b']);
    });

    test('glossSegments bỏ chú thích trong ngoặc và tách ; , /', () {
      expect(glossSegments('con chó (thân mật: cún); chó nhà, cún'),
          {'con chó', 'chó nhà', 'cún'});
    });
  });
}
