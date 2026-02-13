// lib/screens/memory_mode/memory_provider.dart

import 'controllers/memory_controller.dart';

class MemoryProvider {
  // Biến tĩnh giữ instance duy nhất
  static MemoryController? _controller;

  // Getter luôn trả về instance đã có, hoặc tạo mới nếu chưa có
  static MemoryController get controller {
    _controller ??= MemoryController();
    return _controller!;
  }

  // Hàm gọi tắt để thêm từ (giữ nguyên các tham số chi tiết)
  static bool addWord({
    required String word,
    String? meaning,
    String? phonetic,
    String? example,
    String? context,
    String? audioPath,
    Duration? audioStart,
    Duration? audioEnd,
    String? wordType,
    String? cefrLevel,
    String? sourceFile,
    int? sourceLine,
    List<String> tags = const [],
  }) {
    return controller.addWord(
      word: word,
      meaning: meaning,
      phonetic: phonetic,
      example: example,
      context: context,
      audioPath: audioPath,
      audioStart: audioStart,
      audioEnd: audioEnd,
      wordType: wordType,
      cefrLevel: cefrLevel,
      sourceFile: sourceFile,
      sourceLine: sourceLine,
      tags: tags,
    );
  }

  /// Số từ cần ôn (cho badge)
  static int get dueCount => controller.dueItems.length;

  /// Tổng số từ
  static int get totalCount => controller.allItems.length;

  /// Dispose (gọi khi app tắt)
  static void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
