import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/player_provider.dart';
import '../providers/waveform_provider.dart';
import '../widgets/waveform_editor.dart';
import '../widgets/mini_player_controls.dart';

class WaveformScreen extends StatelessWidget {
  const WaveformScreen({super.key});

  // Get theme colors based on current mode
  _ModeTheme _getThemeForMode(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return _ModeTheme(
          primary: const Color(0xFFFFB300),
          secondary: const Color(0xFFFF8F00),
          icon: Icons.self_improvement,
          name: 'Phat Phap',
        );
      case VipMode.english:
        return _ModeTheme(
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF1976D2),
          icon: Icons.school,
          name: 'Tieng Anh',
        );
      case VipMode.music:
        return _ModeTheme(
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFF5B52CC),
          icon: Icons.music_note,
          name: 'Am Nhac',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Consumer2<PlayerProvider, WaveformProvider>(
          builder: (context, player, waveform, child) {
            final theme = _getThemeForMode(player.currentMode);

            return Column(
              children: [
                _buildAppBar(context, player, waveform, theme),
                Expanded(
                  child: player.currentSongPath == null
                      ? _buildEmptyState(context, theme)
                      : _buildContent(context, player, waveform, theme),
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
      _ModeTheme theme,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.waves, color: theme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waveform Editor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  player.currentSongTitle ?? 'No audio loaded',
                  style: TextStyle(fontSize: 12, color: theme.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Mode indicator
          _buildModeIndicator(player, theme),
          const SizedBox(width: 8),
          // Markers count
          if (waveform.markers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${waveform.markers.length}',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            onPressed: () => _pickAudioFile(context),
            icon: Icon(Icons.folder_open, color: theme.primary),
            tooltip: 'Open audio file',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1A1A2E),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('Clear all markers',
                      style: TextStyle(color: Colors.white)),
                ),
                onTap: () => waveform.clearMarkers(),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.file_download, color: Colors.blue),
                  title: Text('Export markers',
                      style: TextStyle(color: Colors.white)),
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

  Widget _buildModeIndicator(PlayerProvider player, _ModeTheme theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Cycle through modes
        final modes = VipMode.values;
        final currentIndex = modes.indexOf(player.currentMode);
        final nextIndex = (currentIndex + 1) % modes.length;
        player.setMode(modes[nextIndex]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(theme.icon, size: 14, color: theme.primary),
            const SizedBox(width: 4),
            Text(
              theme.name,
              style: TextStyle(
                color: theme.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, _ModeTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.waves, size: 64, color: theme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Waveform Editor',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select audio file to view and mark waveform',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickAudioFile(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Audio File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 48),
            _buildInstructions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(_ModeTheme theme) {
    final features = [
      (Icons.zoom_in, 'Pinch or scroll to zoom waveform'),
      (Icons.touch_app, 'Tap to seek, double tap to add marker'),
      (Icons.select_all, 'Long press + drag to select region'),
      (Icons.label, 'Label words, sentences, difficult sections'),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(f.$1, color: theme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(f.$2, style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      PlayerProvider player,
      WaveformProvider waveform,
      _ModeTheme theme,
      ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Waveform Editor
          const WaveformEditor(height: 220, showControls: true),

          const SizedBox(height: 16),

          // Player info card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.1),
                  theme.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Status indicators
                if (player.isLooping || player.isWaitingGap)
                  _buildStatusRow(player, theme),
                if (player.isLooping || player.isWaitingGap)
                  const SizedBox(height: 12),

                // Current position
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(player.state.position),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.primary,
                      ),
                    ),
                    Text(
                      ' / ${_formatDuration(player.state.duration)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 18),
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

          // Loop info (if active)
          if (player.loopStart != null && player.loopEnd != null)
            _buildLoopInfo(player, theme),

          const SizedBox(height: 16),

          // Tips based on mode
          _buildModeTips(player.currentMode, theme),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusRow(PlayerProvider player, _ModeTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (player.isWaitingGap)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDot(color: Color(0xFFFF9800)),
                const SizedBox(width: 6),
                Text(
                  'Gap: ${player.gapDuration.toStringAsFixed(1)}s',
                  style: const TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        else if (player.isLooping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.loop, size: 16, color: Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Text(
                  player.maxLoopCount > 0
                      ? '${player.loopCount}/${player.maxLoopCount}'
                      : '${player.loopCount}x',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoopInfo(PlayerProvider player, _ModeTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.loop, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Loop Region',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_formatDuration(player.loopStart!)} → ${_formatDuration(player.loopEnd!)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _formatDuration(player.loopDuration!),
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => player.clearLoop(),
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTips(VipMode mode, _ModeTheme theme) {
    String title;
    List<String> tips;

    switch (mode) {
      case VipMode.buddhism:
        title = 'Tips for Dharma Learning';
        tips = [
          'Mark important teachings with "Important" type',
          'Use Gap duration for contemplation',
          'Slow speed (0.8x-0.9x) for deep listening',
        ];
        break;
      case VipMode.english:
        title = 'Tips for English Learning';
        tips = [
          'Mark difficult phrases for repeated practice',
          'Use Gap for shadowing (repeat after)',
          'Slow speed (0.5x-0.7x) for pronunciation',
        ];
        break;
      case VipMode.music:
        title = 'Tips for Music';
        tips = [
          'Mark your favorite sections',
          'Loop chorus or bridge sections',
          'Use markers for song structure',
        ];
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: theme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: theme.primary)),
                Expanded(
                  child: Text(tip, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
          )),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

// Helper classes
class _ModeTheme {
  final Color primary;
  final Color secondary;
  final IconData icon;
  final String name;

  const _ModeTheme({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.name,
  });
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.5 + _controller.value * 0.5),
          ),
        );
      },
    );
  }
}