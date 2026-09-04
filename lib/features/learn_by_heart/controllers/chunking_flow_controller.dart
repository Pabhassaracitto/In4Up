// lib/features/learn_by_heart/controllers/chunking_flow_controller.dart

import 'package:flutter/foundation.dart';
import '../models/chunk.dart';
import '../models/learn_by_heart_item.dart';

enum ChunkStepType {
  studySingle, // Nghe & đọc 1 chunk
  clozeSingle, // Điền khuyết 1 chunk
  mergeReview, // Ghép các chunk đã học
  fullRecall, // Tự đọc toàn bài
}

class ChunkFlowStep {
  final ChunkStepType type;
  final int chunkIndex;
  final String title;
  final String description;
  final List<int> lineRange;

  const ChunkFlowStep({
    required this.type,
    required this.chunkIndex,
    required this.title,
    required this.description,
    required this.lineRange,
  });
}

/// Controller điều phối luồng học cuốn chiếu (Cognitive Scaffolding Flow)
class ChunkingFlowController extends ChangeNotifier {
  final LearnByHeartItem item;
  final List<ChunkFlowStep> _steps = [];

  int _currentStepIndex = 0;
  bool _isStepCompleted = false;

  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _steps.length;
  List<ChunkFlowStep> get steps => List.unmodifiable(_steps);
  ChunkFlowStep get currentStep => _steps[_currentStepIndex];
  bool get isStepCompleted => _isStepCompleted;
  bool get isFinished => _currentStepIndex >= _steps.length - 1 && _isStepCompleted;

  ChunkingFlowController(this.item) {
    _buildSteps();
  }

  void _buildSteps() {
    final chunks = item.chunkList.isNotEmpty ? item.chunkList : _fallbackChunks();

    final List<int> accumulatedLines = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      accumulatedLines.addAll(chunk.lineRange);

      // Bước 1: Học & nghe Chunk i
      _steps.add(ChunkFlowStep(
        type: ChunkStepType.studySingle,
        chunkIndex: chunk.index,
        title: 'Học ${chunk.label}',
        description: chunk.clue ?? 'Lắng nghe và đọc theo nhịp',
        lineRange: chunk.lineRange,
      ));

      // Bước 2: Điền khuyết Chunk i
      _steps.add(ChunkFlowStep(
        type: ChunkStepType.clozeSingle,
        chunkIndex: chunk.index,
        title: 'Thử thách: ${chunk.label}',
        description: 'Chạm mở các từ ẩn để tự kiểm tra',
        lineRange: chunk.lineRange,
      ));

      // Bước 3: Nếu đã qua từ chunk 2 trở lên → Ghép các chunk lại
      if (i > 0) {
        _steps.add(ChunkFlowStep(
          type: ChunkStepType.mergeReview,
          chunkIndex: chunk.index,
          title: 'Ghép đoạn (Chunk 1 → ${chunk.index})',
          description: 'Hợp nhất các đoạn đã học trước khi sang phần tiếp theo',
          lineRange: List.unmodifiable(accumulatedLines),
        ));
      }
    }

    // Bước Cuối cùng: Kiểm tra toàn bài
    _steps.add(ChunkFlowStep(
      type: ChunkStepType.fullRecall,
      chunkIndex: chunks.length,
      title: 'Hoàn thành toàn bài',
      description: 'Đọc trọn vẹn bài kinh và đánh giá chu kỳ ôn tập',
      lineRange: item.lineTimestamps.isNotEmpty
          ? item.lineTimestamps.map((t) => t.line).toList()
          : List.generate(item.memorizeLines.length, (i) => i + 1),
    ));
  }

  List<Chunk> _fallbackChunks() {
    final lineCount = item.memorizeLines.isNotEmpty ? item.memorizeLines.length : 4;
    final half = (lineCount / 2).ceil();
    return [
      Chunk(index: 1, label: 'Đoạn 1', lineRange: List.generate(half, (i) => i + 1)),
      Chunk(index: 2, label: 'Đoạn 2', lineRange: List.generate(lineCount - half, (i) => half + i + 1)),
    ];
  }

  void markStepCompleted() {
    _isStepCompleted = true;
    notifyListeners();
  }

  bool nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _isStepCompleted = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _isStepCompleted = true;
      notifyListeners();
      return true;
    }
    return false;
  }
}
