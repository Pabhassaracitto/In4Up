// lib/screens/read_mode/sheets/segments_list_sheet.dart
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/text_segment.dart';
import '../../../providers/text_provider.dart';
import 'create_segment_sheet.dart';

class SegmentsListSheet {
  SegmentsListSheet._();

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => _SegmentsListContent(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _SegmentsListContent extends StatelessWidget {
  final ScrollController scrollController;

  const _SegmentsListContent({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<TextProvider>(
      builder: (context, tp, _) {
        final segments = tp.segments;

        return Column(
          children: [
            // ===== DRAG HANDLE =====
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ===== HEADER =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bookmarks,
                      color: Color(0xFF2196F3),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Segments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          context.uiText('${segments.length} đoạn đã lưu'),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      CreateSegmentSheet.show(context, tp.currentLineIndex);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFF4CAF50),
                    tooltip: context.uiText('Tạo segment mới'),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // ===== CONTENT =====
            Expanded(
              child: segments.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: segments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final segment = segments[index];
                        return _SegmentTile(
                          segment: segment,
                          index: index,
                          onTap: () => _goToSegment(context, segment, tp),
                          onDelete: () => _deleteSegment(context, index, tp),
                          onRepeat: () => _repeatSegment(context, segment, tp),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            'Chưa có segment nào',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Long-press một dòng để tạo segment',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _goToSegment(
      BuildContext context, TextSegment segment, TextProvider tp) {
    Navigator.pop(context);
    tp.setCurrentLine(segment.startLine);
  }

  void _deleteSegment(BuildContext context, int index, TextProvider tp) {
    final segment = tp.segments[index];
    tp.deleteSegment(segment.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('Đã xóa "${segment.name}"')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
      ),
    );
  }

  void _repeatSegment(
      BuildContext context, TextSegment segment, TextProvider tp) {
    Navigator.pop(context);
    // Navigate to segment's start line and set repeat mode
    tp.setCurrentLine(segment.startLine);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.repeat, color: segment.color, size: 18),
            const SizedBox(width: 8),
            Text(context.uiText('Lặp lại "${segment.name}"')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final TextSegment segment;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRepeat;

  const _SegmentTile({
    required this.segment,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('segment_${segment.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A3E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Xóa segment?',
                style: TextStyle(color: Colors.white)),
            content: Text(
              context.uiText('Bạn có muốn xóa "${segment.name}"?'),
              style: TextStyle(color: Colors.grey[400]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[400],
                ),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: segment.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: segment.color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: segment.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered,
                            size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          context.uiText('Dòng ${segment.startLine + 1} → ${segment.endLine + 1} (${segment.lineCount} dòng)'),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (segment.note != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.note, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              segment.note!,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Repeat button
              GestureDetector(
                onTap: onRepeat,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: segment.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.repeat,
                    color: segment.color,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
