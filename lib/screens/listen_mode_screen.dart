// lib/screens/listen_mode_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/waveform_data.dart';
import '../providers/player_provider.dart';
import '../providers/waveform_provider.dart';
import '../widgets/ab_loop_controls.dart';
import '../widgets/player_controls.dart';
import '../widgets/rolling_waveform_controller.dart';
import '../widgets/rolling_waveform_view.dart';
import '../widgets/speed_control.dart';

class ListenModeScreen extends StatefulWidget {
  const ListenModeScreen({super.key});

  @override
  State<ListenModeScreen> createState() => _ListenModeScreenState();
}

class _ListenModeScreenState extends State<ListenModeScreen> {
  late RollingWaveformController _waveformController;

  @override
  void initState() {
    super.initState();
    _waveformController = RollingWaveformController();
  }

  @override
  void dispose() {
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, WaveformProvider>(
      builder: (context, player, waveform, child) {
        // Update waveform data khi có thay đổi
        if (waveform.waveformData.isNotEmpty &&
            _waveformController.waveformData == null) {
          _waveformController.setWaveformData(WaveformData(
            samples: waveform.waveformData,
            duration: player.state.duration,
          ));
        }

        // Update position liên tục
        if (player.state.position != _waveformController.position) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _waveformController.updatePosition(player.state.position);
          });
        }

        // Update loop regions
        if (player.loopStart != null && player.loopEnd != null) {
          if (_waveformController.loopRegions.isEmpty) {
            _waveformController.addLoopRegion(
              LoopRegion(
                start: player.loopStart!,
                end: player.loopEnd!,
              ),
            );
          }
        } else {
          _waveformController.clearLoopRegions();
        }

        if (player.currentSongPath == null) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            const SizedBox(height: 16),

            // Song info
            _buildSongInfo(player),

            const SizedBox(height: 24),

            // Rolling Waveform (60% height)
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RollingWaveformView(
                  controller: _waveformController,
                  onSeek: (position) => player.seek(position),
                  onTap: () => player.togglePlayPause(),
                  showControls: true,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Progress bar
            _buildProgressBar(player),

            const SizedBox(height: 16),

            // Player controls (40% height)
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const PlayerControls(),
                    const SizedBox(height: 16),
                    const ABLoopControls(),
                    const SizedBox(height: 16),
                    const SpeedControlWidget(),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, player),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headphones,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có audio',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.add),
            label: const Text('Chọn file Audio'),
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF),
                  const Color(0xFF5B52CC),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              player.isPlaying ? Icons.equalizer : Icons.music_note,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.currentSongTitle ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  player.currentSongArtist ?? 'Unknown Artist',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(PlayerProvider player) {
    final position = player.state.position;
    final duration = player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            _formatDuration(position),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Expanded(
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) => player.seekToPercent(value),
              activeColor: const Color(0xFF6C63FF),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, PlayerProvider player) {
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
              // TODO: Add marker
            },
          ),
          _QuickAction(
            icon: Icons.bedtime,
            label: 'Hẹn giờ',
            color: const Color(0xFF9C27B0),
            isActive: player.hasSleepTimer,
            onTap: () {
              // TODO: Sleep timer
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && context.mounted) {
          await context.read<PlayerProvider>().loadSong(
                path: file.path!,
                title: file.name,
                autoPlay: true,
              );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
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
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.15),
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
            ),
          ),
        ],
      ),
    );
  }
}
