// lib/screens/tools/word_list/single_word_review_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/tts/tts_service.dart';
// ← FIX: thêm import
import '../../../models/sm2_algorithm.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../widgets/skill_triangle.dart';
import 'package:in4up/core/language/tr_extension.dart';

class SingleWordReviewScreen extends StatefulWidget {
  // ← FIX: bỏ dấu _
  final WordEntry word;
  const SingleWordReviewScreen({super.key, required this.word});

  @override
  State<SingleWordReviewScreen> createState() => _SingleWordReviewScreenState();
}

class _SingleWordReviewScreenState extends State<SingleWordReviewScreen> {
  bool _showAnswer = false;
  Skill _currentSkill = Skill.understand;
  final _tts = TtsService();
  bool _done = false;
  final Map<Skill, int?> _ratings = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (_, provider, __) {
        final word = provider.findByWord(widget.word.word) ?? widget.word;

        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D1520),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: word.vocabType.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    word.vocabType.label(context), // ← works với import
                    style: TextStyle(
                      color: word.vocabType.color, // ← works với import
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  word.word,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.volume_up,
                    color: Colors.white54, size: 20),
                onPressed: () => _tts.speak(word.word),
              ),
            ],
          ),
          body: _done
              ? _buildDone(context, word)
              : _buildReview(context, word, provider),
        );
      },
    );
  }

  Widget _buildReview(
      BuildContext context, WordEntry word, VocabularyProvider provider) {
    final skillColor = _skillColor(_currentSkill);

    return Column(
      children: [
        // ── Skill tabs ──
        Container(
          color: const Color(0xFF0D1520),
          child: Row(
            children: Skill.values.map((s) {
              final rated = _ratings[s];
              final isSelected = s == _currentSkill;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentSkill = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              isSelected ? _skillColor(s) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_skillIcon(s),
                            size: 14,
                            color:
                                isSelected ? _skillColor(s) : Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _skillName(s),
                          style: TextStyle(
                            color:
                                isSelected ? _skillColor(s) : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                        if (rated != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            rated >= 4 ? Icons.check_circle : Icons.cancel,
                            size: 10,
                            color: rated >= 4 ? Colors.green : Colors.red,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Content ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStimulus(word, _currentSkill, skillColor),
                const SizedBox(height: 30),
                if (!_showAnswer)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showAnswer = true),
                    icon: const Icon(Icons.visibility),
                    label: const TrTrText('Hiện đáp án'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                      backgroundColor: skillColor.withValues(alpha: 0.15),
                      foregroundColor: skillColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else ...[
                  _buildAnswer(word),
                  const SizedBox(height: 20),
                  SkillTriangle(word: word, size: 100),
                ],
              ],
            ),
          ),
        ),

        // ── SM-2 buttons ──
        if (_showAnswer) _buildSM2Bar(word, provider, _currentSkill),
      ],
    );
  }

  Widget _buildStimulus(WordEntry w, Skill s, Color color) {
    switch (s) {
      case Skill.understand:
        return Text(
          w.word,
          style: TextStyle(
            color: color,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        );
      case Skill.listen:
        return Column(
          children: [
            GestureDetector(
              onTap: () => _tts.speak(w.word),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volume_up, size: 40, color: color),
              ),
            ),
            const SizedBox(height: 12),
            TrText('Tap để nghe phát âm', style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        );
      case Skill.read:
        return Column(
          children: [
            Text(
              w.word,
              style: TextStyle(
                color: color,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            TrText('Bạn có thể phát âm từ này không?', style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        );
    }
  }

  Widget _buildAnswer(WordEntry w) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          if (w.phonetic != null)
            Text(
              w.phonetic!,
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 8),
          Text(
            w.meaning,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (w.example != null) ...[
            const SizedBox(height: 12),
            Text(
              w.example!,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSM2Bar(
      WordEntry word, VocabularyProvider provider, Skill skill) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Content',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _sm2Btn(
                  'Again',
                  Colors.red, // ← FIX: lowerCamelCase
                  () => _rate(provider, word, skill, 1)),
              const SizedBox(width: 6),
              _sm2Btn('Hard\n${_calcNext(word, skill, 3)}d', Colors.orange,
                  () => _rate(provider, word, skill, 3)),
              const SizedBox(width: 6),
              _sm2Btn('Good\n${_calcNext(word, skill, 4)}d', Colors.green,
                  () => _rate(provider, word, skill, 4)),
              const SizedBox(width: 6),
              _sm2Btn('Easy\n${_calcNext(word, skill, 5)}d', Colors.blue,
                  () => _rate(provider, word, skill, 5)),
            ],
          ),
        ],
      ),
    );
  }

  // ← FIX: đổi _SM2Btn → _sm2Btn (lowerCamelCase method)
  Widget _sm2Btn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

  void _rate(VocabularyProvider p, WordEntry word, Skill skill, int quality) {
    p.reviewWordSkill(word.id, skill, quality);
    HapticFeedback.lightImpact();

    setState(() {
      _ratings[skill] = quality;
      if (_ratings.length == Skill.values.length) {
        _done = true;
        return;
      }
      // Chuyển sang skill tiếp theo chưa rate
      final nextSkill = Skill.values.firstWhere(
        (s) => !_ratings.containsKey(s),
        orElse: () => skill,
      );
      _currentSkill = nextSkill;
      _showAnswer = false;
    });
  }

  int _calcNext(WordEntry word, Skill skill, int quality) {
    final data = word.getSkillData(skill);
    return SM2Algorithm.calculate(
      quality: quality,
      currentEF: data.easeFactor,
      currentInterval: data.interval,
      currentReps: data.repetitions,
    ).interval;
  }

  Widget _buildDone(BuildContext context, WordEntry word) {
    final allGood = _ratings.values.every((q) => q != null && q >= 4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              allGood ? '🎉' : '💪',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              allGood ? 'Content' : 'Continue',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            // Skill results
            ...Skill.values.map((s) {
              final q = _ratings[s];
              if (q == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_skillIcon(s), color: _skillColor(s), size: 16),
                    const SizedBox(width: 8),
                    Text(_skillName(s),
                        style: TextStyle(color: _skillColor(s))),
                    const SizedBox(width: 8),
                    Text(
                      _ratingLabel(q),
                      style: TextStyle(
                        color: q >= 4 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                minimumSize: const Size(160, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Xong',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int q) => switch (q) {
        1 => 'Again',
        3 => 'Hard',
        4 => 'Good',
        5 => 'Easy',
        _ => '$q',
      };

  Color _skillColor(Skill s) => switch (s) {
        Skill.understand => const Color(0xFF42A5F5),
        Skill.listen => const Color(0xFF66BB6A),
        Skill.read => const Color(0xFFEF5350),
      };

  IconData _skillIcon(Skill s) => switch (s) {
        Skill.understand => Icons.lightbulb_outline,
        Skill.listen => Icons.hearing,
        Skill.read => Icons.auto_stories,
      };

  String _skillName(Skill s) => switch (s) {
        Skill.understand => 'Understand',
        Skill.listen => 'Nghe',
        Skill.read => 'Read',
      };
}