import 'package:flutter/foundation.dart';

/// Bài tập mà một nguồn bên ngoài muốn mở sẵn trong tab Viết.
enum WritingTaskType {
  dictation,
  cloze,
  rewrite,
  summary,
}

/// Nơi người học vừa chọn nội dung để luyện viết.
enum WritingSourceKind {
  web,
  pdf,
  text,
}

/// Handoff nhẹ từ reader sang Writing Studio.
///
/// Đây chỉ là ý định mở bài. [WritingAssignment] mới là contract quyết định
/// chính xác text nào được hiển thị và text nào được đưa vào scorer.
@immutable
class WritingSourceRequest {
  final WritingTaskType task;
  final WritingSourceKind kind;
  final String sourceLabel;
  final bool isExcerpt;

  const WritingSourceRequest({
    required this.task,
    required this.kind,
    required this.sourceLabel,
    required this.isExcerpt,
  });
}
