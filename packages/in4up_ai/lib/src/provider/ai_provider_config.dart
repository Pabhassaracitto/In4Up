// packages/in4up_ai/lib/src/provider/ai_provider_config.dart
//
// WP0 (API-001) — Cấu hình nhà cung cấp AI (cloud hoặc server LAN) + chính
// sách định tuyến offline/online cho từng năng lực.
//
// Nguyên tắc (ADR-0008):
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
  /// YT-AUDIT-06 (IN4-104): **theo loại mạng** — wifi ⇒ ưu tiên online,
  /// mạng di động ⇒ ưu tiên cục bộ rồi mới online, không mạng ⇒ chỉ cục bộ.
  ///
  /// Đây là MẶC ĐỊNH mới (trước đây mặc định `offlineFirst`). Resolve ở
  /// `resolveRouteMode()` / `AiConnectivityRouter.resolve()`.
  auto,

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

  /// API-TRANS-MODEL-001 — model DỊCH riêng (trước đây dịch dùng chung
  /// `chatModel` và màn Server & API không có ô nào để chọn). Bỏ trống ⇒ dùng
  /// `chatModel` (hành vi cũ, không phá cấu hình đã có).
  final String? translationModel;
  final String? sttModel;
  final String? ttsModel;
  final bool enabled;

  const AiProviderConfig({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.apiKey,
    this.chatModel,
    this.translationModel,
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
    String? translationModel,
    bool clearTranslationModel = false,
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
      translationModel: clearTranslationModel
          ? null
          : (translationModel ?? this.translationModel),
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
        if (translationModel != null) 'translationModel': translationModel,
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
      translationModel: json['translationModel'] as String?,
      sttModel: json['sttModel'] as String?,
      ttsModel: json['ttsModel'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Model THẬT sẽ dùng khi dịch: `translationModel` nếu có, ngược lại
  /// `chatModel` (giữ tương thích cấu hình cũ — chưa có ô dịch riêng).
  String? get effectiveTranslationModel {
    final t = translationModel;
    if (t != null && t.isNotEmpty) return t;
    final c = chatModel;
    return (c != null && c.isNotEmpty) ? c : null;
  }

  /// Model theo từng năng lực (null ⇒ provider không phục vụ năng lực đó).
  /// UI + báo cáo "AI đang chạy" đọc CHUNG hàm này để không lệch nhau.
  String? modelFor(AiRouteCapability c) {
    switch (c) {
      case AiRouteCapability.chat:
        return (chatModel != null && chatModel!.isNotEmpty) ? chatModel : null;
      case AiRouteCapability.translation:
        return effectiveTranslationModel;
      case AiRouteCapability.sttFile:
        return (sttModel != null && sttModel!.isNotEmpty) ? sttModel : null;
      case AiRouteCapability.tts:
        return (ttsModel != null && ttsModel!.isNotEmpty) ? ttsModel : null;
    }
  }

  /// Provider có model cho năng lực này không (dùng khi routing chọn đích).
  bool supports(AiRouteCapability c) => modelFor(c) != null;
}

/// Chính sách định tuyến toàn app — mặc định `auto` (theo loại mạng).
class AiRoutingPrefs {
  final Map<AiRouteCapability, AiRouteMode> modes;
  final Map<AiRouteCapability, String> preferredProviderIds;

  const AiRoutingPrefs({
    this.modes = const {},
    this.preferredProviderIds = const {},
  });

  /// YT-AUDIT-06 (IN4-104): mặc định `auto` (theo loại mạng) thay vì
  /// `offlineFirst`. Lưu ý: đây là mode NGƯỜI DÙNG CHỌN (hoặc mặc định) —
  /// mode THẬT phải đi qua `resolveRouteMode()` / `AiConnectivityRouter`.
  AiRouteMode modeOf(AiRouteCapability c) => modes[c] ?? AiRouteMode.auto;

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
