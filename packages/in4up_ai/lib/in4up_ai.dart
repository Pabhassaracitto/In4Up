// packages/in4up_ai/lib/in4up_ai.dart

// Facade - chỉ cần import cái này trong app layer
export 'src/facade/ai_service_facade.dart';

// Models
export 'src/models/ai_analysis.dart';
export 'src/models/chat_message.dart';

// Chat context policy (giới hạn lịch sử gửi xuống native — AI-CHAT-01)
export 'src/chat/chat_context_policy.dart';

// Defensive model-output parsing
export 'src/mapper/ai_model_mapper.dart';

// Loader - cho UI hiển thị trạng thái model
export 'src/loader/ai_model_loader.dart'
    show AiModelLoader, ModelLoadResult, ModelSource, AiModelConfig;

// Engine state + interface (interface để test/AT gắn engine giả)
export 'src/engine/ai_engine.dart' show AiEngine, AiEngineState;

// Error log - để app layer lưu vào storage
export 'src/error/ai_error_handler.dart' show ErrorLogEntry;

// YT-AUDIT-05 (IN4-105): mã lỗi MÁY cho `AiAnalysis.errorReason` (UI dịch,
// engine không được nhét chuỗi tiếng Anh thô vào đó nữa).
export 'src/error/ai_error_codes.dart';

// YT-AUDIT-05 (IN4-105): thư viện prompt — export để test pin được NỘI
// DUNG prompt (tra từ phải xin đủ 7 phần, có `grammar` khi có câu). Nếu
// không export thì chỉ có thể test gián tiếp qua engine thật.
export 'src/prompts/ai_prompts_library.dart';

// Mock engine - cho testing
export 'src/engine/ai_engine_mock.dart';

// in4up v11.0 — Barrel export
export 'src/engine/ai_engine_gemma.dart';

// WP1 (API-002) — Engine LLM remote (chat streaming + analysis qua API) và
// hoạch định route theo AiRoutingPrefs.
export 'src/engine/ai_engine_remote.dart'
    show AiEngineRemote, AiRemoteJsonExtractor;
export 'src/engine/ai_route_planner.dart';
// YT-AUDIT-06 (IN4-104): định tuyến theo loại mạng (wifi ⇒ online,
// 4G ⇒ cục bộ rồi online, không mạng ⇒ chỉ cục bộ).
export 'src/engine/ai_connectivity_routing.dart';

// WP0 (API-001) — Tầng Server API (cloud + LAN): cấu hình provider,
// routing offline/online, client OpenAI-compatible duy nhất.
// WP3 (API-004) thêm chatCompletion + OpenAiChatMessage (dịch bằng LLM).
export 'src/provider/ai_provider_config.dart';
export 'src/provider/builtin_ai_providers.dart';
export 'src/provider/ai_provider_store.dart'
    show AiProviderStore;

// API-SYNC-001 — đồng bộ cấu hình Server & API lên Firebase (phần THUẦN:
// snapshot + hòa giải LWW + bia mộ; I/O nằm ở app layer).
export 'src/provider/ai_settings_sync.dart';

// API-DIAG-001 — "AI đang chạy hiện hành là gì": báo cáo route theo năng lực
// (thuần) + chạy thử THẬT qua provider đang cấu hình (transport inject).
export 'src/engine/ai_routing_report.dart';
export 'src/engine/ai_capability_probe.dart';
export 'src/provider/openai_compat_client.dart'
    show
        OpenAiCompatClient,
        OpenAiModelsParser,
        // WP4 (API-005) — parser danh sách giọng TTS (thuần, test được).
        OpenAiVoicesParser,
        OpenAiChatMessage,
        AiApiException,
        AiApiErrorCode,
        AiProviderHealth;

// WP1 (API-002) — Primitives chat streaming: mã lỗi cấu trúc, cancel token,
// message/usage/chunk, parser SSE (dùng chung client + engine + facade).
export 'src/provider/ai_sse.dart';

// WP2 (API-003) — Model + parser kết quả transcribe audio (verbose_json).
export 'src/provider/ai_transcription.dart';
