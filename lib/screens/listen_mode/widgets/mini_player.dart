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
  // ★ THÊM: 3 heights
  static const double microHeight = 52.0;
  static const double mediumHeight = 88.0;
  static const double fullHeight = 340.0;

  // Giữ lại cho backward compat
  static const double collapsedHeight = microHeight;
  static const double expandedHeight = fullHeight;

  static const double borderRadius = 20.0;
  static const double albumArtSize = 44.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double spacing = 12.0;
  static const double paddingHorizontal = 16.0;
  static const double paddingVertical = 10.0;
}

/// Standard animation durations
abstract class MiniPlayerAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 500);
  static const Curve defaultCurve = Curves.easeInOutCubic;
}

/// ★ THÊM: Enum 3 trạng thái
enum MiniPlayerState { micro, medium, full }

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

class _MiniPlayerState extends State<MiniPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ★ THAY: 1 controller cho toàn bộ animation
  late final AnimationController _animController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;

  late final Animation<double> _fadeAnimation;

  // ★ THAY: State thay vì bool
  MiniPlayerState _playerState = MiniPlayerState.micro;

  // Trạng thái hiển thị để tắt Blur khi ẩn ứng dụng (Tránh lỗi EGL Windows)
  bool _isAppVisible = true;

  Timer? _sleepDisplayTimer;
  Duration? _displayedSleepRemaining;

  // Heights tương ứng với từng state
  static const _heights = {
    MiniPlayerState.micro: MiniPlayerDimensions.microHeight,
    MiniPlayerState.medium: MiniPlayerDimensions.mediumHeight,
    MiniPlayerState.full: MiniPlayerDimensions.fullHeight,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      duration: MiniPlayerAnimations.normal,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
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

    if (widget.initiallyExpanded) {
      _playerState = MiniPlayerState.full;
      _animController.value = 1.0;
    }

    _sleepDisplayTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateSleepDisplay(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isVisible = state == AppLifecycleState.resumed;
    if (_isAppVisible != isVisible) {
      setState(() {
        _isAppVisible = isVisible;
      });
      // ★ CHIẾN LƯỢC: Dừng ngay lập tức các Ticker animation để giải phóng GPU Buffer
      final player = context.read<PlayerProvider>();
      _handlePlayStateChange(player.isPlaying);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
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

  // ★ THAY: Toggle theo vòng micro → medium → full → micro
  void _cycleState() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_playerState) {
        case MiniPlayerState.micro:
          _playerState = MiniPlayerState.medium;
          _animController.animateTo(
            0.35,
            duration: MiniPlayerAnimations.normal,
            curve: MiniPlayerAnimations.defaultCurve,
          );
          break;
        case MiniPlayerState.medium:
          _playerState = MiniPlayerState.full;
          _animController.animateTo(
            1.0,
            duration: MiniPlayerAnimations.normal,
            curve: MiniPlayerAnimations.defaultCurve,
          );
          break;
        case MiniPlayerState.full:
          _playerState = MiniPlayerState.micro;
          _animController.animateTo(
            0.0,
            duration: MiniPlayerAnimations.normal,
            curve: MiniPlayerAnimations.defaultCurve,
          );
          break;
      }
    });
    widget.onExpandChanged?.call(_playerState == MiniPlayerState.full);
  }

  void _handlePlayStateChange(bool isPlaying) {
    // Chỉ chạy animation khi đang phát nhạc VÀ ứng dụng đang hiển thị
    if (isPlaying && _isAppVisible) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
      _rotateController.stop();
    }
  }

  // ★ Target height theo state
  double get _targetHeight => _heights[_playerState]!;

  @override
  Widget build(BuildContext context) {
    // Dùng Consumer để lắng nghe mọi thay đổi (isPlaying, position, mode...)
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final currentMode = player.currentMode;
        final theme = MiniPlayerTheme.forMode(currentMode);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePlayStateChange(player.isPlaying);
        });

        return AnimatedContainer(
          duration: MiniPlayerAnimations.normal,
          curve: MiniPlayerAnimations.defaultCurve,
          height: _targetHeight,
          margin: widget.margin,
          child: _buildPlayerContainer(player, theme),
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
                  color: theme.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MiniPlayerDimensions.borderRadius),
        child: _buildBlurWrapper(
          // ★ TỐI ƯU: Nếu app ẩn, không render Material phức tạp
          child: !_isAppVisible
              ? Container(color: theme.primaryColor.withValues(alpha: 0.9))
              : Material(
                  color: Colors.transparent,
                  // ★ Dùng SingleChildScrollView để tránh hiện sọc vàng đen khi đang animate height
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // ── State 0: Micro — chỉ controls ──────────────
                        if (_playerState == MiniPlayerState.micro)
                          _MicroBar(
                            player: player,
                            theme: theme,
                            onCycle: _cycleState,
                          ),

                        // ── State 1: Medium — info + controls ──────────
                        if (_playerState == MiniPlayerState.medium ||
                            _playerState == MiniPlayerState.full)
                          _MediumBar(
                            player: player,
                            theme: theme,
                            pulseController: _pulseController,
                            rotateController: _rotateController,
                            onCycle: _cycleState,
                            isFull: _playerState == MiniPlayerState.full,
                          ),

                        // ── State 2: Full — Phần mở rộng ─────────────
                        if (_playerState == MiniPlayerState.full)
                          SizedBox(
                            // Chiều cao cố định = Full - Medium để không gây overflow lỗi
                            height: MiniPlayerDimensions.fullHeight -
                                MiniPlayerDimensions.mediumHeight,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _MiniPlayerExpandedContent(
                                player: player,
                                theme: theme,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Bọc BackdropFilter khi app đang hiển thị, tắt khi ẩn để tránh lỗi EGL/GPU context
  Widget _buildBlurWrapper({required Widget child}) {
    if (!_isAppVisible) return child;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: child,
    );
  }
}

// =============================================================================
// ★ MỚI: MICRO BAR — State 0
// =============================================================================

class _MicroBar extends StatelessWidget {
  final PlayerProvider player;
  final MiniPlayerTheme theme;
  final VoidCallback onCycle;

  const _MicroBar({
    required this.player,
    required this.theme,
    required this.onCycle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MiniPlayerDimensions.microHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MiniPlayerDimensions.paddingHorizontal,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MicroBtn(
              icon: Icons.replay_10,
              onTap: () => player.replay10(),
            ),
            _MicroPlayBtn(
              isPlaying: player.isPlaying,
              theme: theme,
              onTap: () => player.togglePlayPause(),
            ),
            _MicroBtn(
              icon: Icons.forward_10,
              onTap: () => player.forward10(),
            ),
            _CycleButton(
              state: MiniPlayerState.micro,
              onTap: onCycle,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ★ MỚI: MEDIUM BAR — State 1 + header của State 2
// =============================================================================

class _MediumBar extends StatelessWidget {
  final PlayerProvider player;
  final MiniPlayerTheme theme;
  final AnimationController pulseController;
  final AnimationController rotateController;
  final VoidCallback onCycle;
  final bool isFull;

  const _MediumBar({
    required this.player,
    required this.theme,
    required this.pulseController,
    required this.rotateController,
    required this.onCycle,
    this.isFull = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MiniPlayerDimensions.mediumHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MiniPlayerDimensions.paddingHorizontal,
          vertical: 6,
        ),
        child: Row(
          children: [
            _SmallAlbumArt(
              theme: theme,
              isPlaying: player.isPlaying,
              pulseController: pulseController,
              rotateController: rotateController,
            ),
            const SizedBox(width: 10),
            Expanded(child: _MediumInfo(player: player)),
            const SizedBox(width: 8),
            _MicroBtn(
              icon: Icons.replay_10,
              onTap: () => player.replay10(),
            ),
            _MicroPlayBtn(
              isPlaying: player.isPlaying,
              theme: theme,
              size: 36,
              onTap: () => player.togglePlayPause(),
            ),
            _MicroBtn(
              icon: Icons.forward_10,
              onTap: () => player.forward10(),
            ),
            const SizedBox(width: 4),
            _CycleButton(
              state: isFull ? MiniPlayerState.full : MiniPlayerState.medium,
              onTap: onCycle,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ★ MỚI: CYCLE BUTTON
// =============================================================================

class _CycleButton extends StatelessWidget {
  final MiniPlayerState state;
  final VoidCallback onTap;

  const _CycleButton({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: MiniPlayerAnimations.fast,
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween(begin: 0.25, end: 0.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              _icon,
              key: ValueKey(state),
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    switch (state) {
      case MiniPlayerState.micro:
        return Icons.keyboard_arrow_up_rounded;
      case MiniPlayerState.medium:
        return Icons.keyboard_double_arrow_up_rounded;
      case MiniPlayerState.full:
        return Icons.keyboard_arrow_down_rounded;
    }
  }
}

// =============================================================================
// ★ MỚI: SUB-WIDGETS
// =============================================================================

class _MicroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MicroBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 22,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _MicroPlayBtn extends StatelessWidget {
  final bool isPlaying;
  final MiniPlayerTheme theme;
  final double size;
  final VoidCallback onTap;

  const _MicroPlayBtn({
    required this.isPlaying,
    required this.theme,
    this.size = 40,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: theme.primaryColor,
          size: size * 0.55,
        ),
      ),
    );
  }
}

class _SmallAlbumArt extends StatelessWidget {
  final MiniPlayerTheme theme;
  final bool isPlaying;
  final AnimationController pulseController;
  final AnimationController rotateController;

  const _SmallAlbumArt({
    required this.theme,
    required this.isPlaying,
    required this.pulseController,
    required this.rotateController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {
        return Container(
          width: MiniPlayerDimensions.albumArtSize,
          height: MiniPlayerDimensions.albumArtSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: isPlaying
                ? [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: RotationTransition(
              turns: isPlaying
                  ? Tween(begin: 0.0, end: 1.0).animate(rotateController)
                  : const AlwaysStoppedAnimation(0),
              child: Icon(
                theme.modeIcon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediumInfo extends StatelessWidget {
  final PlayerProvider player;
  const _MediumInfo({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // ★ Căn giữa Column
      children: [
        Text(
          player.currentSongTitle ?? 'Unknown',
          textAlign: TextAlign.center, // ★ Căn giữa text khi xuống dòng
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          maxLines: 2, // Cho phép xuống dòng nếu tiêu đề quá dài
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // ★ Căn giữa các thông số
          children: [
            Text(
              _fmt(player.state.position),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
            Text(
              ' / ${_fmt(player.state.duration)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            if (player.state.speed != 1.0) ...[
              const SizedBox(width: 6),
              _Chip(
                label: '${player.state.speed.toStringAsFixed(2)}x',
                color: Colors.orange,
              ),
            ],
            if (player.isLooping) ...[
              const SizedBox(width: 4),
              _Chip(
                label: player.maxLoopCount > 0
                    ? '${player.loopCount}/${player.maxLoopCount}'
                    : '∞',
                color: const Color(0xFF4CAF50),
                icon: Icons.loop,
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
    required this.onToggleExpand,
    this.onTap,
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
                const SizedBox(width: 8),
                _ExpandButton(
                  isExpanded: isExpanded,
                  expandAnimation: expandAnimation,
                  onTap: onToggleExpand,
                ),
              ],
            ),
          ),
        ));
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
        color: Color(0xFFFF9800).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: Color(0xFFFF9800)),
          SizedBox(width: 3),
          Text(
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
            onSeek: (pos) => player.seek(pos),
            theme: theme,
          ),
          const SizedBox(height: 16),
          _SpeedControlWidget(
            speed: player.state.speed,
            onSpeedChanged: (s) => player.setSpeed(s),
            theme: theme,
          ),
          const SizedBox(height: 16),
          if (player.isLooping || player.loopStart != null) ...[
            _GapControlWidget(
              gapDuration: player.gapDuration,
              onGapChanged: (g) => player.setGapDuration(g),
              theme: theme,
            ),
            const SizedBox(height: 16),
          ],
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
                  color: Color(0xFF4CAF50).withValues(alpha: 0.2),
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
              color: Color(0xFF4CAF50).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: Color(0xFF4CAF50).withValues(alpha: 0.5),
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
                    ? Color(0xFFFF9800).withValues(alpha: 0.2)
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
                  preset == 0
                      ? 'Off'
                      : '${preset.isFinite ? preset.toInt() : 0}s',
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
          activeThumbColor: const Color(0xFF4CAF50),
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
          activeThumbColor: const Color(0xFF9C27B0),
          onTap: () => _showSleepTimerSheet(context, player),
        ),
        _QuickActionButton(
          icon: theme.modeIcon,
          label: theme.modeName,
          isActive: true,
          activeThumbColor: theme.primaryColor,
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
  final Color activeThumbColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeThumbColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? activeThumbColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeThumbColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? activeThumbColor
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? activeThumbColor
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
