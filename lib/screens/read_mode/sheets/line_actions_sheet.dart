// lib/screens/read_mode/sheets/line_actions_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../providers/player_provider.dart';
import '../controllers/read_mode_controller.dart';
import 'create_segment_sheet.dart';

class LineActionsSheet {
  LineActionsSheet._();

  static void show(BuildContext context, int lineIndex) {
    HapticFeedback.mediumImpact();

    final tp = context.read<TextProvider>();
    final player = context.read<PlayerProvider>();
    final line = tp.lines[lineIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Line preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dòng ${lineIndex + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    line.content,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            _ActionTile(
              icon: Icons.volume_up,
              label: 'Đọc TTS',
              subtitle: 'Text-to-Speech đọc dòng này',
              color: const Color(0xFF2196F3),
              onTap: () {
                Navigator.pop(sheetContext);
                tp.setCurrentLine(lineIndex);
                tp.speakCurrentLine();
              },
            ),

            if (line.startTime != null && player.currentSongPath != null)
              _ActionTile(
                icon: Icons.play_circle_outline,
                label: 'Phát audio tại vị trí này',
                subtitle:
                    'Nhảy tới ${_formatDuration(line.startTime!)} trong audio',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  Navigator.pop(sheetContext);
                  player.seek(line.startTime!);
                  player.play();
                },
              ),

            _ActionTile(
              icon: Icons.bookmark_add,
              label: 'Lưu vào bộ sưu tập',
              subtitle: 'Đánh dấu để ôn tập sau',
              color: Colors.amber,
              onTap: () {
                Navigator.pop(sheetContext);
                final controller = context.read<ReadModeController>();
                controller.bookmarkLine(lineIndex);
                CreateSegmentSheet.show(context);
              },
            ),

            _ActionTile(
              icon: Icons.copy,
              label: 'Sao chép dòng',
              subtitle: 'Copy nội dung vào clipboard',
              color: Colors.grey,
              onTap: () {
                Clipboard.setData(ClipboardData(text: line.content));
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Đã sao chép!'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            if (line.translation != null)
              _ActionTile(
                icon: Icons.translate,
                label: 'Sao chép bản dịch',
                subtitle: line.translation!,
                color: const Color(0xFF9C27B0),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: line.translation!));
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Đã sao chép bản dịch!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
