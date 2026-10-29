import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/grammar/grammar.dart';

void main() {
  test('ngôn ngữ không phải EN bị chặn precision-first', () {
    final service = SentenceStructureService.instance;
    const text = 'Chúng tôi học tiếng Anh mỗi ngày.';
    final start = text.indexOf('học');
    final analysis = service.analyzeLine(
      text,
      anchorStart: start,
      anchorEnd: start + 'học'.length,
    );

    expect(analysis.supported, isFalse);
    expect(analysis.phrase, isNull);
    expect(analysis.sentence, isNull);
    expect(analysis.notes, contains('language_gate'));
  });

  test('dòng vắt chưa kết câu chỉ hiện cụm và note, ẩn sentence structure', () {
    final service = SentenceStructureService.instance;
    const text = 'The old man gave his son';
    final start = text.indexOf('son');
    final analysis = service.analyzeLine(
      text,
      anchorStart: start,
      anchorEnd: start + 'son'.length,
    );

    expect(analysis.supported, isTrue);
    expect(analysis.phrase, isNotNull);
    expect(analysis.sentence, isNull);
    expect(analysis.notes, contains('line_continues'));
  });
}
