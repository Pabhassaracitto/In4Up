import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/speed_control.dart';
import '../widgets/waveform_view.dart';
import '../widgets/quick_replay_buttons.dart';
import '../widgets/ab_loop_controls.dart';
import '../widgets/sleep_timer_sheet.dart';
import 'waveform_screen.dart';
import 'text_studio_screen.dart';
import 'sync_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _modeAnimationController;

  @override
  void initState() {
    super.initState();
    _modeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _modeAnimationController.dispose();
    super.dispose();
  }

  // Get theme colors based on current mode
  _ModeTheme _getThemeForMode(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return _ModeTheme(
          primary: const Color(0xFFFFB300),
          secondary: const Color(0xFFFF8F00),
          accent: const Color(0xFFFFE082),
          icon: Icons.self_improvement,
          name: 'Phat Phap',
          gradient: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
        );
      case VipMode.english:
        return _ModeTheme(
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF1976D2),
          accent: const Color(0xFF90CAF9),
          icon: Icons.school,
          name: 'Tieng Anh',
          gradient: [const Color(0xFF2196F3), const Color(0xFF1976D2)],
        );
      case VipMode.music:
        return _ModeTheme(
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFF5B52CC),
          accent: const Color(0xFFB39DDB),
          icon: Icons.music_note,
          name: 'Am Nhac',
          gradient: [const Color(0xFF6C63FF), const Color(0xFF5B52CC)],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            final theme = _getThemeForMode(player.currentMode);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primary.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildAppBar(context, player, theme),
                  Expanded(
                    child: player.currentSongPath == null
                        ? _buildEmptyState(context, theme)
                        : _buildPlayerContent(context, player, theme),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, PlayerProvider player, _ModeTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App Icon with mode color
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              theme.icon,
              color: theme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VipSound Player',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getModeSubtitle(player.currentMode),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Mode Switcher
          _buildModeSwitcher(context, player, theme),

          const SizedBox(width: 8),

          // Other buttons
          if (player.currentSongPath != null) ...[
            _buildSleepTimerButton(context, player, theme),
          ],

          IconButton(
            onPressed: () => _pickAudioFile(context),
            icon: Icon(Icons.folder_open, color: theme.primary),
            tooltip: 'Open audio file',
          ),
        ],
      ),
    );
  }

  String _getModeSubtitle(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return 'Lang nghe - Suy ngam - Tham nhuan';
      case VipMode.english:
        return 'Nghe - Noi - Doc - Viet';
      case VipMode.music:
        return 'Thuong thuc am thanh';
    }
  }

  Widget _buildModeSwitcher(BuildContext context, PlayerProvider player, _ModeTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: VipMode.values.map((mode) {
          final isSelected = player.currentMode == mode;
          final modeTheme = _getThemeForMode(mode);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              player.setMode(mode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? modeTheme.primary.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? modeTheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                modeTheme.icon,
                size: 20,
                color: isSelected ? modeTheme.primary : Colors.grey,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSleepTimerButton(BuildContext context, PlayerProvider player, _ModeTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sync Hub
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SyncHubScreen()),
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: theme.gradient),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.sync, color: Colors.white, size: 16),
          ),
          tooltip: 'Sync Hub',
        ),

        // Text Studio
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TextStudioScreen()),
            );
          },
          icon: Icon(Icons.text_fields, color: theme.primary),
          tooltip: 'Text Studio',
        ),

        // Sleep Timer
        Stack(
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
                color: player.hasSleepTimer ? theme.primary : Colors.grey,
              ),
              tooltip: 'Sleep Timer',
            ),
            if (player.hasSleepTimer)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer, size: 8, color: Colors.white),
                ),
              ),
          ],
        ),

        // Waveform Editor
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WaveformScreen()),
            );
          },
          icon: Icon(Icons.waves, color: theme.primary),
          tooltip: 'Waveform Editor',
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, _ModeTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.library_music,
                size: 64,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No audio loaded',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an audio file to start',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickAudioFile(context),
              icon: const Icon(Icons.add),
              label: const Text('Select Audio File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 48),
            _buildFeaturesList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList(_ModeTheme theme) {
    final features = [
      ('🔁', 'A-B Loop with Gap'),
      ('⏪', 'Quick seek: ±5s, ±10s, ±30s'),
      ('🛏️', 'Sleep Timer'),
      ('📍', 'Save position'),
      ('🎚️', 'Speed: 0.05x - 10x'),
      ('🙏', 'Buddhism Mode'),
      ('📚', 'English Learning Mode'),
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
              Text(f.$2, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerContent(BuildContext context, PlayerProvider player, _ModeTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Album Art with mode-aware colors
          _buildAlbumArt(player, theme),

          const SizedBox(height: 24),

          // Song Info
          _buildSongInfo(player, theme),

          const SizedBox(height: 16),

          // Mode & Status Display
          _buildStatusDisplay(player, theme),

          const SizedBox(height: 24),

          // Waveform
          const WaveformView(),

          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Gap Duration Control (NEW)
         // Loại do bị dư
          /* if (player.isLooping || player.loopStart != null)
            _buildGapControl(player, theme),

          const SizedBox(height: 16),
*/
          // Progress Bar
          _buildProgressBar(player, theme),

          const SizedBox(height: 16),

          // Quick Replay Buttons
          const QuickReplayButtons(),

          const SizedBox(height: 16),

          // Player Controls
          const PlayerControls(),

          // A-B Loop Controls (Updated with gap support)
          const ABLoopControls(),

          const SizedBox(height: 24),

          // Speed Control
          const SpeedControlWidget(),

          const SizedBox(height: 24),

          // Volume Control
          _buildVolumeControl(player, theme),

          const SizedBox(height: 24),

          // Saved Segments
          _buildSegmentsList(player, theme),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(PlayerProvider player, _ModeTheme theme) {
    final isLooping = player.isLooping;
    final isWaitingGap = player.isWaitingGap;

    Color primaryColor;
    Color secondaryColor;
    IconData icon;

    if (isWaitingGap) {
      primaryColor = const Color(0xFFFF9800);
      secondaryColor = const Color(0xFFF57C00);
      icon = Icons.hourglass_top;
    } else if (isLooping) {
      primaryColor = const Color(0xFF4CAF50);
      secondaryColor = const Color(0xFF2E7D32);
      icon = Icons.loop;
    } else {
      primaryColor = theme.primary;
      secondaryColor = theme.secondary;
      icon = theme.icon;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (isWaitingGap)
              Text(
                'Gap: ${player.gapDuration.toStringAsFixed(1)}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (isLooping)
              Text(
                player.maxLoopCount > 0
                    ? 'Loop: ${player.loopCount}/${player.maxLoopCount}'
                    : 'Loop: ${player.loopCount}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                theme.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo(PlayerProvider player, _ModeTheme theme) {
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
            'Saved: ${_formatDuration(savedPosition)}',
            style: TextStyle(
              fontSize: 12,
              color: theme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusDisplay(PlayerProvider player, _ModeTheme theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Sleep Timer Display
        if (player.hasSleepTimer)
          _buildStatusChip(
            icon: Icons.bedtime,
            label: _formatRemaining(player.sleepRemaining),
            color: const Color(0xFF9C27B0),
            onTap: () => player.cancelSleepTimer(),
          ),

        // Speed indicator
        if (player.state.speed != 1.0)
          _buildStatusChip(
            icon: Icons.speed,
            label: '${player.state.speed.toStringAsFixed(2)}x',
            color: theme.primary,
          ),

        // Loop indicator
        if (player.isLooping)
          _buildStatusChip(
            icon: Icons.loop,
            label: player.maxLoopCount > 0
                ? '${player.loopCount}/${player.maxLoopCount}'
                : '${player.loopCount}x',
            color: player.isWaitingGap
                ? const Color(0xFFFF9800)
                : const Color(0xFF4CAF50),
          ),

        // Gap indicator
        if (player.gapDuration > 0 && (player.isLooping || player.loopStart != null))
          _buildStatusChip(
            icon: Icons.hourglass_empty,
            label: '${player.gapDuration.toStringAsFixed(1)}s gap',
            color: const Color(0xFFFF9800),
          ),
      ],
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }

  //Phần Gap bị dư (english)
/*  Widget _buildGapControl(PlayerProvider player, _ModeTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 18,
                color: player.gapDuration > 0
                    ? const Color(0xFFFF9800)
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              const Text(
                'Gap Duration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: player.gapDuration > 0
                      ? const Color(0xFFFF9800).withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  player.gapDuration > 0
                      ? '${player.gapDuration.toStringAsFixed(1)}s'
                      : 'Off',
                  style: TextStyle(
                    color: player.gapDuration > 0
                        ? const Color(0xFFFF9800)
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 1.0, 2.0, 3.0, 5.0].map((gap) {
              final isActive = (player.gapDuration - gap).abs() < 0.01;
              final color = gap > 0 ? const Color(0xFFFF9800) : Colors.grey;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  player.setGapDuration(gap);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? color.withOpacity(0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? color : Colors.grey.withOpacity(0.3),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    gap == 0 ? 'Off' : '${gap.toInt()}s',
                    style: TextStyle(
                      color: isActive ? color : Colors.grey,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _getGapTip(player.currentMode),
            style: TextStyle(
              color: const Color(0xFFFF9800).withOpacity(0.8),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getGapTip(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return 'Gap helps you contemplate and absorb the teachings';
      case VipMode.english:
        return 'Gap gives you time to repeat after (Shadowing)';
      case VipMode.music:
        return 'Gap creates breathing space between loops';
    }
  }
*/
  Widget _buildProgressBar(PlayerProvider player, _ModeTheme theme) {
    final position = player.state.position;
    final duration = player.state.duration;

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        // Progress with loop region highlight
        Stack(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                activeTrackColor: theme.primary,
                inactiveTrackColor: theme.primary.withOpacity(0.2),
                thumbColor: theme.primary,
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  player.seekToPercent(value);
                },
              ),
            ),
          ],
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildVolumeControl(PlayerProvider player, _ModeTheme theme) {
    return Row(
      children: [
        Icon(Icons.volume_down, color: theme.primary.withOpacity(0.7)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.primary,
              inactiveTrackColor: theme.primary.withOpacity(0.2),
              thumbColor: theme.primary,
            ),
            child: Slider(
              value: player.state.volume,
              onChanged: (value) {
                player.setVolume(value);
              },
            ),
          ),
        ),
        Icon(Icons.volume_up, color: theme.primary.withOpacity(0.7)),
      ],
    );
  }

  Widget _buildSegmentsList(PlayerProvider player, _ModeTheme theme) {
    final segments = player.getSegmentsForCurrentSong();
    if (segments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark, color: theme.primary),
            const SizedBox(width: 8),
            Text(
              'Saved Segments (${segments.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...segments.map((segment) {
          Color segmentColor;
          switch (segment.type.name) {
            case 'dharma':
              segmentColor = const Color(0xFFFFB300);
              break;
            case 'english':
              segmentColor = const Color(0xFF2196F3);
              break;
            default:
              segmentColor = const Color(0xFF6C63FF);
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: segmentColor.withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: segmentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bookmark, color: segmentColor),
              ),
              title: Text(segment.title),
              subtitle: Text(
                '${_formatDuration(segment.startTime)} - ${_formatDuration(segment.endTime)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: segmentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${segment.repeatCount}x',
                      style: TextStyle(
                        color: segmentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: segmentColor),
                    onPressed: () => player.playSegment(segment),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7)),
                    onPressed: () => player.deleteSegment(segment.id),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatRemaining(Duration? d) {
    if (d == null) return '';
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60);
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// Helper class for mode theming
class _ModeTheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final IconData icon;
  final String name;
  final List<Color> gradient;

  const _ModeTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.icon,
    required this.name,
    required this.gradient,
  });
}