// PLAN-043 mục 3 — Nhập hàng loạt bằng AI: pin (1) prompt sinh ra nhúng
// đúng header CSV parser hiểu + đủ ngữ cảnh kịch bản; (2) parser bóc được
// code-fence/bảng Markdown/lời dẫn của AI; (3) ghép output nhiều lô giữ 1
// header. Đây là các điểm gãy thật khi dán kết quả AI vào import.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/tools/word_list/vocab_bulk_ai.dart';
import 'package:in4up/screens/tools/word_list/word_import_sheet.dart';

void main() {
  group('buildVocabBulkPrompt', () {
    test('byTopic: nhúng header chuẩn + chủ đề + trình độ + số lượng + mã ngôn ngữ', () {
      final p = buildVocabBulkPrompt(
        scenario: VocabBulkAiScenario.byTopic,
        wordLanguageName: 'English',
        meaningLanguageName: 'Vietnamese',
        wordLanguageCode: 'en',
        inputText: 'du lịch',
        level: 'B1',
        count: 20,
      );
      expect(p, contains(kVocabCsvHeader));
      expect(p, contains('20 từ/cụm từ'));
      expect(p, contains('du lịch'));
      expect(p, contains('B1'));
      expect(p, contains('luôn là en'));
      expect(p, contains('tiếng Vietnamese'));
      // Header trong prompt phải map được bởi parser thật.
      expect(WordTableParser.isHeaderLine(kVocabCsvHeader), isTrue);
    });

    test('enrichList: liệt kê đúng từ đầu vào, bỏ đánh số/nghĩa sơ sài đi kèm', () {
      expect(splitVocabAiInputWords('1. apple\n- banana\ncherry, quả anh đào\n'),
          ['apple', 'banana', 'cherry']);
      final p = buildVocabBulkPrompt(
        scenario: VocabBulkAiScenario.enrichList,
        wordLanguageName: 'English',
        meaningLanguageName: 'Vietnamese',
        wordLanguageCode: 'en',
        inputText: 'apple\nbanana',
      );
      expect(p, contains('- apple'));
      expect(p, contains('- banana'));
      expect(p, contains('Giữ ĐÚNG thứ tự'));
    });

    test('extractFromText: chứa đoạn văn trong khối trích', () {
      final p = buildVocabBulkPrompt(
        scenario: VocabBulkAiScenario.extractFromText,
        wordLanguageName: 'English',
        meaningLanguageName: 'Vietnamese',
        wordLanguageCode: 'en',
        inputText: 'The quick brown fox jumps over the lazy dog.',
        count: 10,
      );
      expect(p, contains('quick brown fox'));
      expect(p, contains('tối đa 10'));
    });

    test('count bị kẹp 1–50', () {
      final p = buildVocabBulkPrompt(
        scenario: VocabBulkAiScenario.byTopic,
        wordLanguageName: 'English',
        meaningLanguageName: 'Vietnamese',
        wordLanguageCode: 'en',
        inputText: 'nấu ăn',
        count: 999,
      );
      expect(p, contains('50 từ/cụm từ'));
    });
  });

  group('buildVocabBulkPromptsForRun', () {
    test('enrich chia lô 20 từ/request', () {
      final words = List.generate(45, (i) => 'word$i').join('\n');
      final prompts = buildVocabBulkPromptsForRun(
        scenario: VocabBulkAiScenario.enrichList,
        wordLanguageName: 'English',
        meaningLanguageName: 'Vietnamese',
        wordLanguageCode: 'en',
        inputText: words,
      );
      expect(prompts.length, 3); // 20 + 20 + 5
      expect(prompts.first, contains('word0'));
      expect(prompts.first, isNot(contains('- word20')));
      expect(prompts.last, contains('word44'));
    });

    test('prompt đã sửa tay được tôn trọng (kịch bản không-phải-làm-giàu)', () {
      final prompts = buildVocabBulkPromptsForRun(
        scenario: VocabBulkAiScenario.byTopic,
        wordLanguageName: 'English',
        meaningLanguageName: 'Vietnamese',
        wordLanguageCode: 'en',
        inputText: 'du lịch',
        editedPrompt: 'PROMPT TÔI TỰ SỬA',
      );
      expect(prompts, ['PROMPT TÔI TỰ SỬA']);
    });

    test('enrich với đầu vào rỗng → không có prompt nào', () {
      expect(
        buildVocabBulkPromptsForRun(
          scenario: VocabBulkAiScenario.enrichList,
          wordLanguageName: 'English',
          meaningLanguageName: 'Vietnamese',
          wordLanguageCode: 'en',
          inputText: '   \n  ',
        ),
        isEmpty,
      );
    });
  });

  group('WordTableParser.sanitizeStructuredText + findHeaderLineIndex', () {
    test('bóc code fence ```csv … ```', () {
      const raw = '```csv\n'
          'word, meaning, ipa, topic, example, example_simple, example_complex, language\n'
          'dog, con chó, /dɒɡ/, animal, The dog runs, A dog runs, , en\n'
          '```';
      final lines = WordTableParser.sanitizeStructuredText(raw)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(WordTableParser.findHeaderLineIndex(lines), 0);
      expect(lines.length, 2);
    });

    test('bảng Markdown: bỏ hàng |---|, gỡ | hai đầu, header map được', () {
      const raw = '| word | meaning | ipa | language |\n'
          '|---|---|---|---|\n'
          '| dog | con chó | /dɒɡ/ | en |';
      final cleaned = WordTableParser.sanitizeStructuredText(raw);
      expect(cleaned, isNot(contains('---')));
      final lines =
          cleaned.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.first, 'word | meaning | ipa | language');
      expect(WordTableParser.isHeaderLine(lines.first), isTrue);
      final fields = WordTableParser.mapHeader(lines.first);
      expect(fields, ['word', 'meaning', 'phonetic', 'language']);
    });

    test('chịu lời dẫn 1-2 dòng trước header', () {
      const raw = 'Đây là danh sách từ vựng cho bạn:\n'
          'word, meaning, language\n'
          'dog, con chó, en';
      final lines = WordTableParser.sanitizeStructuredText(raw)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(WordTableParser.findHeaderLineIndex(lines), 1);
    });

    test('dòng dữ liệu thường không bị nhận nhầm là header', () {
      expect(WordTableParser.isHeaderLine('dog, con chó, en'), isFalse);
    });
  });

  group('WordTableParser.mergeCsvOutputs', () {
    test('hai lô có fence + header lặp → một header duy nhất, đủ dòng dữ liệu', () {
      const batch1 = '```csv\n'
          'word, meaning, language\n'
          'dog, con chó, en\n'
          '```';
      const batch2 = 'word, meaning, language\n'
          'cat, con mèo, en';
      final merged = WordTableParser.mergeCsvOutputs([batch1, batch2]);
      final lines = merged.split('\n');
      expect(lines, [
        'word, meaning, language',
        'dog, con chó, en',
        'cat, con mèo, en',
      ]);
    });

    test('lô không có header vẫn được giữ dòng (thà thừa còn hơn mất từ)', () {
      const batch1 = 'word, meaning, language\ndog, con chó, en';
      const batch2 = 'bird, chim, en';
      final merged = WordTableParser.mergeCsvOutputs([batch1, batch2]);
      expect(merged, contains('bird, chim, en'));
      expect('word,'.allMatches(merged).length, 1);
    });
  });
}
