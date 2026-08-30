// VipSound v11.0 — AiEngine interface

import '../models/ai_analysis.dart';

export '../models/ai_analysis.dart';

enum AiEngineState {
  uninitialized,
  loading,
  ready,
  processing,
  error,
  disposed,
}

abstract class AiEngine {
  AiEngineState get state;

  Future<bool> initialize({required String modelPath});

  /// Complete khi model đã load xong trong backend (native llama.cpp có thể
  /// mất 1–2 phút với file GGUF lớn). Engine mock complete ngay.
  /// Fail (completeError) nếu model/native không load được — facade dùng để
  /// báo UI "đang nạp" và fallback mock trung thực.
  Future<void> get modelReady;

  /// [maxTokens]: số token tối đa model sinh (chat cần >256 vì trả JSON
  /// theo schema; mặc định 256 cho các phân tích ngắn).
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature,
    int maxTokens = 256,
  });

  Future<void> warmUp();
  Future<void> dispose();
}
