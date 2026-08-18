// lib/widgets/shadowing/pronunciation_result.dart
// Widget hiển thị kết quả phát âm đầy đủ

import 'package:in4up/core/language/localized_material.dart';

import '../../shadowing/models/shadowing_result.dart';
import 'phoneme_display.dart';

class PronunciationResultView extends StatelessWidget {
  final ShadowingResult result;
  final VoidCallback? onTryAgain;
  final VoidCallback? onPlayRecording;

  const PronunciationResultView({
    super.key,
    required this.result,
    this.onTryAgain,
    this.onPlayRecording,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Overall Score Card
          _buildScoreCard(),

          const SizedBox(height: 20),

          // Word-by-word results
          ...result.wordResults.map((wordResult) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PhonemeDisplay(
                  phonemeScores: wordResult.phonemeScores,
                  word: wordResult.expectedWord,
                ),
              )),

          const SizedBox(height: 20),

          // Action buttons
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            result.scoreColor.withValues(alpha: 0.2),
            result.scoreColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: result.scoreColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Trophy/Star icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  result.scoreColor,
                  result.scoreColor.withValues(alpha: 0.7)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getScoreIcon(),
              size: 40,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${result.overallScorePercent}',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: result.scoreColor,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: result.scoreColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Grade
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: result.scoreColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Grade: ${result.overallGrade}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.check_circle,
                label: 'Words',
                value: '${result.correctWordCount}/${result.totalWordCount}',
                color: const Color(0xFF4CAF50),
              ),
              _StatItem(
                icon: Icons.speed,
                label: 'Tempo',
                value: '${result.tempoRatio.toStringAsFixed(1)}x',
                color: Colors.orange,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Feedback
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _getFeedbackIcon(),
                  color: result.scoreColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.feedbackMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (onPlayRecording != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPlayRecording,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Play Recording'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        if (onPlayRecording != null && onTryAgain != null)
          const SizedBox(width: 12),
        if (onTryAgain != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onTryAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getScoreIcon() {
    if (result.overallScorePercent >= 90) return Icons.emoji_events;
    if (result.overallScorePercent >= 75) return Icons.star;
    if (result.overallScorePercent >= 60) return Icons.thumb_up;
    return Icons.trending_up;
  }

  IconData _getFeedbackIcon() {
    if (result.overallScorePercent >= 90) return Icons.celebration;
    if (result.overallScorePercent >= 75) return Icons.thumb_up;
    if (result.overallScorePercent >= 60) return Icons.psychology;
    return Icons.fitness_center;
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
