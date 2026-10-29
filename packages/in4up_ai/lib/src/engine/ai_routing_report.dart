// packages/in4up_ai/lib/src/engine/ai_routing_report.dart
//
// API-DIAG-001 — "Hệ thống AI đang chạy cái gì?" (thuần logic, test được).
//
// Owner (2026-10-26): *"Thiết lập hệ thống test thực tế xem các ai nó chạy
// hiện hành là gì"*. Trước đây người dùng chỉ thấy chip "Tự động / Ưu tiên
// online…" và dropdown provider — KHÔNG biết với cấu hình hiện tại thì:
//   • năng lực này đang đi API hay chạy trên máy?
//   • API thì provider + model NÀO?
//   • máy thì engine nào?
// Report ở đây trả lời đúng 3 câu đó cho CẢ 4 năng lực (chat / dịch / STT
// file / TTS), dùng cùng nguồn dữ liệu với engine thật:
//   • mode cấu hình (AiRoutingPrefs) → mode THẬT theo loại mạng
//     (`resolveRouteMode`);
//   • provider: `AiProviderStore.resolveProvider()` (đã xét enabled + model);
//   • model: `AiProviderConfig.modelFor()` (dịch dùng `translationModel`).
//
// KHÔNG chứa chuỗi hiển thị (rule vàng #5): chỉ trả dữ liệu có cấu trúc —
// app layer map sang chuỗi đã dịch. KHÔNG gọi mạng: phần "chạy thử thật" nằm
// ở `ai_capability_probe.dart`.

import 'ai_connectivity_routing.dart';
import '../provider/ai_provider_config.dart';
import '../provider/ai_provider_store.dart';

/// Gợi ý engine CỤC BỘ sẽ chạy khi năng lực không dùng API.
///
/// Chỉ là "loại engine" (enum) — app layer dịch sang câu mô tả, để report
/// không mang tiếng Việt vào tầng package.
enum AiLocalEngineHint {
  /// Chat: Gemma trên máy, hoặc trả lời mẫu khi chưa có model.
  gemmaOrFallback,

  /// Dịch: chuỗi engine dịch trên máy (HY-MT / ML Kit / …).
  translationChain,

  /// STT: Whisper / sherpa-onnx (Parakeet) trên máy.
  whisperOrSherpa,

  /// TTS: engine TTS trên máy (Piper / Edge / Zalo / FPT / …).
  deviceTts,
}

AiLocalEngineHint localEngineHintOf(AiRouteCapability capability) {
  switch (capability) {
    case AiRouteCapability.chat:
      return AiLocalEngineHint.gemmaOrFallback;
    case AiRouteCapability.translation:
      return AiLocalEngineHint.translationChain;
    case AiRouteCapability.sttFile:
      return AiLocalEngineHint.whisperOrSherpa;
    case AiRouteCapability.tts:
      return AiLocalEngineHint.deviceTts;
  }
}

/// Cảnh báo cấu hình cho UI (enum — không phải chuỗi).
enum AiRouteWarning {
  /// Không có cảnh báo.
  none,

  /// Mode không phải "chỉ trên máy" nhưng không provider nào phục vụ được
  /// năng lực này ⇒ request sẽ KHÔNG đi API (chạy trên máy).
  noProviderForCapability,

  /// Có provider nhưng năng lực này chưa chọn model (vd chưa chọn model dịch
  /// và cũng chưa có chat model để fallback).
  noModelForCapability,
}

/// Một dòng trong báo cáo: năng lực → đang dùng cái gì.
class AiCapabilityReport {
  final AiRouteCapability capability;

  /// Mode người dùng chọn (có thể là `auto`).
  final AiRouteMode configuredMode;

  /// Mode THẬT sau khi xét loại mạng (auto → onlineFirst/offlineFirst/…).
  final AiRouteMode effectiveMode;

  /// Provider sẽ được gọi (null ⇒ không gọi API).
  final AiProviderConfig? provider;

  /// Model API sẽ dùng (null khi không có provider / chưa chọn model).
  final String? model;

  /// Loại mạng lúc lập báo cáo.
  final AiNetworkKind network;

  /// Loại engine cục bộ sẽ chạy khi không dùng API.
  final AiLocalEngineHint localEngine;

  const AiCapabilityReport({
    required this.capability,
    required this.configuredMode,
    required this.effectiveMode,
    required this.provider,
    required this.model,
    required this.network,
    required this.localEngine,
  });

  /// Có gọi API không — chính là "AI đang chạy hiện hành".
  bool get usesApi => provider != null && model != null;

  /// Model dịch đang là model riêng hay đang mượn chat model (chỉ có nghĩa
  /// với năng lực dịch).
  bool get translationFallsBackToChatModel =>
      capability == AiRouteCapability.translation &&
      provider != null &&
      provider!.translationModel == null &&
      provider!.chatModel != null;

  AiRouteWarning get warning {
    if (effectiveMode == AiRouteMode.offlineOnly) return AiRouteWarning.none;
    if (provider == null) return AiRouteWarning.noProviderForCapability;
    if (model == null) return AiRouteWarning.noModelForCapability;
    return AiRouteWarning.none;
  }
}

/// Lập báo cáo cho MỌI năng lực (hoặc chỉ [only]).
List<AiCapabilityReport> buildAiRoutingReport({
  required AiProviderStore store,
  required AiNetworkKind network,
  Iterable<AiRouteCapability>? only,
}) {
  final caps = only ?? AiRouteCapability.values;
  return [
    for (final cap in caps)
      _reportFor(store: store, capability: cap, network: network),
  ];
}

AiCapabilityReport _reportFor({
  required AiProviderStore store,
  required AiRouteCapability capability,
  required AiNetworkKind network,
}) {
  final configured = store.routing.modeOf(capability);
  final effective = resolveRouteMode(configured, network);

  AiProviderConfig? provider;
  if (effective != AiRouteMode.offlineOnly) {
    // `resolveProvider` xét cả mode đã resolve + provider bật + có model.
    provider = store.resolveProvider(capability, network: network);
  }

  return AiCapabilityReport(
    capability: capability,
    configuredMode: configured,
    effectiveMode: effective,
    provider: provider,
    model: provider?.modelFor(capability),
    network: network,
    localEngine: localEngineHintOf(capability),
  );
}
