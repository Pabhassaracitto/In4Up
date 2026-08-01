import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/text_provider.dart';

class WriteStudioScreen extends StatelessWidget {
  final VoidCallback onOpenWebReader;
  final VoidCallback onOpenPdfReader;
  final VoidCallback onOpenQuickActions;

  const WriteStudioScreen({
    super.key,
    required this.onOpenWebReader,
    required this.onOpenPdfReader,
    required this.onOpenQuickActions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080B1A),
      child: Consumer<TextProvider>(
        builder: (context, textProvider, _) {
          final hasText = textProvider.hasLyrics;
          final source = textProvider.currentTextPath;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(
                  hasText: hasText,
                  source: source,
                  lineCount: textProvider.lines.length,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickActionChip(
                      icon: Icons.language,
                      label: 'Web Reader',
                      color: const Color(0xFF26A69A),
                      onTap: onOpenWebReader,
                    ),
                    _QuickActionChip(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF Reader',
                      color: const Color(0xFFEF5350),
                      onTap: onOpenPdfReader,
                    ),
                    _QuickActionChip(
                      icon: Icons.auto_awesome,
                      label: 'Công cụ nhanh',
                      color: const Color(0xFF26C6DA),
                      onTap: onOpenQuickActions,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!hasText) ...[
                  _EmptyTextCard(
                    onOpenWebReader: onOpenWebReader,
                    onOpenPdfReader: onOpenPdfReader,
                  ),
                ] else ...[
                  const _FeatureCard(
                    icon: Icons.edit_note,
                    color: Color(0xFF26C6DA),
                    title: 'Chép chính tả có AI chấm',
                    subtitle:
                        'Lấy nội dung từ bài đọc / lyric hiện tại rồi so sánh với câu trả lời của người học.',
                    status: 'Sắp tích hợp',
                  ),
                  const SizedBox(height: 12),
                  const _FeatureCard(
                    icon: Icons.rule_folder_outlined,
                    color: Color(0xFFFFB300),
                    title: 'Ẩn key / điền từ / chọn đáp án',
                    subtitle:
                        'Biến nội dung đang đọc thành bài tập recall, cloze hoặc multiple choice.',
                    status: 'Sắp tích hợp',
                  ),
                  const SizedBox(height: 12),
                  const _FeatureCard(
                    icon: Icons.draw_outlined,
                    color: Color(0xFFAB47BC),
                    title: 'Viết lại & chấm bởi AI',
                    subtitle:
                        'Cho phép người học viết lại, diễn đạt lại hoặc trả lời ngắn và nhận phản hồi.',
                    status: 'Sắp tích hợp',
                  ),
                ],
                const SizedBox(height: 20),
                const _TipCard(
                  title: 'Vai trò của tab Viết',
                  bullets: [
                    'Viết là nhánh output gắn trực tiếp với nguồn text/lyric hiện tại.',
                    'Không mở thêm một module rời rạc, mà nằm cạnh tab Đọc để giữ đúng ngữ cảnh.',
                    'Các bài tập viết sẽ ưu tiên tái dùng nguồn nội dung người học đang mở.',
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
  final bool hasText;
  final String? source;
  final int lineCount;

  const _HeroCard({
    required this.hasText,
    required this.source,
    required this.lineCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF26C6DA).withValues(alpha: 0.24),
            const Color(0xFF2196F3).withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF26C6DA).withValues(alpha: 0.28),
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
                  Icons.edit_square,
                  color: Color(0xFF80DEEA),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Viết · Writing Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Biến đầu vào văn bản thành đầu ra chủ động.',
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
                  hasText ? Icons.description_outlined : Icons.warning_amber,
                  size: 18,
                  color: hasText ? const Color(0xFF4CAF50) : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasText
                        ? 'Nguồn hiện tại: ${source ?? 'văn bản đang mở'} · $lineCount dòng.'
                        : 'Chưa có văn bản hoạt động. Hãy mở PDF hoặc Web Reader để chuẩn bị bài viết.',
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

class _EmptyTextCard extends StatelessWidget {
  final VoidCallback onOpenWebReader;
  final VoidCallback onOpenPdfReader;

  const _EmptyTextCard({
    required this.onOpenWebReader,
    required this.onOpenPdfReader,
  });

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
          const Icon(Icons.menu_book_outlined,
              size: 42, color: Colors.white54),
          const SizedBox(height: 12),
          const Text(
            'Cần nguồn văn bản để bắt đầu luyện viết',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn có thể nhập một bài web hoặc file PDF trước, sau đó các dạng bài viết sẽ dùng chính nội dung đó.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenWebReader,
                icon: const Icon(Icons.language),
                label: const Text('Mở Web Reader'),
              ),
              ElevatedButton.icon(
                onPressed: onOpenPdfReader,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Mở PDF Reader'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;

  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
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
                      color: Color(0xFF26C6DA),
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
