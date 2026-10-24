// lib/features/learn_by_heart/widgets/chain_recitation_view.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import '../controllers/chain_recitation_controller.dart';
import '../models/learn_by_heart_item.dart';

class ChainRecitationView extends StatefulWidget {
  final LearnByHeartItem item;
  final VoidCallback? onCompleted;

  const ChainRecitationView({
    super.key,
    required this.item,
    this.onCompleted,
  });

  @override
  State<ChainRecitationView> createState() => _ChainRecitationViewState();
}

class _ChainRecitationViewState extends State<ChainRecitationView> {
  late final ChainRecitationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChainRecitationController(widget.item);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleReveal() {
    HapticFeedback.selectionClick();
    _controller.revealCurrentTarget();
  }

  void _handleNext() {
    HapticFeedback.mediumImpact();
    _controller.markStepCompleted();
    final hasNext = _controller.nextStep();
    if (!hasNext) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final step = _controller.currentStep;
        final stepIdx = _controller.currentStepIndex;
        final total = _controller.totalSteps;
        final isRevealed = _controller.isCurrentRevealed;
        final isAllDone = _controller.isAllCompleted;

        if (step == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chain Step Progress Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Mối nối liên hoàn (Xích kệ ngôn ${stepIdx + 1}/$total)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${((stepIdx + 1) / total * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Prime Line (Câu mồi kích hoạt)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CÂU MỒI DẪN DẮT (DÒNG ${stepIdx + 1})',
                          style: const TextStyle(
                            color: Color(0xFFB388FF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (step.primePaliPrompt != null && step.primePaliPrompt!.isNotEmpty) ...[
                    Text(
                      step.primePaliPrompt!,
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    step.primePrompt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Target Line (Câu cần nối tiếp)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRevealed ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isRevealed ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CÂU CẦN ĐỌC TIẾP (DÒNG ${stepIdx + 2})',
                          style: TextStyle(
                            color: isRevealed ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isRevealed) ...[
                    if (step.targetPaliLine != null && step.targetPaliLine!.isNotEmpty) ...[
                      Text(
                        step.targetPaliLine!,
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      step.targetLine,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '___ ? Hãy nhớ câu tiếp theo trong đầu ? ___',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (!isRevealed)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleReveal,
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Xem câu tiếp theo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB388FF),
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleNext,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(stepIdx < total - 1 ? 'Thuộc câu nối → Sang mối tiếp' : 'Hoàn tất xích kệ ngôn! 🎉'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
