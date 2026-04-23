import '../models/ai_analysis.dart';

/// Abstract interface cho mọi AI backend
/// Hiện tại: GemmaEngine (llama.cpp)
/// Tương lai: MediaPipeEngine (iOS Neural Engine) - v2
abstract class AiEngine {
  /// Trạng thái hiện tại của engine
  AiEngineState get state;

  /// Khởi tạo và load model (chạy trên Isolate)
  /// [modelPath]: Đường dẫn đến file .gguf
  Future<bool> initialize({required String modelPath});

  /// Phân tích văn bản - trả về Stream để update UI dần dần
  /// Emit nhiều lần: partial result → full result
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    required double temperature, // Câu xung quanh (để Gemma hiểu ngữ cảnh)
  });

  /// Giải phóng tài nguyên
  Future<void> dispose();

  /// Warm-up: Load model sẵn vào RAM (gọi khi app start)
  Future<void> warmUp();
}

enum AiEngineState {
  uninitialized,
  loading, // Đang load model
  ready, // Sẵn sàng xử lý
  processing, // Đang phân tích
  error,
  disposed,
}
