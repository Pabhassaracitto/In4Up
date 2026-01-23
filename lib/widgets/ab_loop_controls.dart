// lib/widgets/ab_loop_controls.dart
// VipSound - Enhanced A-B Loop Controls
// Version 2.0 - Optimized for Buddhism & English Learning

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'save_segment_dialog.dart';

class ABLoopControls extends StatelessWidget {
  final bool showModeIndicator;
  final bool compact;

  const ABLoopControls({
    super.key,
    this.showModeIndicator = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: _getBackgroundColor(player),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(player),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode Indicator (nếu bật)
              if (showModeIndicator && !compact) ...[
                _ModeIndicator(player: player),
                const SizedBox(height: 12),
              ],

              // Header
              _LoopHeader(player: player),
              const SizedBox(height: 12),

              // Main Controls
              _MainControls(player: player),

              // Extended Controls (khi đang loop)
              if (player.isLooping) ...[
                const SizedBox(height: 16),
                _ExtendedControls(player: player, compact: compact),
              ],

              // Gap Duration Slider (khi đang loop hoặc có A point)
              if ((player.isLooping || player.loopStart != null) && !compact) ...[
                const SizedBox(height: 16),
                _GapDurationSlider(player: player),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(PlayerProvider player) {
    if (player.isWaitingGap) {
      return const Color(0xFFFF9800).withOpacity(0.15); // Đang chờ gap
    }
    if (player.isLooping) {
      return const Color(0xFF4CAF50).withOpacity(0.15); // Đang loop
    }
    return Colors.white.withOpacity(0.05); // Mặc định
  }

  Color _getBorderColor(PlayerProvider player) {
    if (player.isWaitingGap) {
      return const Color(0xFFFF9800).withOpacity(0.5);
    }
    if (player.isLooping) {
      return const Color(0xFF4CAF50).withOpacity(0.5);
    }
    return Colors.transparent;
  }
}

// ==================== MODE INDICATOR ====================

class _ModeIndicator extends StatelessWidget {
  final PlayerProvider player;

  const _ModeIndicator({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getModeColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getModeColor().withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getModeIcon(), size: 16, color: _getModeColor()),
          const SizedBox(width: 6),
          Text(
            _getModeName(),
            style: TextStyle(
              color: _getModeColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          // Quick mode switch buttons
          ...VipMode.values.map((mode) => _ModeButton(
            mode: mode,
            isActive: player.currentMode == mode,
            onTap: () => player.setMode(mode),
          )),
        ],
      ),
    );
  }

  Color _getModeColor() {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return const Color(0xFFFFB300); // Amber
      case VipMode.english:
        return const Color(0xFF2196F3); // Blue
      case VipMode.music:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  IconData _getModeIcon() {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return Icons.self_improvement;
      case VipMode.english:
        return Icons.school;
      case VipMode.music:
        return Icons.music_note;
    }
  }

  String _getModeName() {
    switch (player.currentMode) {
      case VipMode.buddhism:
        return 'Phật Pháp';
      case VipMode.english:
        return 'Tiếng Anh';
      case VipMode.music:
        return 'Âm Nhạc';
    }
  }
}

class _ModeButton extends StatelessWidget {
  final VipMode mode;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? _getModeColor().withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isActive ? _getModeColor() : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          _getModeIcon(),
          size: 14,
          color: isActive ? _getModeColor() : Colors.grey,
        ),
      ),
    );
  }

  Color _getModeColor() {
    switch (mode) {
      case VipMode.buddhism:
        return const Color(0xFFFFB300);
      case VipMode.english:
        return const Color(0xFF2196F3);
      case VipMode.music:
        return const Color(0xFF9C27B0);
    }
  }

  IconData _getModeIcon() {
    switch (mode) {
      case VipMode.buddhism:
        return Icons.self_improvement;
      case VipMode.english:
        return Icons.school;
      case VipMode.music:
        return Icons.music_note;
    }
  }
}

// ==================== LOOP HEADER ====================

class _LoopHeader extends StatelessWidget {
  final PlayerProvider player;

  const _LoopHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status Icon
        _StatusIcon(player: player),
        const SizedBox(width: 8),

        // Status Text
        Text(
          _getStatusText(),
          style: TextStyle(
            color: _getStatusColor(),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Loop Duration (nếu có)
        if (player.loopDuration != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _formatDuration(player.loopDuration!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusText() {
    if (player.isWaitingGap) {
      return 'Đang chờ... ${player.gapDuration.toStringAsFixed(1)}s';
    }
    if (player.isLooping) {
      return 'Đang lặp đoạn';
    }
    return 'Lặp A-B';
  }

  Color _getStatusColor() {
    if (player.isWaitingGap) {
      return const Color(0xFFFF9800);
    }
    if (player.isLooping) {
      return const Color(0xFF4CAF50);
    }
    return Colors.grey;
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }
}

class _StatusIcon extends StatelessWidget {
  final PlayerProvider player;

  const _StatusIcon({required this.player});

  @override
  Widget build(BuildContext context) {
    if (player.isWaitingGap) {
      return _AnimatedPauseIcon();
    }
    if (player.isLooping) {
      return _AnimatedLoopIcon();
    }
    return Icon(
      Icons.loop,
      size: 18,
      color: Colors.grey,
    );
  }
}

class _AnimatedLoopIcon extends StatefulWidget {
  @override
  State<_AnimatedLoopIcon> createState() => _AnimatedLoopIconState();
}

class _AnimatedLoopIconState extends State<_AnimatedLoopIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(
        Icons.loop,
        size: 18,
        color: Color(0xFF4CAF50),
      ),
    );
  }
}

class _AnimatedPauseIcon extends StatefulWidget {
  @override
  State<_AnimatedPauseIcon> createState() => _AnimatedPauseIconState();
}

class _AnimatedPauseIconState extends State<_AnimatedPauseIcon>
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
    return FadeTransition(
      opacity: _controller,
      child: const Icon(
        Icons.pause_circle,
        size: 18,
        color: Color(0xFFFF9800),
      ),
    );
  }
}

// ==================== MAIN CONTROLS ====================

class _MainControls extends StatelessWidget {
  final PlayerProvider player;

  const _MainControls({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Nút A
        _LoopButton(
          label: 'A',
          isActive: player.loopStart != null,
          time: player.loopStart,
          onTap: () => player.setLoopStart(),
          onLongPress: () {
            // Long press để xóa điểm A
            if (player.loopStart != null && !player.isLooping) {
              player.clearLoop();
            }
          },
          color: const Color(0xFF4CAF50),
        ),

        // Center content
        _CenterContent(player: player),

        // Nút B
        _LoopButton(
          label: 'B',
          isActive: player.loopEnd != null,
          time: player.loopEnd,
          onTap: () => player.setLoopEnd(),
          onLongPress: () {
            // Long press để seek đến điểm B
            if (player.loopEnd != null) {
              player.seek(player.loopEnd!);
            }
          },
          color: const Color(0xFFF44336),
        ),
      ],
    );
  }
}

class _CenterContent extends StatelessWidget {
  final PlayerProvider player;

  const _CenterContent({required this.player});

  @override
  Widget build(BuildContext context) {
    if (player.isLooping) {
      return _LoopProgressIndicator(player: player);
    }

    // Hướng dẫn
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Icon(
            Icons.arrow_forward,
            color: Colors.grey.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            player.loopStart != null
                ? 'Bấm B để lặp'
                : 'Bấm A để bắt đầu',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopProgressIndicator extends StatelessWidget {
  final PlayerProvider player;

  const _LoopProgressIndicator({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Loop count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: player.isWaitingGap
                  ? [const Color(0xFFFF9800), const Color(0xFFFF5722)]
                  : [const Color(0xFF6C63FF), const Color(0xFF5B52CC)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (player.isWaitingGap
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF6C63FF))
                    .withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                player.isWaitingGap ? Icons.hourglass_top : Icons.replay,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                player.maxLoopCount > 0
                    ? '${player.loopCount}/${player.maxLoopCount}'
                    : '${player.loopCount}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Progress bar (nếu có max loop count)
        if (player.maxLoopCount > 0) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: player.loopProgress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  player.isWaitingGap
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF4CAF50),
                ),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ==================== EXTENDED CONTROLS ====================

class _ExtendedControls extends StatelessWidget {
  final PlayerProvider player;
  final bool compact;

  const _ExtendedControls({
    required this.player,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Skip Gap / Skip to next loop
        if (player.isWaitingGap)
          _ActionButton(
            icon: Icons.skip_next,
            label: 'Bỏ qua',
            color: const Color(0xFFFF9800),
            onTap: () => player.toggleLoopPause(),
          )
        else
          _ActionButton(
            icon: Icons.fast_forward,
            label: 'Loop tiếp',
            color: const Color(0xFF6C63FF),
            onTap: () => player.skipToNextLoop(),
          ),

        // Save button
        _ActionButton(
          icon: Icons.bookmark_add,
          label: 'Lưu',
          color: const Color(0xFFFFB300),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const SaveSegmentDialog(),
            );
          },
        ),

        // Loop count selector
        if (!compact)
          _LoopCountSelector(player: player),

        // Clear button
        _ActionButton(
          icon: Icons.close,
          label: 'Xóa',
          color: const Color(0xFFF44336),
          onTap: () => player.clearLoop(),
        ),
      ],
    );
  }
}

class _LoopCountSelector extends StatelessWidget {
  final PlayerProvider player;

  const _LoopCountSelector({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_one, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          DropdownButton<int>(
            value: player.maxLoopCount,
            dropdownColor: const Color(0xFF2D2D44),
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: [0, 3, 5, 7, 10, 15, 20].map((count) {
              return DropdownMenuItem(
                value: count,
                child: Text(count == 0 ? '∞' : '${count}x'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                player.setMaxLoopCount(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ==================== GAP DURATION SLIDER ====================

class _GapDurationSlider extends StatelessWidget {
  final PlayerProvider player;

  const _GapDurationSlider({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: player.gapDuration > 0
                    ? const Color(0xFFFF9800)
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Khoảng lặng:',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: player.gapDuration > 0
                      ? const Color(0xFFFF9800).withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  player.gapDuration > 0
                      ? '${player.gapDuration.toStringAsFixed(1)}s'
                      : 'Tắt',
                  style: TextStyle(
                    color: player.gapDuration > 0
                        ? const Color(0xFFFF9800)
                        : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFF9800),
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: const Color(0xFFFF9800),
              overlayColor: const Color(0xFFFF9800).withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: player.gapDuration,
              min: 0.0,
              max: 10.0,
              divisions: 20,
              onChanged: (value) => player.setGapDuration(value),
            ),
          ),

          // Quick presets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 1.0, 2.0, 3.0, 5.0].map((seconds) {
              final isActive = player.gapDuration == seconds;
              return GestureDetector(
                onTap: () => player.setGapDuration(seconds),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFF9800).withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFFF9800)
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    seconds == 0 ? 'Tắt' : '${seconds.toInt()}s',
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFFFF9800)
                          : Colors.grey,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Tip based on mode
          const SizedBox(height: 8),
          _ModeTip(player: player),
        ],
      ),
    );
  }
}

class _ModeTip extends StatelessWidget {
  final PlayerProvider player;

  const _ModeTip({required this.player});

  @override
  Widget build(BuildContext context) {
    String tip;
    IconData icon;
    Color color;

    switch (player.currentMode) {
      case VipMode.buddhism:
        tip = '💡 Khoảng lặng giúp suy ngẫm, thấm nhuần lời dạy';
        icon = Icons.self_improvement;
        color = const Color(0xFFFFB300);
        break;
      case VipMode.english:
        tip = '💡 Khoảng lặng để bạn lặp lại theo (Shadowing)';
        icon = Icons.record_voice_over;
        color = const Color(0xFF2196F3);
        break;
      case VipMode.music:
        tip = '💡 Khoảng lặng tạo nhịp thở giữa các đoạn';
        icon = Icons.music_note;
        color = const Color(0xFF9C27B0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
                color: color.withOpacity(0.8),
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

// ==================== REUSABLE WIDGETS ====================

class _LoopButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Duration? time;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color color;

  const _LoopButton({
    required this.label,
    required this.isActive,
    this.time,
    required this.onTap,
    this.onLongPress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isActive ? color : Colors.white38,
            width: 3,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (time != null)
              Text(
                _formatTime(time!),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== COMPACT VERSION ====================

/// Phiên bản nhỏ gọn cho mini player
class ABLoopControlsCompact extends StatelessWidget {
  const ABLoopControlsCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        if (!player.hasLoop && player.loopStart == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: player.isLooping
                ? const Color(0xFF4CAF50).withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A indicator
              _CompactPoint(
                label: 'A',
                isActive: player.loopStart != null,
                color: const Color(0xFF4CAF50),
              ),

              // Progress or arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: player.isLooping
                    ? Text(
                  '${player.loopCount}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : const Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: Colors.grey,
                ),
              ),

              // B indicator
              _CompactPoint(
                label: 'B',
                isActive: player.loopEnd != null,
                color: const Color(0xFFF44336),
              ),

              // Clear button
              if (player.isLooping) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => player.clearLoop(),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white54,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompactPoint extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;

  const _CompactPoint({
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : Colors.transparent,
        border: Border.all(
          color: isActive ? color : Colors.grey,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}