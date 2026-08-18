import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import '../models/word_entry.dart';
import '../models/sm2_algorithm.dart';
import '../providers/vocabulary_provider.dart';
import 'skill_triangle.dart';
import 'skill_sliders.dart';

/// ═══════════════════════════════════════════════════════════════
///  WORD DETAIL SHEET
///  
///  Bottom sheet chi tiết từ vựng
///  - Xem thông tin từ
///  - Điều chỉnh % trực tiếp
///  - Đánh giá nhanh / SM-2
/// ═══════════════════════════════════════════════════════════════
class WordDetailSheet extends StatefulWidget {
  final WordEntry word;

  const WordDetailSheet({super.key, required this.word});

  @override
  State<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<WordDetailSheet> {
  late double _u, _l, _r;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _u = widget.word.understand;
    _l = widget.word.listen;
    _r = widget.word.read;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<VocabularyProvider>();
    final word = prov.allWords.firstWhere(
      (w) => w.id == widget.word.id,
      orElse: () => widget.word,
    );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Zone badge
            _buildZoneBadge(word),
            const SizedBox(height: 16),

            // Word + meaning
            Text(
              word.word,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: word.visualColor,
              ),
            ),
            if (word.phonetic != null)
              Text(
                word.phonetic!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            const SizedBox(height: 4),
            Text(word.meaning, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),

            // Triangle + Sliders
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkillTriangle(word: word, size: 120),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _skillBar('Hiểu', word.understand, const Color(0xFF42A5F5)),
                      _skillBar('Nghe', word.listen, const Color(0xFF66BB6A)),
                      _skillBar('Đọc', word.read, const Color(0xFFEF5350)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Edit mode toggle
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _editing = !_editing),
                  icon: Icon(_editing ? Icons.check : Icons.edit, size: 18),
                  label: Text(_editing ? 'Xong' : 'Chỉnh sửa %'),
                ),
              ],
            ),

            // Sliders (edit mode)
            if (_editing) ...[
              const Divider(),
              const SizedBox(height: 8),
              SkillSliders(
                understand: _u,
                listen: _l,
                read: _r,
                onChanged: (u, l, r) {
                  setState(() {
                    _u = u;
                    _l = l;
                    _r = r;
                  });
                  prov.updateWordAllScores(word.id, u, l, r);
                },
              ),
            ],

            const SizedBox(height: 16),

            // SM-2 Stats
            _buildSM2Stats(word),
            const SizedBox(height: 16),

            // Tip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      word.zone.tip,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick assess buttons
            _buildQuickAssessButtons(context, word, prov),
            const SizedBox(height: 12),

            // SM-2 Review buttons
            if (word.isDue) ...[
              const Divider(),
              const SizedBox(height: 12),
              _buildSM2Buttons(context, word, prov),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildZoneBadge(WordEntry word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: word.zone.color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: word.zone.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(word.zone.icon, size: 16, color: word.zone.color),
          const SizedBox(width: 6),
          Text(
            word.zone.label,
            style: TextStyle(
              color: word.zone.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: color.withAlpha(25),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSM2Stats(WordEntry word) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _stat('Reviews', '${word.totalReviews}', Icons.repeat),
        _stat(
          'Accuracy',
          '${(word.accuracy * 100).toInt()}%',
          Icons.check_circle_outline,
        ),
        _stat(
          'Next',
          word.nextReview != null
              ? (word.daysUntilDue <= 0 
                  ? 'Now' 
                  : '${word.daysUntilDue}d')
              : 'New',
          Icons.schedule,
          highlight: word.isDue,
        ),
        _stat(
          'Interval',
          '${word.interval}d',
          Icons.calendar_today,
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon, {bool highlight = false}) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: highlight ? Colors.orange : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: highlight ? Colors.orange : null,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQuickAssessButtons(
    BuildContext context,
    WordEntry word,
    VocabularyProvider prov,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _quickAssess(context, Skill.understand, word, prov),
            icon: const Icon(Icons.lightbulb_outline, size: 16),
            label: const Text('Hiểu', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _quickAssess(context, Skill.listen, word, prov),
            icon: const Icon(Icons.hearing, size: 16),
            label: const Text('Nghe', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _quickAssess(context, Skill.read, word, prov),
            icon: const Icon(Icons.auto_stories, size: 16),
            label: const Text('Đọc', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSM2Buttons(
    BuildContext context,
    WordEntry word,
    VocabularyProvider prov,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⏰ Đánh giá SM-2 (Spaced Repetition)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _sm2Btn('Again\n1d', Colors.red, () {
              prov.reviewWord(word.id, 1);
              Navigator.pop(context);
            }),
            const SizedBox(width: 8),
            _sm2Btn('Hard\n${_calcInterval(word, 3)}d', Colors.orange, () {
              prov.reviewWord(word.id, 3);
              Navigator.pop(context);
            }),
            const SizedBox(width: 8),
            _sm2Btn('Good\n${_calcInterval(word, 4)}d', Colors.green, () {
              prov.reviewWord(word.id, 4);
              Navigator.pop(context);
            }),
            const SizedBox(width: 8),
            _sm2Btn('Easy\n${_calcInterval(word, 5)}d', Colors.blue, () {
              prov.reviewWord(word.id, 5);
              Navigator.pop(context);
            }),
          ],
        ),
      ],
    );
  }

  Widget _sm2Btn(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(25),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  int _calcInterval(WordEntry word, int quality) {
    final result = SM2Algorithm.calculate(
      quality: quality,
      currentEF: word.easeFactor,
      currentInterval: word.interval,
      currentReps: word.repetitions,
    );
    return result.interval;
  }

  void _quickAssess(
    BuildContext ctx,
    Skill skill,
    WordEntry word,
    VocabularyProvider prov,
  ) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text('${word.word} - ${_skillName(skill)}'),
        content: Text(_skillQuestion(skill)),
        actions: [
          TextButton(
            onPressed: () {
              prov.quickAnswerWord(word.id, skill, false);
              Navigator.pop(context);
            },
            child: const Text('❌ Chưa', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.quickAnswerWord(word.id, skill, true);
              Navigator.pop(context);
            },
            child: const Text('✅ Biết rồi'),
          ),
        ],
      ),
    );
  }

  String _skillName(Skill s) {
    switch (s) {
      case Skill.understand: return 'Hiểu';
      case Skill.listen: return 'Nghe';
      case Skill.read: return 'Đọc';
    }
  }

  String _skillQuestion(Skill s) {
    switch (s) {
      case Skill.understand: return 'Bạn hiểu nghĩa từ này không?';
      case Skill.listen: return 'Bạn nghe được từ này không?';
      case Skill.read: return 'Bạn đọc được từ này không?';
    }
  }
}
