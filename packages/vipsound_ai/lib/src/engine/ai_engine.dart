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

  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature,
  });

  Future<void> warmUp();
  Future<void> dispose();
}
