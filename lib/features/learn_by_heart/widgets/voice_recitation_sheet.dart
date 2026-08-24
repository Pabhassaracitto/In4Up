// lib/features/learn_by_heart/widgets/voice_recitation_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n/learn_by_heart_l10n.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../services/voice_recitation_service.dart';

class VoiceRecitationSheet extends StatefulWidget {
  final LearnByHeartItem item;
  final void Function(FSRSRating rating) onRated;

  const VoiceRecitationSheet({
    super.key,
    required this.item,
    required this.onRated,
  });

  static Future<void> show(
    BuildContext context, {
    required LearnByHeartItem item,
    required void Function(FSRSRating rating) onRated,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceRecitationSheet(item: item, onRated: onRated),
    );
  }

  @override
  State<VoiceRecitationSheet> createState() => _VoiceRecitationSheetState();
}

class _VoiceRecitationSheetState extends State<VoiceRecitationSheet> {
  final VoiceRecitationService _voiceService = VoiceRecitationService();

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _handleMicTap() async {
    HapticFeedback.mediumImpact();
    final l10n = LearnByHeartL10n.of(context);

    if (!_voiceService.isRecording) {
      final success = await _voiceService.startRecitation();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.voiceRecallMicPermission)),
        );
      }
    } else {
      await _voiceService.stopAndEvaluate(widget.item.vietnameseText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LearnByHeartL10n.of(context);

    return AnimatedBuilder(
      animation: _voiceService,
      builder: (context, _) {
        final isRecording = _voiceService.isRecording;
        final isTranscribing = _voiceService.isTranscribing;
        final result = _voiceService.lastResult;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              // Title
              Row(
                children: [
                  const Icon(Icons.mic_rounded, color: Color(0xFF6C63FF), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.voiceRecallTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Target Verse Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.voiceRecallTargetText,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.item.vietnameseText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Evaluation Result Display (if available)
                      if (result != null) ...[
                        _buildResultSection(result, l10n),
                        const SizedBox(height: 20),
                      ] else if (isTranscribing) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                              const SizedBox(height: 12),
                              Text(
                                l10n.voiceRecallAnalyzing,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_voiceService.sttUnavailable) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.voiceRecallSttUnavailable,
                                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            isRecording
                                ? '🎙️ ${l10n.voiceRecallListening}'
                               : l10n.voiceRecallStartHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isRecording ? const Color(0xFF4CAF50) : Colors.grey[400],
                              fontSize: 13,
                              fontWeight: isRecording ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Mic Control Button
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: _handleMicTap,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isRecording ? 68 : 60,
                    height: isRecording ? 68 : 60,
                    decoration: BoxDecoration(
                      color: isRecording ? const Color(0xFFE53935) : const Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isRecording ? const Color(0xFFE53935) : const Color(0xFF6C63FF))
                              .withValues(alpha: 0.45),
                          blurRadius: isRecording ? 20 : 10,
                          spreadRadius: isRecording ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: isRecording ? 34 : 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isRecording ? l10n.voiceRecallStopToScore : l10n.voiceRecallStartRecording,
                style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultSection(VoiceRecitationResult result, LearnByHeartL10n l10n) {
    final accuracy = result.accuracyPercent;
    final isGood = accuracy >= 70.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGood ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : const Color(0xFFFFB300).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isGood ? const Color(0xFF4CAF50) : const Color(0xFFFFB300)).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${accuracy.toStringAsFixed(0)}% ${l10n.voiceRecallAccuracy}',
                  style: TextStyle(
                    color: isGood ? const Color(0xFF81C784) : const Color(0xFFFFD54F),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                isGood ? '🎉 ${l10n.voiceRecallExcellent}' : l10n.voiceRecallNeedMore,
                style: TextStyle(
                  color: isGood ? const Color(0xFF81C784) : Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Word-by-word Alignment Display
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: result.wordMatches.map((m) {
              Color color;
              Color bg;
              switch (m.status) {
                case WordMatchStatus.exact:
                  color = const Color(0xFF81C784);
                  bg = const Color(0xFF4CAF50).withValues(alpha: 0.2);
                  break;
                case WordMatchStatus.partial:
                  color = const Color(0xFFFFD54F);
                  bg = const Color(0xFFFFB300).withValues(alpha: 0.2);
                  break;
                case WordMatchStatus.missed:
                  color = const Color(0xFFEF5350);
                  bg = const Color(0xFFE53935).withValues(alpha: 0.2);
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  m.targetWord,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Auto-FSRS Rating CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onRated(result.suggestedRating);
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('${l10n.voiceRecallSubmitResult} (${result.suggestedRating.label})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGood ? const Color(0xFF4CAF50) : const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
