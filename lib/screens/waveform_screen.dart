import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/player_provider.dart';
import '../providers/waveform_provider.dart';
import '../widgets/waveform_editor.dart';
import '../widgets/mini_player_controls.dart';

class WaveformScreen extends StatelessWidget {
  const WaveformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Consumer2<PlayerProvider, WaveformProvider>(
          builder: (context, player, waveform, child) {
            return Column(
              children: [
                // App Bar
                _buildAppBar(context, player, waveform),

                // Waveform Editor
                Expanded(
                  child: player.currentSongPath == null
                      ? _buildEmptyState(context)
                      : _buildContent(context, player, waveform),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(
      BuildContext context,
      PlayerProvider player,
      WaveformProvider waveform,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.waves,
              color: Color(0xFF6C63FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waveform Editor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  player.currentSongTitle ?? 'Chưa có audio',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Markers count
          if (waveform.markers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${waveform.markers.length} markers',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.folder_open),
            tooltip: 'Mở file audio',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1A1A2E),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('Xóa tất cả markers', style: TextStyle(color: Colors.white)),
                ),
                onTap: () => waveform.clearMarkers(),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.file_download, color: Colors.blue),
                  title: Text('Export markers', style: TextStyle(color: Colors.white)),
                ),
                onTap: () {
                  final data = waveform.exportMarkers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported ${data.length} markers')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
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
              Icons.waves,
              size: 64,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Waveform Editor',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chọn file audio để xem và đánh dấu sóng âm',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.folder_open),
            label: const Text('Mở file audio'),
          ),
          const SizedBox(height: 48),
          // Features
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                _FeatureItem(
                  icon: Icons.zoom_in,
                  text: 'Zoom sóng âm chi tiết (Pinch hoặc scroll)',
                ),
                _FeatureItem(
                  icon: Icons.touch_app,
                  text: 'Tap để seek, Double tap để thêm marker',
                ),
                _FeatureItem(
                  icon: Icons.select_all,
                  text: 'Long press và kéo để chọn đoạn',
                ),
                _FeatureItem(
                  icon: Icons.label,
                  text: 'Đánh nhãn từng từ, câu, đoạn khó',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      PlayerProvider player,
      WaveformProvider waveform,
      ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Waveform Editor
          const WaveformEditor(
            height: 200,
            showControls: true,
          ),

          const SizedBox(height: 16),

          // Player info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Current position
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(player.state.position),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    const Text(
                      ' / ',
                      style: TextStyle(color: Colors.grey, fontSize: 20),
                    ),
                    Text(
                      _formatDuration(player.state.duration),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mini controls
                const MiniPlayerControls(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Hướng dẫn',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Pinch hoặc dùng slider để zoom\n'
                      '• Kéo ngang để scroll\n'
                      '• Tap để nhảy đến vị trí\n'
                      '• Double tap để thêm điểm đánh dấu\n'
                      '• Long press + kéo để chọn đoạn',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
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
            autoPlay: false,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000 ~/ 10;
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}