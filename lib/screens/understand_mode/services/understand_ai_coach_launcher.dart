// lib/screens/understand_mode/services/understand_ai_coach_launcher.dart
//
// Glue giữa workspace tab Hiểu và sheet "Trợ lý hiểu bài": đọc state hiện có
// (UnderstandProvider + TextProvider), dựng UnderstandAiContext SNAPSHOT rồi
// mở sheet. Không ghi âm, không upload audio, không thay đổi state của
// player/understand — chỉ đọc.
//
// [buildUnderstandAiContextFromProviders] tách riêng nhận provider qua tham
// số để unit test được mà không cần dựng cả widget tree.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/understand_ai/understand_ai_context.dart';
import '../../../features/understand_ai/understand_ai_coach_sheet.dart';
import '../../../providers/text_provider.dart';
import '../understand_provider.dart';

/// Dựng context cho AI Coach từ provider của tab Hiểu.
///
/// [text] optional: chỉ dùng để lấy tiêu đề tài liệu (test truyền null).
UnderstandAiContext buildUnderstandAiContextFromProviders({
  required UnderstandProvider understand,
  TextProvider? text,
  int focusLineIndex = -1,
}) {
  return UnderstandAiContext.fromLineTexts(
    lines: understand.lrcLines.map((line) => line.text).toList(),
    currentLineIndex: understand.currentLineIndex,
    focusLineIndex: focusLineIndex,
    sourceTitle: text?.currentDocument?.title,
    learningMode: understand.learningMode,
  );
}

/// Mở sheet "Trợ lý hiểu bài" từ workspace header (action "Hỏi AI").
Future<void> openUnderstandAiCoach(BuildContext context) async {
  final understand = context.read<UnderstandProvider>();
  final text = context.read<TextProvider>();
  final aiContext = buildUnderstandAiContextFromProviders(
    understand: understand,
    text: text,
  );
  await showUnderstandAiCoachSheet(
    context: context,
    aiContext: aiContext,
    lines: understand.lrcLines.map((line) => line.text).toList(),
  );
}
