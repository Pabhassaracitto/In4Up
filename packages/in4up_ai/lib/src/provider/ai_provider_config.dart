// packages/in4up_ai/lib/src/provider/ai_provider_config.dart
//
// WP0 (API-001) — Cấu hình nhà cung cấp AI (cloud hoặc server LAN) + chính
// sách định tuyến offline/online cho từng năng lực.
//
// Nguyên tắc (ADR-0007):
// - App KHÔNG kèm key nào (BYOK) — user tự nhập.
// - Mặc định: DANH SÁCH RỖNG + mọi năng lực offlineFirst → chưa cấu hình thì
//   app hành xử y hệt trước khi có tầng API.
// - baseUrl cloud bắt buộc https; http (cleartext) chỉ chấp nhận host
//   LAN/localhost (check trong OpenAiCompatClient — không check ở đây để
//   config layer thuần dữ liệu, test được).

import 'dart:convert';

/// Năng lực có thể định tuyến qua API.
enum AiRouteCapability {
  /// AI Chat / Word Lookup / Write Studio (LLM).
  chat,

  /// Bóc băng file audio (STT file — KHÔNG phải live mic).
  sttFile,

  /// Dịch thuật (LLM engine bổ sung vào chuỗi engine có sẵn).
  translation,

  /// Đọc chữ (TTS cloud/local server).
  tts,
}

/// Chính sách định tuyến cho 1 năng lực.
enum AiRouteMode {
  /// Thử engine offline trước; lỗi/thiếu model → thử API (nếu có provider).
  offlineFirst,

  /// Thử API trước (nếu có provider + mạng); lỗi → fallback offline.
  onlineFirst,

  /// Không bao giờ gọi API cho năng lực này (riêng tư / tiết kiệm dữ liệu).
  offlineOnly,
}

/// 1 nhà cung cấp AI — cloud (Groq/Gemini/OpenAI/OpenRouter…) hoặc
/// server nhà (Ollama/LM Studio/llama-server/Speaches/Kokoro…).
///
/// [id] cố định sau khi tạo (dùng làm khóa tham chiếu trong routing prefs).
class AiProviderConfig {
  final String id;
  final String label;
  final String baseUrl;

  /// Cloud: bắt buộc. Server LAN: thường bỏ trống.
  final String? apiKey;

  /// Tên model theo năng lực — user chọn từ /v1/models (KHÔNG hard-code).
  final String? chatModel;
  final String? sttModel;
  final String? ttsModel;
  final bool enabled;

  const AiProviderConfig({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.apiKey,
    this.chatModel,
    this.sttModel,
    this.ttsModel,
    this.enabled = true,
  });

  AiProviderConfig copyWith({
    String? label,
    String? baseUrl,
    String? apiKey,
    bool clearApiKey = false,
    String? chatModel,
    bool clearChatModel = false,
    String? sttModel,
    bool clearSttModel = false,
    String? ttsModel,
    bool clearTtsModel = false,
    bool? enabled,
  }) {
    return AiProviderConfig(
      id: id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      chatModel: clearChatModel ? null : (chatModel ?? this.chatModel),
      sttModel: clearSttModel ? null : (sttModel ?? this.sttModel),
      ttsModel: clearTtsModel ? null : (ttsModel ?? this.ttsModel),
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'baseUrl': baseUrl,
        if (apiKey != null && apiKey!.isNotEmpty) 'apiKey': apiKey,
        if (chatModel != null) 'chatModel': chatModel,
        if (sttModel != null) 'sttModel': sttModel,
        if (ttsModel != null) 'ttsModel': ttsModel,
        'enabled': enabled,
      };

  static AiProviderConfig fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String?,
      chatModel: json['chatModel'] as String?,
      sttModel: json['sttModel'] as String?,
      ttsModel: json['ttsModel'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Provider có model cho năng lực này không (dùng khi routing chọn đích).
  bool supports(AiRouteCapability c) {
    switch (c) {
      case AiRouteCapability.chat:
        return chatModel != null && chatModel!.isNotEmpty;
      case AiRouteCapability.sttFile:
        return sttModel != null && sttModel!.isNotEmpty;
      case AiRouteCapability.translation:
        return chatModel != null && chatModel!.isNotEmpty;
      case AiRouteCapability.tts:
        return ttsModel != null && ttsModel!.isNotEmpty;
    }
  }
}

/// Chính sách định tuyến toàn app — mặc định toàn bộ offlineFirst.
class AiRoutingPrefs {
  final Map<AiRouteCapability, AiRouteMode> modes;
  final Map<AiRouteCapability, String> preferredProviderIds;

  const AiRoutingPrefs({
    this.modes = const {},
    this.preferredProviderIds = const {},
  });

  AiRouteMode modeOf(AiRouteCapability c) =>
      modes[c] ?? AiRouteMode.offlineFirst;

  String? preferredProviderOf(AiRouteCapability c) => preferredProviderIds[c];

  AiRoutingPrefs copyWith({
    Map<AiRouteCapability, AiRouteMode>? modes,
    Map<AiRouteCapability, String>? preferredProviderIds,
  }) {
    return AiRoutingPrefs(
      modes: modes ?? this.modes,
      preferredProviderIds: preferredProviderIds ?? this.preferredProviderIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'modes': {
          for (final e in modes.entries)
            e.key.toString().split('.').last: e.value.toString().split('.').last,
        },
        'preferredProviderIds': Map<String, String>.from(preferredProviderIds
            .map((k, v) => MapEntry(k.toString().split('.').last, v))),
      };

  static AiRoutingPrefs fromJson(Map<String, dynamic> json) {
    final modes = <AiRouteCapability, AiRouteMode>{};
    final rawModes = json['modes'] as Map<String, dynamic>? ?? {};
    for (final cap in AiRouteCapability.values) {
      final key = cap.toString().split('.').last;
      final raw = rawModes[key] as String?;
      if (raw == null) continue;
      for (final m in AiRouteMode.values) {
        if (m.toString().split('.').last == raw) {
          modes[cap] = m;
          break;
        }
      }
    }
    final preferred = <AiRouteCapability, String>{};
    final rawPreferred = json['preferredProviderIds'] as Map<String, dynamic>? ?? {};
    for (final cap in AiRouteCapability.values) {
      final key = cap.toString().split('.').last;
      final raw = rawPreferred[key] as String?;
      if (raw != null && raw.isNotEmpty) preferred[cap] = raw;
    }
    return AiRoutingPrefs(modes: modes, preferredProviderIds: preferred);
  }
}

/// Tiện ích encode/decode list provider (dùng chung cho store + test).
String encodeProviders(List<AiProviderConfig> providers) =>
    jsonEncode([for (final p in providers) p.toJson()]);

List<AiProviderConfig> decodeProviders(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    // Prefs hỏng/không phải JSON — coi như chưa có provider nào (không crash).
    return const [];
  }
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is Map<String, dynamic>) AiProviderConfig.fromJson(item),
  ];
}
