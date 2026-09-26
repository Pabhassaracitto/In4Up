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

// Mock engine - cho testing
export 'src/engine/ai_engine_mock.dart';

// in4up v11.0 — Barrel export
export 'src/engine/ai_engine_gemma.dart';

// WP1 (API-002) — Engine LLM remote (chat streaming + analysis qua API) và
// hoạch định route theo AiRoutingPrefs.
export 'src/engine/ai_engine_remote.dart'
    show AiEngineRemote, AiRemoteJsonExtractor;
export 'src/engine/ai_route_planner.dart';

// WP0 (API-001) — Tầng Server API (cloud + LAN): cấu hình provider,
// routing offline/online, client OpenAI-compatible duy nhất.
export 'src/provider/ai_provider_config.dart';
export 'src/provider/ai_provider_store.dart'
    show AiProviderStore;
export 'src/provider/openai_compat_client.dart'
    show
        OpenAiCompatClient,
        OpenAiModelsParser,
        AiApiException,
        AiApiErrorCode,
        AiProviderHealth;

// WP1 (API-002) — Primitives chat streaming: mã lỗi cấu trúc, cancel token,
// message/usage/chunk, parser SSE (dùng chung client + engine + facade).
export 'src/provider/ai_sse.dart';
