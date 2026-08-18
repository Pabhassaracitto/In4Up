// lib/screens/memory_mode/sheets/word_detail_sheet.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import '../models/memory_item.dart';
import '../models/memory_stage.dart';

/// Chi tiết một từ trong vườn nhớ
/// Hiện: word, meaning, phonetic, example, context, stats, history
class WordDetailSheet extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayAudio;
  final ValueChanged<MemoryItem>? onUpdate;

  const WordDetailSheet({
    super.key,
    required this.item,
    this.onDelete,
    this.onPlayAudio,
    this.onUpdate,
  });

  /// Hiển thị sheet
  static void show(
    BuildContext context, {
    required MemoryItem item,
    VoidCallback? onDelete,
    VoidCallback? onPlayAudio,
    ValueChanged<MemoryItem>? onUpdate,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WordDetailSheet(
        item: item,
        onDelete: onDelete,
        onPlayAudio: onPlayAudio,
        onUpdate: onUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = item.stage;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: stage.primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: stage.primaryColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== HEADER: Stage + Word =====
                  _buildHeader(stage),
                  const SizedBox(height: 24),

                  // ===== MEANING =====
                  if (item.meaning != null) ...[
                    const _SectionTitle(label: 'Nghĩa', icon: Icons.translate),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF4CAF50).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        item.meaning!,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ===== EXAMPLE =====
                  if (item.example != null) ...[
                    const _SectionTitle(
                        label: 'Ví dụ', icon: Icons.format_quote),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFF2196F3).withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        item.example!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[300],
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ===== CONTEXT (dòng gốc) =====
                  if (item.context != null) ...[
                    const _SectionTitle(
                        label: 'Ngữ cảnh gốc', icon: Icons.article),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '📖 ${item.context!}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ===== MEMORY STATS =====
                  const _SectionTitle(
                      label: 'Trạng thái trí nhớ', icon: Icons.psychology),
                  const SizedBox(height: 12),
                  _buildMemoryStats(stage),
                  const SizedBox(height: 20),

                  // ===== STAGE JOURNEY =====
                  const _SectionTitle(
                      label: 'Hành trình', icon: Icons.timeline),
                  const SizedBox(height: 12),
                  _buildStageJourney(stage),
                  const SizedBox(height: 24),

                  // ===== AUDIO BUTTON =====
                  if (item.audioPath != null && onPlayAudio != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onPlayAudio,
                        icon: const Icon(Icons.volume_up, size: 18),
                        label: const Text('Nghe phát âm'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2196F3),
                          side: BorderSide(
                            color: Color(0xFF2196F3).withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ===== DELETE BUTTON =====
                  if (onDelete != null)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          _confirmDelete(context);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Xóa khỏi vườn'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(MemoryStage stage) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stage icon large
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: stage.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(stage.emoji, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word
              Text(
                item.word,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: stage.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),

              // Phonetic
              if (item.phonetic != null)
                Text(
                  item.phonetic!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const SizedBox(height: 6),

              // Tags row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Stage label
                  _TagChip(
                    label: stage.label,
                    color: stage.primaryColor,
                  ),
                  // Word type
                  if (item.wordType != null)
                    _TagChip(
                      label: item.wordType!,
                      color: const Color(0xFF2196F3),
                    ),
                  // CEFR level
                  if (item.cefrLevel != null)
                    _TagChip(
                      label: item.cefrLevel!,
                      color: const Color(0xFFFF9800),
                    ),
                  // Custom tags
                  ...item.tags.map((tag) => _TagChip(
                        label: tag,
                        color: Colors.grey,
                      )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryStats(MemoryStage stage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Strength bar
          Row(
            children: [
              Text(
                'Sức nhớ',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${(item.strength * 100).round()}%',
                style: TextStyle(
                  color: stage.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.strength,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(stage.primaryColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              _StatCell(
                label: 'Tổng ôn',
                value: '${item.totalReviews}',
                icon: Icons.replay,
              ),
              _StatCell(
                label: 'Đúng',
                value: '${(item.accuracy * 100).round()}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF4CAF50),
              ),
              _StatCell(
                label: 'Sai',
                value: '${item.incorrectCount}',
                icon: Icons.cancel_outlined,
                color: const Color(0xFFF44336),
              ),
              _StatCell(
                label: 'Hệ số',
                value: item.easeFactor.toStringAsFixed(1),
                icon: Icons.speed,
                color: const Color(0xFF2196F3),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Timing info
          _TimingRow(
            label: 'Thêm vào',
            value: _formatDate(item.createdAt),
            icon: Icons.add_circle_outline,
          ),
          if (item.lastReviewedAt != null)
            _TimingRow(
              label: 'Ôn lần cuối',
              value: _formatRelative(item.lastReviewedAt!),
              icon: Icons.history,
            ),
          if (item.nextReviewAt != null)
            _TimingRow(
              label: item.needsReview ? 'Quá hạn' : 'Ôn tiếp',
              value: item.needsReview
                  ? '${item.overdueHours.toStringAsFixed(1)}h trước'
                  : _formatRelative(item.nextReviewAt!),
              icon: Icons.schedule,
              valueColor: item.needsReview ? const Color(0xFFFF5252) : null,
            ),
        ],
      ),
    );
  }

  Widget _buildStageJourney(MemoryStage currentStage) {
    return Row(
      children: MemoryStage.values.map((stage) {
        final isReached = stage.index <= currentStage.index;
        final isCurrent = stage == currentStage;

        return Expanded(
          child: Column(
            children: [
              // Connector line
              Row(
                children: [
                  if (stage.index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isReached
                            ? stage.primaryColor.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  // Circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isCurrent ? 36 : 24,
                    height: isCurrent ? 36 : 24,
                    decoration: BoxDecoration(
                      color: isReached
                          ? stage.primaryColor
                              .withValues(alpha: isCurrent ? 0.3 : 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: stage.primaryColor, width: 2)
                          : null,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color:
                                    stage.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        stage.emoji,
                        style: TextStyle(fontSize: isCurrent ? 16 : 10),
                      ),
                    ),
                  ),
                  if (stage.index < MemoryStage.values.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isReached && stage.index < currentStage.index
                            ? stage.primaryColor.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (isCurrent)
                Text(
                  stage.label,
                  style: TextStyle(
                    color: stage.primaryColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa từ này?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          context.uiText('Xóa "${item.word}" khỏi vườn nhớ?\nDữ liệu ôn tập sẽ mất.'),
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
              onDelete?.call();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatRelative(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) {
      final absDiff = diff.abs();
      if (absDiff.inDays > 0) return '${absDiff.inDays} ngày trước';
      if (absDiff.inHours > 0) return '${absDiff.inHours} giờ trước';
      return '${absDiff.inMinutes} phút trước';
    } else {
      if (diff.inDays > 0) return 'sau ${diff.inDays} ngày';
      if (diff.inHours > 0) return 'sau ${diff.inHours} giờ';
      return 'sau ${diff.inMinutes} phút';
    }
  }
}

// ==================== HELPER WIDGETS ====================

class _SectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionTitle({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: c.withValues(alpha: 0.6)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _TimingRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const Spacer(),
          Text(
            context.uiText(value),
            style: TextStyle(
              color: valueColor ?? Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
