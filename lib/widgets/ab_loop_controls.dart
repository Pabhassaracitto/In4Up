import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'save_segment_dialog.dart';

class ABLoopControls extends StatelessWidget {
  const ABLoopControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: player.isLooping
                ? const Color(0xFF4CAF50).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: player.isLooping
                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.loop,
                    size: 16,
                    color: player.isLooping ? const Color(0xFF4CAF50) : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    player.isLooping ? 'Đang lặp đoạn' : 'Lặp A-B',
                    style: TextStyle(
                      color: player.isLooping ? const Color(0xFF4CAF50) : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Controls
              Row(
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

                  // Thông tin loop hoặc hướng dẫn
                  if (player.isLooping) ...[
                    // Loop info
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.replay, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                '${player.loopCount}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Nút Save & Clear
                        Row(
                          children: [
                            // Save button
                            _ActionButton(
                              icon: Icons.bookmark_add,
                              label: 'Lưu',
                              color: Colors.amber,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const SaveSegmentDialog(),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // Clear button
                            _ActionButton(
                              icon: Icons.close,
                              label: 'Xóa',
                              color: Colors.red,
                              onTap: () => player.clearLoop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    // Hướng dẫn
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.grey.withOpacity(0.5),
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.loopStart != null
                                ? 'Bấm B để lặp'
                                : 'Bấm A để bắt đầu',
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.7),
                              fontSize: 11,
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
                ],
              ),
            ],
          ),
        );
      },
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isActive ? color : Colors.white38,
            width: 3,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (time != null)
              Text(
                _formatDuration(time!),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}