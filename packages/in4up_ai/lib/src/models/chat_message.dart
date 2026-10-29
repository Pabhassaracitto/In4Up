import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant, system }

@immutable
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    DateTime? createdAt,
    this.isError = false,
  }) : createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({String? text, bool? isError}) => ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        isError: isError ?? this.isError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'isError': isError,
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
      );
}
