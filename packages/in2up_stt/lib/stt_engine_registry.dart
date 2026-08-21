// packages/in2up_stt/lib/stt_engine_registry.dart
//
// SttEngineRegistry — đăng ký & tạo engine theo SttEngineType.
// Đây là trung tâm của Strategy Pattern: thêm engine mới (vd Sherpa) chỉ
// cần implement SttEngine rồi đăng ký ở đây.

import 'models/stt_result.dart';
import 'stt_engine.dart';
import 'stt_engine_native.dart';
import 'stt_engine_native_strategy.dart';
import 'stt_engine_sherpa.dart';
import 'stt_engine_whisper_strategy.dart';

/// Factory đăng ký một loại engine.
typedef SttEngineFactory = SttEngine Function();

class SttEngineRegistry {
  SttEngineRegistry._();

  /// Map type → factory. Facade có thể override để thêm engine tuỳ chỉnh.
  static final Map<SttEngineType, SttEngineFactory> _factories = {
    SttEngineType.native: _nativeFactory,
    SttEngineType.whisper: _whisperFactory,
    // Sherpa — spike PoC. Khi chạy thử có thể tắt bằng cách đăng ký lại
    // hoặc bỏ dòng này để không build sherpa vào APK.
    SttEngineType.sherpa: _sherpaFactory,
  };

  static SttEngine _sherpaFactory() => SherpaSttEngine();

  /// Whisper cần modelDir — set từ ngoài sau khi SttModelManager khởi tạo.
  static String? whisperModelDir;
  static WhisperSttEngine? _whisperInstance;

  static SttEngine _nativeFactory() => NativeSttEngine(SttEngineNative());

  static SttEngine _whisperFactory() {
    _whisperInstance ??= WhisperSttEngine(
      modelDir: whisperModelDir ?? '',
    );
    return _whisperInstance!;
  }

  /// Đăng ký engine mới (dùng cho Sherpa hoặc custom).
  static void register(SttEngineType type, SttEngineFactory factory) {
    _factories[type] = factory;
  }

  /// Tạo engine theo type. Trả null nếu chưa đăng ký.
  static SttEngine? create(SttEngineType type) {
    final factory = _factories[type];
    return factory == null ? null : factory();
  }

  /// Đặt modelDir cho Whisper (gọi sau khi model manager init).
  static void configureWhisperModelDir(String dir) {
    whisperModelDir = dir;
    if (_whisperInstance != null) {
      _whisperInstance = WhisperSttEngine(modelDir: dir);
    }
  }

  /// Danh sách type đã đăng ký.
  static List<SttEngineType> get registeredTypes => _factories.keys.toList();
}
