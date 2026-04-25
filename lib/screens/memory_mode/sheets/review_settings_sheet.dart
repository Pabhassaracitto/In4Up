// lib/screens/memory_mode/sheets/review_settings_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/review_session.dart';
import '../models/memory_stage.dart';

/// Cài đặt trước khi bắt đầu ôn tập
class ReviewSettingsSheet extends StatefulWidget {
  final int totalDue;
  final int totalItems;
  final Map<MemoryStage, int> stageDistribution;
  final ValueChanged<ReviewSettings> onStart;

  const ReviewSettingsSheet({
    super.key,
    required this.totalDue,
    required this.totalItems,
    required this.stageDistribution,
    required this.onStart,
  });

  static void show(
    BuildContext context, {
    required int totalDue,
    required int totalItems,
    required Map<MemoryStage, int> stageDistribution,
    required ValueChanged<ReviewSettings> onStart,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReviewSettingsSheet(
        totalDue: totalDue,
        totalItems: totalItems,
        stageDistribution: stageDistribution,
        onStart: onStart,
      ),
    );
  }

  @override
  State<ReviewSettingsSheet> createState() => _ReviewSettingsSheetState();
}

class _ReviewSettingsSheetState extends State<ReviewSettingsSheet> {
  ReviewMode _mode = ReviewMode.spaced;
  int _maxCards = 20;
  MemoryStage? _stageFilter;
  bool _shuffleOrder = false;
  bool _showMeaningFirst = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Row(
                  children: [
                    Text('💧', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 8),
                    Text(
                      'Cài đặt ôn tập',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ===== MODE SELECTION =====
                Text(
                  'Chế độ',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ModeChip(
                      mode: ReviewMode.spaced,
                      label: 'SRS',
                      emoji: '💧',
                      desc: '${widget.totalDue} cần ôn',
                      isSelected: _mode == ReviewMode.spaced,
                      onTap: () => setState(() => _mode = ReviewMode.spaced),
                    ),
                    _ModeChip(
                      mode: ReviewMode.cram,
                      label: 'Nhồi nhét',
                      emoji: '🔥',
                      desc: 'Tất cả ${widget.totalItems} từ',
                      isSelected: _mode == ReviewMode.cram,
                      onTap: () => setState(() => _mode = ReviewMode.cram),
                    ),
                    _ModeChip(
                      mode: ReviewMode.difficult,
                      label: 'Từ khó',
                      emoji: '⚡',
                      desc: 'Seed + Sprout + accuracy thấp',
                      isSelected: _mode == ReviewMode.difficult,
                      onTap: () => setState(() => _mode = ReviewMode.difficult),
                    ),
                    _ModeChip(
                      mode: ReviewMode.random,
                      label: 'Ngẫu nhiên',
                      emoji: '🎲',
                      desc: 'Xáo trộn tất cả',
                      isSelected: _mode == ReviewMode.random,
                      onTap: () => setState(() => _mode = ReviewMode.random),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ===== MAX CARDS =====
                Row(
                  children: [
                    Text(
                      'Số thẻ tối đa',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '$_maxCards',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _maxCards.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19,
                  activeColor: const Color(0xFF4CAF50),
                  inactiveColor: Colors.white.withValues(alpha: 0.1),
                  onChanged: (v) => setState(() => _maxCards = v.round()),
                ),

                const SizedBox(height: 12),

                // ===== OPTIONS =====
                _OptionSwitch(
                  label: 'Xáo trộn thứ tự',
                  value: _shuffleOrder,
                  onChanged: (v) => setState(() => _shuffleOrder = v),
                ),
                _OptionSwitch(
                  label: 'Hiện nghĩa trước (đảo thẻ)',
                  value: _showMeaningFirst,
                  onChanged: (v) => setState(() => _showMeaningFirst = v),
                ),

                const SizedBox(height: 24),

                // ===== START BUTTON =====
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      widget.onStart(ReviewSettings(
                        mode: _mode,
                        maxCards: _maxCards,
                        stageFilter: _stageFilter,
                        shuffle: _shuffleOrder,
                        showMeaningFirst: _showMeaningFirst,
                      ));
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Bắt đầu ôn tập',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewSettings {
  final ReviewMode mode;
  final int maxCards;
  final MemoryStage? stageFilter;
  final bool shuffle;
  final bool showMeaningFirst;

  const ReviewSettings({
    this.mode = ReviewMode.spaced,
    this.maxCards = 20,
    this.stageFilter,
    this.shuffle = false,
    this.showMeaningFirst = false,
  });
}

class _ModeChip extends StatelessWidget {
  final ReviewMode mode;
  final String label;
  final String emoji;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.mode,
    required this.label,
    required this.emoji,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF4CAF50).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Color(0xFF4CAF50).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color:
                        isSelected ? const Color(0xFF4CAF50) : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF4CAF50),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}
