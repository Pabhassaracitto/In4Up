// lib/features/learn_by_heart/widgets/elaborative_card.dart

import 'package:flutter/material.dart';

class ElaborativeCard extends StatelessWidget {
  final String shortMeaning;
  final List<String> keywords;
  final String lifeConnection;
  final bool initiallyExpanded;

  const ElaborativeCard({
    super.key,
    required this.shortMeaning,
    required this.keywords,
    required this.lifeConnection,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (shortMeaning.isEmpty && keywords.isEmpty && lifeConnection.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.5),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFFFD54F),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Móc treo ghi nhớ (Elaborative Anchor)',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Short Meaning
          if (shortMeaning.isNotEmpty) ...[
            Text(
              'Ý NGHĨA CỐT LÕI',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shortMeaning,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Keywords
          if (keywords.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: keywords.map((kw) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '#$kw',
                    style: const TextStyle(
                      color: Color(0xFFB388FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Life Connection
          if (lifeConnection.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite_outline_rounded,
                    color: Color(0xFF4CAF50),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Liên hệ thực tế: $lifeConnection',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
