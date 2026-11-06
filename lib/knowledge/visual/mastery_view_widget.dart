/// ═══════════════════════════════════════════════════════════════
/// MASTERY VIEW WIDGET — Word view + Collection view + toggle (D9)
///
/// D9 (LOCKED): CẢ 2 view + toggle chuyển đổi.
///   * Word view (hexagram): xem 1 từ — 6 đỉnh, production gap.
///   * Collection view (scatter): xem toàn kho — x=Input, y=Output.
///
/// Feature flag hexagon_v1: tắt → dùng skill_triangle cũ (Venn/Triangle).
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../engine/ema_engine.dart' show MasteryVector;
import '../models/learning_state.dart' show SkillDimension;
import 'collection_scatter_painter.dart' show CollectionScatterPainter, ScatterPoint;
import 'hexagram_painter.dart' show HexagramPainter;
import 'mastery_geometry.dart' show productionGap;

enum MasteryViewMode { word, collection }

/// Widget hiển thị mastery với toggle Word ↔ Collection.
class MasteryViewWidget extends StatefulWidget {
  final MasteryVector mastery;
  final List<MasteryVector>? collectionPoints; // cho Collection view

  const MasteryViewWidget({
    super.key,
    required this.mastery,
    this.collectionPoints,
  });

  @override
  State<MasteryViewWidget> createState() => _MasteryViewWidgetState();
}

class _MasteryViewWidgetState extends State<MasteryViewWidget> {
  MasteryViewMode _mode = MasteryViewMode.word;

  @override
  Widget build(BuildContext context) {
    final labels = _localizedLabels(context);
    final masteryMap = _masteryMap(widget.mastery);

    return Column(
      children: [
        // Toggle Word ↔ Collection
        _ToggleRow(
          mode: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
        Expanded(
          child: switch (_mode) {
            MasteryViewMode.word => CustomPaint(
              painter: HexagramPainter(
                mastery: masteryMap,
                showLabels: true,
                showGaps: true,
                labels: labels,
              ),
              child: Container(),
            ),
            MasteryViewMode.collection => CustomPaint(
              painter: CollectionScatterPainter(
                points: _scatterPoints(widget.collectionPoints ?? []),
              ),
              child: Container(),
            ),
          },
        ),
        _GapInfoRow(mastery: widget.mastery),
      ],
    );
  }

  Map<SkillDimension, double?> _masteryMap(MasteryVector mv) {
    return <SkillDimension, double?>{
      SkillDimension.understanding: mv.understanding,
      SkillDimension.listening: mv.listening,
      SkillDimension.reading: mv.reading,
      SkillDimension.use: mv.hasUse ? mv.useDisplay : null,
      SkillDimension.speak: mv.hasSpeak ? mv.speak : null,
      SkillDimension.write: mv.hasWrite ? mv.write : null,
    };
  }

  List<ScatterPoint> _scatterPoints(List<MasteryVector> mvs) {
    return mvs
        .map((mv) => ScatterPoint(
              unitId: '',
              mastery: _masteryMap(mv),
            ))
        .toList();
  }

  List<String> _localizedLabels(BuildContext context) {
    final sources = ['Hiểu', 'Nghe', 'Đọc', 'Dùng', 'Nói', 'Viết'];
    return sources.map((s) {
      final t = context.uiText(s);
      return t.isNotEmpty ? t.runes.first.toString() : '';
    }).toList();
  }
}

/// Toggle row: Word ↔ Collection.
class _ToggleRow extends StatelessWidget {
  final MasteryViewMode mode;
  final ValueChanged<MasteryViewMode> onChanged;

  const _ToggleRow({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ToggleButton(
          label: 'Word view',
          active: mode == MasteryViewMode.word,
          onTap: () => onChanged(MasteryViewMode.word),
        ),
        const SizedBox(width: 8),
        _ToggleButton(
          label: 'Collection view',
          active: mode == MasteryViewMode.collection,
          onTap: () => onChanged(MasteryViewMode.collection),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.blue.shade100 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            context.uiText(label),
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.blue.shade700 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiển thị production gap info.
class _GapInfoRow extends StatelessWidget {
  final MasteryVector mastery;

  const _GapInfoRow({required this.mastery});

  @override
  Widget build(BuildContext context) {
    final gaps = <String>[];
    final pairs = [
      ['Hiểu', 'Dùng'],
      ['Nghe', 'Nói'],
      ['Đọc', 'Viết'],
    ];
    final masteryMap = <SkillDimension, double?>{
      SkillDimension.understanding: mastery.understanding,
      SkillDimension.listening: mastery.listening,
      SkillDimension.reading: mastery.reading,
      SkillDimension.use: mastery.hasUse ? mastery.useDisplay : null,
      SkillDimension.speak: mastery.hasSpeak ? mastery.speak : null,
      SkillDimension.write: mastery.hasWrite ? mastery.write : null,
    };

    for (var i = 0; i < 3; i++) {
      final gap = productionGap(
        center: ui.Offset.zero, radius: 1.0,
        mirrorPair: [
          SkillDimension.values[i],
          SkillDimension.values[i + 3],
        ],
        masteryMap: masteryMap,
      );
      if (gap != null) {
        gaps.add('${pairs[i][0]}↔${pairs[i][1]}: ${(gap * 100).round()}%');
      }
    }

    if (gaps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(context.uiText('Chưa đánh giá'),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: gaps
            .map((g) => Text(g, style: const TextStyle(fontSize: 11)))
            .toList(),
      ),
    );
  }
}
