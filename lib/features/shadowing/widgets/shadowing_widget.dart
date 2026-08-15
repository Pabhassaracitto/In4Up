// NEW - UI shadowing
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../shadowing/models/shadowing_result.dart';
import '../providers/shadowing_provider.dart';
import 'waveform_comparison_painter.dart';
import 'package:in4up/core/language/tr_extension.dart';

/// Widget chính cho Shadowing Mode
class ShadowingWidget extends StatefulWidget {
  const ShadowingWidget({super.key});

  @override
  State<ShadowingWidget> createState() => _ShadowingWidgetState();
}

class _ShadowingWidgetState extends State<ShadowingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _revealController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _revealAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShadowingProvider, PlayerProvider>(
      builder: (context, shadowing, player, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A237E).withValues(alpha: 0.3),
                const Color(0xFF0D1B2A),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFF2196F3).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(shadowing),

              const SizedBox(height: 16),

              // Main content based on state
              _buildStateContent(shadowing, player),

              const SizedBox(height: 16),

              // Actions
              _buildActions(shadowing, player),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ShadowingProvider shadowing) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic,
            color: Color(0xFF2196F3),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shadowing Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getStateDescription(shadowing.state),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (shadowing.sessionResults.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Content',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStateContent(
      ShadowingProvider shadowing, PlayerProvider player) {
    switch (shadowing.state) {
      case ShadowingState.idle:
        return _buildIdleState(shadowing, player);
      case ShadowingState.playingOriginal:
        return _buildWaitingState(shadowing); // Đang nghe mẫu
      case ShadowingState.countdown:
        return _buildCountdownState(shadowing);
      case ShadowingState.recording:
        return _buildRecordingState(shadowing);
      case ShadowingState.analyzing:
        return _buildProcessingState();
      case ShadowingState.showingResults:
        return _buildResultState(shadowing);
    }
    //return const SizedBox.shrink();
  }

  Widget _buildIdleState(ShadowingProvider shadowing, PlayerProvider player) {
    final hasLoop = player.loopStart != null && player.loopEnd != null;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.record_voice_over,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            hasLoop
                ? 'Content'
                : 'Content',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasLoop) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_formatDuration(player.loopStart!)} → ${_formatDuration(player.loopEnd!)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Nút bắt đầu (chuyển sang trạng thái nghe mẫu/ghi âm)
            ElevatedButton.icon(
              onPressed: () {
                // Setup segment from player's loop
                shadowing.setSegment(
                  start: player.loopStart!,
                  end: player.loopEnd!,
                  audioPath: player.currentSongPath ?? '',
                  waveform: [],
                );
                // Bắt đầu quy trình: Nghe mẫu -> Countdown -> Ghi âm
                shadowing.playOriginal();
              },
              icon: const Icon(Icons.play_arrow),
              label: const TrText(context.l10n.shadowingStartPractice),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3)),
            ),
          ],
        ],
      ),
    );
  }

  /*Widget _buildReadyState(ShadowingProvider shadowing) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.play_circle_outline,
            size: 48,
            color: Color(0xFF2196F3),
          ),
          const SizedBox(height: 16),
          const TrText('1. Nghe đoạn mẫu\n2. Nhấn nút ghi âm\n3. Lặp lại theo mẫu', style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Content',
            style: const TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }*/

  Widget _buildWaitingState(ShadowingProvider shadowing) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(context.l10n.shadowingListeningSample, style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: shadowing.gapProgress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2196F3),
                  ),
                ),
                const Icon(
                  Icons.hourglass_empty,
                  size: 32,
                  color: Color(0xFF2196F3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.shadowingListenCarefully, style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownState(ShadowingProvider shadowing) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(context.l10n.shadowingReadyEx, style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2196F3).withValues(alpha: 0.2),
                    border: Border.all(
                      color: const Color(0xFF2196F3),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${shadowing.countdown}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingState(ShadowingProvider shadowing) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RecordingDot(),
              SizedBox(width: 8),
              Text(context.l10n.shadowingRecording, style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Amplitude visualization
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _LiveAmplitudePainter(
                amplitude: shadowing.currentAmplitude,
                waveform: shadowing.recordedWaveform,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Duration
          Text(
            _formatDuration(shadowing.recordedDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Content',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          ),
          SizedBox(height: 20),
          Text(context.l10n.shadowingAnalyzing, style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(ShadowingProvider shadowing) {
    final result = shadowing.currentResult;
    if (result == null) return const SizedBox.shrink();

    // Start reveal animation
    if (!_revealController.isAnimating && _revealController.value == 0) {
      _revealController.forward();
    }

    return AnimatedBuilder(
      animation: _revealAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _revealAnimation.value,
          child: Column(
            children: [
              // Grade display
              _buildGradeDisplay(result),

              const SizedBox(height: 20),

              // Waveform comparison
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: WaveformComparisonPainter(
                      originalWaveform: result.originalWaveform,
                      recordedWaveform: result.userWaveform,
                      animationProgress: _revealAnimation.value,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Score breakdown
              _buildScoreBreakdown(result),

              const SizedBox(height: 16),

              // Feedbacks
              // if (result.feedbacks.isNotEmpty)
              //   _buildFeedbacks(result.feedbacks),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGradeDisplay(ShadowingResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            result.scoreColor.withValues(alpha: 0.3),
            result.scoreColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: result.scoreColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            result.overallGrade, // Sử dụng overallGrade string
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            'Grade', // Hoặc mapping từ overallGrade
            style: TextStyle(
              color: result.scoreColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(result.overallScore * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown(ShadowingResult result) {
    final acoustic = result.acousticAnalysis;
    return Row(
      children: [
        Expanded(
          child: _ScoreItem(
            label: context.l10n.shadowingRhythm,
            score: acoustic?.rhythmScore ?? 0.0,
            icon: Icons.music_note,
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreItem(
            label: context.l10n.shadowingPitch,
            score: acoustic?.pitchScore ?? 0.0,
            icon: Icons.timer,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreItem(
            label: context.l10n.shadowingEnergy,
            score: acoustic?.energyScore ?? 0.0,
            icon: Icons.graphic_eq,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  // Widget _buildFeedbacks(List<ShadowingFeedback> feedbacks) { ... } // Tạm thời comment out vì model mới chưa có feedbacks list tương thích

  Widget _buildActions(ShadowingProvider shadowing, PlayerProvider player) {
    switch (shadowing.state) {
      case ShadowingState.idle:
        final hasLoop = player.loopStart != null && player.loopEnd != null;
        return ElevatedButton.icon(
          onPressed: hasLoop
              ? () {
                  shadowing.setSegment(
                    start: player.loopStart!,
                    end: player.loopEnd!,
                    audioPath: player.currentSongPath ?? '',
                    waveform: [],
                  );
                  shadowing.playOriginal();
                }
              : null,
          icon: const Icon(Icons.play_arrow),
          label: const TrText(context.l10n.shadowingPlaySample),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );

      case ShadowingState.playingOriginal:
        return ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            shadowing.stopPlayback();
          },
          icon: const Icon(Icons.stop_circle_outlined),
          label: const TrText(context.l10n.shadowingStopSample),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );

      case ShadowingState.countdown:
        return OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            shadowing.reset();
          },
          icon: const Icon(Icons.close),
          label: const TrText(context.l10n.shadowingCancelCountdown),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
        );

      case ShadowingState.recording:
        return ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            shadowing.stopRecording();
          },
          icon: const Icon(Icons.stop),
          label: const TrText(context.l10n.shadowingStopRecording),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        );

      case ShadowingState.showingResults:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _revealController.reset();
                  shadowing.retry();
                },
                icon: const Icon(Icons.refresh),
                label: const TrText(context.l10n.shadowingRetry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  shadowing.reset();
                },
                icon: const Icon(Icons.check),
                label: const TrText(context.l10n.shadowingFinish),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _getStateDescription(ShadowingState state) {
    switch (state) {
      case ShadowingState.idle:
        return 'Content';
      case ShadowingState.playingOriginal:
        return 'Content';
      case ShadowingState.countdown:
        return 'Content';
      case ShadowingState.recording:
        return 'Content';
      case ShadowingState.analyzing:
        return 'Content';
      case ShadowingState.showingResults:
        return 'Content';
      //default:
      //return '';
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000 ~/ 10;
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }
}

// Helper widgets
class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.5 + _controller.value * 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.5),
                blurRadius: 8 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  final Color color;

  const _ScoreItem({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '${(score * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAmplitudePainter extends CustomPainter {
  final double amplitude;
  final List<double> waveform;

  _LiveAmplitudePainter({
    required this.amplitude,
    required this.waveform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw recent waveform
    if (waveform.isNotEmpty) {
      final visibleSamples = (size.width / 3).floor();
      final startIdx =
          (waveform.length - visibleSamples).clamp(0, waveform.length);

      for (int i = startIdx; i < waveform.length; i++) {
        final x = (i - startIdx) / visibleSamples * size.width;
        final amp = waveform[i].clamp(0.0, 1.0);
        final barHeight = amp * (size.height * 0.8);

        canvas.drawLine(
          Offset(x, centerY - barHeight / 2),
          Offset(x, centerY + barHeight / 2),
          paint..color = Colors.red.withValues(alpha: 0.3 + amp * 0.7),
        );
      }
    }

    // Draw current amplitude indicator
    final indicatorHeight = amplitude * (size.height * 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width - 10, centerY),
          width: 8,
          height: indicatorHeight,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.red,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveAmplitudePainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.waveform.length != waveform.length;
  }
}