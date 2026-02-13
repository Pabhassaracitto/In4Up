import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../models/playback_state.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Seek backward 10s
            _buildControlButton(
              icon: Icons.replay_10,
              onPressed: () {
                final newPosition =
                    player.state.position - const Duration(seconds: 10);
                player.seek(
                  newPosition < Duration.zero ? Duration.zero : newPosition,
                );
              },
              size: 48,
            ),

            const SizedBox(width: 16),

            // Skip Previous
            _buildControlButton(
              icon: Icons.skip_previous,
              onPressed: () {
                player.seek(Duration.zero);
              },
              size: 56,
            ),

            const SizedBox(width: 16),

            // Play/Pause
            _buildPlayPauseButton(player),

            const SizedBox(width: 16),

            // Skip Next
            _buildControlButton(
              icon: Icons.skip_next,
              onPressed: () {
                // For single file player, seek to end
              },
              size: 56,
            ),

            const SizedBox(width: 16),

            // Seek forward 10s
            _buildControlButton(
              icon: Icons.forward_10,
              onPressed: () {
                final newPosition =
                    player.state.position + const Duration(seconds: 10);
                if (newPosition < player.state.duration) {
                  player.seek(newPosition);
                }
              },
              size: 48,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        iconSize: size * 0.5,
        onPressed: onPressed,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPlayPauseButton(PlayerProvider player) {
    final isPlaying = player.state.status == PlaybackStatus.playing;
    final isLoading = player.state.status == PlaybackStatus.loading ||
        player.state.status == PlaybackStatus.buffering;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : player.togglePlayPause,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 40,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}
