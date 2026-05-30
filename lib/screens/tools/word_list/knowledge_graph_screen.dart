// ═══════════════════════════════════════════════════════════════
//  KNOWLEDGE GRAPH — Visualize từ vựng theo mạng lưới
//  Package: graphview ^1.2.0 (đã có trong pubspec.yaml)
//  Nodes: VocabularyType color-coded
//  Edges: parent-child relationships
//  Tap node → Expanded detail bottom sheet
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphview/GraphView.dart';
import 'package:provider/provider.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/vocabulary_type.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';

class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  final Graph _graph = Graph()..isTree = false;
  final BuchheimWalkerConfiguration _config = BuchheimWalkerConfiguration();
  final _tts = TtsService();

  // Node ID → WordEntry mapping
  final Map<int, String> _nodeToWordId = {};
  final Map<String, Node> _wordIdToNode = {};

  WordEntry? _selectedWord;
  VocabularyType? _filterType;
  String _layoutMode = 'tree'; // 'tree' | 'force' | 'layered'
  Algorithm? _algorithm;

  late VocabularyProvider _provider;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    _config
      ..siblingSeparation = 60
      ..levelSeparation = 80
      ..subtreeSeparation = 60
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<VocabularyProvider>();
    _buildGraph();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── Build Graph từ VocabularyProvider ──────────────────────

  void _buildGraph() {
    _graph.nodes.clear();
    _graph.edges.clear();
    _nodeToWordId.clear();
    _wordIdToNode.clear();

    final words = _filterType == null
        ? _provider.allWords
        : _provider.allWords.where((w) => w.vocabType == _filterType).toList();

    // Giới hạn 80 nodes để tránh lag
    final limited = words.take(80).toList();

    // Tạo nodes
    for (final word in limited) {
      final node = Node.Id(word.id.hashCode);
      _nodeToWordId[word.id.hashCode] = word.id;
      _wordIdToNode[word.id] = node;
      _graph.addNode(node);
    }

    // Tạo edges từ parent-child relationships
    for (final word in limited) {
      final parentNode = _wordIdToNode[word.id];
      if (parentNode == null) continue;

      for (final childId in word.childIds) {
        final childNode = _wordIdToNode[childId];
        if (childNode != null) {
          _graph.addEdge(
            parentNode,
            childNode,
            paint: Paint()
              ..color = word.vocabType.color.withValues(alpha: 0.4)
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }

    // Không gọi setState ở đây nếu được gọi từ didChangeDependencies
    // vì Flutter sẽ tự động build sau đó.
  }

  // ── Get WordEntry từ Node ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Selector<VocabularyProvider, int>(
      selector: (_, prov) => prov.allWords.length,
      builder: (context, wordCount, child) {
        _provider = context.read<VocabularyProvider>();
        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildFilterBar(),
                _buildLegend(),
                Expanded(child: _buildGraphView()),
              ],
            ),
          ),
          floatingActionButton: _buildFABs(),
        );
      },
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.hub_outlined, color: Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 8),
          const Text(
            'Knowledge Graph',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          // Node count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Color(0xFF6C63FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_graph.nodeCount()} nodes',
              style: const TextStyle(
                color: Color(0xFF9C8FFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Layout toggle
          _LayoutToggle(
            current: _layoutMode,
            onChanged: (mode) {
              _algorithm = null; // Reset algorithm để tạo lại theo mode mới
              setState(() => _layoutMode = mode);
              _buildGraph();
            },
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0A0F1A),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Tất cả',
              color: const Color(0xFF9E9E9E),
              isSelected: _filterType == null,
              onTap: () {
                setState(() => _filterType = null);
                _buildGraph();
              },
            ),
            const SizedBox(width: 6),
            ...VocabularyType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(
                    label: type.label,
                    color: type.color,
                    isSelected: _filterType == type,
                    onTap: () {
                      setState(() =>
                          _filterType = _filterType == type ? null : type);
                      _buildGraph();
                    },
                  ),
                )),
            const SizedBox(width: 8),
            // Refresh
            GestureDetector(
              onTap: () {
                _buildGraph();
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.refresh, size: 16, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF080B1A),
      child: Row(
        children: [
          ...VocabularyType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.label,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              )),
          const Spacer(),
          Text(
            'Tap node để xem chi tiết',
            style: TextStyle(color: Colors.grey[700], fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Graph View ─────────────────────────────────────────────

  Widget _buildGraphView() {
    if (_graph.nodeCount() == 0) {
      return _buildEmptyState();
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.3,
      maxScale: 3.0,
      transformationController: _transformCtrl,
      child: RepaintBoundary(
        child: GraphView(
          graph: _graph,
          algorithm: _getAlgorithm(),
          paint: Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final wordId = _nodeToWordId[node.key?.value];
            if (wordId == null) return const SizedBox.shrink();

            WordEntry? word;
            try {
              word = _provider.allWords.firstWhere((w) => w.id == wordId);
            } catch (_) {
              return const SizedBox.shrink();
            }

            return _GraphNode(
              word: word,
              isSelected: _selectedWord?.id == word.id,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedWord = word);
                _showWordDetail(word!);
              },
            );
          },
        ),
      ),
    );
  }

  Algorithm _getAlgorithm() {
    if (_algorithm != null) return _algorithm!;

    switch (_layoutMode) {
      case 'force':
        _algorithm = FruchtermanReingoldAlgorithm(
          FruchtermanReingoldConfiguration()..iterations = 300,
        );
        break;
      case 'layered':
        _algorithm = SugiyamaAlgorithm(
          SugiyamaConfiguration()
            ..nodeSeparation = 40
            ..levelSeparation = 80,
        );
        break;
      default:
        _algorithm = BuchheimWalkerAlgorithm(
          _config,
          TreeEdgeRenderer(_config),
        );
    }
    return _algorithm!;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            'Chưa có từ vựng nào',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm từ vựng và tạo liên kết để xem graph',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── FABs ───────────────────────────────────────────────────

  Widget _buildFABs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reset zoom
        FloatingActionButton.small(
          heroTag: 'reset_zoom',
          backgroundColor: const Color(0xFF1A2235),
          onPressed: () {
            _transformCtrl.value = Matrix4.identity();
            HapticFeedback.lightImpact();
          },
          child: const Icon(Icons.fit_screen, color: Colors.white70, size: 18),
        ),
        const SizedBox(height: 8),
        // Rebuild
        FloatingActionButton.small(
          heroTag: 'rebuild',
          backgroundColor: const Color(0xFF6C63FF),
          onPressed: () {
            _buildGraph();
            HapticFeedback.mediumImpact();
          },
          child: const Icon(Icons.auto_graph, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  // ── Word Detail Sheet ──────────────────────────────────────

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
          Future.delayed(
            const Duration(milliseconds: 300),
            () => _showWordDetail(targetWord),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// GRAPH NODE WIDGET
// ══════════════════════════════════════════════════════════

class _GraphNode extends StatelessWidget {
  final WordEntry word;
  final bool isSelected;
  final VoidCallback onTap;

  const _GraphNode({
    required this.word,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = word.vocabType.color;
    final size = _nodeSize(word);

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
            child: Text(
              word.word.length > 10
                  ? '${word.word.substring(0, 8)}...'
                  : word.word,
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

  // Node size phụ thuộc vào type + encounter count
  double _nodeSize(WordEntry w) {
    final base = switch (w.vocabType) {
      VocabularyType.paragraph => 105.0,
      VocabularyType.sentence => 90.0,
      VocabularyType.phrase => 75.0,
      VocabularyType.word => 60.0,
    };
    // Từ gặp nhiều lần → node lớn hơn
    return base + (w.encounterCount * 2).clamp(0, 20);
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
                  word.vocabType.label,
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
                'Thuần thục: ${(word.mastery * 100).toInt()}%',
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
                          '"${c.surroundingText}"',
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
                          '${c.sourceIcon} ${c.displaySource}',
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

class _LayoutToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _LayoutToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      icon: const Icon(Icons.account_tree, color: Colors.white54, size: 18),
      onSelected: onChanged,
      itemBuilder: (_) => [
        _item('tree', Icons.account_tree_outlined, 'Cây phân cấp'),
        _item('force', Icons.bubble_chart_outlined, 'Force Layout'),
        _item('layered', Icons.layers_outlined, 'Layered'),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color:
                    current == v ? const Color(0xFF6C63FF) : Colors.grey[400]),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: current == v ? Colors.white : Colors.grey[400],
                fontSize: 13,
                fontWeight: current == v ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (current == v) ...[
              const Spacer(),
              const Icon(Icons.check, color: Color(0xFF6C63FF), size: 14),
            ],
          ],
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
