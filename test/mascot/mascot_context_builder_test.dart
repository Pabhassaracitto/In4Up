// test/mascot/mascot_context_builder_test.dart
//
// MASCOT-003 — test thuần cho builder ngữ cảnh theo tab (PLAN-050 §5/§8).

import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/mascot/mascot_context_builder.dart';
import 'package:in4up/features/mascot/mascot_prompts.dart';

void main() {
  group('truncateAtSentenceBoundary', () {
    test('chuỗi ngắn — giữ nguyên', () {
      expect(truncateAtSentenceBoundary('Học từ mới.', 50), 'Học từ mới.');
    });

    test('cắt ở biên câu gần nhất', () {
      const text = 'Câu thứ nhất thật dài để vượt ngân sách. Câu hai ngắn.';
      final cut = truncateAtSentenceBoundary(text, 30);
      expect(cut.startsWith('Câu thứ nhất'), isTrue);
      expect(cut.endsWith('.'), isTrue);
      expect(cut.length, lessThanOrEqualTo(30));
      expect(cut.contains('Câu hai'), isFalse);
    });

    test('không có biên câu trong cửa sổ — cắt ở khoảng trắng', () {
      const text = 'mot hai ba bon nam sau bay tam chin muoi';
      final cut = truncateAtSentenceBoundary(text, 12);
      expect(cut, 'mot hai ba');
    });

    test('trả rỗng cho chuỗi trống', () {
      expect(truncateAtSentenceBoundary('   ', 10), '');
    });
  });

  group('buildMascotContextBlock', () {
    test('chỉ chứa dữ liệu thật — mục trống bị bỏ', () {
      final block = buildMascotContextBlock(const MascotContextData(
        surface: 'Nghe · Nói',
        dueWordCount: 12,
      ));
      expect(block, contains('Nghe · Nói'));
      expect(block, contains('12'));
      expect(block, isNot(contains('Tài liệu đang mở')));
      expect(block, isNot(contains('Bài nghe hiện tại')));
    });

    test('excerpt dài được cắt theo ngân sách biên câu', () {
      final longText =
          List.filled(20, 'Câu mẫu thứ mấy cho đủ độ dài cần thiết.')
              .join(' ');
      final block = buildMascotContextBlock(MascotContextData(
        surface: 'Đọc',
        documentExcerpt: longText,
      ));
      final excerptLine =
          block.split('\n').firstWhere((l) => l.contains('Trích tài liệu'));
      // 500 + dấu ngoặc + nhãn — chắc chắn nhỏ hơn nguyên văn.
      expect(excerptLine.length, lessThan(longText.length));
    });

    test('isPlaying phản ánh đúng', () {
      final block = buildMascotContextBlock(
          const MascotContextData(surface: 'Nghe', isPlaying: true));
      expect(block, contains('Audio đang phát: có'));
    });
  });

  group('buildMascotOneShotContext', () {
    test('tổng không vượt ngân sách mascot', () {
      final prompt = buildMascotDefaultSystemPrompt();
      final data = MascotContextData(
        surface: 'Đọc · Đọc',
        documentExcerpt: 'Câu dài. ' * 300,
        dueWordCount: 9,
        streakDays: 4,
      );
      final ctx = buildMascotOneShotContext(data, systemPrompt: prompt);
      expect(ctx.length, lessThanOrEqualTo(kMascotContextMaxChars));
      expect(ctx, contains('Sara'));
      expect(ctx, contains('[NGỮ CẢNH APP HIỆN TẠI]'));
    });

    test('prompt giàu ngữ cảnh vẫn giữ nguyên phần system', () {
      final prompt = buildMascotDefaultSystemPrompt();
      final ctx = buildMascotOneShotContext(
        const MascotContextData(surface: 'Nhớ'),
        systemPrompt: prompt,
      );
      expect(ctx.startsWith(prompt), isTrue);
    });
  });
}
