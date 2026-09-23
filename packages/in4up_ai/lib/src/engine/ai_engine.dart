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

  /// True khi backend đang xử lý một request (chat dùng để biết "còn đang
  /// generate" — không báo "chưa nạp model" và không đẩy thêm request).
  bool get isBusy;

  Future<bool> initialize({required String modelPath});

  /// Hủy mọi request đang treo và dựng lại backend (isolate + native handle)
  /// với model hiện tại — dùng khi native treo (FFI blocking không thể cancel)
  /// hoặc isolate bị hệ thống thu hồi vì thiếu RAM.
  ///
  /// Trả về true khi backend đã handshake lại xong (model native vẫn cần
  /// [modelReady] để báo nạp xong). Trả về false nếu không thể khởi động lại
  /// (chưa từng init / spawn lỗi) — facade sẽ báo lỗi retry được cho người dùng.
  Future<bool> recover({String? reason});

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
