// lib/screens/understand_mode/widgets/understand_workspace_header.dart
//
// Header của workspace tab Hiểu — tách khỏi understand_workspace_screen.dart
// để test được độc lập (không cần dựng cả UnderstandTabConnector/PlayerProvider).
//
// "Hỏi AI" là MỘT ACTION trong hàng chip (cùng cấp Qua Nói / YouGlish / Ôn
// tập / Công cụ nhanh) — KHÔNG phải tab/mode thứ ba. TabBar bên dưới vẫn chỉ
// có Đồng bộ / Shadowing.

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';

class UnderstandWorkspaceHeader extends StatelessWidget {
  final VoidCallback onOpenSpeakMode;
  final VoidCallback onOpenYouGlish;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenQuickActions;

  /// Action "Hỏi AI" — mở sheet Trợ lý hiểu bài (AI Coach).
  final VoidCallback onOpenAiCoach;

  const UnderstandWorkspaceHeader({
    super.key,
    required this.onOpenSpeakMode,
    required this.onOpenYouGlish,
    required this.onOpenReview,
    required this.onOpenQuickActions,
    required this.onOpenAiCoach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFB300).withValues(alpha: 0.16),
                  const Color(0xFFFFB300).withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.24),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hiểu · Comprehension Workspace',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Đây là nơi ghép audio với text, đồng bộ dòng, phân tích ngữ cảnh và nối sang luyện nói hoặc ôn nhớ.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _WorkspaceChip(
                  icon: Icons.mic_rounded,
                  label: 'Qua Nói',
                  color: const Color(0xFFB388FF),
                  onTap: onOpenSpeakMode,
                ),
                const SizedBox(width: 8),
                _WorkspaceChip(
                  icon: Icons.record_voice_over,
                  label: 'YouGlish',
                  color: const Color(0xFF00BCD4),
                  onTap: onOpenYouGlish,
                ),
                const SizedBox(width: 8),
                _WorkspaceChip(
                  icon: Icons.school,
                  label: 'Ôn tập',
                  color: const Color(0xFF66BB6A),
                  onTap: onOpenReview,
                ),
                const SizedBox(width: 8),
                _WorkspaceChip(
                  icon: Icons.auto_awesome,
                  label: 'Công cụ nhanh',
                  color: const Color(0xFFFFB300),
                  onTap: onOpenQuickActions,
                ),
                const SizedBox(width: 8),
                // AI Coach — action theo ngữ cảnh, không phải mode thứ ba.
                _WorkspaceChip(
                  icon: Icons.psychology_outlined,
                  label: 'Hỏi AI',
                  color: const Color(0xFF7DD3FC),
                  onTap: onOpenAiCoach,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WorkspaceChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
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
