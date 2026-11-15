// in4up v11.0 — Barrel export

export 'models/content_id.dart';
export 'models/stt_config.dart';
export 'models/stt_model_info.dart';
export 'models/stt_result.dart';
export 'stt_engine.dart';
export 'stt_engine_registry.dart';
export 'stt_engine_whisper_strategy.dart';
export 'stt_engine_native_strategy.dart';
export 'stt_lrc_converter.dart';
export 'utils/whisper_language.dart';
// WHISPER-CLI-WIN-001: tìm + soi binary whisper.cpp (import table PE) để
// đường CLI báo đúng "thiếu DLL nào" thay vì exit -1073741515 với log rỗng.
export 'utils/src/whisper_cli_runtime.dart';
export 'utils/src/whisper_cli_locator.dart';
// WHISPER-CLI-WIN-001: `whisperPcmLoader` — điểm nối bộ đọc WAV→PCM cho đường
// FFI (mặc định null ⇒ engine đi CLI). Chỉ export phần cần dùng, không mở
// toàn bộ FFI nội bộ của engine.
export 'stt_engine_whisper.dart' show WhisperPcmLoader, registerWhisperPcmLoader;
export 'stt_service_facade.dart';
export 'diarization/speaker_annotation.dart';
export 'diarization/diarization_service.dart';
export 'diarization/speaker_sidecar.dart';
export 'meetily/meetily_adapter.dart';

export 'stt_engine_sherpa.dart';
export 'stt_engine_remote.dart';
export 'sherpa_bindings.dart';
export 'sherpa_model_manager.dart';
export 'import/model_bundle_scanner.dart';
export 'tts/sherpa_piper_tts_core.dart';
export 'tts/piper_voice_catalog.dart';
export 'tts/vieneu_tts_core.dart';
export 'tts/vieneu_model_files.dart';
export 'tts/vieneu_tts_paths.dart';
export 'vad/sherpa_vad_core.dart';
