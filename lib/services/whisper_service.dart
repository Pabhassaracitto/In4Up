import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in2up_stt/stt_model_manager.dart';
import 'package:in2up_stt/in2up_stt.dart';
import '../native/whisper_bindings.dart';

/// Service quản lý trực tiếp Native FFI cho Whisper (đặc biệt là Windows)
/// Kết nối giữa logic Native và SttModelManager hiện tại
class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  Pointer<Void>? _context;
  bool get isInitialized => _context != null;

  /// Khởi tạo Native Context từ model đã được SttModelManager tải về
  Future<void> initNativeContext() async {
    // Hiện tại bindings chỉ cấu hình cho Windows
    if (!Platform.isWindows) return;

    try {
      final modelManager = SttModelManager();

      // Đảm bảo Manager đã khởi tạo để biết đường dẫn thư mục model
      await modelManager.initialize();

      // Tìm model tốt nhất đang có sẵn (ưu tiên base hoặc small)
      final bestLevel = modelManager.getBestAvailableLocalModel(
        preferredOrder: [
          WhisperModelLevel.base,
          WhisperModelLevel.small,
          WhisperModelLevel.tiny,
        ],
      );

      if (bestLevel == null) {
        debugPrint(
            'ℹ️ WhisperService: Chưa có model offline nào để init native context.');
        return;
      }

      final modelPath = modelManager.getModelPath(bestLevel);
      if (modelPath == null || !await File(modelPath).exists()) {
        debugPrint(
            '⚠️ WhisperService: File model không tồn tại tại $modelPath');
        return;
      }

      debugPrint(
          '🚀 WhisperService: Đang nạp model native ($bestLevel) từ: $modelPath');

      // Gọi hàm từ whisper_bindings.dart
      _context = whisperInitFromFile(modelPath);

      if (_context != null) {
        debugPrint(
            '✅ WhisperService: Native context khởi tạo thành công tại $_context');
      } else {
        debugPrint('❌ WhisperService: whisper_init_* trả về null (context rỗng)');
      }
    } catch (e) {
      debugPrint('❌ WhisperService Error: $e');
    }
  }

  // Bạn có thể thêm các hàm wrapper cho whisper_full_parallel tại đây nếu cần
}
