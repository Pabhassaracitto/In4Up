import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';

class MiniPlayerTheme {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final IconData modeIcon;
  final String modeName;
  final String modeSubtitle;
  final List<Color> gradientColors;

  const MiniPlayerTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.modeIcon,
    required this.modeName,
    required this.modeSubtitle,
    required this.gradientColors,
  });

  static const buddhism = MiniPlayerTheme(
    primaryColor: Color(0xFFFFB300),
    secondaryColor: Color(0xFFFF8F00),
    accentColor: Color(0xFFFFE082),
    modeIcon: Icons.self_improvement,
    modeName: 'Phat Phap',
    modeSubtitle: 'Lang nghe - Suy ngam',
    gradientColors: [Color(0xFFFFB300), Color(0xFFFF8F00), Color(0xFFE65100)],
  );

  static const english = MiniPlayerTheme(
    primaryColor: Color(0xFF2196F3),
    secondaryColor: Color(0xFF1976D2),
    accentColor: Color(0xFF90CAF9),
    modeIcon: Icons.school,
    modeName: 'Tieng Anh',
    modeSubtitle: 'Nghe - Noi - Ghi nho',
    gradientColors: [Color(0xFF2196F3), Color(0xFF1976D2), Color(0xFF0D47A1)],
  );

  static const music = MiniPlayerTheme(
    primaryColor: Color(0xFF6C63FF),
    secondaryColor: Color(0xFF5B52CC),
    accentColor: Color(0xFFB39DDB),
    modeIcon: Icons.music_note,
    modeName: 'Am Nhac',
    modeSubtitle: 'Thuong thuc am thanh',
    gradientColors: [Color(0xFF6C63FF), Color(0xFF5B52CC), Color(0xFF311B92)],
  );

  static MiniPlayerTheme forMode(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return buddhism;
      case VipMode.english:
        return english;
      case VipMode.music:
        return music;
    }
  }
}

class MiniPlayer extends StatefulWidget {
  final VoidCallback? onTap;
  final ValueChanged<bool>? onExpandChanged;
  final bool initiallyExpanded;
  final bool showShadow;
  final EdgeInsets margin;

  const MiniPlayer({
    super.key,
    this.onTap,
    this.onExpandChanged,
    this.initiallyExpanded = false,
    this.showShadow = true,
    this.margin = const EdgeInsets.all(12),
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late final AnimationController _expandController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isExpanded = false;
  Timer? _sleepDisplayTimer;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    if (_isExpanded) {
      _expandController.value = 1.0;
    }

    _sleepDisplayTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _updateSleepDisplay(),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _sleepDisplayTimer?.cancel();
    super.dispose();
  }

  void _updateSleepDisplay() {
    if (!mounted) return;
    setState(() {});
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
    widget.onExpandChanged?.call(_isExpanded);
  }

  void _handlePlayStateChange(bool isPlaying) {
    if (isPlaying) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
      _rotateController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        if (player.currentSongPath == null) {
          return const SizedBox.shrink();
        }

        final theme = MiniPlayerTheme.forMode(player.currentMode);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePlayStateChange(player.isPlaying);
        });

        return AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            final height = lerpDouble(72.0, 320.0, _expandAnimation.value)!;
            return Container(
              height: height,
              margin: widget.margin,
              child: _buildPlayerContainer(player, theme),
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerContainer(PlayerProvider player, MiniPlayerTheme theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
        boxShadow: widget.showShadow
            ? [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                _buildHeader(player, theme),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _isExpanded || _expandAnimation.value > 0
                        ? _MiniPlayerExpandedContent(player: player, theme: theme)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(PlayerProvider player, MiniPlayerTheme theme) {
    return SizedBox(
      height: 72,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _AlbumArtWidget(
                mode: player.currentMode,
                isPlaying: player.isPlaying,
                theme: theme,
                rotateController: _rotateController,
                pulseController: _pulseController,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SongInfoWidget(
                  title: player.currentSongTitle ?? 'Unknown',
                  position: player.state.position,
                  duration: player.state.duration,
                  isLooping: player.isLooping,
                  loopCount: player.loopCount,
                  maxLoopCount: player.maxLoopCount,
                  speed: player.state.speed,
                  isWaitingGap: player.isWaitingGap,
                ),
              ),
              const SizedBox(width: 8),
              _PlayControlsWidget(
                isPlaying: player.isPlaying,
                theme: theme,
                onPlayPause: () => player.togglePlayPause(),
                onPrevious: () => player.replay10(),
                onNext: () => player.forward10(),
              ),
              IconButton(
                icon: RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
                  child: const Icon(Icons.keyboard_arrow_down),
                ),
                color: Colors.white,
                onPressed: _toggleExpand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumArtWidget extends StatelessWidget {
  final VipMode mode;
  final bool isPlaying;
  final MiniPlayerTheme theme;
  final AnimationController rotateController;
  final AnimationController pulseController;

  const _AlbumArtWidget({
    required this.mode,
    required this.isPlaying,
    required this.theme,
    required this.rotateController,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulseValue = isPlaying ? 1.0 + (pulseController.value * 0.05) : 1.0;
        return Transform.scale(
          scale: pulseValue,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RotationTransition(
                turns: isPlaying
                    ? Tween(begin: 0.0, end: 1.0).animate(rotateController)
                    : const AlwaysStoppedAnimation(0),
                child: Icon(theme.modeIcon, color: Colors.white, size: 26),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SongInfoWidget extends StatelessWidget {
  final String title;
  final Duration position;
  final Duration duration;
  final bool isLooping;
  final int loopCount;
  final int maxLoopCount;
  final double speed;
  final bool isWaitingGap;

  const _SongInfoWidget({
    required this.title,
    required this.position,
    required this.duration,
    required this.isLooping,
    required this.loopCount,
    required this.maxLoopCount,
    required this.speed,
    required this.isWaitingGap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
            ),
            const SizedBox(width: 8),
            if (isLooping) _buildLoopBadge(),
            if (speed != 1.0) ...[
              const SizedBox(width: 4),
              _buildSpeedBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLoopBadge() {
    final Color badgeColor = isWaitingGap ? const Color(0xFFFF9800) : const Color(0xFF4CAF50);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.loop, size: 10, color: badgeColor),
          const SizedBox(width: 3),
          Text(
            maxLoopCount > 0 ? '$loopCount/$maxLoopCount' : '${loopCount}x',
            style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 2)}x',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _PlayControlsWidget extends StatelessWidget {
  final bool isPlaying;
  final MiniPlayerTheme theme;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PlayControlsWidget({
    required this.isPlaying,
    required this.theme,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.replay_10),
          color: Colors.white.withOpacity(0.85),
          iconSize: 20,
          onPressed: () {
            HapticFeedback.lightImpact();
            onPrevious();
          },
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPlayPause();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: theme.primaryColor,
              size: 28,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.forward_10),
          color: Colors.white.withOpacity(0.85),
          iconSize: 20,
          onPressed: () {
            HapticFeedback.lightImpact();
            onNext();
          },
        ),
      ],
    );
  }
}

class _MiniPlayerExpandedContent extends StatelessWidget {
  final PlayerProvider player;
  final MiniPlayerTheme theme;

  const _MiniPlayerExpandedContent({
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _ProgressBarWidget(
            position: player.state.position,
            duration: player.state.duration,
            loopStart: player.loopStart,
            loopEnd: player.loopEnd,
            onSeek: (position) => player.seek(position),
          ),
          const SizedBox(height: 16),
          _SpeedControlWidget(
            speed: player.state.speed,
            onSpeedChanged: (speed) => player.setSpeed(speed),
          ),
          const SizedBox(height: 16),
          if (player.isLooping || player.loopStart != null)
            _GapControlWidget(
              gapDuration: player.gapDuration,
              onGapChanged: (gap) => player.setGapDuration(gap),
            ),
          if (player.isLooping || player.loopStart != null) const SizedBox(height: 16),
          _QuickActionsWidget(player: player, theme: theme),
        ],
      ),
    );
  }
}

class _ProgressBarWidget extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration? loopStart;
  final Duration? loopEnd;
  final ValueChanged<Duration> onSeek;

  const _ProgressBarWidget({
    required this.position,
    required this.duration,
    this.loopStart,
    this.loopEnd,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: progress,
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              onSeek(newPosition);
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
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
              if (loopStart != null && loopEnd != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Loop: ${_formatDuration(loopEnd! - loopStart!)}',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                _formatDuration(duration),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _SpeedControlWidget extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  const _SpeedControlWidget({
    required this.speed,
    required this.onSpeedChanged,
  });

  static const List<double> presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed, size: 16, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 8),
            Text('Speed', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${speed.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: presets.map((preset) {
            final isActive = (speed - preset).abs() < 0.01;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSpeedChanged(preset);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.25) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '${preset}x',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _GapControlWidget extends StatelessWidget {
  final double gapDuration;
  final ValueChanged<double> onGapChanged;

  const _GapControlWidget({
    required this.gapDuration,
    required this.onGapChanged,
  });

  static const List<double> presets = [0, 1, 2, 3, 5];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 16,
              color: gapDuration > 0 ? const Color(0xFFFF9800) : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text('Gap', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gapDuration > 0
                    ? const Color(0xFFFF9800).withOpacity(0.2)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                gapDuration > 0 ? '${gapDuration.toStringAsFixed(1)}s' : 'Off',
                style: TextStyle(
                  color: gapDuration > 0 ? const Color(0xFFFF9800) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: presets.map((preset) {
            final isActive = (gapDuration - preset).abs() < 0.01;
            final color = preset > 0 ? const Color(0xFFFF9800) : Colors.white;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onGapChanged(preset);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.25) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? color.withOpacity(0.5) : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  preset == 0 ? 'Off' : '${preset.toInt()}s',
                  style: TextStyle(
                    color: isActive ? color : Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QuickActionsWidget extends StatelessWidget {
  final PlayerProvider player;
  final MiniPlayerTheme theme;

  const _QuickActionsWidget({
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionButton(
          icon: Icons.loop,
          label: player.isLooping ? 'Stop' : 'Loop',
          isActive: player.isLooping,
          activeColor: const Color(0xFF4CAF50),
          onTap: () {
            if (player.isLooping) {
              player.clearLoop();
            } else if (player.loopStart != null) {
              player.setLoopEnd();
            } else {
              player.setLoopStart();
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.bedtime_outlined,
          label: player.hasSleepTimer ? _formatRemaining(player.sleepRemaining) : 'Sleep',
          isActive: player.hasSleepTimer,
          activeColor: const Color(0xFF9C27B0),
          onTap: () => _showSleepTimerSheet(context, player),
        ),
        _QuickActionButton(
          icon: theme.modeIcon,
          label: theme.modeName,
          isActive: true,
          activeColor: theme.primaryColor,
          onTap: () => _showModeSheet(context, player),
        ),
      ],
    );
  }

  String _formatRemaining(Duration? d) {
    if (d == null) return 'Sleep';
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  void _showSleepTimerSheet(BuildContext context, PlayerProvider player) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SleepTimerSheet(player: player),
    );
  }

  void _showModeSheet(BuildContext context, PlayerProvider player) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModeSelectionSheet(player: player),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.5) : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? activeColor : Colors.white.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTimerSheet extends StatelessWidget {
  final PlayerProvider player;

  const _SleepTimerSheet({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sleep Timer',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (player.hasSleepTimer)
                    _TimerOption(
                      label: 'Cancel',
                      onTap: () {
                        player.cancelSleepTimer();
                        Navigator.pop(context);
                      },
                    ),
                  ...PlayerProvider.sleepTimerPresets.map(
                        (minutes) => _TimerOption(
                      label: '$minutes min',
                      onTap: () {
                        player.setSleepTimerMinutes(minutes);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TimerOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimerOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}

class _ModeSelectionSheet extends StatelessWidget {
  final PlayerProvider player;

  const _ModeSelectionSheet({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Mode',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ...VipMode.values.map((mode) {
              final theme = MiniPlayerTheme.forMode(mode);
              final isSelected = player.currentMode == mode;
              return _ModeOption(
                theme: theme,
                isSelected: isSelected,
                onTap: () {
                  player.setMode(mode);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final MiniPlayerTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
            theme.primaryColor.withOpacity(0.3),
            theme.secondaryColor.withOpacity(0.2),
          ])
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primaryColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                theme.modeIcon,
                color: isSelected ? theme.primaryColor : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.modeName,
                    style: TextStyle(
                      color: isSelected ? theme.primaryColor : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    theme.modeSubtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}