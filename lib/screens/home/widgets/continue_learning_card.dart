import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import 'continue_learning_section.dart';

/// HOME-CONTINUE-001 — widget kết nối của khu vực "Tiếp tục học".
///
/// Chỉ đọc dữ liệu THẬT từ các provider đã có sẵn ở app root:
/// - [PlayerProvider.currentSongTitle] → bài nghe đang dở;
/// - [TextProvider.currentDocument] / [TextProvider.currentTextPath]
///   → văn bản đang đọc;
/// - [VocabularyProvider.dueCount] → số từ đến hạn ôn.
///
/// Không tạo dữ liệu giả: provider nào chưa có dữ liệu thì mục tương ứng
/// không xuất hiện. "Workspace gần đây" sẽ được thêm khi có provider thật
/// expose dữ liệu đó (yêu cầu "nếu dữ liệu hiện có hỗ trợ").
class ContinueLearningCard extends StatelessWidget {
  final VoidCallback onResumeListening;
  final VoidCallback onResumeReading;
  final VoidCallback onReviewDue;

  const ContinueLearningCard({
    super.key,
    required this.onResumeListening,
    required this.onResumeReading,
    required this.onReviewDue,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final text = context.watch<TextProvider>();
    final vocab = context.watch<VocabularyProvider>();

    final entries = buildContinueLearningEntries(
      onResumeListening: onResumeListening,
      onResumeReading: onResumeReading,
      onReviewDue: onReviewDue,
      listeningTitle: player.currentSongTitle,
      readingTitle: _readingTitle(text),
      dueWordCount: vocab.dueCount,
    );

    return ContinueLearningSection(entries: entries);
  }

  /// Tiêu đề văn bản đang đọc: ưu tiên title của document, fallback tên file
  /// từ đường dẫn đang mở. Null = chưa đọc gì → không hiện entry.
  String? _readingTitle(TextProvider text) {
    final doc = text.currentDocument;
    if (doc != null && doc.title.trim().isNotEmpty) {
      return doc.title.trim();
    }
    final path = text.currentTextPath?.trim();
    if (path == null || path.isEmpty) return null;
    final name = path.replaceAll('\\', '/').split('/').last.trim();
    return name.isEmpty ? null : name;
  }
}
