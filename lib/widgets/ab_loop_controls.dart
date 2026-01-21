import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class ABLoopControls extends StatelessWidget {
  const ABLoopControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Nút A
              _LoopButton(
                label: 'A',
                isActive: player.loopStart != null,
                time: player.loopStart,
                onTap: () => player.setLoopStart(),
                color: Colors.green,
              ),
              
              // Trạng thái loop
              if (player.isLooping) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.loop, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${player.loopCount}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Nút B
              _LoopButton(
                label: 'B',
                isActive: player.loopEnd != null,
                time: player.loopEnd,
                onTap: () => player.setLoopEnd(),
                color: Colors.red,
              ),
              
              // Nút xóa loop
              if (player.isLooping)
                IconButton(
                  onPressed: () => player.clearLoop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Xóa loop',
                ),
              
              // Nút lưu thành segment
              if (player.isLooping)
                IconButton(
                  onPressed: () => _showSaveDialog(context, player),
                  icon: const Icon(Icons.bookmark_add, color: Colors.amber),
                  tooltip: 'Lưu đoạn này',
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSaveDialog(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SaveSegmentSheet(player: player),
    );
  }
}

class _LoopButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Duration? time;
  final VoidCallback onTap;
  final Color color;

  const _LoopButton({
    required this.label,
    required this.isActive,
    this.time,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color : Colors.white24,
          border: Border.all(
            color: isActive ? color : Colors.white38,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (time != null)
              Text(
                _formatDuration(time!),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}