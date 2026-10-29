// YT-AUDIT-05 (IN4-105) — Prompt tra từ phải XIN ĐỦ 7 phần.
//
// Lỗi gốc của "tab GIẢI THÍCH không có ngữ pháp": prompt `wordLookup` KHÔNG
// bao giờ hỏi khoá `grammar`. Parser (`AiAnalysis.fromJson`) vốn đã đọc được
// `grammar` từ trước — chỉ là prompt chưa xin, nên `AiAnalysis.grammar` luôn
// `null` và ô Ngữ pháp không bao giờ hiện, kể cả khi AI chạy tốt.
//
// Test thuần — không cần thiết bị / mạng / model AI.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

String prompt({String word = 'very', String? context}) =>
    AiPromptsLibrary.buildPrompt(
      type: AiAnalysisType.wordLookup,
      text: word,
      context: context,
    );

void main() {
  const ctx = 'This is a very good idea.';

  group('tra từ CÓ câu ngữ cảnh (luồng thật của màn YouTube)', () {
    final p = prompt(context: ctx);

    test('xin NGỮ PHÁP — đây chính là chỗ bản cũ thiếu', () {
      expect(p.contains('"grammar"'), isTrue,
          reason: 'Prompt không xin grammar ⇒ AiAnalysis.grammar luôn null ⇒ '
              'ô "Ngữ pháp" (cấu trúc/chủ ngữ/động từ/tân ngữ) không bao giờ '
              'hiện, đúng triệu chứng owner báo.');
      for (final key in <String>[
        'subject',
        'verb',
        'object',
        'complement',
        'adverbial',
        'pattern',
        'explanation_vi',
      ]) {
        expect(p.contains('"$key"'), isTrue, reason: 'thiếu khoá $key');
      }
    });

    test('xin đủ 6 phần còn lại mà tab GIẢI THÍCH hiện', () {
      expect(p.contains('"summary"'), isTrue); // tóm tắt AI
      expect(p.contains('"memory_hook"'), isTrue); // mẹo nhớ
      expect(p.contains('"context_examples"'), isTrue); // ví dụ trong ngữ cảnh
      expect(p.contains('"visual_prompt"'), isTrue); // hình ảnh gợi nhớ
      expect(p.contains('"pao_suggestions"'), isTrue); // câu chuyện ghi nhớ
      expect(p.contains('"ipa_fallback"'), isTrue); // phiên âm
    });

    test('truyền CẢ câu ngữ cảnh lẫn từ vào prompt', () {
      expect(p.contains(ctx), isTrue);
      expect(p.contains('very'), isTrue);
    });

    test('nhắc model trả đúng 1 JSON, không bọc markdown', () {
      expect(p.toLowerCase().contains('only one valid json'), isTrue);
      expect(p.contains('No markdown fences'), isTrue);
    });

    test('JSON mẫu hợp lệ: các dòng trong object khớp ngoặc', () {
      final body = p.substring(p.indexOf('{'), p.lastIndexOf('}') + 1);
      // Chỉ đếm ngoặc ở ĐẦU DÒNG (khỏi vướng dấu ngoặc trong chuỗi mô tả).
      final opens = RegExp(r'^\s*\{', multiLine: true).allMatches(body).length +
          RegExp(r'^\s*"[a-z_]+": \{', multiLine: true).allMatches(body).length;
      final closes = RegExp(r'^\s*\}', multiLine: true).allMatches(body).length;
      expect(opens, closes, reason: 'JSON mẫu trong prompt lệch ngoặc');
      // Phải có đúng 2 object lồng: object ngoài + word_detail + grammar.
      expect(opens, 3);
    });
  });

  group('tra từ KHÔNG có câu ngữ cảnh', () {
    final p = prompt();

    test('BỎ hẳn grammar — ngữ pháp là của CÂU, không phải của TỪ', () {
      expect(p.contains('"grammar"'), isFalse,
          reason: 'Bắt model bịa subject/verb cho một từ đơn ⇒ vô nghĩa, '
              'phình JSON, và model nhỏ hay cắt ngang ở cuối.');
    });

    test('vẫn xin đủ các phần còn lại', () {
      expect(p.contains('"summary"'), isTrue);
      expect(p.contains('"memory_hook"'), isTrue);
      expect(p.contains('"context_examples"'), isTrue);
      expect(p.contains('"visual_prompt"'), isTrue);
      expect(p.contains('"pao_suggestions"'), isTrue);
    });

    test('không bị kẹt dấu phẩy thừa khi bỏ grammar', () {
      final body = p.substring(p.indexOf('{'), p.lastIndexOf('}') + 1);
      expect(body.contains(',,'), isFalse);
      expect(body.contains(',\n}'), isFalse);
      expect(body.contains(',\n  }'), isFalse);
    });
  });

  group('câu phân tích (sentenceParse) không bị ảnh hưởng', () {
    test('vẫn có grammar của riêng nó', () {
      final p = AiPromptsLibrary.buildPrompt(
        type: AiAnalysisType.sentenceParse,
        text: 'She gave me a book.',
      );
      expect(p.contains('"grammar"'), isTrue);
      expect(p.contains('"explanation_vi"'), isTrue);
    });
  });
}
