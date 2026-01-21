import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../audio/audio_player_service.dart';

class WaveformView extends StatefulWidget {
  const WaveformView({super.key});

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _waveformData = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    _generateWaveformData();
  }

  void _generateWaveformData() {
    _waveformData.clear();
    for (int i = 0; i < 60; i++) {
      _waveformData.add(_random.nextDouble() * 0.8 + 0.2);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final isPlaying = player.state.status == PlaybackStatus.playing;
        final progress = player.state.duration.inMilliseconds > 0
            ? player.state.position.inMilliseconds /
            player.state.duration.inMilliseconds
            : 0.0;

        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(double.infinity, 80),
                painter: WaveformPainter(
                  waveformData: _waveformData,
                  progress: progress,
                  isPlaying: isPlaying,
                  animationValue: _animationController.value,
                  activeColor: const Color(0xFF6C63FF),
                  inactiveColor: Colors.white24,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final bool isPlaying;
  final double animationValue;
  final Color activeColor;
  final Color inactiveColor;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
    required this.animationValue,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final barWidth = size.width / waveformData.length - 2;
    final centerY = size.height / 2;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * (barWidth + 2);
      final barProgress = i / waveformData.length;

      final isActive = barProgress <= progress;

      double heightMultiplier = waveformData[i];
      if (isPlaying && isActive) {
        heightMultiplier *= 0.8 + 0.4 * math.sin((animationValue + i * 0.1) * 2 * math.pi);
      }

      final barHeight = size.height * 0.8 * heightMultiplier;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }

    final progressX = size.width * progress;
    final linePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(progressX, 0),
      Offset(progressX, size.height),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}