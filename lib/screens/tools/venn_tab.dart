// Three-skill Venn diagram with touch-friendly grouped drag and bulk actions.
import 'dart:math' as math;

import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/storage_service.dart';
import 'vocabulary_six_skill_view.dart';
import '../../widgets/word_detail_sheet.dart';

class VennTab extends StatefulWidget {
  /// Optional seams for testing the persisted view preference.
  final bool Function()? readSixSkillMode;
  final Future<void> Function(bool)? writeSixSkillMode;

  const VennTab({super.key, this.readSixSkillMode, this.writeSixSkillMode});

  @override
  State<VennTab> createState() => _VennTabState();
}

/// The draggable keeps this same object for the lifetime of the gesture. The
/// second finger can add ids to it after the drag avatar has been created.
class _VennDragBatch {
  _VennDragBatch(this.anchorId, this.sourceZone) : ids = {anchorId};

  final String anchorId;
  final MasteryZone sourceZone;
  final Set<String> ids;
}

class _VennTabState extends State<VennTab> {
  MasteryZone? _hoveredZone;
  MasteryZone? _selectedZone;
  MasteryZone? _selectionSource;
  final Set<String> _selectedIds = {};
  final ValueNotifier<int> _dragCount = ValueNotifier(0);
  final GlobalKey _diagramKey = GlobalKey();
  _VennDragBatch? _activeDrag;
  bool _selectionMode = false;
  bool _sixSkillMode = false;
  Future<void> _modeWrite = Future<void>.value();
  int _modeRevision = 0;

  @override
  void initState() {
    super.initState();
    try {
      final storage = StorageService();
      _sixSkillMode = widget.readSixSkillMode?.call() ??
          (storage.isInitialized && storage.getHexagonV1Flag());
    } catch (error) {
      debugPrint('Could not read six-skill view preference: $error');
    }
  }

  void _setSixSkillMode(bool enabled) {
    if (_sixSkillMode == enabled || _activeDrag != null) return;
    setState(() => _sixSkillMode = enabled);
    final revision = ++_modeRevision;
    final writer = widget.writeSixSkillMode;
    // Serialize writes so rapid toggles cannot persist an older choice last.
    _modeWrite = _modeWrite.then((_) async {
      if (writer != null) {
        await writer(enabled);
      } else if (StorageService().isInitialized) {
        await StorageService().saveHexagonV1Flag(enabled);
      } else {
        throw StateError('Settings storage is unavailable');
      }
    }).catchError((Object error, StackTrace stack) {
      debugPrint('Could not save six-skill view preference: $error');
      // A later choice is queued and may still save successfully. Do not
      // claim that the current choice is unsaved for a superseded failure.
      if (mounted && revision == _modeRevision) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(context.uiText('Không lưu được chế độ xem; lựa chọn chỉ áp dụng trong phiên này.')),
        ));
      }
    });
  }

  @override
  void dispose() {
    _dragCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(builder: (context, prov, _) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('venn_toggle_six_skills'),
              onPressed: _activeDrag == null
                  ? () => _setSixSkillMode(!_sixSkillMode)
                  : null,
              icon: Icon(_sixSkillMode ? Icons.bubble_chart_outlined : Icons.hexagon_outlined, size: 18),
              label: Text(context.uiText(_sixSkillMode ? 'Venn ba kỹ năng' : 'Sáu kỹ năng')),
            ),
          ),
          Expanded(
            child: _sixSkillMode
                ? VocabularySixSkillView(words: prov.allWords)
                : _buildVennBody(context, prov),
          ),
        ],
      );
    });
  }

  Widget _buildVennBody(BuildContext context, VocabularyProvider prov) {
    if (prov.total == 0) return _buildEmptyState(context);
    final zones = prov.wordsByZone;
    final counts = {for (final zone in MasteryZone.values) zone: zones[zone]?.length ?? 0};
    return Column(
      children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              context.uiText('Giữ và kéo một từ; chạm thêm từ cùng vùng bằng ngón khác.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Text(
            '🔵 ${context.uiText('HIỂU')}  ·  🟢 ${context.uiText('NGHE')}  ·  🔴 ${context.uiText('ĐỌC')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Expanded(flex: 5, child: _buildVennDiagram(prov, counts)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(context.uiText('Chuyển vùng sẽ thay đổi điểm của cả ba kỹ năng.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFCC80), fontSize: 10)),
          ),
          Expanded(flex: 5, child: _buildWordList(prov, zones)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_rounded, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            const Text('Chưa có từ vựng', style: TextStyle(color: Colors.grey, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Lưu từ từ tab Read để phân tích', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );

  Widget _buildVennDiagram(VocabularyProvider prov, Map<MasteryZone, int> counts) {
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(box.maxWidth, box.maxHeight);
      if (size <= 0) return const SizedBox.shrink();
      final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
      final targetSize = (size * 0.18).clamp(32.0, 48.0);
      Offset at(double dx, double dy) => center + Offset(size * dx, size * dy);
      return Container(
        key: _diagramKey,
        color: const Color(0xFF0D1526),
        child: Stack(
          children: [
            Positioned.fill(
              child: DragTarget<_VennDragBatch>(
                key: const Key('venn_diagram_background'),
                onWillAcceptWithDetails: (details) => identical(_activeDrag, details.data),
                onMove: (details) {
                  final zone = _zoneAt(details.offset, center, size);
                  final target = zone == details.data.sourceZone ? null : zone;
                  if (_hoveredZone != target) setState(() => _hoveredZone = target);
                },
                onLeave: (_) {
                  if (_hoveredZone != null) setState(() => _hoveredZone = null);
                },
                onAcceptWithDetails: (details) {
                  final zone = _zoneAt(details.offset, center, size);
                  if (zone == null || zone == details.data.sourceZone) {
                    _finishDrag(details.data.anchorId);
                  } else {
                    _moveBatch(prov, details.data, zone);
                  }
                },
                builder: (context, candidates, rejected) =>
                    CustomPaint(painter: _VennPainter(center, size)),
              ),
            ),
            _positionedTarget(at(0, -0.35), targetSize, MasteryZone.understandOnly, 'H', counts, prov),
            _positionedTarget(at(-0.30, 0.20), targetSize, MasteryZone.listenOnly, 'N', counts, prov),
            _positionedTarget(at(0.30, 0.20), targetSize, MasteryZone.readOnly, 'Đ', counts, prov),
            _positionedTarget(at(-0.15, -0.12), targetSize, MasteryZone.understandListen, 'H+N', counts, prov),
            _positionedTarget(at(0.15, -0.12), targetSize, MasteryZone.understandRead, 'H+Đ', counts, prov),
            _positionedTarget(at(0, 0.30), targetSize, MasteryZone.listenRead, 'N+Đ', counts, prov),
            _positionedTarget(at(0, 0.07), targetSize, MasteryZone.mastered, '★', counts, prov),
            Positioned(
              right: 8,
              top: 8,
              child: _zoneTarget(MasteryZone.blindSpot, '◉', counts, prov, targetSize),
            ),
          ],
        ),
      );
    });
  }

  /// Resolve a drop anywhere within the painted circles, not just on a badge.
  /// The separate blind-spot badge remains the target for the outside region.
  MasteryZone? _zoneAt(Offset global, Offset center, double size) {
    final box = _diagramKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final position = box.globalToLocal(global);
    final radius = size * 0.28;
    final understand = (position - (center + Offset(0, -size * 0.20))).distance <= radius;
    final listen = (position - (center + Offset(-size * 0.18, size * 0.12))).distance <= radius;
    final read = (position - (center + Offset(size * 0.18, size * 0.12))).distance <= radius;
    final mask = (understand ? 1 : 0) | (listen ? 2 : 0) | (read ? 4 : 0);
    return switch (mask) {
      1 => MasteryZone.understandOnly,
      2 => MasteryZone.listenOnly,
      4 => MasteryZone.readOnly,
      3 => MasteryZone.understandListen,
      5 => MasteryZone.understandRead,
      6 => MasteryZone.listenRead,
      7 => MasteryZone.mastered,
      _ => null,
    };
  }

  Widget _positionedTarget(Offset center, double size, MasteryZone zone,
      String symbol, Map<MasteryZone, int> counts, VocabularyProvider prov) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: _zoneTarget(zone, symbol, counts, prov, size),
    );
  }

  Widget _zoneTarget(MasteryZone zone, String symbol, Map<MasteryZone, int> counts,
      VocabularyProvider prov, double size) {
    final hovered = _hoveredZone == zone;
    final selected = _selectedZone == zone;
    final color = zone == MasteryZone.blindSpot ? const Color(0xFF6B778D) : zone.color;
    final foreground = color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    return DragTarget<_VennDragBatch>(
      key: ValueKey('venn_target_${zone.name}'),
      onWillAcceptWithDetails: (details) {
        final accepted = identical(_activeDrag, details.data) && details.data.sourceZone != zone;
        if (accepted) setState(() => _hoveredZone = zone);
        return accepted;
      },
      onLeave: (_) {
        if (_hoveredZone == zone) setState(() => _hoveredZone = null);
      },
      onAcceptWithDetails: (details) => _moveBatch(prov, details.data, zone),
      builder: (context, candidates, rejected) => Tooltip(
        message: context.uiText(zone.label),
        child: Semantics(
          button: true,
          label: '${context.uiText(zone.label)}: ${counts[zone] ?? 0}',
          selected: selected,
          child: GestureDetector(
            onTap: _activeDrag == null
                ? () => setState(() {
                      _selectedZone = selected ? null : zone;
                      _selectionMode = false;
                      _selectionSource = null;
                      _selectedIds.clear();
                    })
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withValues(alpha: hovered ? 1 : 0.88),
                shape: BoxShape.circle,
                border: Border.all(color: selected || hovered ? Colors.white : Colors.white24,
                    width: selected || hovered ? 2.5 : 1),
                boxShadow: hovered ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 12)] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_zoneSymbol(zone, symbol),
                      maxLines: 1,
                      style: TextStyle(color: foreground, fontSize: size < 40 ? 8 : 10, fontWeight: FontWeight.bold)),
                  Text('${counts[zone] ?? 0}',
                      style: TextStyle(color: foreground, fontSize: size < 40 ? 11 : 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _zoneSymbol(MasteryZone zone, String fallback) {
    if (zone == MasteryZone.mastered || zone == MasteryZone.blindSpot) return fallback;
    // Short symbols stay legible in the small intersections. The tooltip and
    // semantic label expose the full localized skill/zone names.
    final vietnamese = Localizations.localeOf(context).languageCode == 'vi';
    final understand = vietnamese ? 'H' : 'U';
    final listen = vietnamese ? 'N' : 'L';
    final read = vietnamese ? 'Đ' : 'R';
    return switch (zone) {
      MasteryZone.understandOnly => understand,
      MasteryZone.listenOnly => listen,
      MasteryZone.readOnly => read,
      MasteryZone.understandListen => '$understand+$listen',
      MasteryZone.understandRead => '$understand+$read',
      MasteryZone.listenRead => '$listen+$read',
      _ => fallback,
    };
  }

  Widget _buildWordList(VocabularyProvider prov, Map<MasteryZone, List<WordEntry>> zones) {
    final displayWords = _selectedZone == null ? prov.allWords : (zones[_selectedZone] ?? []);
    final source = _selectionSource ?? _selectedZone;
    final validSelected = _selectedIds.where((id) => prov.findById(id)?.zone == _selectionSource).toSet();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedZone == null
                      ? '${context.uiText('Tất cả')} (${displayWords.length})'
                      : '${context.uiText(_selectedZone!.label)} (${displayWords.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (_selectedZone != null)
                IconButton(
                  tooltip: context.uiText('Tất cả'),
                  onPressed: _activeDrag != null ? null : () => setState(() {
                    _selectedZone = null;
                    _selectedIds.clear();
                    _selectionSource = null;
                    _selectionMode = false;
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              TextButton.icon(
                key: const Key('venn_selection_mode'),
                onPressed: _activeDrag != null ? null : () => setState(() {
                  _selectionMode = !_selectionMode;
                  _selectedIds.clear();
                  _selectionSource = null;
                }),
                icon: Icon(_selectionMode ? Icons.close : Icons.checklist, size: 18),
                label: Text(context.uiText(_selectionMode ? 'Hủy chọn' : 'Chọn nhiều')),
              ),
            ],
          ),
        ),
        if (_selectionMode || _activeDrag != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(context.uiText('Đã chọn ${validSelected.length} từ'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
                TextButton(
                  key: const Key('venn_select_all'),
                  onPressed: source == null || _activeDrag != null ? null : () => setState(() {
                    _selectionSource = source;
                    _selectedIds
                      ..clear()
                      ..addAll((zones[source] ?? []).map((word) => word.id));
                  }),
                  child: Text(context.uiText('Chọn cả vùng')),
                ),
                PopupMenuButton<MasteryZone>(
                  key: const Key('venn_move_selected'),
                  enabled: validSelected.isNotEmpty && _activeDrag == null,
                  color: const Color(0xFF1A2235),
                  tooltip: context.uiText('Chuyển đến vùng'),
                  onSelected: (zone) => _moveSelected(prov, validSelected, zone),
                  itemBuilder: (context) => [
                    for (final zone in MasteryZone.values)
                      if (zone != _selectionSource)
                        PopupMenuItem(
                          value: zone,
                          child: Row(children: [
                            Icon(zone.icon, color: zone.color, size: 18),
                            const SizedBox(width: 8),
                            Text(context.uiText(zone.label), style: const TextStyle(color: Colors.white)),
                          ]),
                        ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.drive_file_move_outline,
                          size: 18, color: validSelected.isEmpty ? Colors.white30 : const Color(0xFFB3ABFF)),
                      const SizedBox(width: 4),
                      Text(context.uiText('Chuyển'),
                          style: TextStyle(color: validSelected.isEmpty ? Colors.white30 : const Color(0xFFB3ABFF))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: displayWords.isEmpty
              ? const Center(child: Text('Không có từ trong vùng này', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final word in displayWords) _draggableWord(word)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _draggableWord(WordEntry word) {
    final batch = _VennDragBatch(word.id, word.zone);
    return LongPressDraggable<_VennDragBatch>(
      key: ValueKey('venn_drag_${word.id}'),
      data: batch,
      // DragTargetDetails.offset is now the finger position (rather than the
      // feedback widget's top-left), so circle hit-testing matches the drop.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      maxSimultaneousDrags: _activeDrag == null ? 1 : 0,
      onDragStarted: () => _startDrag(batch),
      onDraggableCanceled: (_, __) => _finishDrag(word.id),
      onDragCompleted: () => _finishDrag(word.id),
      feedback: ValueListenableBuilder<int>(
        valueListenable: _dragCount,
        builder: (context, count, _) => Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF34405E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: word.zone.color, width: 2),
                ),
                child: material.Text(word.word, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Positioned(
                right: -8,
                top: -8,
                child: CircleAvatar(
                  key: const Key('venn_drag_badge'),
                  radius: 12,
                  backgroundColor: const Color(0xFF6C63FF),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: _wordChip(word)),
      child: GestureDetector(
        key: ValueKey('venn_word_${word.id}'),
        onTap: () => _onWordTap(word),
        child: _wordChip(word),
      ),
    );
  }

  Widget _wordChip(WordEntry word) {
    final selected = _selectedIds.contains(word.id);
    final color = word.zone == MasteryZone.blindSpot ? const Color(0xFFB0BEC5) : word.zone.color;
    return Semantics(
      button: true,
      selected: selected,
      label: word.word,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.25) : const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : color.withValues(alpha: 0.5), width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check_circle : word.zone.icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(child: material.Text(word.word, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }

  void _onWordTap(WordEntry word) {
    final drag = _activeDrag;
    if (drag != null) {
      if (word.zone != drag.sourceZone) {
        _showSameZoneHint();
        return;
      }
      if (drag.ids.add(word.id)) {
        _dragCount.value = drag.ids.length;
        setState(() => _selectedIds.add(word.id));
      }
      return;
    }
    if (_selectionMode) {
      if (_selectionSource != null && _selectionSource != word.zone) {
        _showSameZoneHint();
        return;
      }
      setState(() {
        _selectionSource ??= word.zone;
        if (!_selectedIds.add(word.id)) _selectedIds.remove(word.id);
        if (_selectedIds.isEmpty) _selectionSource = null;
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(word: word),
    );
  }

  void _showSameZoneHint() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.uiText('Chỉ gom các từ cùng vùng ban đầu.')),
      duration: const Duration(seconds: 2),
    ));
  }

  void _startDrag(_VennDragBatch batch) {
    if (_activeDrag != null) return;
    if (_selectionMode && _selectionSource == batch.sourceZone && _selectedIds.contains(batch.anchorId)) {
      batch.ids.addAll(_selectedIds);
    }
    _dragCount.value = batch.ids.length;
    setState(() {
      _activeDrag = batch;
      _selectionSource = batch.sourceZone;
      _selectedIds
        ..clear()
        ..addAll(batch.ids);
    });
  }

  void _finishDrag(String anchorId) {
    if (!mounted || _activeDrag?.anchorId != anchorId) return;
    setState(() {
      _activeDrag = null;
      _hoveredZone = null;
      if (_selectedIds.length > 1) {
        // A cancelled drop keeps the group selected, ready for another try.
        _selectionMode = true;
      } else if (!_selectionMode) {
        _selectedIds.clear();
        _selectionSource = null;
      }
    });
  }

  void _moveBatch(VocabularyProvider prov, _VennDragBatch batch, MasteryZone destination) {
    if (!identical(_activeDrag, batch)) return;
    final ids = batch.ids.where((id) => prov.findById(id)?.zone == batch.sourceZone).toSet();
    setState(() {
      _activeDrag = null;
      _hoveredZone = null;
      _selectionMode = false;
      _selectionSource = null;
      _selectedIds.clear();
    });
    prov.setWordsZone(ids, destination);
  }

  void _moveSelected(VocabularyProvider prov, Set<String> ids, MasteryZone destination) {
    setState(() {
      _selectionMode = false;
      _selectionSource = null;
      _selectedIds.clear();
    });
    prov.setWordsZone(ids, destination);
  }
}

class _VennPainter extends CustomPainter {
  const _VennPainter(this.center, this.size);
  final Offset center;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final radius = size * 0.28;
    final circles = [
      (center + Offset(0, -size * 0.20), const Color(0xFF42A5F5)),
      (center + Offset(-size * 0.18, size * 0.12), const Color(0xFF66BB6A)),
      (center + Offset(size * 0.18, size * 0.12), const Color(0xFFEF5350)),
    ];
    for (final circle in circles) {
      canvas.drawCircle(circle.$1, radius, Paint()..color = circle.$2.withValues(alpha: 0.14));
      canvas.drawCircle(circle.$1, radius, Paint()
        ..color = circle.$2.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _VennPainter old) => old.center != center || old.size != size;
}
