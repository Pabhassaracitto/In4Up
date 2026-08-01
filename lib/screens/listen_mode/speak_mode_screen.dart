import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      child: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final hasAudio = player.currentSongPath != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                    'Các chức năng sâu hơn như AI chấm phát âm sẽ tiếp tục gom về đây.',
                    'Mục tiêu là giảm việc người dùng phải đi vòng qua tab công cụ riêng.',
                  ],
                ),
              ],
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
