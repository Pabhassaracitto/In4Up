// packages/vipsound_ai/lib/vipsound_ai.dart

// Facade - chỉ cần import cái này trong app layer
export 'src/facade/ai_service_facade.dart';

// Models
export 'src/models/ai_analysis.dart';

// Loader - cho UI hiển thị trạng thái model
export 'src/loader/ai_model_loader.dart'
    show AiModelLoader, ModelLoadResult, ModelSource, AiModelConfig;

// Engine state - cho UI
export 'src/engine/ai_engine.dart' show AiEngineState;

// Error log - để app layer lưu vào storage
export 'src/error/ai_error_handler.dart' show ErrorLogEntry;

// Mock engine - cho testing
export 'src/engine/ai_engine_mock.dart';

// VipSound v11.0 — Barrel export
export 'src/engine/ai_engine_gemma.dart';