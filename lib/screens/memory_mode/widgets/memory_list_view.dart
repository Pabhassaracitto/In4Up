// lib/screens/memory_mode/widgets/memory_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/memory_controller.dart';
import '../models/memory_item.dart';
import '../models/memory_stage.dart';

class MemoryListView extends StatelessWidget {
  const MemoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryController>(
      builder: (context, controller, _) {
        final items = controller.filteredItems;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _MemoryListTile(
              item: item,
              onTap: () {
                HapticFeedback.selectionClick();
              },
              onDismissed: () => controller.removeItem(item.id),
            );
          },
        );
      },
    );
  }
}

class _MemoryListTile extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _MemoryListTile({
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final stage = item.stage;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.all(stage.index <= 1 ? 14 : 10),
          decoration: BoxDecoration(
            color: item.displayBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: stage.borderWidth > 0
                ? Border.all(
                    color: stage.primaryColor.withValues(alpha: 0.3),
                    width: stage.borderWidth.clamp(0, 2),
                  )
                : null,
          ),
          child: Row(
            children: [
              Text(stage.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.word,
                      style: TextStyle(
                        fontSize: 14 * stage.fontScale.clamp(0.9, 1.3),
                        fontWeight: stage.index <= 2
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: item.displayColor,
                      ),
                    ),
                    if (item.meaning != null)
                      Text(
                        item.meaning!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(item.strength * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: stage.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.needsReview)
                    Text(
                      'Cần ôn',
                      style: TextStyle(
                        fontSize: 9,
                        color: const Color(0xFFFF5252),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (item.nextReviewAt != null)
                    Text(
                      _formatNextReview(item.nextReviewAt!),
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNextReview(DateTime next) {
    final diff = next.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }
}
