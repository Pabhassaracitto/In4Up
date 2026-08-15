// lib/screens/tools/triangle_tab.dart
// ═══════════════════════════════════════════════════════════════
//  TRIANGLE TAB - Bản đồ tam giác + Đánh giá nhanh
//  Nguồn: TriangleMapScreen + AssessmentScreen từ mode3
//  Vị trí: Tools → Tab "Đánh giá"
//
//  ✅ Bản đồ tam giác hiển thị vị trí từng từ (3 skill axes)
//  ✅ Tap từ trên tam giác → xem chi tiết
//  ✅ Tab "Đánh giá nhanh" để tự test từng chiều
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/skill_triangle.dart';
import '../../widgets/word_detail_sheet.dart';
import 'package:in4up/core/language/tr_extension.dart';

class TriangleTab extends StatefulWidget {
  const TriangleTab({super.key});

  @override
  State<TriangleTab> createState() => _TriangleTabState();
}

class _TriangleTabState extends State<TriangleTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFFFA726),
          labelColor: const Color(0xFFFFA726),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
                icon: Icon(Icons.change_history_rounded),
                text: context.tr('Bản đồ tam giác')),
            Tab(icon: Icon(Icons.quiz_outlined), text: context.tr('Đánh giá nhanh')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _TriangleMapView(),
              _AssessmentView(),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  Triangle Map View
// ══════════════════════════════════════════
class _TriangleMapView extends StatefulWidget {
  const _TriangleMapView();

  @override
  State<_TriangleMapView> createState() => _TriangleMapViewState();
}

class _TriangleMapViewState extends State<_TriangleMapView> {
  String? _selectedWordId;

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, prov, _) {
        if (prov.total == 0) {
          return const Center(
              child: Text(context.l10n.wordListEmpty, style: TextStyle(color: Colors.grey)));
        }

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;
                      final cx = constraints.maxWidth / 2;
                      final cy = size / 2 + 20;
                      final r = size * 0.38;

                      final vertices = [
                        Offset(cx, cy - r),
                        Offset(cx - r * 0.866, cy + r * 0.5),
                        Offset(cx + r * 0.866, cy + r * 0.5),
                      ];
                      final center = Offset(cx, cy + r * 0.1);

                      return Stack(
                        children: [
                          CustomPaint(
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight),
                            painter: _TriangleFramePainter(
                                vertices: vertices, center: center),
                          ),
                          ..._buildLabels(vertices),
                          ...prov.allWords.map((w) {
                            final pos = _wordPosition(w, vertices, center);
                            return Positioned(
                              left: pos.dx - w.visualSize / 2,
                              top: pos.dy - w.visualSize / 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedWordId = w.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: w.visualSize,
                                  height: w.visualSize,
                                  decoration: BoxDecoration(
                                    color: w.visualColor.withAlpha(
                                        (w.visualOpacity * 200).toInt()),
                                    shape: BoxShape.circle,
                                    border: _selectedWordId == w.id
                                        ? Border.all(
                                            color: Colors.black, width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      w.word.length > 6
                                          ? '${w.word.substring(0, 5)}…'
                                          : w.word,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: w.visualWeight,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),

                  // Legend
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(20), blurRadius: 8),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TrText('📍 Vị trí:', style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                          TrText('• Gần đỉnh = mạnh skill đó', style: TextStyle(fontSize: 9)),
                          TrText('• Tâm = cân bằng', style: TextStyle(fontSize: 9)),
                          SizedBox(height: 4),
                          TrText('📏 Khoảng cách:', style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                          TrText('• Xa tâm = mastery cao', style: TextStyle(fontSize: 9)),
                          TrText('• Gần tâm = mastery thấp', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selected word panel
            if (_selectedWordId != null &&
                prov.allWords.any((w) => w.id == _selectedWordId))
              _buildSelectedWordPanel(context, prov),
          ],
        );
      },
    );
  }

  Offset _wordPosition(WordEntry w, List<Offset> vertices, Offset center) {
    final x = vertices[0].dx * w.understand +
        vertices[1].dx * w.listen +
        vertices[2].dx * w.read;
    final y = vertices[0].dy * w.understand +
        vertices[1].dy * w.listen +
        vertices[2].dy * w.read;
    final sum = w.understand + w.listen + w.read;
    final rawX = sum > 0 ? x / sum : center.dx;
    final rawY = sum > 0 ? y / sum : center.dy;

    final scaleFactor = 0.3 + w.mastery * 0.7;
    return Offset(
      center.dx + (rawX - center.dx) * scaleFactor,
      center.dy + (rawY - center.dy) * scaleFactor,
    );
  }

  List<Widget> _buildLabels(List<Offset> vertices) {
    final labels = [
      ('🔵 HIỂU', const Color(0xFF42A5F5), const Offset(0, -30)),
      ('🟢 NGHE', const Color(0xFF66BB6A), const Offset(-30, 15)),
      ('🔴 ĐỌC', const Color(0xFFEF5350), const Offset(30, 15)),
    ];
    return List.generate(3, (i) {
      return Positioned(
        left: vertices[i].dx + labels[i].$3.dx - 30,
        top: vertices[i].dy + labels[i].$3.dy - 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: labels[i].$2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(labels[i].$1,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ),
      );
    });
  }

  Widget _buildSelectedWordPanel(
      BuildContext context, VocabularyProvider prov) {
    final word = prov.allWords.firstWhere((w) => w.id == _selectedWordId);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: word.zone.color,
                radius: 20,
                child: Icon(word.zone.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.word,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(word.meaning,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedWordId = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _skillChip('Understand', word.understand, const Color(0xFF42A5F5)),
              const SizedBox(width: 8),
              _skillChip('Nghe', word.listen, const Color(0xFF66BB6A)),
              const SizedBox(width: 8),
              _skillChip('Read', word.read, const Color(0xFFEF5350)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showDetail(context, word),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const TrTrText('Chi tiết'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skillChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text('$label: ${(value * 100).toInt()}%',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  void _showDetail(BuildContext ctx, WordEntry w) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(word: w),
    );
  }
}

// ══════════════════════════════════════════
//  Assessment View (Đánh giá nhanh)
// ══════════════════════════════════════════
class _AssessmentView extends StatefulWidget {
  const _AssessmentView();

  @override
  State<_AssessmentView> createState() => _AssessmentViewState();
}

class _AssessmentViewState extends State<_AssessmentView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Skill _currentSkill = Skill.understand;
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isComplete = false;
  int _correct = 0;
  int _total = 0;
  List<WordEntry> _queue = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) {
          setState(() {
            _currentSkill = Skill.values[_tabCtrl.index];
            _reset();
          });
        }
      });
  }

  void _reset() {
    setState(() {
      _currentIndex = 0;
      _showAnswer = false;
      _isComplete = false;
      _correct = 0;
      _total = 0;
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
        if (_queue.isEmpty || _currentIndex == 0 && !_isComplete) {
          _queue = List<WordEntry>.from(prov.allWords)
            ..sort((a, b) =>
                a.scoreOf(_currentSkill).compareTo(b.scoreOf(_currentSkill)));
          _queue = _queue.take(20).toList();
        }

        return Column(
          children: [
            TabBar(
              controller: _tabCtrl,
              indicatorColor: _skillColor,
              labelColor: _skillColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.lightbulb_outline), text: 'HIỂU'),
                Tab(icon: Icon(Icons.hearing), text: 'NGHE'),
                Tab(icon: Icon(Icons.auto_stories), text: 'ĐỌC'),
              ],
            ),
            if (!_isComplete && _queue.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('${_currentIndex + 1} / ${_queue.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _queue.length,
                          valueColor: AlwaysStoppedAnimation(_skillColor),
                          backgroundColor: _skillColor.withAlpha(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isComplete
                  ? _buildResults(prov)
                  : _queue.isEmpty
                      ? const Center(child: TrTrText('Chưa có từ vựng để đánh giá'))
                      : _buildCard(prov),
            ),
          ],
        );
      },
    );
  }

  Color get _skillColor {
    switch (_currentSkill) {
      case Skill.understand:
        return const Color(0xFF42A5F5);
      case Skill.listen:
        return const Color(0xFF66BB6A);
      case Skill.read:
        return const Color(0xFFEF5350);
    }
  }

  String get _questionText {
    switch (_currentSkill) {
      case Skill.understand:
        return 'Content';
      case Skill.listen:
        return 'Content';
      case Skill.read:
        return 'Content';
    }
  }

  Widget _buildCard(VocabularyProvider prov) {
    final word = _queue[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _skillColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_questionText,
                style: TextStyle(color: _skillColor, fontSize: 14),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 32),

          // Stimulus
          _buildStimulus(word),
          const SizedBox(height: 24),

          // Answer reveal
          if (_showAnswer) ...[
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(word.meaning,
                      style: const TextStyle(fontSize: 20, color: Colors.grey)),
                  if (word.phonetic != null)
                    Text(word.phonetic!,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  SkillTriangle(word: word, size: 80),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (!_showAnswer)
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAnswer = true),
              icon: const Icon(Icons.visibility),
              label: const TrTrText('Xem đáp án'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _skillColor.withAlpha(25),
                foregroundColor: _skillColor,
                minimumSize: const Size(200, 48),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _answer(prov, false),
                    icon: const Icon(Icons.close, size: 20),
                    label: const TrTrText('Chưa biết'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _answer(prov, true),
                    icon: const Icon(Icons.check, size: 20),
                    label: const TrTrText('Đã biết'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStimulus(WordEntry word) {
    switch (_currentSkill) {
      case Skill.understand:
        return Text(word.word,
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: _skillColor));
      case Skill.listen:
        return Column(
          children: [
            Icon(Icons.volume_up, size: 64, color: _skillColor),
            const SizedBox(height: 8),
            Text(word.phonetic ?? '/${word.word}/',
                style: TextStyle(fontSize: 20, color: _skillColor)),
            TrText('(Hãy tưởng tượng bạn NGHE từ này)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        );
      case Skill.read:
        return Column(
          children: [
            Text(word.word,
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _skillColor,
                    letterSpacing: 2)),
            TrText('Bạn có đọc/phát âm được không?', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        );
    }
  }

  void _answer(VocabularyProvider prov, bool correct) {
    prov.quickAnswerWord(_queue[_currentIndex].id, _currentSkill, correct);
    setState(() {
      _total++;
      if (correct) _correct++;
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        _showAnswer = false;
      } else {
        _isComplete = true;
      }
    });
  }

  Widget _buildResults(VocabularyProvider prov) {
    final pct = _total > 0 ? (_correct / _total * 100).toInt() : 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
              pct >= 70
                  ? '🎉'
                  : pct >= 40
                      ? '💪'
                      : '📚',
              style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('$pct%',
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _skillColor)),
          Text('Content',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _queue = [];
                _currentIndex = 0;
                _isComplete = false;
                _correct = 0;
                _total = 0;
                _showAnswer = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const TrText(context.l10n.shadowingRetry),
          ),
        ],
      ),
    );
  }
}

// ── Triangle Frame Painter ──
class _TriangleFramePainter extends CustomPainter {
  final List<Offset> vertices;
  final Offset center;

  _TriangleFramePainter({required this.vertices, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF42A5F5).withAlpha(20),
          const Color(0xFF66BB6A).withAlpha(20),
          const Color(0xFFEF5350).withAlpha(20),
        ],
      ).createShader(Rect.fromPoints(vertices[0], vertices[2]));

    final trianglePath = Path()
      ..moveTo(vertices[0].dx, vertices[0].dy)
      ..lineTo(vertices[1].dx, vertices[1].dy)
      ..lineTo(vertices[2].dx, vertices[2].dy)
      ..close();

    canvas.drawPath(trianglePath, fillPaint);

    canvas.drawPath(
        trianglePath,
        Paint()
          ..color = Colors.grey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    final linePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (final v in vertices) {
      canvas.drawLine(center, v, linePaint);
    }

    for (double scale = 0.25; scale <= 0.75; scale += 0.25) {
      final scaled = vertices
          .map((v) => Offset(
                center.dx + (v.dx - center.dx) * scale,
                center.dy + (v.dy - center.dy) * scale,
              ))
          .toList();
      final p = Path()
        ..moveTo(scaled[0].dx, scaled[0].dy)
        ..lineTo(scaled[1].dx, scaled[1].dy)
        ..lineTo(scaled[2].dx, scaled[2].dy)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..color = Colors.grey.shade300
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
    }

    canvas.drawCircle(center, 4, Paint()..color = Colors.grey.shade500);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}