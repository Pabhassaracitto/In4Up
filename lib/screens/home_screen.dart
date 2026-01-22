import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/speed_control.dart';
import '../widgets/waveform_view.dart';
import '../widgets/quick_replay_buttons.dart';
import '../widgets/ab_loop_controls.dart';
import '../widgets/sleep_timer_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            return Column(
              children: [
                // App Bar
                _buildAppBar(context, player),

                // Main Content
                Expanded(
                  child: player.currentSongPath == null
                      ? _buildEmptyState(context)
                      : _buildPlayerContent(context, player),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note,
              color: Color(0xFF6C63FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VipSound Player',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Pháp thoại & Học tiếng Anh',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Sleep Timer Button
          if (player.currentSongPath != null) ...[
            _buildSleepTimerButton(context, player),
            const SizedBox(width: 8),
          ],

          IconButton(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.folder_open),
            tooltip: 'Mở file audio',
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTimerButton(BuildContext context, PlayerProvider player) {
    return Stack(
      children: [
        IconButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF1A1A2E),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => const SleepTimerSheet(),
            );
          },
          icon: Icon(
            Icons.bedtime,
            color: player.hasSleepTimer ? const Color(0xFF6C63FF) : null,
          ),
          tooltip: 'Hẹn giờ tắt',
        ),
        if (player.hasSleepTimer)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.library_music,
                size: 64,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có audio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn file audio để bắt đầu',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickAudioFile(context),
              icon: const Icon(Icons.add),
              label: const Text('Chọn file audio'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 48),
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      ('🔁', 'A-B Loop: Lặp đoạn'),
      ('⏪', 'Tua nhanh: ±5s, ±10s, ±30s'),
      ('🛏️', 'Hẹn giờ tắt'),
      ('📍', 'Lưu vị trí nghe'),
      ('🎚️', 'Điều chỉnh tốc độ: 0.05x - 10x'),
    ];

    return Column(
      children: features.map((f) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.$1, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                f.$2,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerContent(BuildContext context, PlayerProvider player) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Album Art
          _buildAlbumArt(player),

          const SizedBox(height: 24),

          // Song Info
          _buildSongInfo(player),

          const SizedBox(height: 16),

          // Sleep Timer Display
          if (player.hasSleepTimer) _buildSleepTimerDisplay(player),

          const SizedBox(height: 24),

          // Waveform
          const WaveformView(),

          const SizedBox(height: 16),

          // A-B Loop Controls
          const ABLoopControls(),

          const SizedBox(height: 16),

          // Progress Bar
          _buildProgressBar(player),

          const SizedBox(height: 16),

          // Quick Replay Buttons
          const QuickReplayButtons(),

          const SizedBox(height: 16),

          // Player Controls
          const PlayerControls(),

          const SizedBox(height: 24),

          // Speed Control
          const SpeedControlWidget(),

          const SizedBox(height: 24),

          // Volume Control
          _buildVolumeControl(player),

          const SizedBox(height: 24),

          // Saved Segments
          _buildSegmentsList(player),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(PlayerProvider player) {
    final isLooping = player.isLooping;

    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLooping
              ? [
            const Color(0xFF4CAF50),
            const Color(0xFF2E7D32),
          ]
              : [
            const Color(0xFF6C63FF),
            const Color(0xFF3F3D56),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: isLooping
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLooping ? Icons.loop : Icons.music_note,
              size: 100,
              color: Colors.white,
            ),
            if (isLooping) ...[
              const SizedBox(height: 8),
              Text(
                'Loop: ${player.loopCount}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSleepTimerDisplay(PlayerProvider player) {
    final remaining = player.sleepRemaining;
    if (remaining == null) return const SizedBox.shrink();

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bedtime, size: 16, color: Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Text(
            'Tắt sau: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => player.cancelSleepTimer(),
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo(PlayerProvider player) {
    // Hiển thị vị trí đã lưu nếu có
    final savedPosition = player.getSavedPosition(player.currentSongPath ?? '');

    return Column(
      children: [
        Text(
          player.currentSongTitle ?? 'Unknown',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          player.currentSongArtist ?? 'Unknown Artist',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        if (savedPosition != null && savedPosition.inSeconds > 10) ...[
          const SizedBox(height: 4),
          Text(
            'Đã lưu: ${_formatDuration(savedPosition)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C63FF),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(PlayerProvider player) {
    final position = player.state.position;
    final duration = player.state.duration;

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              player.seekToPercent(value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.grey),
              ),
              if (player.isLooping && player.loopDuration != null)
                Text(
                  'Loop: ${_formatDuration(player.loopDuration!)}',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                  ),
                ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeControl(PlayerProvider player) {
    return Row(
      children: [
        const Icon(Icons.volume_down, color: Colors.grey),
        Expanded(
          child: Slider(
            value: player.state.volume,
            onChanged: (value) {
              player.setVolume(value);
            },
          ),
        ),
        const Icon(Icons.volume_up, color: Colors.grey),
      ],
    );
  }

  Widget _buildSegmentsList(PlayerProvider player) {
    final segments = player.getSegmentsForCurrentSong();
    if (segments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đoạn đã lưu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...segments.map((segment) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.bookmark,
              color: segment.type.name == 'dharma'
                  ? Colors.amber
                  : segment.type.name == 'english'
                  ? Colors.green
                  : Colors.blue,
            ),
            title: Text(segment.title),
            subtitle: Text(
              '${_formatDuration(segment.startTime)} - ${_formatDuration(segment.endTime)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${segment.repeatCount}x',
                  style: const TextStyle(color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => player.playSegment(segment),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          if (context.mounted) {
            final player = context.read<PlayerProvider>();
            await player.loadSong(
              path: file.path!,
              title: file.name,
              autoPlay: true,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn file: $e')),
        );
      }
    }
  }
}