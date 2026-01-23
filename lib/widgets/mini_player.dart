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

  // ============================================================
  // MINI PLAYER (Thanh nhỏ ở dưới cùng)
  // ============================================================
  Widget _buildMiniPlayer(BuildContext context, PlayerProvider player) {
    final progress = player.state.duration.inMilliseconds > 0
        ? player.state.position.inMilliseconds /
        player.state.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 8),
            // Controls row
            Row(
              children: [
                // Song info
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Navigate to full player screen
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          player.currentSongTitle ?? 'No song selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _formatDuration(player.state.position),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const Text(
                              ' / ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(player.state.duration),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            // A-B Loop indicator
                            if (player.state.isLooping) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'A-B',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Quick controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Replay 10s
                    IconButton(
                      onPressed: () => player.replay10(),
                      icon: const Icon(Icons.replay_10, size: 24),
                      color: Colors.white70,
                      tooltip: '-10s',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    // Play/Pause
                    IconButton(
                      onPressed: () => player.togglePlayPause(),
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 44,
                        color: const Color(0xFF6C63FF),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    // Forward 10s
                    IconButton(
                      onPressed: () => player.forward10(),
                      icon: const Icon(Icons.forward_10, size: 24),
                      color: Colors.white70,
                      tooltip: '+10s',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXPANDED PLAYER (Player mở rộng với nhiều controls hơn)
  // ============================================================
  Widget _buildExpandedPlayer(BuildContext context, PlayerProvider player) {
    final progress = player.state.duration.inMilliseconds > 0
        ? player.state.position.inMilliseconds /
        player.state.duration.inMilliseconds
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song title
            Text(
              player.currentSongTitle ?? 'No song selected',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Progress slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: const Color(0xFF6C63FF),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFF6C63FF),
                overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) => player.seekToPercent(value),
              ),
            ),

            // Time row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Current position
                  Text(
                    _formatDuration(player.state.position),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  // Speed indicator
                  GestureDetector(
                    onTap: () => _showSpeedPicker(context, player),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${player.state.speed.toStringAsFixed(2)}x',
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Total duration
                  Text(
                    _formatDuration(player.state.duration),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Replay 30s
                IconButton(
                  onPressed: () => player.replay30(),
                  icon: const Icon(Icons.replay_30),
                  color: Colors.white70,
                  tooltip: '-30s',
                ),
                // Replay 10s
                IconButton(
                  onPressed: () => player.replay10(),
                  icon: const Icon(Icons.replay_10),
                  color: Colors.white70,
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
                      size: 36,
                    ),
                    color: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                // Forward 10s
                IconButton(
                  onPressed: () => player.forward10(),
                  icon: const Icon(Icons.forward_10),
                  color: Colors.white70,
                  tooltip: '+10s',
                ),
                // Forward 30s
                IconButton(
                  onPressed: () => player.forward30(),
                  icon: const Icon(Icons.forward_30),
                  color: Colors.white70,
                  tooltip: '+30s',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Secondary controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // A-B Loop toggle
                _buildSecondaryButton(
                  icon: Icons.repeat,
                  label: 'A-B',
                  isActive: player.state.isLooping,
                  onTap: () => player.toggleLoop(),
                ),
                // Sleep Timer
                _buildSecondaryButton(
                  icon: Icons.bedtime_outlined,
                  label: player.state.sleepTimerRemaining != null
                      ? _formatDuration(player.state.sleepTimerRemaining!)
                      : 'Sleep',
                  isActive: player.state.sleepTimerRemaining != null,
                  onTap: () => _showSleepTimerPicker(context, player),
                ),
                // Bookmark
                _buildSecondaryButton(
                  icon: Icons.bookmark_border,
                  label: 'Mark',
                  isActive: false,
                  onTap: () {
                    // TODO: Add bookmark at current position
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FULL SCREEN PLAYER
  // ============================================================
  Widget _buildFullPlayer(BuildContext context, PlayerProvider player) {
    // Full player - can be expanded later with waveform, lyrics, etc.
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Now Playing'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Album art placeholder
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.music_note,
                  size: 100,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ),
          // Expanded player controls
          Expanded(
            flex: 2,
            child: _buildExpandedPlayer(context, player),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPER WIDGETS
  // ============================================================
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6C63FF).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF6C63FF) : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF6C63FF) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS
  // ============================================================
  void _showSpeedPicker(BuildContext context, PlayerProvider player) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: speeds.map((speed) {
                final isSelected =
                    (player.state.speed - speed).abs() < 0.01;
                return GestureDetector(
                  onTap: () {
                    player.setSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context, PlayerProvider player) {
    final durations = [
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(hours: 1),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sleep Timer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (player.state.sleepTimerRemaining != null)
                  TextButton(
                    onPressed: () {
                      player.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel Timer',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: durations.map((duration) {
                final label = duration.inMinutes >= 60
                    ? '${duration.inHours}h'
                    : '${duration.inMinutes}m';
                return GestureDetector(
                  onTap: () {
                    player.setSleepTimer(duration);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UTILITY FUNCTIONS
  // ============================================================
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}