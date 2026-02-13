import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../providers/player_provider.dart';

// =============================================================================
// CONSTANTS & THEME DEFINITIONS
// =============================================================================

/// Theme colors for each mode
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
    modeSubtitle: 'Lang nghe - Suy ngam - Tham nhuan',
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

/// Standard dimensions
abstract class MiniPlayerDimensions {
  static const double collapsedHeight = 72.0;
  static const double expandedHeight = 340.0;
  static const double borderRadius = 20.0;
  static const double albumArtSize = 52.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double spacing = 12.0;
  static const double paddingHorizontal = 16.0;
  static const double paddingVertical = 12.0;
}

/// Standard animation durations
abstract class MiniPlayerAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Curve defaultCurve = Curves.easeInOutCubic;
}

// =============================================================================
// MAIN WIDGET
// =============================================================================

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
  late final Animation<double> _scaleAnimation;

  bool _isExpanded = false;
  Timer? _sleepDisplayTimer;
  Duration? _displayedSleepRemaining;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    _expandController = AnimationController(
      duration: MiniPlayerAnimations.normal,
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: MiniPlayerAnimations.defaultCurve,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: MiniPlayerAnimations.defaultCurve,
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
  void didUpdateWidget(MiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      setState(() {
        _isExpanded = widget.initiallyExpanded;
      });
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
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

    final player = context.read<PlayerProvider>();
    if (player.sleepRemaining != _displayedSleepRemaining) {
      setState(() {
        _displayedSleepRemaining = player.sleepRemaining;
      });
    }
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
    return Selector<PlayerProvider, VipMode>(
      selector: (_, player) => player.currentMode,
      builder: (context, currentMode, child) {
        final theme = MiniPlayerTheme.forMode(currentMode);
        final player = context.read<PlayerProvider>();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePlayStateChange(player.isPlaying);
        });

        return AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            final height = lerpDouble(
              MiniPlayerDimensions.collapsedHeight,
              MiniPlayerDimensions.expandedHeight,
              _expandAnimation.value,
            )!;

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
        borderRadius: BorderRadius.circular(MiniPlayerDimensions.borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
        boxShadow: widget.showShadow
            ? [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MiniPlayerDimensions.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                _MiniPlayerHeader(
                  player: player,
                  theme: theme,
                  isExpanded: _isExpanded,
                  expandAnimation: _expandAnimation,
                  rotateController: _rotateController,
                  pulseController: _pulseController,
                  onTap: widget.onTap,
                  onToggleExpand: _toggleExpand,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _isExpanded || _expandAnimation.value > 0
                          ? _MiniPlayerExpandedContent(
                              player: player,
                              theme: theme,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER SECTION
// =============================================================================

class _MiniPlayerHeader extends StatelessWidget {
  final PlayerProvider player;
  final MiniPlayerTheme theme;
  final bool isExpanded;
  final Animation<double> expandAnimation;
  final AnimationController rotateController;
  final AnimationController pulseController;
  final VoidCallback? onTap;
  final VoidCallback onToggleExpand;

  const _MiniPlayerHeader({
    required this.player,
    required this.theme,
    required this.isExpanded,
    required this.expandAnimation,
    required this.rotateController,
    required this.pulseController,
    this.onTap,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MiniPlayerDimensions.collapsedHeight,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MiniPlayerDimensions.paddingHorizontal,
          ),
          child: Row(
            children: [
              _AlbumArtWidget(
                mode: player.currentMode,
                isPlaying: player.isPlaying,
                theme: theme,
                rotateController: rotateController,
                pulseController: pulseController,
              ),
              const SizedBox(width: MiniPlayerDimensions.spacing),
              Expanded(
                child: _SongInfoWidget(
                  title: player.currentSongTitle ?? 'Unknown',
                  artist: player.currentSongArtist,
                  position: player.state.position,
                  duration: player.state.duration,
                  isLooping: player.isLooping,
                  loopCount: player.loopCount,
                  maxLoopCount: player.maxLoopCount,
                  speed: player.state.speed,
                  isWaitingGap: player.isWaitingGap,
                  theme: theme,
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
              _ExpandButton(
                isExpanded: isExpanded,
                expandAnimation: expandAnimation,
                onTap: onToggleExpand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ALBUM ART WIDGET
// =============================================================================

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
    return RepaintBoundary(
        child: AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulseValue =
            isPlaying ? 1.0 + (pulseController.value * 0.05) : 1.0;

        return Transform.scale(
          scale: pulseValue,
          child: Container(
            width: MiniPlayerDimensions.albumArtSize,
            height: MiniPlayerDimensions.albumArtSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          theme.accentColor.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: isPlaying
                        ? Tween(begin: 0.0, end: 1.0).animate(rotateController)
                        : const AlwaysStoppedAnimation(0),
                    child: Icon(
                      theme.modeIcon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  if (isPlaying)
                    ...List.generate(2, (index) {
                      return AnimatedBuilder(
                        animation: pulseController,
                        builder: (context, child) {
                          final delay = index * 0.3;
                          final progress =
                              (pulseController.value + delay) % 1.0;

                          return Opacity(
                            opacity: (1.0 - progress) * 0.5,
                            child: Container(
                              width: MiniPlayerDimensions.albumArtSize *
                                  (0.8 + progress * 0.4),
                              height: MiniPlayerDimensions.albumArtSize *
                                  (0.8 + progress * 0.4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    ));
  }
}

// =============================================================================
// SONG INFO WIDGET
// =============================================================================

class _SongInfoWidget extends StatelessWidget {
  final String title;
  final String? artist;
  final Duration position;
  final Duration duration;
  final bool isLooping;
  final int loopCount;
  final int maxLoopCount;
  final double speed;
  final bool isWaitingGap;
  final MiniPlayerTheme theme;

  const _SongInfoWidget({
    required this.title,
    this.artist,
    required this.position,
    required this.duration,
    required this.isLooping,
    required this.loopCount,
    required this.maxLoopCount,
    required this.speed,
    required this.isWaitingGap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Use Selector to update only when position/duration changes
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              player.currentSongTitle ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${_formatDuration(player.state.position)} / ${_formatDuration(player.state.duration)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                if (player.isLooping) _buildLoopBadge(player),
                if (player.state.speed != 1.0) ...[
                  const SizedBox(width: 4),
                  _buildSpeedBadge(player.state.speed),
                ],
                if (player.isWaitingGap) ...[
                  const SizedBox(width: 4),
                  _buildWaitingBadge(),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoopBadge(PlayerProvider player) {
    final Color badgeColor =
        player.isWaitingGap ? const Color(0xFFFF9800) : const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.loop, size: 10, color: badgeColor),
          const SizedBox(width: 3),
          Text(
            player.maxLoopCount > 0
                ? '${player.loopCount}/${player.maxLoopCount}'
                : '${player.loopCount}x',
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedBadge(double speed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 2)}x',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWaitingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: const Color(0xFFFF9800)),
          const SizedBox(width: 3),
          const Text(
            'Gap',
            style: TextStyle(
              color: Color(0xFFFF9800),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// =============================================================================
// EXPAND BUTTON
// =============================================================================

class _ExpandButton extends StatelessWidget {
  final bool isExpanded;
  final Animation<double> expandAnimation;
  final VoidCallback onTap;

  const _ExpandButton({
    required this.isExpanded,
    required this.expandAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: RotationTransition(
            turns: Tween(begin: 0.0, end: 0.5).animate(expandAnimation),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withValues(alpha: 0.85),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PULSING DOT WIDGET
// =============================================================================

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({
    required this.color,
  });

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
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
          ),
        );
      },
    );
  }
}

// =============================================================================
// PLAY CONTROLS WIDGET
// =============================================================================

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
        _ControlButton(
          icon: Icons.replay_10,
          size: 20,
          onTap: onPrevious,
        ),
        const SizedBox(width: 4),
        _PlayPauseButton(
          isPlaying: isPlaying,
          theme: theme,
          onTap: onPlayPause,
        ),
        const SizedBox(width: 4),
        _ControlButton(
          icon: Icons.forward_10,
          size: 20,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: size,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final MiniPlayerTheme theme;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MiniPlayerAnimations.fast,
      vsync: this,
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_PlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _controller,
            color: widget.theme.primaryColor,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EXPANDED CONTENT
// =============================================================================

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
            isLooping: player.isLooping,
            onSeek: (position) => player.seek(position),
            theme: theme,
          ),
          const SizedBox(height: 16),
          _SpeedControlWidget(
            speed: player.state.speed,
            onSpeedChanged: (speed) => player.setSpeed(speed),
            theme: theme,
          ),
          const SizedBox(height: 16),
          if (player.isLooping || player.loopStart != null)
            _GapControlWidget(
              gapDuration: player.gapDuration,
              onGapChanged: (gap) => player.setGapDuration(gap),
              theme: theme,
            ),
          if (player.isLooping || player.loopStart != null)
            const SizedBox(height: 16),
          _QuickActionsWidget(
            player: player,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROGRESS BAR WIDGET
// =============================================================================

class _ProgressBarWidget extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool isLooping;
  final ValueChanged<Duration> onSeek;
  final MiniPlayerTheme theme;

  const _ProgressBarWidget({
    required this.position,
    required this.duration,
    this.loopStart,
    this.loopEnd,
    required this.isLooping,
    required this.onSeek,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final percent =
                      (details.localPosition.dx / constraints.maxWidth)
                          .clamp(0.0, 1.0);
                  final newPosition = Duration(
                    milliseconds: (percent * duration.inMilliseconds).round(),
                  );
                  onSeek(newPosition);
                },
                onTapDown: (details) {
                  final percent =
                      (details.localPosition.dx / constraints.maxWidth)
                          .clamp(0.0, 1.0);
                  final newPosition = Duration(
                    milliseconds: (percent * duration.inMilliseconds).round(),
                  );
                  onSeek(newPosition);
                  HapticFeedback.selectionClick();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (loopStart != null &&
                        loopEnd != null &&
                        duration.inMilliseconds > 0)
                      Positioned.fill(
                        child: _buildLoopRegion(constraints.maxWidth),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth * progress) - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            if (loopStart != null && loopEnd != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
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
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoopRegion(double trackWidth) {
    if (duration.inMilliseconds == 0) return const SizedBox.shrink();

    final startPercent = loopStart!.inMilliseconds / duration.inMilliseconds;
    final endPercent = loopEnd!.inMilliseconds / duration.inMilliseconds;

    return Stack(
      children: [
        Positioned(
          left: trackWidth * startPercent,
          width: trackWidth * (endPercent - startPercent),
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
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

// =============================================================================
// SPEED CONTROL WIDGET
// =============================================================================

class _SpeedControlWidget extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSpeedChanged;
  final MiniPlayerTheme theme;

  const _SpeedControlWidget({
    required this.speed,
    required this.onSpeedChanged,
    required this.theme,
  });

  static const List<double> presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.speed,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'Speed',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${speed.toStringAsFixed(2)}x',
                style: const TextStyle(
                  color: Colors.white,
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
            final isActive = (speed - preset).abs() < 0.01;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSpeedChanged(preset);
              },
              child: AnimatedContainer(
                duration: MiniPlayerAnimations.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${preset}x',
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
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

// =============================================================================
// GAP CONTROL WIDGET
// =============================================================================

class _GapControlWidget extends StatelessWidget {
  final double gapDuration;
  final ValueChanged<double> onGapChanged;
  final MiniPlayerTheme theme;

  const _GapControlWidget({
    required this.gapDuration,
    required this.onGapChanged,
    required this.theme,
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
              color: gapDuration > 0
                  ? const Color(0xFFFF9800)
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'Gap Duration',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gapDuration > 0
                    ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                gapDuration > 0 ? '${gapDuration.toStringAsFixed(1)}s' : 'Off',
                style: TextStyle(
                  color:
                      gapDuration > 0 ? const Color(0xFFFF9800) : Colors.white,
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
              child: AnimatedContainer(
                duration: MiniPlayerAnimations.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  preset == 0 ? 'Off' : '${preset.toInt()}s',
                  style: TextStyle(
                    color:
                        isActive ? color : Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        _buildModeTip(),
      ],
    );
  }

  Widget _buildModeTip() {
    String tip;
    IconData icon;
    Color color;

    switch (theme.modeIcon) {
      case Icons.self_improvement:
        tip = 'Gap helps you contemplate the teachings';
        icon = Icons.self_improvement;
        color = const Color(0xFFFFB300);
        break;
      case Icons.school:
        tip = 'Gap gives you time to repeat (Shadowing)';
        icon = Icons.record_voice_over;
        color = const Color(0xFF2196F3);
        break;
      default:
        tip = 'Gap creates rhythm between sections';
        icon = Icons.music_note;
        color = const Color(0xFF9C27B0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// QUICK ACTIONS WIDGET
// =============================================================================

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
          label: player.isLooping ? 'Stop Loop' : 'Loop',
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
          label: player.hasSleepTimer
              ? _formatRemaining(player.sleepRemaining)
              : 'Sleep',
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
    if (d.inHours > 0) {
      return '${d.inHours}h${d.inMinutes.remainder(60)}m';
    }
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
          color: isActive
              ? activeColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isActive ? activeColor : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.7),
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

// =============================================================================
// BOTTOM SHEETS
// =============================================================================

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
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sleep Timer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Auto pause after selected time',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
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
                      icon: Icons.close,
                      isSelected: false,
                      color: Colors.red,
                      onTap: () {
                        player.cancelSleepTimer();
                        Navigator.pop(context);
                      },
                    ),
                  ...PlayerProvider.sleepTimerPresets.map((minutes) {
                    return _TimerOption(
                      label: '$minutes min',
                      icon: Icons.bedtime,
                      isSelected: false,
                      onTap: () {
                        player.setSleepTimerMinutes(minutes);
                        Navigator.pop(context);
                      },
                    );
                  }),
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
  final IconData icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _TimerOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? const Color(0xFF6C63FF);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? buttonColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? buttonColor : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? buttonColor
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? buttonColor : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
      child: AnimatedContainer(
        duration: MiniPlayerAnimations.fast,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.3),
                    theme.secondaryColor.withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : Colors.white.withValues(alpha: 0.1),
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
                    ? theme.primaryColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
