/// VipSound STT - Hybrid Speech-to-Text Module
///
/// Cách dùng:
/// ```dart
/// import 'package:vipsound_stt/vipsound_stt.dart';
/// ```

library vipsound_stt;

// Core facade
export 'stt_service_facade.dart';

// Engines
export 'stt_engine_native.dart';
export 'stt_engine_whisper.dart';

// Model management
export 'stt_model_manager.dart';

// LRC conversion
export 'stt_lrc_converter.dart';

// Models
export 'models/stt_result.dart';
export 'models/stt_config.dart';
export 'models/stt_model_info.dart';
