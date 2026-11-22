import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant, system }

@immutable
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final bool isError;

  /// PSRC-264 — ngữ cảnh MỘT LẦN đi kèm tin này (vd snapshot tab Hiểu/YouTube).
  ///
  /// TÁCH KHỎI [text] để bubble chỉ hiện câu hỏi người dùng gõ, và để engine
  /// KHÔNG tái đính ngữ cảnh này vào các lượt sau (trước đây ngữ cảnh được
  /// nối THẲNG vào text ⇒ lịch sử hội thoại cứ thế lặp lại prompt cũ ở mọi
  /// câu hỏi tiếp theo). Không null = đây là lượt ĐẦU của một chủ đề.
  final String? oneShotContext;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    DateTime? createdAt,
    this.isError = false,
    this.oneShotContext,
  }) : createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({String? text, bool? isError, String? oneShotContext}) =>
      ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        isError: isError ?? this.isError,
        oneShotContext: oneShotContext ?? this.oneShotContext,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'isError': isError,
        // Chỉ ghi khi có — lịch sử cũ không có field này vẫn đọc được.
        if (oneShotContext != null) 'oneShotContext': oneShotContext,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ??
            'message-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.values.firstWhere(
          (value) => value.name == json['role'],
          orElse: () => ChatRole.assistant,
        ),
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        isError: json['isError'] as bool? ?? false,
        oneShotContext: json['oneShotContext'] as String?,
      );
}
