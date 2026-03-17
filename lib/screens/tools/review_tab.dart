// lib/screens/tools/review_tab.dart
// ═══════════════════════════════════════════════════════════════
//  REVIEW TAB - Ôn tập SM-2 (Spaced Repetition)
//  Nguồn: ReviewScreen từ mode3
//  Vị trí: Tools → Tab "Ôn tập"
//
//  ✅ Review theo SM-2 cho từng skill riêng biệt
//  ✅ 4 nút đánh giá: Again / Hard / Good / Easy
//  ✅ Hiển thị interval tiếp theo cho mỗi nút
//  ✅ Tabs: Tất cả / Hiểu / Nghe / Đọc
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/word_entry.dart';
import '../../models/sm2_algorithm.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/skill_triangle.dart';
import '../../widgets/word_detail_sheet.dart';

class ReviewTab extends StatefulWidget {
  const ReviewTab({super.key});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Skill? _currentSkill;
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isComplete = false;
  Map<Skill, int> _reviewed = {};
  Map<Skill, int> _correct = {};
  List<_ReviewItem> _queue = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) {
          setState(() {
            _currentSkill =
                _tabCtrl.index == 0 ? null : Skill.values[_tabCtrl.index - 1];
            _loadQueue();
          });
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue.isEmpty && !_isComplete) _loadQueue();
  }

  void _loadQueue() {
    final prov = context.read<VocabularyProvider>();
    final items = <_ReviewItem>[];
    for (final word in prov.allWords) {
      if (_currentSkill != null) {
        if (word.isSkillDue(_currentSkill!)) {
          items.add(_ReviewItem(word: word, skill: _currentSkill!));
        }
      } else {
        for (final skill in word.dueSkills) {
          items.add(_ReviewItem(word: word, skill: skill));
        }
      }
    }
    items.sort((a, b) => a.word
        .skillDaysUntilDue(a.skill)
        .compareTo(b.word.skillDaysUntilDue(b.skill)));
    setState(() {
      _queue = items.take(20).toList();
      _currentIndex = 0;
      _showAnswer = false;
      _isComplete = _queue.isEmpty;
      _reviewed = {for (final s in Skill.values) s: 0};
      _correct = {for (final s in Skill.values) s: 0};
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, prov, _) {
        return Column(
          children: [
            // Tab bar với badge
            TabBar(
              controller: _tabCtrl,
              indicatorColor: const Color(0xFFEF5350),
              labelColor: const Color(0xFFEF5350),
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(child: _tabLabel('Tất cả', _countDue(prov, null))),
                Tab(
                    child:
                        _tabLabel('Hiểu', _countDue(prov, Skill.understand))),
                Tab(child: _tabLabel('Nghe', _countDue(prov, Skill.listen))),
                Tab(child: _tabLabel('Đọc', _countDue(prov, Skill.read))),
              ],
            ),
            Expanded(
              child: _isComplete ? _buildComplete(prov) : _buildReview(prov),
            ),
          ],
        );
      },
    );
  }

  Widget _tabLabel(String name, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: const TextStyle(fontSize: 12)),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ],
      ],
    );
  }

  int _countDue(VocabularyProvider prov, Skill? skill) {
    if (skill == null) {
      return prov.allWords.fold(0, (sum, w) => sum + w.dueSkills.length);
    }
    return prov.allWords.where((w) => w.isSkillDue(skill)).length;
  }

  Widget _buildReview(VocabularyProvider prov) {
    if (_queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              _currentSkill == null
                  ? '🎉 Không có từ nào cần ôn tập!'
                  : 'Không có từ nào cần ôn ${_skillName(_currentSkill!)}!',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Quay lại sau nhé!',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadQueue,
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại'),
            ),
          ],
        ),
      );
    }

    final item = _queue[_currentIndex];
    final word = item.word;
    final skill = item.skill;
    final skillData = word.getSkillData(skill);

    return Column(
      children: [
        // Progress
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _queue.length,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(_skillColor(skill)),
        ),

        // Skill badge
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: _skillColor(skill).withAlpha(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_skillIcon(skill), color: _skillColor(skill), size: 18),
              const SizedBox(width: 8),
              Text(
                'Ôn tập: ${_skillName(skill).toUpperCase()}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _skillColor(skill)),
              ),
              const SizedBox(width: 12),
              Text('${_currentIndex + 1}/${_queue.length}',
                  style: TextStyle(color: _skillColor(skill))),
            ],
          ),
        ),

        // Card content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStimulus(word, skill),
                const SizedBox(height: 30),
                if (!_showAnswer)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showAnswer = true),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Hiện đáp án'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                      backgroundColor: _skillColor(skill).withAlpha(30),
                      foregroundColor: _skillColor(skill),
                    ),
                  )
                else ...[
                  _buildAnswer(word, skill),
                  const SizedBox(height: 20),
                  SkillTriangle(word: word, size: 100),
                  const SizedBox(height: 16),

                  // Skill SM-2 stats
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _skillColor(skill).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem(
                            'Score', '${(skillData.score * 100).toInt()}%'),
                        _statItem('Interval', '${skillData.interval}d'),
                        _statItem(
                            'EF', skillData.easeFactor.toStringAsFixed(2)),
                        _statItem('Reps', '${skillData.repetitions}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // SM-2 answer buttons
        if (_showAnswer)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Đánh giá độ khó:',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _sm2Btn('Again\n1d', Colors.red, () {
                      _reviewWithSM2(prov, item, 1);
                    }),
                    const SizedBox(width: 8),
                    _sm2Btn('Hard\n${_calcInterval(word, skill, 3)}d',
                        Colors.orange, () {
                      _reviewWithSM2(prov, item, 3);
                    }),
                    const SizedBox(width: 8),
                    _sm2Btn(
                        'Good\n${_calcInterval(word, skill, 4)}d', Colors.green,
                        () {
                      _reviewWithSM2(prov, item, 4);
                    }),
                    const SizedBox(width: 8),
                    _sm2Btn(
                        'Easy\n${_calcInterval(word, skill, 5)}d', Colors.blue,
                        () {
                      _reviewWithSM2(prov, item, 5);
                    }),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _reviewWithSM2(VocabularyProvider prov, _ReviewItem item, int quality) {
    prov.reviewWordSkill(item.word.id, item.skill, quality);
    final skill = item.skill;
    setState(() {
      _reviewed[skill] = (_reviewed[skill] ?? 0) + 1;
      if (quality >= 3) _correct[skill] = (_correct[skill] ?? 0) + 1;
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        _showAnswer = false;
      } else {
        _isComplete = true;
      }
    });
  }

  int _calcInterval(WordEntry word, Skill skill, int quality) {
    final data = word.getSkillData(skill);
    final result = SM2Algorithm.calculate(
      quality: quality,
      currentEF: data.easeFactor,
      currentInterval: data.interval,
      currentReps: data.repetitions,
    );
    return result.interval;
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
        child: Text(label,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildStimulus(WordEntry word, Skill skill) {
    final color = _skillColor(skill);
    switch (skill) {
      case Skill.understand:
        return Text(word.word,
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: color));
      case Skill.listen:
        return Column(
          children: [
            Icon(Icons.volume_up, size: 72, color: color),
            const SizedBox(height: 12),
            Text(word.phonetic ?? '/${word.word}/',
                style: TextStyle(fontSize: 22, color: color)),
            const SizedBox(height: 4),
            Text('Tưởng tượng bạn NGHE từ này',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        );
      case Skill.read:
        return Column(
          children: [
            Text(word.word,
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 3)),
            const SizedBox(height: 8),
            Text('Bạn có thể ĐỌC/PHÁT ÂM từ này không?',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        );
    }
  }

  Widget _buildAnswer(WordEntry word, Skill skill) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(word.meaning,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
        if (word.phonetic != null) ...[
          const SizedBox(height: 4),
          Text(word.phonetic!,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
        ],
        if (word.example != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(word.example!,
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
          ),
        ],
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildComplete(VocabularyProvider prov) {
    final totalReviewed = _reviewed.values.fold(0, (a, b) => a + b);
    final totalCorrect = _correct.values.fold(0, (a, b) => a + b);
    final pct =
        totalReviewed > 0 ? (totalCorrect / totalReviewed * 100).toInt() : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                pct >= 80
                    ? '🎉'
                    : pct >= 60
                        ? '💪'
                        : '📚',
                style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text('Phiên ôn tập hoàn thành!',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),

            // Skill breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: Skill.values.map((s) {
                    final rev = _reviewed[s] ?? 0;
                    final cor = _correct[s] ?? 0;
                    if (rev == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(_skillIcon(s), color: _skillColor(s), size: 18),
                          const SizedBox(width: 8),
                          Text(_skillName(s),
                              style: TextStyle(
                                  color: _skillColor(s),
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('$cor/$rev',
                              style: TextStyle(color: _skillColor(s))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadQueue,
              icon: const Icon(Icons.refresh),
              label: const Text('Ôn tiếp'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _skillColor(Skill s) {
    switch (s) {
      case Skill.understand:
        return const Color(0xFF42A5F5);
      case Skill.listen:
        return const Color(0xFF66BB6A);
      case Skill.read:
        return const Color(0xFFEF5350);
    }
  }

  IconData _skillIcon(Skill s) {
    switch (s) {
      case Skill.understand:
        return Icons.lightbulb_outline;
      case Skill.listen:
        return Icons.hearing;
      case Skill.read:
        return Icons.auto_stories;
    }
  }

  String _skillName(Skill s) {
    switch (s) {
      case Skill.understand:
        return 'Hiểu';
      case Skill.listen:
        return 'Nghe';
      case Skill.read:
        return 'Đọc';
    }
  }
}

class _ReviewItem {
  final WordEntry word;
  final Skill skill;
  const _ReviewItem({required this.word, required this.skill});
}
