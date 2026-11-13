// lib/services/shadowing/offline_stt_service.dart

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';

/// Adapter tương thích ngược - dùng SttServiceFacade bên trong.
class OfflineSTTService {
  static final _facade = SttServiceFacade();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _facade.initialize(config: SttConfig.quickNote);
    _initialized = true;
    debugPrint('✅ OfflineSTTService (via SttFacade) initialized');
  }

  /// PSRC-227: never substitute the reference sentence for a failed/empty STT
  /// result. A null return means "not recognized", not "the user read perfectly".
  static Future<String?> transcribe(String audioPath) async {
    if (!_initialized) await initialize();

    try {
      final output = await _facade.transcribeFile(
        audioPath,
        config: SttConfig.quickNote,
      );

      if (output.success && output.result.fullText.trim().isNotEmpty) {
        debugPrint('🎤 Real STT: "${output.result.fullText}"');
        return output.result.fullText;
      }
      debugPrint('⚠️ Shadowing STT returned no usable transcript');
      return null;
    } catch (e) {
      debugPrint('❌ OfflineSTTService.transcribe error: $e');
      return null;
    }
  }

  static void dispose() {
    _facade.dispose();
    _initialized = false;
  }
}
