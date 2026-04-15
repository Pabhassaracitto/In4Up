// lib/services/shadowing/offline_stt_service.dart

import 'package:flutter/foundation.dart';
import 'package:vipsound_stt/vipsound_stt.dart';

/// Adapter tương thích ngược - dùng SttServiceFacade bên trong
class OfflineSTTService {
  static final _facade = SttServiceFacade();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _facade.initialize(config: SttConfig.quickNote);
    _initialized = true;
    debugPrint('✅ OfflineSTTService (via SttFacade) initialized');
  }

  /// Transcribe audio file - thay simulation bằng engine thật
  static Future<String> transcribe(
    String audioPath,
    String originalText, // Giữ để tương thích - không dùng nữa
  ) async {
    if (!_initialized) await initialize();

    try {
      final output = await _facade.transcribeFile(
        audioPath,
        config: SttConfig.quickNote,
      );

      if (output.success && output.result.fullText.isNotEmpty) {
        debugPrint('🎤 Real STT: "${output.result.fullText}"');
        return output.result.fullText;
      }
      return originalText;
    } catch (e) {
      debugPrint('❌ OfflineSTTService.transcribe error: $e');
      return originalText;
    }
  }

  static void dispose() {
    _facade.dispose();
    _initialized = false;
  }
}
