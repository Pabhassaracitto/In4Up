import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../providers/vocabulary_provider.dart';
import '../../core/navigation/workspace_handoff_inbox.dart';
import '../../models/i4u_shell_contracts.dart';
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
    return ListenableBuilder(
      listenable: I4uWorkspaceHandoffInbox.instance,
      builder: (context, _) {
        final source = I4uWorkspaceHandoffInbox.instance.current;
        return Column(
          children: [
            if (source != null) _buildIncomingSourceCard(context, source),
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
      },
    );
  }

  Widget _buildIncomingSourceCard(
    BuildContext context,
    I4uSourceFingerprint source,
  ) {
    final isVideo = source.sourceType == I4uSourceType.video;
    final timestamp = source.timestampMs == null
        ? null
        : Duration(milliseconds: source.timestampMs!);
    return Material(
      color: const Color(0xFF121B32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Icon(
              isVideo ? Icons.ondemand_video_outlined : Icons.headphones_outlined,
              color: const Color(0xFF8B83FF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.uiText('Nguồn đang ghi nhớ'),
                    style: const TextStyle(
                      color: Color(0xFFB8B2FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isVideo ? context.uiText('Video') : context.uiText('Audio')}${timestamp == null ? '' : ' · ${timestamp.toString().split('.').first}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if ((source.selectedText ?? '').trim().isNotEmpty)
                    Text(
                      source.selectedText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.uiText('Đóng ngữ cảnh'),
              onPressed: I4uWorkspaceHandoffInbox.instance.clear,
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
