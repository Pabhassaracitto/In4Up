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

import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import '../../features/tts/tts_service.dart';
import '../../models/word_entry.dart';
import '../../services/ipa_resolver.dart';
import 'vocabulary_map_clusters.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/skill_triangle.dart';
import '../../widgets/word_detail_sheet.dart';

class TriangleTab extends StatefulWidget {
  /// Optional pronunciation seam for tests or an alternative speech service.
  const TriangleTab({super.key, this.pronounce});

  final Future<void> Function(String text, String language)? pronounce;

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
          tabs: [
            Tab(
              icon: const Icon(Icons.change_history_rounded),
              text: context.uiText('Bản đồ tam giác'),
            ),
            Tab(
              icon: const Icon(Icons.quiz_outlined),
              text: context.uiText('Đánh giá nhanh'),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              const _TriangleMapView(),
              _AssessmentView(pronounce: widget.pronounce),
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
    return Consumer<VocabularyProvider>(builder: (context, prov, _) {
      if (prov.total == 0) {
        return const Center(child: Text('Chưa có từ vựng', style: TextStyle(color: Colors.grey)));
      }
      final selected = prov.allWords.where((word) => word.id == _selectedWordId).toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              context.uiText('Gần đỉnh: kỹ năng tương đối mạnh · Tâm: các kỹ năng cân bằng'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final size = constraints.biggest;
              if (size.isEmpty) return const SizedBox.shrink();
              final shortest = size.width < size.height ? size.width : size.height;
              final radius = (shortest * 0.38).clamp(0.0, 240.0);
              final center = Offset(size.width / 2, size.height / 2);
              final vertices = [
                Offset(center.dx, center.dy - radius),
                Offset(center.dx - radius * 0.866, center.dy + radius * 0.5),
                Offset(center.dx + radius * 0.866, center.dy + radius * 0.5),
              ];
              final clusters = clusterVocabularyMapPoints([
                for (final word in prov.allWords)
                  VocabularyMapPoint(word, _wordPosition(word, vertices, center)),
              ]);
              return Container(
                color: const Color(0xFF0D1526),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(
                      painter: _TriangleFramePainter(vertices: vertices, center: center),
                    )),
                    ..._buildLabels(vertices),
                    for (final cluster in clusters)
                      Positioned(
                        left: cluster.center.dx - cluster.diameter / 2,
                        top: cluster.center.dy - cluster.diameter / 2,
                        child: VocabularyClusterMarker(
                          key: ValueKey('triangle_cluster_${cluster.words.first.id}'),
                          cluster: cluster,
                          selectedWordId: _selectedWordId,
                          onTap: () => _selectCluster(cluster),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(context.uiText('Chạm cụm để chọn từng từ'),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          if (selected.isNotEmpty) _buildSelectedWordPanel(selected.first),
        ],
      );
    });
  }

  Future<void> _selectCluster(VocabularyMapCluster cluster) async {
    final word = cluster.words.length == 1
        ? cluster.words.first
        : await showVocabularyClusterSheet(context, cluster.words);
    if (mounted && word != null) setState(() => _selectedWordId = word.id);
  }

  Offset _wordPosition(WordEntry word, List<Offset> vertices, Offset center) {
    final sum = word.understand + word.listen + word.read;
    if (sum <= 0) return center;
    final weighted = (vertices[0] * word.understand +
        vertices[1] * word.listen + vertices[2] * word.read) / sum;
    final scale = 0.3 + word.mastery * 0.7;
    return center + (weighted - center) * scale;
  }

  List<Widget> _buildLabels(List<Offset> vertices) {
    final labels = [
      ('🔵 HIỂU', const Color(0xFF42A5F5), const Offset(0, -29)),
      ('🟢 NGHE', const Color(0xFF66BB6A), const Offset(-20, 15)),
      ('🔴 ĐỌC', const Color(0xFFEF5350), const Offset(20, 15)),
    ];
    return List.generate(3, (i) => Positioned(
      left: vertices[i].dx + labels[i].$3.dx - 30,
      top: vertices[i].dy + labels[i].$3.dy - 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: labels[i].$2, borderRadius: BorderRadius.circular(12)),
        child: Text(context.uiText(labels[i].$1),
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    ));
  }

  Widget _buildSelectedWordPanel(WordEntry word) {
    return Container(
      key: const Key('triangle_selected_panel'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: word.zone.color, radius: 18,
                  child: Icon(word.zone.icon, color: Colors.black87, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  material.Text(word.word, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  material.Text(word.meaning, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
              IconButton(
                tooltip: context.uiText('Đóng'),
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => setState(() => _selectedWordId = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _skillChip(context.uiText('Hiểu'), word.understand, const Color(0xFF42A5F5)),
              _skillChip(context.uiText('Nghe'), word.listen, const Color(0xFF66BB6A)),
              _skillChip(context.uiText('Đọc'), word.read, const Color(0xFFEF5350)),
              TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => WordDetailSheet(word: word),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Chi tiết'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skillChip(String label, double value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text('$label: ${(value * 100).round()}%',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

// ══════════════════════════════════════════
//  Assessment View (Đánh giá nhanh)
// ══════════════════════════════════════════
class _AssessmentView extends StatefulWidget {
  const _AssessmentView({this.pronounce});

  final Future<void> Function(String text, String language)? pronounce;

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
  bool _playing = false;
  bool _ipaPending = false;
  String? _answerIpa;
  String? _answerIpaSource;
  int _ipaRequest = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() {
        final skill = Skill.values[_tabCtrl.index];
        if (!_tabCtrl.indexIsChanging && skill != _currentSkill) {
          setState(() {
            _currentSkill = skill;
            _reset();
          });
        }
      });
  }

  void _reset() {
    _ipaRequest++;
    _currentIndex = 0;
    _showAnswer = false;
    _isComplete = false;
    _correct = 0;
    _total = 0;
    _queue = [];
    _ipaPending = false;
    _answerIpa = null;
    _answerIpaSource = null;
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
        if (_queue.isEmpty && !_isComplete) {
          _queue = List<WordEntry>.from(prov.allWords)
            ..sort((a, b) => a.scoreOf(_currentSkill).compareTo(b.scoreOf(_currentSkill)));
          _queue = _queue.take(20).toList();
        } else if (_queue.isNotEmpty && !_isComplete) {
          // Provider entries are mutable; keep the current item stable while
          // removing words deleted elsewhere and refreshing edited values.
          final currentId = _queue[_currentIndex].id;
          final byId = {for (final word in prov.allWords) word.id: word};
          _queue = [for (final word in _queue) if (byId.containsKey(word.id)) byId[word.id]!];
          final newIndex = _queue.indexWhere((word) => word.id == currentId);
          if (newIndex >= 0) {
            _currentIndex = newIndex;
          } else {
            _currentIndex = _queue.isEmpty ? 0 : _currentIndex.clamp(0, _queue.length - 1).toInt();
            _showAnswer = false;
            _ipaRequest++;
          }
        }

        return Column(
          children: [
            TabBar(
              controller: _tabCtrl,
              indicatorColor: _skillColor,
              labelColor: _skillColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(
                  icon: const Icon(Icons.lightbulb_outline),
                  text: context.uiText('HIỂU'),
                ),
                Tab(
                  icon: const Icon(Icons.hearing),
                  text: context.uiText('NGHE'),
                ),
                Tab(
                  icon: const Icon(Icons.auto_stories),
                  text: context.uiText('ĐỌC'),
                ),
              ],
            ),
            if (!_isComplete && _queue.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(context.uiText('${_currentIndex + 1} / ${_queue.length}'),
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
                      ? const Center(child: Text('Chưa có từ vựng để đánh giá'))
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
        return '🔵 Bạn có HIỂU NGHĨA từ này không?';
      case Skill.listen:
        return '🟢 Bạn có NGHE HIỂU từ này không?';
      case Skill.read:
        return '🔴 Bạn có ĐỌC ĐƯỢC từ này không?';
    }
  }

  Widget _buildCard(VocabularyProvider prov) {
    final word = _queue[_currentIndex];
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _skillColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                child: Text(_questionText,
                    style: TextStyle(color: _skillColor, fontSize: 14), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              _buildStimulus(word),
              const SizedBox(height: 20),
              if (_showAnswer) ...[
                const Divider(),
                const SizedBox(height: 8),
                if (_currentSkill == Skill.listen)
                  material.Text(word.word, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                if (_currentSkill == Skill.read) ...[
                  Text(_answerIpaSource == 'g2p' ? context.uiText('IPA (ước tính)') : 'IPA',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (_ipaPending)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if ((_answerIpa ?? '').isNotEmpty)
                    material.Text(_answerIpa!, key: const Key('assessment_ipa'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF80DEEA), fontSize: 24, fontWeight: FontWeight.w600))
                  else
                    Text(context.uiText('Chưa có IPA cho từ này'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  TextButton.icon(
                    key: const Key('assessment_read_speak'),
                    onPressed: _playing ? null : () => _playWord(word),
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: Text(context.uiText('Nghe phát âm')),
                  ),
                ] else if ((word.phonetic ?? '').trim().isNotEmpty)
                  material.Text(word.phonetic!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                if (word.meaning.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  material.Text(word.meaning, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.white70)),
                ],
                const SizedBox(height: 10),
                SkillTriangle(word: word, size: 70),
                const SizedBox(height: 18),
              ],
              if (!_showAnswer)
                ElevatedButton.icon(
                  key: const Key('assessment_reveal'),
                  onPressed: () => _revealAnswer(word),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Xem đáp án'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _skillColor.withAlpha(25),
                    foregroundColor: _skillColor,
                    minimumSize: const Size(200, 48),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(
                      onPressed: () => _answer(prov, false),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Chưa biết'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A2029),
                        foregroundColor: const Color(0xFFFFA3A3),
                        minimumSize: const Size(0, 52),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton.icon(
                      onPressed: () => _answer(prov, true),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Đã biết'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF183C30),
                        foregroundColor: const Color(0xFFA5D6A7),
                        minimumSize: const Size(0, 52),
                      ),
                    )),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStimulus(WordEntry word) {
    switch (_currentSkill) {
      case Skill.understand:
        return material.Text(word.word,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _skillColor));
      case Skill.listen:
        return Column(
          children: [
            IconButton.filledTonal(
              key: const Key('assessment_listen_speak'),
              tooltip: context.uiText('Nghe phát âm'),
              onPressed: _playing ? null : () => _playWord(word),
              iconSize: 52,
              padding: const EdgeInsets.all(16),
              icon: Icon(Icons.volume_up, color: _skillColor),
            ),
            const SizedBox(height: 8),
            Text(context.uiText('Nhấn để nghe'),
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        );
      case Skill.read:
        return Column(
          children: [
            material.Text(word.word, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _skillColor, letterSpacing: 2)),
            const Text('Bạn có đọc/phát âm được không?', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        );
    }
  }

  Future<void> _playWord(WordEntry word) async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      final pronounce = widget.pronounce;
      if (pronounce != null) {
        await pronounce(word.word, word.language);
      } else {
        final tts = TtsService();
        await tts.speak(word.word, language: word.language);
        if (tts.error != null) throw StateError('TTS unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.uiText('Không phát được âm thanh. Hãy kiểm tra cài đặt giọng đọc.')),
        ));
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _revealAnswer(WordEntry word) {
    final storedIpa = (word.phonetic ?? '').trim();
    final request = ++_ipaRequest;
    setState(() {
      _showAnswer = true;
      _answerIpa = storedIpa.isEmpty ? null : storedIpa;
      _answerIpaSource = word.phoneticSource;
      _ipaPending = _currentSkill == Skill.read && storedIpa.isEmpty;
    });
    if (_ipaPending) unawaited(_loadIpa(word, request));
  }

  Future<void> _loadIpa(WordEntry word, int request) async {
    IpaResolution? result;
    try {
      // English G2P is not an appropriate guess for other languages. In those
      // cases only use an installed dictionary, never fabricate /the word/.
      final english = RegExp(r'^en(?:[-_]|$)', caseSensitive: false).hasMatch(word.language.trim());
      result = await IpaResolver.resolve(word.word, mode: english ? IpaSaveMode.auto : IpaSaveMode.dict);
    } catch (_) {
      // IPA is optional; keep the answer usable without a dictionary/model.
    }
    if (!mounted || request != _ipaRequest) return;
    // A user or background resolver may have filled the entry while lookup
    // was running; the saved value always wins over an estimated result.
    final current = context.read<VocabularyProvider>().findById(word.id);
    final saved = (current?.phonetic ?? '').trim();
    setState(() {
      _ipaPending = false;
      _answerIpa = saved.isNotEmpty ? saved : result?.ipa;
      _answerIpaSource = saved.isNotEmpty ? current?.phoneticSource : result?.source;
    });
  }

  void _answer(VocabularyProvider prov, bool correct) {
    final id = _queue[_currentIndex].id;
    _ipaRequest++;
    prov.quickAnswerWord(id, _currentSkill, correct);
    setState(() {
      _total++;
      if (correct) _correct++;
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        _showAnswer = false;
        _answerIpa = null;
        _ipaPending = false;
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
          Text(context.uiText('$pct%'),
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _skillColor)),
          Text(context.uiText('$_correct / $_total đúng'),
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(_reset);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
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
  bool shouldRepaint(covariant _TriangleFramePainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.vertices.length != vertices.length ||
      List.generate(vertices.length, (i) => oldDelegate.vertices[i] != vertices[i])
          .any((changed) => changed);
}
