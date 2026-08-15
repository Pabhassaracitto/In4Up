import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vocabulary_provider.dart';
import '../services/vocab_sync_service.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, provider, _) {
        if (!provider.isSyncEnabled) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<SyncStatus>(
          valueListenable: provider.syncStatusNotifier,
          builder: (context, status, _) {
            return ValueListenableBuilder<DateTime?>(
              valueListenable: provider.lastSyncedNotifier,
              builder: (context, lastSync, _) {
                return _buildBadge(context, status, lastSync);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBadge(
      BuildContext context, SyncStatus status, DateTime? lastSync) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case SyncStatus.syncing:
        color = Colors.blue;
        icon = Icons.sync;
        label = 'Đang đồng bộ...';
        break;
      case SyncStatus.error:
        color = Colors.red;
        icon = Icons.sync_problem;
        label = 'Lỗi đồng bộ';
        break;
      case SyncStatus.success:
        color = Colors.green;
        icon = Icons.cloud_done;
        label = 'Đã đồng bộ';
        break;
      case SyncStatus.idle:
      default:
        color = Colors.grey;
        icon = Icons.cloud_queue;
        label =
            lastSync != null ? 'Đã lưu ${_formatTime(lastSync)}' : 'Sẵn sàng';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(status, icon, color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(SyncStatus status, IconData icon, Color color) {
    if (status == SyncStatus.syncing) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Icon(icon, size: 12, color: color);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
    if (diff.inHours < 24) return '${diff.inHours}h trước';
    return '${dt.day}/${dt.month}';
  }
}
