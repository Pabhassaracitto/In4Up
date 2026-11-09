// packages/in4up_ai/lib/src/engine/ai_capability_probe.dart
//
// API-DIAG-001 — "chạy thử THẬT" từng năng lực qua API đang cấu hình.
//
// `ai_routing_report.dart` trả lời "SẼ dùng cái gì" (thuần dữ liệu). File này
// trả lời "THỰC TẾ có chạy được không": gửi một request THẬT, rất nhỏ, tới
// đúng provider/model mà app sẽ dùng, rồi báo ok/lỗi + độ trễ.
//
// Nguyên tắc:
// - Không bao giờ log/hiển thị apiKey; lỗi trả về là MÃ lỗi cấu trúc
//   ([AiApiErrorCode]) + message của server (không chứa header).
// - Mỗi lần thử đều có timeout rõ ràng (chat/tts 20s, stt 30s) — người dùng
//   đang ngồi chờ ở màn cài đặt.
// - Transport được inject để test 100% offline (không gọi mạng thật, không
//   cần key trong code test).
// - Dịch được kiểm bằng ĐÚNG model dịch (`translationModel` nếu có, ngược lại
//   `chatModel`) và một câu ngắn — vì "chat model chạy được" KHÔNG bảo đảm
//   model dịch chạy được.
// - STT file cần file audio thật ⇒ ở đây chỉ kiểm tra /v1/models (provider
//   sống + model STT có trong danh sách). `sttModelListVerified = true`,
//   `transcribedRealAudio = false` — UI phải nói rõ để không hiểu nhầm.
//
// KHÔNG chứa chuỗi hiển thị tiếng Việt (rule vàng #5): chỉ trả dữ liệu có
// cấu trúc, app layer tự dựng câu đã dịch.

import '../provider/ai_provider_config.dart';
import '../provider/openai_compat_client.dart';

enum AiProbeStatus {
  /// Gửi request thật, provider trả lời hợp lệ.
  ok,

  /// Provider trả lỗi (mã ở [AiProbeResult.errorCode] nếu có).
  failed,

  /// Không có gì để thử (mode offlineOnly / chưa có provider / thiếu model).
  skipped,
}

/// Lý do bỏ qua (enum — UI dịch).
enum AiProbeSkipReason {
  /// Không provider nào phục vụ năng lực này (hoặc routing = chỉ trên máy).
  noProvider,

  /// Provider chưa chọn model cho năng lực này.
  noModel,
}

/// Kết quả 1 lần chạy thử.
class AiProbeResult {
  final AiRouteCapability capability;
  final AiProbeStatus status;
  final AiProbeSkipReason? skipReason;
  final AiProviderConfig? provider;
  final String? model;
  final Duration latency;
  final AiApiErrorCode? errorCode;

  /// Message gốc từ provider/server (KHÔNG dịch — nội dung kỹ thuật).
  final String? errorDetail;

  /// Output mẫu thu được (chat/dịch) — UI hiện "model trả về: …".
  final String? sample;

  /// Số byte audio TTS nhận được.
  final int? audioBytes;

  /// Số model provider khai báo (khi gọi /v1/models).
  final int? modelCount;

  /// STT: model đã chọn có trong /v1/models?
  final bool? modelPresentInModelList;

  /// STT: đã bóc băng file audio thật? (false — probe không có file mẫu).
  final bool transcribedRealAudio;

  const AiProbeResult({
    required this.capability,
    required this.status,
    this.skipReason,
    this.provider,
    this.model,
    this.latency = Duration.zero,
    this.errorCode,
    this.errorDetail,
    this.sample,
    this.audioBytes,
    this.modelCount,
    this.modelPresentInModelList,
    this.transcribedRealAudio = false,
  });

  bool get ok => status == AiProbeStatus.ok;

  factory AiProbeResult.skipped(
    AiRouteCapability capability,
    AiProbeSkipReason reason, {
    AiProviderConfig? provider,
    String? model,
  }) =>
      AiProbeResult(
        capability: capability,
        status: AiProbeStatus.skipped,
        skipReason: reason,
        provider: provider,
        model: model,
      );
}

/// Lớp gửi request thật — inject để test không cần mạng.
abstract class AiProbeTransport {
  /// Chat 1 câu ngắn, trả content.
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String prompt,
    required Duration timeout,
  });

  /// Danh sách model của provider (dùng cho phép thử STT file).
  Future<List<String>> listModels({
    required AiProviderConfig provider,
    required Duration timeout,
  });

  /// Tổng hợp 1 từ ngắn, trả số byte audio.
  Future<int> speech({
    required AiProviderConfig provider,
    required String model,
    required String input,
    required Duration timeout,
  });
}

/// Transport thật: dùng ĐÚNG client OpenAI-compat duy nhất (ADR-0008).
class OpenAiCompatProbeTransport implements AiProbeTransport {
  const OpenAiCompatProbeTransport();

  OpenAiCompatClient _client(AiProviderConfig p) => OpenAiCompatClient(
        baseUrl: p.baseUrl,
        apiKey: p.apiKey,
      );

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String prompt,
    required Duration timeout,
  }) =>
      _client(provider).chatCompletion(
        model: model,
        messages: [OpenAiChatMessage('user', prompt)],
        maxTokens: 32,
        temperature: 0,
        timeout: timeout,
      );

  @override
  Future<List<String>> listModels({
    required AiProviderConfig provider,
    required Duration timeout,
  }) =>
      _client(provider).listModels();

  @override
  Future<int> speech({
    required AiProviderConfig provider,
    required String model,
    required String input,
    required Duration timeout,
  }) async {
    final bytes = await _client(provider).synthesizeSpeech(
      model: model,
      input: input,
      timeout: timeout,
    );
    return bytes.length;
  }
}

/// Chạy thử 1 năng lực.
///
/// [provider] lấy từ báo cáo (`AiCapabilityReport.provider`) — nếu null thì
/// trả `skipped` chứ không tự đi tìm provider (để UI phản ánh ĐÚNG cấu hình
/// đang chạy, không "tự sửa" cho đẹp).
Future<AiProbeResult> probeAiCapability({
  required AiRouteCapability capability,
  required AiProviderConfig? provider,
  AiProbeTransport transport = const OpenAiCompatProbeTransport(),
  Duration? timeout,
}) async {
  if (provider == null) {
    return AiProbeResult.skipped(
        capability, AiProbeSkipReason.noProvider);
  }

  final model = provider.modelFor(capability);
  if (model == null) {
    return AiProbeResult.skipped(
      capability,
      AiProbeSkipReason.noModel,
      provider: provider,
    );
  }

  final limit = timeout ??
      (capability == AiRouteCapability.sttFile
          ? const Duration(seconds: 30)
          : const Duration(seconds: 20));

  final watch = Stopwatch()..start();
  try {
    switch (capability) {
      case AiRouteCapability.chat:
      case AiRouteCapability.translation:
        final text = await transport.chat(
          provider: provider,
          model: model,
          prompt: _promptFor(capability),
          timeout: limit,
        );
        watch.stop();
        final trimmed = text.trim();
        if (trimmed.isEmpty) {
          return AiProbeResult(
            capability: capability,
            status: AiProbeStatus.failed,
            provider: provider,
            model: model,
            latency: watch.elapsed,
            errorCode: AiApiErrorCode.invalidResponse,
          );
        }
        return AiProbeResult(
          capability: capability,
          status: AiProbeStatus.ok,
          provider: provider,
          model: model,
          latency: watch.elapsed,
          sample: _clip(trimmed),
        );

      case AiRouteCapability.tts:
        final bytes = await transport.speech(
          provider: provider,
          model: model,
          input: 'Xin chào',
          timeout: limit,
        );
        watch.stop();
        if (bytes <= 0) {
          return AiProbeResult(
            capability: capability,
            status: AiProbeStatus.failed,
            provider: provider,
            model: model,
            latency: watch.elapsed,
            errorCode: AiApiErrorCode.invalidResponse,
          );
        }
        return AiProbeResult(
          capability: capability,
          status: AiProbeStatus.ok,
          provider: provider,
          model: model,
          latency: watch.elapsed,
          audioBytes: bytes,
        );

      case AiRouteCapability.sttFile:
        // Không gửi file audio (app không có file mẫu): kiểm provider sống +
        // model STT có trong /v1/models. KHÔNG báo là đã bóc băng.
        final models = await transport.listModels(
          provider: provider,
          timeout: limit,
        );
        watch.stop();
        final found = models.contains(model);
        return AiProbeResult(
          capability: capability,
          status: found ? AiProbeStatus.ok : AiProbeStatus.failed,
          provider: provider,
          model: model,
          latency: watch.elapsed,
          errorCode: found ? null : AiApiErrorCode.invalidResponse,
          modelCount: models.length,
          modelPresentInModelList: found,
          transcribedRealAudio: false,
        );
    }
  } on AiApiException catch (e) {
    watch.stop();
    return AiProbeResult(
      capability: capability,
      status: AiProbeStatus.failed,
      provider: provider,
      model: model,
      latency: watch.elapsed,
      errorCode: e.code,
      errorDetail: e.message,
    );
  } catch (e) {
    watch.stop();
    return AiProbeResult(
      capability: capability,
      status: AiProbeStatus.failed,
      provider: provider,
      model: model,
      latency: watch.elapsed,
      errorDetail: '$e',
    );
  }
}

/// Câu thử: chat thì "trả lời 1 từ", dịch thì dịch 1 câu ngắn.
///
/// Đây là PROMPT gửi cho model (input kỹ thuật), không phải chuỗi UI.
String _promptFor(AiRouteCapability capability) {
  switch (capability) {
    case AiRouteCapability.translation:
      return 'Translate to Vietnamese, output the translation only: '
          '"Good morning"';
    case AiRouteCapability.chat:
    case AiRouteCapability.tts:
    case AiRouteCapability.sttFile:
      return 'Reply with exactly one word: OK';
  }
}

/// Cặp (năng lực, provider) cần thử — dựng từ báo cáo route.
class AiCapabilityProbeTarget {
  final AiRouteCapability capability;
  final AiProviderConfig? provider;
  const AiCapabilityProbeTarget(this.capability, this.provider);
}

/// Chạy thử nhiều năng lực TUẦN TỰ (tránh dồn 4 request cùng lúc lên server
/// nhà) và báo từng kết quả ngay ([onResult]) để UI cập nhật dần.
Future<List<AiProbeResult>> probeAiCapabilities({
  required Iterable<AiCapabilityProbeTarget> targets,
  AiProbeTransport transport = const OpenAiCompatProbeTransport(),
  void Function(AiProbeResult result)? onResult,
}) async {
  final out = <AiProbeResult>[];
  for (final target in targets) {
    final result = await probeAiCapability(
      capability: target.capability,
      provider: target.provider,
      transport: transport,
    );
    out.add(result);
    onResult?.call(result);
  }
  return out;
}

String _clip(String text) {
  const max = 120;
  final single = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return single.length <= max ? single : '${single.substring(0, max)}…';
}
