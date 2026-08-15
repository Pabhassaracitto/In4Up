// lib/screens/memory_mode/memory_tab_connector.dart

import 'package:flutter/material.dart';
import 'memory_mode_screen.dart';

/// Connector để tích hợp Memory Mode vào tab system của in4up
///
/// Sử dụng trong MainScreen:
/// ```dart
/// // Trong tabs list:
/// const MemoryTabConnector(), // Tab NHỚ
/// ```
class MemoryTabConnector extends StatelessWidget {
  const MemoryTabConnector({super.key});

  @override
  Widget build(BuildContext context) {
    return const MemoryModeScreen();
  }

  /// Icon cho tab bar
  static const IconData tabIcon = Icons.psychology;
  static const IconData tabIconActive = Icons.psychology;

  /// Label
  static const String tabLabel = 'Remember';

  /// Badge count (số từ cần ôn)
  /// Gọi từ main screen để hiện notification badge
  static Future<int> getDueBadgeCount() async {
    // TODO: Quick check from storage without full controller
    return 0;
  }
}

/// Mixin để tích hợp vào TextProvider (lưu từ → Memory)
/// Sử dụng trong TextProvider khi user save word:
///
/// ```dart
/// // Trong text_provider.dart > saveWord():
/// MemoryBridge.addWordToMemory(
///   word: word,
///   meaning: meaning,
///   context: contextLine,
///   sourceFile: currentFileName,
/// );
/// ```
class MemoryBridge {
  static final List<Map<String, dynamic>> _pendingWords = [];

  /// Thêm từ vào hàng đợi (gọi từ TextProvider)
  static void addWordToMemory({
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
  }) {
    _pendingWords.add({
      'word': word,
      'meaning': meaning,
      'phonetic': phonetic,
      'example': example,
      'context': context,
      'audioPath': audioPath,
      'audioStart': audioStart?.inMilliseconds,
      'audioEnd': audioEnd?.inMilliseconds,
      'wordType': wordType,
      'cefrLevel': cefrLevel,
      'sourceFile': sourceFile,
      'sourceLine': sourceLine,
    });

    debugPrint('🧠 MemoryBridge: queued "$word" for memory');
  }

  /// Lấy và xóa pending words (gọi từ MemoryController)
  static List<Map<String, dynamic>> consumePendingWords() {
    final words = List<Map<String, dynamic>>.from(_pendingWords);
    _pendingWords.clear();
    return words;
  }

  /// Có pending words không?
  static bool get hasPending => _pendingWords.isNotEmpty;
}