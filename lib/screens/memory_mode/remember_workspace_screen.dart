import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../providers/vocabulary_provider.dart';
import 'memory_tab_connector.dart';
import 'widgets/remember_workspace_header.dart';

/// NHỚ-WORKSPACE-002 — màn workspace Nhớ.
///
/// Public API (constructor + callback) giữ NGUYÊN như trước để
/// main_shell.dart không phải đổi: vocabulary provider, due count và các
/// callback mở Review / Word List / Timeline / Stats / Word Map không đổi.
/// Phần trình bày được tách sang [RememberWorkspaceHeader] để phân rõ
/// hoạt động học chính (Ôn tập / Thuộc lòng) khỏi công cụ xem tiến độ.
class RememberWorkspaceScreen extends StatelessWidget {
  final VoidCallback onOpenReview;
  final VoidCallback onOpenWordList;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenQuickActions;
  final VoidCallback? onOpenLearnByHeart;

  const RememberWorkspaceScreen({
    super.key,
    required this.onOpenReview,
    required this.onOpenWordList,
    required this.onOpenTimeline,
    required this.onOpenStats,
    required this.onOpenMap,
    required this.onOpenQuickActions,
    this.onOpenLearnByHeart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AUDIT-2026-10-20 (mục 3): BỎ `AutoHideInfoBanner` (tự ẩn sau 5
        // giây) — người dùng chưa kịp chọn thì cả thanh chức năng biến
        // mất. Thay bằng cơ chế GỘP/BUNG bằng mũi tên (như thanh phát
        // trong vùng đọc): mặc định gọn, bấm mũi tên để bung ra.
        Consumer<VocabularyProvider>(
          builder: (context, vocab, _) {
            return RememberWorkspaceHeader(
              dueCount: vocab.dueCount,
              totalWords: vocab.wordCount,
              onOpenReview: onOpenReview,
              onOpenLearnByHeart: onOpenLearnByHeart,
              onOpenWordList: onOpenWordList,
              onOpenTimeline: onOpenTimeline,
              onOpenStats: onOpenStats,
              onOpenMap: onOpenMap,
              onOpenQuickActions: onOpenQuickActions,
            );
          },
        ),
        const Expanded(
          child: MemoryTabConnector(),
        ),
      ],
    );
  }
}
