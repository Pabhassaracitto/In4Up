// Knowledge Graph: a paged, collision-free view of vocabulary relationships.
import 'dart:math' as math;

import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/vocabulary_type.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import 'knowledge_graph_layout.dart';

class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  static const _pageSize = 60;
  late final _tts = TtsService();
  final _transformCtrl = TransformationController();
  final _searchCtrl = TextEditingController();
  late VocabularyProvider _provider;

  WordEntry? _selectedWord;
  VocabularyType? _filterType;
  KnowledgeGraphArrangement _arrangement = KnowledgeGraphArrangement.connected;
  String _query = '';
  int _page = 0;
  String? _fitSignature;
  Size? _canvasSize;
  Size? _viewportSize;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, provider, _) {
        _provider = provider;
        final query = _query.trim().toLowerCase();
        final matching = provider.allWords.where((word) {
          return (_filterType == null || word.vocabType == _filterType) &&
              (query.isEmpty ||
                  word.word.toLowerCase().contains(query) ||
                  word.meaning.toLowerCase().contains(query));
        }).toList();
        final ordered = KnowledgeGraphLayout.orderByConnections(matching);
        final pageCount = math.max(1, (ordered.length / _pageSize).ceil());
        if (_page >= pageCount) _page = pageCount - 1;
        final start = _page * _pageSize;
        final visible = ordered.skip(start).take(_pageSize).toList();
        final layout = KnowledgeGraphLayout.build(visible, arrangement: _arrangement);

        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildSearchAndFilters(),
                _buildPageBar(start, visible.length, ordered.length, pageCount),
                _buildLegend(),
                Expanded(child: _buildGraphView(visible, layout, provider.total)),
              ],
            ),
          ),
          floatingActionButton: visible.isEmpty ? null : _buildFABs(),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      color: const Color(0xFF0D1520),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.hub_outlined, color: Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Knowledge Graph',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          PopupMenuButton<KnowledgeGraphArrangement>(
            key: const Key('graph_arrangement'),
            color: const Color(0xFF1A2235),
            tooltip: context.uiText('Bố cục'),
            icon: const Icon(Icons.account_tree_outlined, color: Colors.white70),
            initialValue: _arrangement,
            onSelected: (value) => setState(() => _arrangement = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: KnowledgeGraphArrangement.connected,
                child: Text(context.uiText('Theo liên kết')),
              ),
              PopupMenuItem(
                value: KnowledgeGraphArrangement.force,
                child: Text(context.uiText('Bố cục lực')),
              ),
              PopupMenuItem(
                value: KnowledgeGraphArrangement.layered,
                child: Text(context.uiText('Theo tầng')),
              ),
              PopupMenuItem(
                value: KnowledgeGraphArrangement.grid,
                child: Text(context.uiText('Lưới')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: const Color(0xFF0A0F1A),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        children: [
          TextField(
            key: const Key('graph_search'),
            controller: _searchCtrl,
            onChanged: (value) => setState(() {
              _query = value;
              _page = 0;
            }),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: context.uiText('Tìm từ hoặc nghĩa'),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.uiText('Xóa tìm kiếm'),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _query = '';
                          _page = 0;
                        });
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: context.uiText('Tất cả'),
                  color: const Color(0xFFB0BEC5),
                  isSelected: _filterType == null,
                  onTap: () => setState(() {
                    _filterType = null;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 6),
                ...VocabularyType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterChip(
                        label: type.label(context),
                        color: type.color,
                        isSelected: _filterType == type,
                        onTap: () => setState(() {
                          _filterType = _filterType == type ? null : type;
                          _page = 0;
                        }),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBar(int start, int count, int total, int pageCount) {
    final first = count == 0 ? 0 : start + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$first–${start + count} / $total ${context.uiText('nút')}',
              key: const Key('graph_page_count'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          if (pageCount > 1) ...[
            IconButton(
              key: const Key('graph_previous_page'),
              tooltip: context.uiText('Trang trước'),
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
            ),
            Text('${_page + 1} / $pageCount', style: const TextStyle(color: Colors.white70)),
            IconButton(
              key: const Key('graph_next_page'),
              tooltip: context.uiText('Trang sau'),
              onPressed: _page + 1 < pageCount ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          ...VocabularyType.values.map((type) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: type.color),
                    const SizedBox(width: 4),
                    Text(type.label(context), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              )),
          Text(context.uiText('Liên kết hiện trong trang'),
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildGraphView(List<WordEntry> words, KnowledgeGraphLayout layout, int total) {
    if (words.isEmpty) {
      return Center(
        child: Text(total == 0
            ? context.uiText('Chưa có từ vựng nào')
            : context.uiText('Không tìm thấy từ phù hợp'),
            style: const TextStyle(color: Colors.white70)),
      );
    }
    final byId = {for (final word in words) word.id: word};
    return LayoutBuilder(builder: (context, constraints) {
      final viewport = constraints.biggest;
      _canvasSize = layout.size;
      _viewportSize = viewport;
      // An actual data/link/viewport change triggers fit; opening a detail sheet
      // or rebuilding the provider must not reset the user's pan and zoom.
      final signature = [
        _arrangement.name,
        _page,
        viewport.width,
        viewport.height,
        for (final word in words) '${word.id}:${knowledgeGraphNodeSize(word)}',
        for (final link in layout.links) '${link.from}>${link.to}',
      ].join('|');
      if (_fitSignature != signature) {
        _fitSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _fitSignature == signature) _fitGraph();
        });
      }
      return InteractiveViewer(
        key: const Key('knowledge_graph_viewer'),
        constrained: false,
        boundaryMargin: const EdgeInsets.all(1000),
        minScale: 0.01,
        maxScale: 3,
        transformationController: _transformCtrl,
        child: SizedBox(
          width: layout.size.width,
          height: layout.size.height,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GraphEdgePainter(layout, byId))),
              for (final word in words)
                Positioned(
                  left: layout.centers[word.id]!.dx - knowledgeGraphNodeSize(word) / 2,
                  top: layout.centers[word.id]!.dy - knowledgeGraphNodeSize(word) / 2,
                  child: _GraphNode(
                    key: ValueKey('knowledge_graph_node_${word.id}'),
                    word: word,
                    isSelected: _selectedWord?.id == word.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedWord = word);
                      _showWordDetail(word);
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  void _fitGraph() {
    final canvas = _canvasSize;
    final viewport = _viewportSize;
    if (canvas == null || viewport == null || canvas.isEmpty || viewport.isEmpty) return;
    final scale = math.min(1.0, math.min(viewport.width / canvas.width, viewport.height / canvas.height))
        .clamp(0.01, 3.0);
    final dx = (viewport.width - canvas.width * scale) / 2;
    final dy = (viewport.height - canvas.height * scale) / 2;
    _transformCtrl.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  void _zoom(double factor) {
    final viewport = _viewportSize;
    if (viewport == null || viewport.isEmpty) return;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final sceneCenter = _transformCtrl.toScene(center);
    final scale = (_transformCtrl.value.getMaxScaleOnAxis() * factor).clamp(0.01, 3.0);
    _transformCtrl.value = Matrix4.identity()
      ..translate(center.dx - sceneCenter.dx * scale, center.dy - sceneCenter.dy * scale)
      ..scale(scale);
  }

  Widget _buildFABs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'graph_fit',
          tooltip: context.uiText('Vừa màn hình'),
          backgroundColor: const Color(0xFF1A2235),
          onPressed: _fitGraph,
          child: const Icon(Icons.fit_screen, color: Colors.white70),
        ),
        FloatingActionButton.small(
          heroTag: 'graph_zoom_in',
          tooltip: context.uiText('Phóng to'),
          backgroundColor: const Color(0xFF1A2235),
          onPressed: () => _zoom(1.4),
          child: const Icon(Icons.add, color: Colors.white70),
        ),
        FloatingActionButton.small(
          heroTag: 'graph_zoom_out',
          tooltip: context.uiText('Thu nhỏ'),
          backgroundColor: const Color(0xFF1A2235),
          onPressed: () => _zoom(1 / 1.4),
          child: const Icon(Icons.remove, color: Colors.white70),
        ),
      ],
    );
  }

  void _showWordDetail(WordEntry word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WordDetailSheet(
        word: word,
        provider: _provider,
        tts: _tts,
        onNavigateTo: (targetWord) {
          Navigator.pop(context);
          setState(() => _selectedWord = targetWord);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showWordDetail(targetWord);
          });
        },
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  const _GraphEdgePainter(this.layout, this.words);
  final KnowledgeGraphLayout layout;
  final Map<String, WordEntry> words;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in layout.links) {
      final from = layout.centers[link.from]!;
      final to = layout.centers[link.to]!;
      final delta = to - from;
      if (delta.distance == 0) continue;
      final direction = delta / delta.distance;
      final start = from + direction * (knowledgeGraphNodeSize(words[link.from]!) / 2);
      final end = to - direction * (knowledgeGraphNodeSize(words[link.to]!) / 2 + 2);
      final paint = Paint()
        ..color = words[link.from]!.vocabType.color.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, paint);
      final perpendicular = Offset(-direction.dy, direction.dx);
      canvas.drawLine(end, end - direction * 8 + perpendicular * 4, paint);
      canvas.drawLine(end, end - direction * 8 - perpendicular * 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.words != words;
}

// ══════════════════════════════════════════════════════════
// GRAPH NODE WIDGET
// ══════════════════════════════════════════════════════════

class _GraphNode extends StatelessWidget {
  final WordEntry word;
  final bool isSelected;
  final VoidCallback onTap;

  const _GraphNode({
    super.key,
    required this.word,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = word.vocabType.color;
    final size = knowledgeGraphNodeSize(word);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.35)
              : color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.5),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: material.Text(
              word.word,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: _fontSize(word),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  double _fontSize(WordEntry w) {
    return switch (w.vocabType) {
      VocabularyType.paragraph => 8.0,
      VocabularyType.sentence => 9.0,
      VocabularyType.phrase => 10.0,
      VocabularyType.word => 11.0,
    };
  }
}

// ══════════════════════════════════════════════════════════
// WORD DETAIL SHEET (trong Graph)
// ══════════════════════════════════════════════════════════

class _WordDetailSheet extends StatelessWidget {
  final WordEntry word;
  final VocabularyProvider provider;
  final TtsService tts;
  final void Function(WordEntry) onNavigateTo;

  const _WordDetailSheet({
    required this.word,
    required this.provider,
    required this.tts,
    required this.onNavigateTo,
  });

  @override
  Widget build(BuildContext context) {
    final color = word.vocabType.color;
    final parents = provider.getParents(word.id);
    final children = provider.getChildren(word.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  word.vocabType.label(context),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  word.word,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // TTS button
              GestureDetector(
                onTap: () => tts.speak(word.word),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.volume_up, color: color, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Meaning
          if (word.meaning.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                word.meaning,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Mastery bar
          Row(
            children: [
              Text(
                context.uiText('Thuần thục: ${(word.mastery * 100).toInt()}%'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: word.mastery,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(
                        word.zone.color.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ],
          ),

          // Contexts
          if (word.contexts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(Icons.menu_book, 'Ngữ cảnh'),
            const SizedBox(height: 8),
            ...word.contexts.take(2).map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.surroundingText.isNotEmpty)
                        Text(
                          context.uiText('"${c.surroundingText}"'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (c.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${c.sourceIcon} ${c.composeDisplaySource(
                            c.hasGeneratedPositionLabel &&
                                    c.pageOrPosition != null
                                ? context.uiText(c.pageOrPosition!)
                                : c.pageOrPosition,
                          )}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                )),
          ],

          // Related nodes — navigate trong graph
          if (parents.isNotEmpty || children.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(Icons.account_tree_outlined, 'Liên kết trong Graph'),
            const SizedBox(height: 8),
            if (parents.isNotEmpty) ...[
              Text('Thuộc về:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: parents
                    .map((p) => _RelatedNodeChip(
                          word: p,
                          prefix: '▲',
                          onTap: () => onNavigateTo(p),
                        ))
                    .toList(),
              ),
            ],
            if (children.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Chứa:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: children
                    .map((c) => _RelatedNodeChip(
                          word: c,
                          prefix: '▼',
                          onTap: () => onNavigateTo(c),
                        ))
                    .toList(),
              ),
            ],
          ],

          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.school,
                  label: 'Ôn tập',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to ReviewTab
                    Navigator.pushNamed(context, '/review');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.volume_up,
                  label: 'Nghe',
                  color: color,
                  onTap: () => tts.speak(word.word),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey[500],
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
}

class _RelatedNodeChip extends StatelessWidget {
  final WordEntry word;
  final String prefix;
  final VoidCallback onTap;

  const _RelatedNodeChip({
    required this.word,
    required this.prefix,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: word.vocabType.bgColor,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: word.vocabType.color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$prefix ',
                style: TextStyle(
                  color: word.vocabType.color,
                  fontSize: 10,
                ),
              ),
              Text(
                word.word,
                style: TextStyle(
                  color: word.vocabType.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios,
                  size: 10, color: word.vocabType.color),
            ],
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}
