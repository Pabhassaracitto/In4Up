import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/player_provider.dart';
import '../providers/waveform_provider.dart';
import '../widgets/waveform_editor.dart';
import '../widgets/player_controls.dart';
import '../widgets/speed_control.dart';
import '../widgets/ab_loop_controls.dart';

/// Chế độ NGHE - Audio-first experience
/// Focus: Waveform, Speed control, A-B Loop, Markers
class ListenModeScreen extends StatelessWidget {
  const ListenModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, WaveformProvider>(
      builder: (context, player, waveform, child) {
        // Nếu chưa có audio
        if (player.currentSongPath == null) {
          return _buildEmptyState(context);
        }

        return _buildPlayerContent(context, player, waveform);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headphones,
                size: 64,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Chế độ Nghe',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Thêm audio để bắt đầu nghe',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),

            // Import button
            ElevatedButton.icon(
              onPressed: () => _pickAudioFile(context),
              icon: const Icon(Icons.add),
              label: const Text('Chọn file Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Features
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      (Icons.waves, 'Waveform Editor chuyên nghiệp'),
      (Icons.loop, 'A-B Loop để lặp đoạn'),
      (Icons.speed, 'Điều chỉnh tốc độ 0.5x - 2.0x'),
      (Icons.bookmark, 'Đánh dấu điểm quan trọng'),
      (Icons.bedtime, 'Hẹn giờ tắt (Sleep Timer)'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(f.$1, color: const Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 12),
                Text(
                  f.$2,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlayerContent(BuildContext context, PlayerProvider player, WaveformProvider waveform) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Album art & Song info
          _buildSongInfo(player),

          const SizedBox(height: 24),

          // Waveform Editor (Full featured)
          const WaveformEditor(
            height: 220,
            showControls: true,
            showMarkersList: true,
            showShadowingArea: false,
          ),

          const SizedBox(height: 16),

          // A-B Loop Controls
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ABLoopControls(),
          ),

          const SizedBox(height: 16),

          // Progress & Time
          _buildProgressSection(player),

          const SizedBox(height: 16),

          // Player Controls
          const PlayerControls(),

          const SizedBox(height: 24),

          // Speed Control
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SpeedControlWidget(),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(context, player, waveform),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSongInfo(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Album art placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: player.isLooping
                    ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                    : [const Color(0xFF6C63FF), const Color(0xFF3F3D56)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (player.isLooping
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF6C63FF)).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              player.isLooping ? Icons.loop : Icons.music_note,
              color: Colors.white,
              size: 36,
            ),
          ),

          const SizedBox(width: 16),

          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.currentSongTitle ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  player.currentSongArtist ?? 'Unknown Artist',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),

                // Status badges
                Row(
                  children: [
                    if (player.isLooping)
                      _StatusBadge(
                        icon: Icons.loop,
                        label: '${player.loopCount}x',
                        color: const Color(0xFF4CAF50),
                      ),
                    if (player.hasSleepTimer) ...[
                      const SizedBox(width: 8),
                      _StatusBadge(
                        icon: Icons.bedtime,
                        label: _formatDuration(player.sleepRemaining ?? Duration.zero),
                        color: const Color(0xFF9C27B0),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(PlayerProvider player) {
    final position = player.state.position;
    final duration = player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: const Color(0xFF6C63FF),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: const Color(0xFF6C63FF),
              overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) => player.seekToPercent(value),
            ),
          ),

          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (player.isLooping && player.loopDuration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Loop: ${_formatDuration(player.loopDuration!)}',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, PlayerProvider player, WaveformProvider waveform) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickAction(
            icon: Icons.bookmark_add,
            label: 'Đánh dấu',
            color: const Color(0xFFFFB300),
            onTap: () {
              waveform.addMarker(
                startTime: player.state.position,
                label: 'Marker ${waveform.markers.length + 1}',
              );
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã thêm đánh dấu'),
                  backgroundColor: Color(0xFFFFB300),
                ),
              );
            },
          ),
          _QuickAction(
            icon: Icons.bedtime,
            label: 'Hẹn giờ',
            color: const Color(0xFF9C27B0),
            isActive: player.hasSleepTimer,
            onTap: () => _showSleepTimerSheet(context, player),
          ),
          _QuickAction(
            icon: Icons.share,
            label: 'Chia sẻ',
            color: const Color(0xFF2196F3),
            onTap: () {
              // TODO: Share
            },
          ),
          _QuickAction(
            icon: Icons.playlist_add,
            label: 'Playlist',
            color: const Color(0xFF4CAF50),
            onTap: () {
              // TODO: Add to playlist
            },
          ),
        ],
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, PlayerProvider player) {
    final durations = [5, 10, 15, 30, 45, 60, 90, 120];

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
                  'Hẹn giờ tắt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (player.hasSleepTimer)
                  TextButton(
                    onPressed: () {
                      player.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    child: const Text('Hủy hẹn giờ', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: durations.map((mins) {
                final label = mins >= 60 ? '${mins ~/ 60} giờ' : '$mins phút';
                return GestureDetector(
                  onTap: () {
                    player.setSleepTimerMinutes(mins);
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF9C27B0),
                        fontWeight: FontWeight.bold,
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

  Future<void> _pickAudioFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result != null && result.files.single.path != null && context.mounted) {
      await context.read<PlayerProvider>().loadSong(
        path: result.files.single.path!,
        title: result.files.single.name,
        autoPlay: true,
      );
      HapticFeedback.mediumImpact();
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// Helper widgets
class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
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
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.3) : color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: isActive ? Border.all(color: color) : null,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.grey[500],
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}