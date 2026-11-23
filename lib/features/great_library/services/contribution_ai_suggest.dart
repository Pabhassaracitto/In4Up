// lib/features/great_library/services/contribution_ai_suggest.dart
//
// GLIB-006 — nút "Gợi ý bằng AI" (opt-in, mặc định TẮT — ADR-0031 D6).
// Backend pluggable (OpenAiCompatChatBackend thật tái dùng tầng BYOK
// in4up_ai; fake trong test) → khi tắt/chưa cấu hình provider: KHÔNG gọi
// network, trả null ngay.

import 'dart:convert';

import 'package:in4up_ai/in4up_ai.dart';

import '../../translation/engines/llm_mt_engine.dart' show LlmMtBackend;
import '../models/pack_manifest.dart';
import 'pack_contribution_service.dart';

/// Gợi ý metadata AI trả về (user vẫn sửa lại trước khi gửi).
class ContributionAiSuggestion {
  const ContributionAiSuggestion({
    this.title,
    this.description,
    this.tags,
    this.level,
  });

  final String? title;
  final String? description;
  final List<String>? tags;
  final String? level;
}

class ContributionAiSuggest {
  ContributionAiSuggest({
    Future<AiProviderConfig?> Function()? providerResolver,
    LlmMtBackend? backend,
    this.timeout = const Duration(seconds: 30),
  })  : _providerResolver = providerResolver,
        _backend = backend ?? const OpenAiCompatChatBackend();

  final Future<AiProviderConfig?> Function()? _providerResolver;
  final LlmMtBackend _backend;
  final Duration timeout;

  /// Có provider BYOK khả dụng không (quyết định nút AI có bật không).
  Future<bool> isAvailable() async => await _resolve() != null;

  Future<AiProviderConfig?> _resolve() async {
    final resolver = _providerResolver;
    if (resolver == null) return null;
    try {
      return await resolver();
    } on Object {
      return null;
    }
  }

  /// Gợi ý title/mô tả/tags/CEFR từ mẫu nội dung. Trả null khi: không có
  /// provider (BYOK chưa cấu hình), lỗi mạng/API — UI giữ nguyên form.
  Future<ContributionAiSuggestion?> suggest({
    required PackType type,
    required List<String> sampleWords,
  }) async {
    final provider = await _resolve();
    if (provider == null) return null; // AI tắt/chưa cấu hình → 0 network.
    final model = provider.chatModel;
    if (model == null || model.trim().isEmpty) return null;

    final sample = sampleWords.take(30).join(', ');
    const system = 'You are a metadata assistant for a language-learning '
        'content pack library. Reply with STRICT JSON only.';
    final user = 'Suggest metadata for a ${type.wire} pack with these sample '
        'items: $sample.\n'
        'Reply JSON: {"title": "...", "description": "...", '
        '"tags": ["..."], "level": "A1|A2|B1|B2|C1|C2|mixed"}. '
        'Title/description in Vietnamese, tags in lowercase English, '
        'level is the CEFR estimate.';

    final String raw;
    try {
      raw = await _backend.chat(
        provider: provider,
        model: model,
        systemPrompt: system,
        userPrompt: user,
        maxTokens: 300,
        timeout: timeout,
      );
    } on Object {
      return null;
    }
    return _parse(raw);
  }

  ContributionAiSuggestion? _parse(String raw) {
    // Chịu cả output bọc ```json fence.
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on Object {
      return null;
    }
    if (decoded is! Map) return null;
    final map = decoded.cast<String, dynamic>();
    String? str(String k) {
      final v = map[k];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final level = str('level');
    return ContributionAiSuggestion(
      title: str('title'),
      description: str('description'),
      tags: (map['tags'] is List)
          ? (map['tags'] as List)
              .whereType<String>()
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .take(10)
              .toList()
          : null,
      level:
          (level != null && kPackLevels.contains(level)) ? level : null,
    );
  }
}
