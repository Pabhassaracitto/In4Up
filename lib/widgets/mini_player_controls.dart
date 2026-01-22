import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class MiniPlayerControls extends StatelessWidget {
  const MiniPlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replay 10s
            IconButton(
              onPressed: () => player.replay10(),
              icon: const Icon(Icons.replay_10, size: 28),
              color: Colors.white70,
            ),

            const SizedBox(width: 8),

            // A-B Loop Start
            _LoopButton(
              label: 'A',
              isActive: player.loopStart != null,
              onTap: () => player.setLoopStart(),
            ),

            const SizedBox(width: 8),

            // Play/Pause
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: player.isLooping
                      ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                      : [const Color(0xFF6C63FF), const Color(0xFF3F3D56)],
                ),
              ),
              child: IconButton(
                onPressed: () => player.togglePlayPause(),
                icon: Icon(
                  player.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 8),

            // A-B Loop End
            _LoopButton(
              label: 'B',
              isActive: player.loopEnd != null,
              onTap: () => player.setLoopEnd(),
            ),

            const SizedBox(width: 8),

            // Forward 10s
            IconButton(
              onPressed: () => player.forward10(),
              icon: const Icon(Icons.forward_10, size: 28),
              color: Colors.white70,
            ),

            // Clear loop (nếu đang loop)
            if (player.isLooping)
              IconButton(
                onPressed: () => player.clearLoop(),
                icon: const Icon(Icons.close, size: 20),
                color: Colors.red,
                tooltip: 'Xóa loop',
              ),
          ],
        );
      },
    );
  }
}

class _LoopButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LoopButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? (label == 'A' ? Colors.green : Colors.red)
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isActive
                ? (label == 'A' ? Colors.green : Colors.red)
                : Colors.white38,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}