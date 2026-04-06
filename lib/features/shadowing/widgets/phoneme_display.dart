// lib/widgets/shadowing/phoneme_display.dart
// Widget hiển thị IPA phonemes với điểm số
import 'package:flutter/material.dart';

import '../models/phoneme_models.dart';
import '../services/cmu_dictionary_service.dart';

class PhonemeDisplay extends StatelessWidget {
  final List<PhonemeScore> phonemeScores;
  final String word;
  final bool showDetails;

  const PhonemeDisplay({
    super.key,
    required this.phonemeScores,
    required this.word,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E).withValues(alpha: 0.95),
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF6C63FF)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.abc, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${phonemeScores.length} phonemes',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              _buildOverallScore(),
            ],
          ),

          const SizedBox(height: 16),

          // Phoneme cards
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: phonemeScores.map((ps) {
              return _PhonemeCard(
                phonemeScore: ps,
                onTap:
                    showDetails ? () => _showPhonemeDetails(context, ps) : null,
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildOverallScore() {
    final avgScore = phonemeScores.isEmpty
        ? 0.0
        : phonemeScores.fold(0.0, (sum, p) => sum + p.score) /
            phonemeScores.length;
    final percent = (avgScore * 100).round();

    Color color;
    if (avgScore >= 0.85) {
      color = const Color(0xFF4CAF50);
    } else if (avgScore >= 0.70) {
      color = const Color(0xFFFFB300);
    } else {
      color = const Color(0xFFF44336);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: Color(0xFFFF5722),
          label: 'Vowel',
        ),
        SizedBox(width: 16),
        _LegendItem(
          color: Color(0xFF2196F3),
          label: 'Consonant',
        ),
        SizedBox(width: 16),
        _LegendItem(
          color: Color(0xFF9C27B0),
          label: 'Diphthong',
        ),
      ],
    );
  }

  void _showPhonemeDetails(BuildContext context, PhonemeScore ps) {
    final description = CMUDictionaryService.getPhonemeDescription(ps.phoneme);
    final examples = CMUDictionaryService.getPhonemeExamples(ps.phoneme);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ps.scoreColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '/${ps.phoneme}/',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: ps.scoreColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ps.type.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: ps.type == PhonemeType.vowel
                              ? const Color(0xFFFF5722)
                              : ps.type == PhonemeType.diphthong
                                  ? const Color(0xFF9C27B0)
                                  : const Color(0xFF2196F3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score: ${ps.scorePercent}% (${ps.grade})',
                        style: TextStyle(
                          fontSize: 16,
                          color: ps.scoreColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            if (examples.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Examples:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: examples
                    .map((ex) => Chip(
                          label: Text(ex),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(color: Colors.white),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PhonemeCard extends StatelessWidget {
  final PhonemeScore phonemeScore;
  final VoidCallback? onTap;

  const _PhonemeCard({
    required this.phonemeScore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = phonemeScore.scoreColor;
    final typeColor = phonemeScore.type == PhonemeType.vowel
        ? const Color(0xFFFF5722)
        : phonemeScore.type == PhonemeType.diphthong
            ? const Color(0xFF9C27B0)
            : const Color(0xFF2196F3);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: typeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),

            // IPA Symbol
            Text(
              '/${phonemeScore.phoneme}/',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
              ),
            ),

            const SizedBox(height: 2),

            // Score
            Text(
              '${phonemeScore.scorePercent}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),

            const SizedBox(height: 4),

            // Grade badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                phonemeScore.grade,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
