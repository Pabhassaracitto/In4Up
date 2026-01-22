import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends StatelessWidget {
  final bool expanded;
  final bool fullScreen;

  const MiniPlayer({
    super.key,
    this.expanded = false,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        if (fullScreen) {
          return _buildFullPlayer(context, player);
        }

        if (expanded) {
          return _buildExpandedPlayer(context, player);
        }

        return _buildMiniPlayer(context, player);
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, PlayerProvider player) {
    final progress = player.state.duration.inMilliseconds > 0
        ? player.state.position.inMilliseconds / player.state.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 8),
          // Controls
          Row(
            children: [
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.currentSongTitle ?? 'No song',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatDuration(player.state.position),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Quick controls
              Row(
                children: [
                  IconButton(
                    onPressed: () => player.replay10(),
                    icon: const Icon(Icons.replay_10, size: 24),
                    tooltip: '-10s',
                  ),
                  IconButton(
                    onPressed: () => player.togglePlayPause(),
                    icon: Icon(
                      player.isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 40,
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  IconButton(
                    onPressed: () => player.forward10(),
                    icon: const Icon(Icons.forward_10, size: 24),
                    tooltip: '+10s',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPlayer(BuildContext context, PlayerProvider player) {
    final progress = player.state.duration.inMilliseconds > 0
        ? player.state.position.inMilliseconds / player.state.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Song title
          Text(
            player.currentSongTitle ?? 'No song',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) => player.seekToPercent(value),
            ),
          ),
          // Time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(player.state.position),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                // Speed indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${player.state.speed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(player.state.duration),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => player.replay30(),
                icon: const Icon(Icons.replay_30),
                tooltip: '-30s',
              ),
              IconButton(
                onPressed: () => player.replay10(),
                icon: const Icon(Icons.replay_10),
                tooltip: '-10s',
              ),
              // Play/Pause button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
                child: IconButton(
                  onPressed: () => player.togglePlayPause(),
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                  color: const Color(0xFF6C63FF),
                ),
              ),
              IconButton(
                onPressed: () => player.forward10(),
                icon: const Icon(Icons.forward_10),
                tooltip: '+10s',
              ),
              IconButton(
                onPressed: () => player.forward30(),
                icon: const Icon(Icons.forward_30),
                tooltip: '+30s',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullPlayer(BuildContext context, PlayerProvider player) {
    // Full player layout - similar to home screen player
    return _buildExpandedPlayer(context, player);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes =