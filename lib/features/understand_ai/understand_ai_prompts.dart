// lib/features/understand_ai/understand_ai_prompts.dart
//
// Quick actions + prompt builder cho AI Coach tab Hiểu.
//
// Các prompt dưới đây là NỘI DUNG gửi cho AI (giống các prompt review của
// Write Studio), không phải chrome UI — không đưa vào catalog dịch. Người
// dùng thấy nguyên văn prompt trong ô nhập của AI Chat và có thể sửa trước
// khi gửi (yêu cầu: "hiển thị rõ context trước khi gửi").
//
// Prompt chỉ chứa văn bản từ UnderstandAiContext — không kèm audio, không
// kèm lịch sử học, không kèm cả tài liệu (context đã bị cắt theo ngân sách
// ký tự ở understand_ai_context.dart).

import 'understand_ai_context.dart';

/// Bốn quick action trong sheet "Trợ lý hiểu bài".
enum UnderstandAiQuickAction {
  /// "Giải thích câu này"
  explainSentence,

  /// "Tóm tắt đoạn vừa nghe"
  summarizeRecent,

  /// "Kiểm tra hiểu bài"
  checkComprehension,

  /// "Cho tôi một gợi ý"
  giveHint,
}

extension UnderstandAiQuickActionX on UnderstandAiQuickAction {
  /// Quick action này có cần lyric/text đang mở hay không.
  /// giveHint vẫn dùng được khi chưa có text (gợi ý cách luyện theo mode).
  bool get requiresLyrics => this != UnderstandAiQuickAction.giveHint;
}

// Icon và nhãn hiển thị được map ở tầng UI — understand_ai_coach_sheet.dart
// — để file này thuần logic, không phụ thuộc Flutter.

/// Dựng prompt hoàn chỉnh cho một quick action.
///
/// Luôn trả về chuỗi không rỗng; phần ngữ cảnh chỉ gồm các đoạn đã được cắt
/// theo ngân sách ký tự trong [UnderstandAiContext].
String buildUnderstandQuickPrompt(
  UnderstandAiQuickAction action,
  UnderstandAiContext context,
) {
  final buffer = StringBuffer();
  buffer.write(_contextHeader(action, context));

  switch (action) {
    case UnderstandAiQuickAction.explainSentence:
      buffer.write(
        _optionalBlock('Ngữ cảnh quanh câu', context.surroundingText),
      );
      buffer.write(
        'Giải thích câu trong dấu « » giúp mình: dịch nghĩa tiếng Việt, chỉ ra '
        'các từ/cụm từ khó và cấu trúc ngữ pháp đáng chú ý. Viết ngắn gọn, dễ hiểu.',
      );
      break;

    case UnderstandAiQuickAction.summarizeRecent:
      buffer.write(
        'Tóm tắt đoạn trong « Đoạn vừa nghe » bằng 3–5 câu tiếng Việt: nêu ý '
        'chính và 3–5 từ vựng đáng nhớ kèm nghĩa ngắn.',
      );
      break;

    case UnderstandAiQuickAction.checkComprehension:
      buffer.write(
        'Kiểm tra hiểu bài của mình về đoạn vừa rồi: đặt 3 câu hỏi từ dễ đến '
        'khó, đợi mình tự trả lời, rồi mới đưa đáp án ngắn ở cuối.',
      );
      break;

    case UnderstandAiQuickAction.giveHint:
      buffer.write(context.hasText ? _hintWithText : _hintWithoutText);
      break;
  }

  return buffer.toString();
}

String _contextHeader(
  UnderstandAiQuickAction action,
  UnderstandAiContext context,
) {
  final parts = <String>[
    if (context.learningMode == UnderstandLearningMode.shadowing)
      'mình đang luyện Shadowing'
    else
      'mình đang học theo chế độ Đồng bộ',
    if (context.sourceTitle != null) 'bài: « ${context.sourceTitle} »',
  ];

  final buffer = StringBuffer();
  buffer.write('Mình đang học ở tab Hiểu (${parts.join(', ')}).\n');

  // "Đoạn vừa nghe" chỉ cần cho tóm tắt / kiểm tra; giải thích và gợi ý
  // chỉ cần câu đang chọn để prompt gọn.
  if (action == UnderstandAiQuickAction.summarizeRecent ||
      action == UnderstandAiQuickAction.checkComprehension) {
    buffer.write(_optionalBlock('Đoạn vừa nghe', context.recentText));
  }

  if (context.selectedText != null) {
    final lineLabel = context.focusLineIndex == null
        ? ''
        : ' (dòng ${context.focusLineIndex! + 1})';
    buffer.write('Câu mình đang hỏi$lineLabel:\n');
    buffer.write('« ${context.selectedText} »\n\n');
  }

  return buffer.toString();
}

String _optionalBlock(String label, String? text) {
  if (text == null || text.isEmpty) return '';
  return '$label:\n« $text »\n\n';
}

const String _hintWithText =
    'Cho mình MỘT gợi ý ngắn giúp hiểu tốt hơn đoạn này: chỉ gợi ý mở '
    '(từ khoá, cấu trúc cần chú ý), chưa giải thích trọn vẹn, để mình tự suy ra.';

const String _hintWithoutText =
    'Chưa có câu nào đang phát. Cho mình một gợi ý luyện tập tiếp theo phù hợp '
    'với chế độ mình đang chọn nhé.';
