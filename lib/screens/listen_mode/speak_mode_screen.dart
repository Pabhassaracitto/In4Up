import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/responsive/app_responsive.dart';
import '../../features/shadowing/models/shadowing_preset.dart';
import '../../features/shadowing/models/shadowing_result.dart';
import '../../features/shadowing/providers/shadowing_provider.dart';
import '../../features/shadowing/widgets/shadowing_widget.dart';
import '../../providers/player_provider.dart';

class SpeakModeScreen extends StatelessWidget {
  final VoidCallback onOpenYouGlish;
  final VoidCallback onOpenQuickActions;
  final VoidCallback onOpenUnderstand;

  const SpeakModeScreen({
    super.key,
    required this.onOpenYouGlish,
    required this.onOpenQuickActions,
    required this.onOpenUnderstand,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080B1A),
      child: Consumer2<PlayerProvider, ShadowingProvider>(
        builder: (context, player, shadowing, _) {
          final hasAudio = player.currentSongPath != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            child: ResponsiveContentFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(hasAudio: hasAudio, title: player.currentSongTitle),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionChip(
                        icon: Icons.record_voice_over,
                        label: 'YouGlish',
                        color: const Color(0xFF00BCD4),
                        onTap: onOpenYouGlish,
                      ),
                      _QuickActionChip(
                        icon: Icons.auto_awesome,
                        label: 'Công cụ nhanh',
                        color: const Color(0xFF7C4DFF),
                        onTap: onOpenQuickActions,
                      ),
                      _QuickActionChip(
                        icon: Icons.lightbulb_outline,
                        label: 'Qua tab Hiểu',
                        color: const Color(0xFFFFB300),
                        onTap: onOpenUnderstand,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SpeakingStatsRow(shadowing: shadowing),
                  const SizedBox(height: 16),
                  _SpeakingPresetCard(shadowing: shadowing),
                  const SizedBox(height: 16),
                  _SpeakingHistoryCard(shadowing: shadowing),
                  const SizedBox(height: 20),
                  if (!hasAudio) ...[
                    _EmptyAudioCard(onOpenQuickActions: onOpenQuickActions),
                  ] else ...[
                    const ShadowingWidget(),
                  ],
                  const SizedBox(height: 20),
                  const _TipCard(
                    title: 'Luồng luyện nói đề xuất',
                    bullets: [
                      '1. Chọn audio ở tab Nghe hoặc mở nhanh từ Công cụ nhanh.',
                      '2. Tạo A-B loop cho câu muốn luyện.',
                      '3. Chuyển sang tab Nói để shadowing và nghe lại bản ghi.',
                      '4. Dùng YouGlish để đối chiếu phát âm tự nhiên.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _TipCard(
                    title: 'Thiết kế hiện tại',
                    bullets: [
                      'Nói là không gian thực hành phát âm và lặp lại có chủ đích.',
                      'Preset nhanh giúp đổi nhịp luyện tập mà không cần chui sâu vào cài đặt.',
                      'Các chức năng sâu hơn như AI chấm phát âm sẽ tiếp tục gom về đây.',
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool hasAudio;
  final String? title;

  const _HeroCard({required this.hasAudio, this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C4DFF).withValues(alpha: 0.24),
            const Color(0xFF2196F3).withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFFB388FF),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nói · Speaking Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Luyện shadowing, phát âm và phản xạ đầu ra.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasAudio ? Icons.music_note : Icons.warning_amber_rounded,
                  size: 18,
                  color: hasAudio ? const Color(0xFF4CAF50) : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasAudio
                        ? (title?.trim().isNotEmpty == true
                            ? 'Nguồn đang dùng: $title'
                            : 'Đã có audio, có thể bắt đầu luyện nói.')
                        : 'Chưa có audio hoạt động. Hãy mở nguồn từ tab Nghe hoặc Công cụ nhanh.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAudioCard extends StatelessWidget {
  final VoidCallback onOpenQuickActions;

  const _EmptyAudioCard({required this.onOpenQuickActions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.library_music_outlined,
              size: 42, color: Colors.white54),
          const SizedBox(height: 12),
          const Text(
            'Cần một nguồn audio để bắt đầu luyện nói',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn có thể mở YouTube, thư viện âm thanh hoặc nguồn gần đây từ nút công cụ nhanh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onOpenQuickActions,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Mở Công cụ nhanh'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakingStatsRow extends StatelessWidget {
  final ShadowingProvider shadowing;

  const _SpeakingStatsRow({required this.shadowing});

  @override
  Widget build(BuildContext context) {
    final lastScore = shadowing.lastScorePercent;
    final bestScore = shadowing.bestScorePercent;
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Lượt luyện',
            value: '${shadowing.totalPracticeCount}',
            color: const Color(0xFFB388FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Điểm gần nhất',
            value: lastScore == null ? '--' : '$lastScore%',
            color: const Color(0xFF42A5F5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Điểm tốt nhất',
            value: bestScore == null ? '--' : '$bestScore%',
            color: const Color(0xFF66BB6A),
          ),
        ),
      ],
    );
  }
}

class _SpeakingPresetCard extends StatelessWidget {
  final ShadowingProvider shadowing;

  const _SpeakingPresetCard({required this.shadowing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Preset luyện nói nâng cao',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showSavePresetDialog(context, shadowing),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Lưu preset'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chọn nhanh preset theo mục tiêu, hoặc lưu cấu hình hiện tại thành preset cá nhân.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preset đang dùng',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  '${shadowing.activePresetLabel} · ${shadowing.repeatCount}x · ${shadowing.playbackSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Preset hệ thống',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ...shadowing.builtInPresets.map(
            (preset) => _PresetTile(
              preset: preset,
              onApply: () => shadowing.applyPreset(preset),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Preset cá nhân',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (shadowing.customPresets.isNotEmpty)
                Text(
                  '${shadowing.customPresets.length} preset',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (shadowing.customPresets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Chưa có preset cá nhân. Hãy chỉnh repeat/speed theo ý bạn rồi bấm “Lưu preset”.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          else
            ...shadowing.customPresets.map(
              (preset) => _PresetTile(
                preset: preset,
                onApply: () => shadowing.applyPreset(preset),
                onDelete: () =>
                    _confirmDeletePreset(context, shadowing, preset),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showSavePresetDialog(
    BuildContext context,
    ShadowingProvider shadowing,
  ) async {
    final nameController = TextEditingController();
    final noteController = TextEditingController(
      text:
          'Preset ${shadowing.repeatCount}x · ${shadowing.playbackSpeed.toStringAsFixed(1)}x',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lưu preset cá nhân'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên preset',
                hintText: 'Ví dụ: Fluency sáng',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú ngắn',
                hintText: 'Mục tiêu của preset này',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await shadowing.saveCurrentAsPreset(
                name: nameController.text,
                description: noteController.text,
              );
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    nameController.dispose();
    noteController.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu preset cá nhân')),
      );
    }
  }

  Future<void> _confirmDeletePreset(
    BuildContext context,
    ShadowingProvider shadowing,
    ShadowingPreset preset,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa preset'),
        content: Text('Bạn có chắc muốn xóa preset "${preset.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await shadowing.deleteCustomPreset(preset.id);
    }
  }
}

class _PresetTile extends StatelessWidget {
  final ShadowingPreset preset;
  final VoidCallback onApply;
  final VoidCallback? onDelete;

  const _PresetTile({
    required this.preset,
    required this.onApply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (preset.isBuiltIn
                  ? const Color(0xFF7C4DFF)
                  : const Color(0xFF26C6DA))
              .withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preset.description.isEmpty
                      ? preset.compactLabel
                      : '${preset.description} · ${preset.compactLabel}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onApply,
            child: const Text('Áp dụng'),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _SpeakingHistoryCard extends StatelessWidget {
  final ShadowingProvider shadowing;

  const _SpeakingHistoryCard({required this.shadowing});

  @override
  Widget build(BuildContext context) {
    final history = shadowing.savedHistory.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lịch sử luyện nói',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (shadowing.savedHistory.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Xóa'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shadowing.savedHistory.isEmpty
                ? 'Chưa có phiên shadowing nào được lưu. Sau khi luyện xong, kết quả sẽ xuất hiện ở đây.'
                : 'Xem nhanh các phiên gần đây để theo dõi tiến bộ phát âm và độ bám câu.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (shadowing.savedHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            _HistoryOverviewRow(shadowing: shadowing),
            const SizedBox(height: 14),
            ...history.map((entry) => _HistoryTile(entry: entry)),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa lịch sử luyện nói'),
        content: const Text(
            'Bạn có chắc muốn xóa toàn bộ lịch sử shadowing đã lưu không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<ShadowingProvider>().clearSavedHistory();
    }
  }
}

class _HistoryOverviewRow extends StatelessWidget {
  final ShadowingProvider shadowing;

  const _HistoryOverviewRow({required this.shadowing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'TB gần đây',
            value: '${shadowing.averageScorePercent.toStringAsFixed(0)}%',
            color: const Color(0xFF7C4DFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Preset hiện tại',
            value:
                '${shadowing.repeatCount}x · ${shadowing.playbackSpeed.toStringAsFixed(1)}x',
            color: const Color(0xFFFFB300),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ShadowingHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showHistoryDetail(context, entry),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: entry.scoreColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: entry.scoreColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${entry.overallScorePercent}% · ${entry.gradeLabel}',
                    style: TextStyle(
                      color: entry.scoreColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTimestamp(entry.timestamp),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.originalText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (entry.recognizedText != null &&
                entry.recognizedText!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Bạn nói: ${entry.recognizedText}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                    '${entry.correctWordCount}/${entry.totalWordCount} từ đúng'),
                _metaChip('Tempo ${(entry.tempoRatio * 100).round()}%'),
                _metaChip('Xem chi tiết'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Future<void> _showHistoryDetail(
      BuildContext context, ShadowingHistoryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final exportText = _buildExportText(entry);
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.94,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Review phiên luyện nói',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip(
                          '${entry.overallScorePercent}% · ${entry.gradeLabel}'),
                      _metaChip(
                          '${entry.correctWordCount}/${entry.totalWordCount} từ đúng'),
                      _metaChip('Tempo ${(entry.tempoRatio * 100).round()}%'),
                      _metaChip(_formatTimestamp(entry.timestamp)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailSection('Câu gốc', entry.originalText),
                  if (entry.recognizedText != null &&
                      entry.recognizedText!.trim().isNotEmpty)
                    _detailSection('Câu nhận diện', entry.recognizedText!),
                  if ((entry.feedbackMessage ?? '').trim().isNotEmpty)
                    _detailSection(
                        'Nhận xét tổng quát', entry.feedbackMessage!),
                  if (entry.acoustic != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Acoustic snapshot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _miniMetric('Pitch',
                                '${(entry.acoustic!.pitchScore * 100).round()}%')),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _miniMetric('Energy',
                                '${(entry.acoustic!.energyScore * 100).round()}%')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _miniMetric('Rhythm',
                                '${(entry.acoustic!.rhythmScore * 100).round()}%')),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _miniMetric('Spectral',
                                '${(entry.acoustic!.spectralScore * 100).round()}%')),
                      ],
                    ),
                  ],
                  if (entry.wordBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Từng từ / điểm rơi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...entry.wordBreakdown.map(
                      (word) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${word.expectedWord} → ${word.recognizedWord ?? '∅'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${word.scorePercent}% · ${word.shortStatus}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            if (word.phonemeIssues.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Âm cần chú ý: ${word.phonemeIssues.join(', ')}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: exportText));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Đã copy phản hồi vào clipboard')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copy phản hồi'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static Widget _detailSection(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  static Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static String _buildExportText(ShadowingHistoryEntry entry) {
    final buffer = StringBuffer();
    buffer.writeln('in2up · Shadowing Review');
    buffer.writeln('Thời gian: ${_formatTimestamp(entry.timestamp)}');
    buffer.writeln('Điểm: ${entry.overallScorePercent}% · ${entry.gradeLabel}');
    buffer
        .writeln('Từ đúng: ${entry.correctWordCount}/${entry.totalWordCount}');
    buffer.writeln('Tempo: ${(entry.tempoRatio * 100).round()}%');
    buffer.writeln();
    buffer.writeln('Câu gốc: ${entry.originalText}');
    if (entry.recognizedText != null &&
        entry.recognizedText!.trim().isNotEmpty) {
      buffer.writeln('Câu nhận diện: ${entry.recognizedText}');
    }
    if ((entry.feedbackMessage ?? '').trim().isNotEmpty) {
      buffer.writeln('Nhận xét: ${entry.feedbackMessage}');
    }
    if (entry.wordBreakdown.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Chi tiết từ:');
      for (final word in entry.wordBreakdown) {
        buffer.writeln(
            '- ${word.expectedWord} → ${word.recognizedWord ?? '∅'} | ${word.scorePercent}% | ${word.shortStatus}');
        if (word.phonemeIssues.isNotEmpty) {
          buffer.writeln('  Âm cần chú ý: ${word.phonemeIssues.join(', ')}');
        }
      }
    }
    return buffer.toString();
  }

  static String _formatTimestamp(DateTime timestamp) {
    final d = timestamp;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _TipCard({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: Color(0xFFB388FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
