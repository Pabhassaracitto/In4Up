// lib/screens/read_mode/widgets/recent_file_card.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../models/recent_file.dart';

class RecentFileCard extends StatelessWidget {
  final RecentFile file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const RecentFileCard({
    super.key,
    required this.file,
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
              if (file.totalLines > 0) _buildProgressBar(),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
      height: 66,
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
        // ★ FIX: dùng typeEmoji thay vì typeIcon
        child: Text(
          file.thumbnailEmoji ?? file.typeEmoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  // ── Info Column ──────────────────────────────────────────────
  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          file.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Subtitle
        if (file.subtitle != null &&
            file.subtitle!.isNotEmpty &&
            file.subtitle != file.localPath) ...[
          const SizedBox(height: 2),
          Text(
            file.subtitle!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 7),

        // Badges
        Row(
          children: [
            _TypeBadge(
              // ★ FIX: dùng typeLabel thay vì typeIcon
              label: file.typeLabel,
              color: _typeColor,
            ),
            const SizedBox(width: 6),
            _ProgressText(
              text: file.progressText,
              color: _progressColor,
            ),
          ],
        ),
      ],
    );
  }

  // ── Arrow ────────────────────────────────────────────────────
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

  // ── Progress Bar ─────────────────────────────────────────────
  Widget _buildProgressBar() {
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: file.readProgress,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        valueColor: AlwaysStoppedAnimation<Color>(
          _progressColor.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  // ── Color helpers ─────────────────────────────────────────────

  Color get _borderColor {
    if (file.isCompleted) return Colors.green.withValues(alpha: 0.35);
    if (file.isInProgress) return _typeColor.withValues(alpha: 0.25);
    return Colors.white.withValues(alpha: 0.07);
  }

  List<Color> get _gradientColors {
    // ★ FIX: dùng đúng tên enum localPdf / localText / cloud
    switch (file.type) {
      case RecentFileType.localPdf:
        return [const Color(0xFF7B1818), const Color(0xFFBF3030)];
      case RecentFileType.cloud:
        return [const Color(0xFF0D3060), const Color(0xFF1565C0)];
      case RecentFileType.localText:
        return [const Color(0xFF13472E), const Color(0xFF27AE60)];
    }
  }

  Color get _typeColor {
    // ★ FIX: dùng đúng tên enum
    switch (file.type) {
      case RecentFileType.localPdf:
        return const Color(0xFFEF5350);
      case RecentFileType.cloud:
        return const Color(0xFF2196F3);
      case RecentFileType.localText:
        return const Color(0xFF4CAF50);
    }
  }

  Color get _progressColor {
    if (file.isCompleted) return Colors.green;
    if (file.readProgress > 0.5) return const Color(0xFF2196F3);
    if (file.readProgress > 0) return const Color(0xFFFF9800);
    return Colors.white.withValues(alpha: 0.35);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

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

class _ProgressText extends StatelessWidget {
  final String text;
  final Color color;
  const _ProgressText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      context.uiText(text),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
