import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recent_audio.dart';

class RecentAudioCard extends StatelessWidget {
  final RecentAudio audio;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const RecentAudioCard({
    super.key,
    required this.audio,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMainRow(),
              if (audio.totalDuration != Duration.zero) _buildProgressBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main Row ─────────────────────────────────────────────────
  Widget _buildMainRow() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildThumbnail(),
          const SizedBox(width: 12),
          Expanded(child: _buildInfo()),
          _buildArrow(),
        ],
      ),
    );
  }

  // ── Thumbnail ────────────────────────────────────────────────
  Widget _buildThumbnail() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          audio.thumbnailEmoji ?? audio.typeEmoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }

  // ── Info ─────────────────────────────────────────────────────
  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          audio.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (audio.artist != null && audio.artist!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            audio.artist!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            _Badge(label: audio.typeLabel, color: _typeColor),
            const SizedBox(width: 6),
            Text(
              audio.progressText,
              style: TextStyle(
                color: _progressColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(
        Icons.chevron_right,
        size: 20,
        color: Colors.white.withValues(alpha: 0.25),
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────
  Widget _buildProgressBar() {
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: audio.listenProgress,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        valueColor: AlwaysStoppedAnimation<Color>(
          _progressColor.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  // ── Colors ───────────────────────────────────────────────────
  Color get _borderColor {
    if (audio.isCompleted) return Colors.green.withValues(alpha: 0.35);
    if (audio.isInProgress) return _typeColor.withValues(alpha: 0.25);
    return Colors.white.withValues(alpha: 0.07);
  }

  List<Color> get _gradientColors {
    switch (audio.type) {
      case RecentAudioType.youtube:
        return [const Color(0xFF8B0000), const Color(0xFFCC0000)];
      case RecentAudioType.local:
        return [const Color(0xFF1A0D3F), const Color(0xFF6C63FF)];
    }
  }

  Color get _typeColor {
    switch (audio.type) {
      case RecentAudioType.youtube:
        return const Color(0xFFFF5252);
      case RecentAudioType.local:
        return const Color(0xFF6C63FF);
    }
  }

  Color get _progressColor {
    if (audio.isCompleted) return Colors.green;
    if (audio.listenProgress > 0.5) return const Color(0xFF6C63FF);
    if (audio.listenProgress > 0) return const Color(0xFFFF9800);
    return Colors.white.withValues(alpha: 0.35);
  }
}

// ── Badge ─────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
