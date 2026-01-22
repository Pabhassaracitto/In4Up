import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/speed_control.dart';
import '../widgets/waveform_view.dart';

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
                _buildAppBar(context),

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

  Widget _buildAppBar(BuildContext context) {
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
                'Ultra Music Player',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Speed: 0.05x - 10.0x',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Audio File',
          ),
        ],
      ),
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
              'No Music Loaded',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to select an audio file',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickAudioFile(context),
              icon: const Icon(Icons.add),
              label: const Text('Select Audio File'),
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
      ('🚀', 'Ultra Slow: 0.05x - 0.5x'),
      ('🎯', 'Normal: 0.5x - 2.0x'),
      ('⚡', 'Ultra Fast: 2.0x - 10.0x'),
      ('🎵', 'Pitch Preservation'),
      ('🔊', 'Transient Detection'),
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
          _buildAlbumArt(),

          const SizedBox(height: 24),

          // Song Info
          _buildSongInfo(player),

          const SizedBox(height: 24),

          // Waveform
          const WaveformView(),

          const SizedBox(height: 24),

          // Progress Bar
          _buildProgressBar(player),

          const SizedBox(height: 24),

          // Player Controls
          const PlayerControls(),

          const SizedBox(height: 32),

          // Speed Control
          const SpeedControlWidget(),

          const SizedBox(height: 24),

          // Volume Control
          _buildVolumeControl(player),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C63FF),
            Color(0xFF3F3D56),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.music_note,
          size: 100,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSongInfo(PlayerProvider player) {
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
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }
}