import 'package:flutter/foundation.dart';

import 'writing_source_request.dart';
import '../services/writing_sentence_segmenter.dart';

/// Nguồn assignment quyết định hành vi điều hướng của UI.
enum AssignmentOrigin {
  /// Một dòng trong TextProvider; người học có thể chuyển dòng trước/sau.
  perLine,

  /// Đoạn bôi chọn độc lập từ Web/PDF; không dùng line navigator.
  excerpt,

  /// Toàn bộ tài liệu Web/PDF; không dùng line navigator.
  fullDocument,
}

/// Profile quyết định scorer được phép chạy.
///
/// Trục này cố ý độc lập với [AssignmentOrigin].
enum ScoringProfile {
  sentenceLevel,
  documentSignals,
}

@immutable
class WritingAssignmentContext {
  final String sourceKey;
  final String sourceTitle;
  final String fullText;
  final List<String> lines;
  final int lineIndex;
  final WritingSourceRequest? request;

  const WritingAssignmentContext({
    required this.sourceKey,
    required this.sourceTitle,
    required this.fullText,
    required this.lines,
    required this.lineIndex,
    required this.request,
  });
}

/// Contract duy nhất giữa source, UI composer và scoring engine.
@immutable
class WritingAssignment {
  final String id;
  final WritingTaskType task;

  /// Text thực sự được scorer đánh giá.
  final String sourceText;

  /// Text đầy đủ chỉ để tham khảo; không bị cắt khi sentence-level fallback.
  final String contextText;

  final String sourceTitle;
  final AssignmentOrigin origin;
  final ScoringProfile scoringProfile;
  final int sourceWordCount;
  final int? lineIndex;

  const WritingAssignment({
    required this.id,
    required this.task,
    required this.sourceText,
    required this.contextText,
    required this.sourceTitle,
    required this.origin,
    required this.scoringProfile,
    required this.sourceWordCount,
    this.lineIndex,
  });

  bool get showLineNavigator => origin == AssignmentOrigin.perLine;

  bool get needsContextPreview => sourceText.trim() != contextText.trim();

  bool get isWorkspaceTask =>
      task == WritingTaskType.rewrite || task == WritingTaskType.summary;

  /// Tạo assignment từ snapshot của TextProvider và task đang được chọn.
  ///
  /// Task hiện tại là nguồn sự thật; `request.task` chỉ là intent lúc handoff.
  factory WritingAssignment.fromContext({
    required WritingAssignmentContext context,
    required WritingTaskType task,
  }) {
    final fullText = context.fullText.trim();
    final request = context.request;

    if (request != null && request.isExcerpt) {
      if (task == WritingTaskType.summary) {
        return WritingAssignment(
          id: _id('excerpt_summary', context.sourceKey, fullText),
          task: task,
          sourceText: fullText,
          contextText: fullText,
          sourceTitle: 'Đoạn trích · ${request.sourceLabel}',
          origin: AssignmentOrigin.excerpt,
          scoringProfile: ScoringProfile.documentSignals,
          sourceWordCount: _wordCount(fullText),
        );
      }

      final sentenceCount = WritingSentenceSegmenter.count(fullText);
      final scoringText = sentenceCount <= 1
          ? fullText
          : WritingSentenceSegmenter.firstSentence(fullText);
      final prefix = sentenceCount <= 1 ? 'Đoạn trích' : 'Câu đầu đoạn trích';

      return WritingAssignment(
        id: _id('excerpt_${task.name}', context.sourceKey, scoringText),
        task: task,
        sourceText: scoringText,
        contextText: fullText,
        sourceTitle: '$prefix · ${request.sourceLabel}',
        origin: AssignmentOrigin.excerpt,
        scoringProfile: ScoringProfile.sentenceLevel,
        sourceWordCount: _wordCount(scoringText),
      );
    }

    if (request != null && !request.isExcerpt && task == WritingTaskType.summary) {
      return WritingAssignment(
        id: _id('document_summary', context.sourceKey, fullText),
        task: task,
        sourceText: fullText,
        contextText: fullText,
        sourceTitle: request.sourceLabel,
        origin: AssignmentOrigin.fullDocument,
        scoringProfile: ScoringProfile.documentSignals,
        sourceWordCount: _wordCount(fullText),
      );
    }

    final safeLineIndex = context.lines.isEmpty
        ? 0
        : context.lineIndex.clamp(0, context.lines.length - 1).toInt();
    final lineText = context.lines.isEmpty ? fullText : context.lines[safeLineIndex];

    return WritingAssignment(
      id: _id('line_${safeLineIndex}_${task.name}', context.sourceKey, lineText),
      task: task,
      sourceText: lineText.trim(),
      contextText: lineText.trim(),
      sourceTitle: context.sourceTitle,
      origin: AssignmentOrigin.perLine,
      scoringProfile: ScoringProfile.sentenceLevel,
      sourceWordCount: _wordCount(lineText),
      lineIndex: safeLineIndex,
    );
  }

  static int _wordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  static String _id(String prefix, String sourceKey, String text) {
    return '${prefix}_${_stableHash('$sourceKey\u0000$text')}';
  }

  /// Hash deterministic, giữ phép nhân dưới ngưỡng an toàn của JavaScript.
  static String _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
