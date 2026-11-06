/// Six-skill word / collection visualization. The caller supplies nullable
/// scores so that an unassessed axis is never rendered as an evaluated zero.
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';

import '../models/learning_state.dart' show SkillDimension;
import 'collection_scatter_painter.dart';
import 'hexagram_painter.dart';
import 'mastery_geometry.dart';

enum MasteryViewMode { word, collection }

class MasteryViewWidget extends StatefulWidget {
  final Map<SkillDimension, double?> mastery;
  final bool useIsPartial;
  final List<ScatterPoint> collectionPoints;

  const MasteryViewWidget({
    super.key,
    required this.mastery,
    this.useIsPartial = false,
    this.collectionPoints = const [],
  });

  @override
  State<MasteryViewWidget> createState() => _MasteryViewWidgetState();
}

class _MasteryViewWidgetState extends State<MasteryViewWidget> {
  MasteryViewMode _mode = MasteryViewMode.word;

  static const _names = <SkillDimension, String>{
    SkillDimension.understanding: 'Hiểu',
    SkillDimension.listening: 'Nghe',
    SkillDimension.reading: 'Đọc',
    SkillDimension.use: 'Dùng',
    SkillDimension.speak: 'Nói',
    SkillDimension.write: 'Viết',
  };

  @override
  Widget build(BuildContext context) {
    final plotted = widget.collectionPoints.where(
      (point) => inputMastery(point.mastery) != null &&
          outputMastery(point.mastery) != null,
    ).length;

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            _modeButton(MasteryViewMode.word, 'Từng từ', 'mastery_word_mode'),
            _modeButton(MasteryViewMode.collection, 'Kho từ', 'mastery_collection_mode'),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: _mode == MasteryViewMode.word
                ? _wordView(context)
                : _collectionView(context, plotted),
          ),
        ),
      ],
    );
  }

  Widget _modeButton(MasteryViewMode mode, String label, String key) {
    final active = _mode == mode;
    return OutlinedButton(
      key: Key(key),
      onPressed: () => setState(() => _mode = mode),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? const Color(0xFF354568) : Colors.transparent,
        foregroundColor: active ? Colors.white : Colors.white70,
        side: BorderSide(color: active ? const Color(0xFF90CAF9) : Colors.white38),
      ),
      child: Text(context.uiText(label)),
    );
  }

  Widget _wordView(BuildContext context) {
    final values = widget.mastery;
    final gaps = <Widget>[];
    for (final pair in kMirrorPairs) {
      final gap = productionGap(
        center: ui.Offset.zero,
        radius: 1,
        mirrorPair: pair,
        masteryMap: values,
      );
      if (gap != null) {
        final first = context.uiText(_names[pair[0]]!);
        final second = context.uiText(_names[pair[1]]!);
        gaps.add(material.Text(
          '$first ↔ $second: ${(gap * 100).round()}%',
          style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12),
        ));
      }
    }

    return Column(
      children: [
        SizedBox(
          key: const Key('mastery_hexagram'),
          height: 235,
          width: double.infinity,
          child: CustomPaint(
            painter: HexagramPainter(
              mastery: values,
              labels: const ['1', '2', '3', '4', '5', '6'],
            ),
          ),
        ),
        for (var i = 0; i < SkillDimension.values.length; i++)
          _skillRow(context, i, SkillDimension.values[i], values),
        if (gaps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.uiText('Chênh lệch'),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 14, runSpacing: 4, children: gaps),
        ],
      ],
    );
  }

  Widget _skillRow(BuildContext context, int i, SkillDimension dim,
      Map<SkillDimension, double?> values) {
    final value = values[dim];
    final partial = dim == SkillDimension.use && widget.useIsPartial && value != null;
    final display = value == null
        ? context.uiText('Chưa đánh giá')
        : '${(value * 100).round()}%${partial ? ' · ${context.uiText('Một phần')}' : ''}';
    final color = i < 3 ? const Color(0xFF64B5F6) : const Color(0xFF81C784);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withValues(alpha: 0.22),
            child: material.Text('${i + 1}',
                style: TextStyle(color: color, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.uiText(_names[dim]!),
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          material.Text(
            display,
            key: Key('mastery_value_${dim.name}'),
            style: TextStyle(color: value == null ? Colors.white60 : color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _collectionView(BuildContext context, int plotted) {
    return Column(
      children: [
        SizedBox(
          key: const Key('mastery_scatter'),
          height: 260,
          width: double.infinity,
          child: CustomPaint(
            painter: CollectionScatterPainter(points: widget.collectionPoints),
          ),
        ),
        Text(context.uiText('Ngang: Hiểu, Nghe, Đọc. Dọc: Dùng, Nói, Viết.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(context.uiText('Chỉ vẽ từ có điểm ở cả hai nhóm; trung bình chỉ tính điểm hiện có.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.uiText('Từ có đủ dữ liệu'),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 6),
            material.Text('$plotted/${widget.collectionPoints.length}',
                key: const Key('mastery_scatter_count'),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
        if (plotted == 0) ...[
          const SizedBox(height: 12),
          Text(context.uiText('Chưa đủ dữ liệu đầu vào và đầu ra để hiển thị từ nào.'),
              key: const Key('mastery_scatter_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ],
    );
  }
}
