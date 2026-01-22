import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class WaveformView extends StatefulWidget {
  const WaveformView({super.key});

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 50;
  final List<double> _bars = List.generate(_barCount, (_) => 0.1);
  final List<double> _targetBars = List.generate(_barCount, (_) => 0.1);
  Timer? _timer;
  final Random _random = Random();

  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _startWaveAnimation();
  }

  void _initAnimation() {
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController?.dispose();
    super.dispose();
  }

  void _startWaveAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        final player = context.read<PlayerProvider>();
        final isPlaying = player.isPlaying;
        final speed = player.state.speed;

        setState(() {
          for (int i = 0; i < _barCount; i++) {
            if (isPlaying) {
              if (_random.nextDouble() > 0.7) {
                _targetBars[i] = _random.nextDouble() * speed.clamp(0.3, 1.5);
              }
              _bars[i] = _bars[i] + (_targetBars[i] - _bars[i]) * 0.3;
            } else {
              _targetBars[i] = 0.1;
              _bars[i] = _bars[i] + (_targetBars[i] - _bars[i]) * 0.1;
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final progress = player.state.duration.inMilliseconds > 0
            ? player.state.position.inMilliseconds /
            player.state.duration.inMilliseconds
            : 0.0;

        return Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Background gradient
                if (_glowAnimation != null)
                  AnimatedBuilder(
                    animation: _glowAnimation!,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF6C63FF).withOpacity(
                                player.isPlaying ? _glowAnimation!.value * 0.1 : 0.02,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Loop region highlight
                if (player.isLooping &&
                    player.loopStart != null &&
                    player.loopEnd != null &&
                    player.state.duration.inMilliseconds > 0)
                  Positioned.fill(
                    child: _buildLoopRegion(player),
                  ),

                // Waveform bars
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_barCount, (index) {
                      final barProgress = index / _barCount;
                      final isPassed = barProgress <= progress;
                      final isInLoop = _isInLoopRegion(player, barProgress);

                      return _WaveformBar(
                        height: _bars[index],
                        isPassed: isPassed,
                        isInLoop: isInLoop,
                        isPlaying: player.isPlaying,
                      );
                    }),
                  ),
                ),

                // Progress indicator line
                Positioned(
                  left: 8 + (MediaQuery.of(context).size.width - 48) * progress,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                // Current time overlay
                Positioned(
                  left: 8,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(player.state.position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

                // Duration overlay
                Positioned(
                  right: 8,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(player.state.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoopRegion(PlayerProvider player) {
    final duration = player.state.duration.inMilliseconds;
    if (duration == 0) return const SizedBox.shrink();

    final startPercent = player.loopStart!.inMilliseconds / duration;
    final endPercent = player.loopEnd!.inMilliseconds / duration;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = width * startPercent;
        final regionWidth = width * (endPercent - startPercent);

        return Stack(
          children: [
            Positioned(
              left: left,
              width: regionWidth,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  border: Border.symmetric(
                    vertical: BorderSide(
                      color: const Color(0xFF4CAF50).withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isInLoopRegion(PlayerProvider player, double barProgress) {
    if (!player.isLooping ||
        player.loopStart == null ||
        player.loopEnd == null ||
        player.state.duration.inMilliseconds == 0) {
      return false;
    }

    final duration = player.state.duration.inMilliseconds;
    final startPercent = player.loopStart!.inMilliseconds / duration;
    final endPercent = player.loopEnd!.inMilliseconds / duration;

    return barProgress >= startPercent && barProgress <= endPercent;
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _WaveformBar extends StatelessWidget {
  final double height;
  final bool isPassed;
  final bool isInLoop;
  final bool isPlaying;

  const _WaveformBar({
    required this.height,
    required this.isPassed,
    required this.isInLoop,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    Color barColor;
    if (isInLoop) {
      barColor = isPassed
          ? const Color(0xFF4CAF50)
          : const Color(0xFF4CAF50).withOpacity(0.4);
    } else {
      barColor = isPassed
          ? const Color(0xFF6C63FF)
          : const Color(0xFF6C63FF).withOpacity(0.3);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: 3,
      height: 8 + (height * 60),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(2),
        boxShadow: isPlaying && isPassed
            ? [
          BoxShadow(
            color: barColor.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
    );
  }
}