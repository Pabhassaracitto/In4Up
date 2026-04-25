// lib/features/tts/widgets/auto_split_section.dart

import 'package:flutter/material.dart';

import '../../../services/text_splitter_service.dart';

/// Widget tách dòng tự động - nhúng vào Settings
class AutoSplitSection extends StatefulWidget {
  final String currentText;
  final Color primaryColor;
  final void Function(List<String> lines) onApply;

  const AutoSplitSection({
    super.key,
    required this.currentText,
    required this.onApply,
    this.primaryColor = const Color(0xFF6C63FF),
  });

  @override
  State<AutoSplitSection> createState() => _AutoSplitSectionState();
}

class _AutoSplitSectionState extends State<AutoSplitSection> {
  SplitMode _mode = SplitMode.smart;
  int _minWords = 4;
  int _maxWords = 15;
  SplitPreview? _preview;

  @override
  void initState() {
    super.initState();
    _updatePreview();
  }

  void _updatePreview() {
    setState(() {
      _preview = TextSplitterService.preview(
        widget.currentText,
        mode: _mode,
        minWordsBeforeSplit: _minWords,
        maxWordsPerLine: _maxWords,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.auto_fix_high, size: 18, color: widget.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Tách dòng tự động',
              style: TextStyle(
                fontSize: 16,
                color: widget.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mode selector
        Text(
          'Chế độ tách',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              SplitMode.values.where((m) => m != SplitMode.none).map((mode) {
            final isSelected = mode == _mode;
            return GestureDetector(
              onTap: () {
                _mode = mode;
                _updatePreview();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.primaryColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? widget.primaryColor
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isSelected ? widget.primaryColor : Colors.grey[300],
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Sliders
        if (_mode == SplitMode.smart || _mode == SplitMode.clause) ...[
          _SliderRow(
            label: 'Tối thiểu $_minWords từ trước khi tách',
            value: _minWords.toDouble(),
            min: 2,
            max: 10,
            color: widget.primaryColor,
            onChanged: (v) {
              _minWords = v.round();
              _updatePreview();
            },
          ),
        ],
        if (_mode == SplitMode.smart) ...[
          _SliderRow(
            label: 'Tối đa $_maxWords từ/dòng',
            value: _maxWords.toDouble(),
            min: 8,
            max: 30,
            color: widget.primaryColor,
            onChanged: (v) {
              _maxWords = v.round();
              _updatePreview();
            },
          ),
        ],

        // Preview
        if (_preview != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Xem trước',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_preview!.originalLineCount} dòng → ${_preview!.totalLines} dòng '
                      '(~${_preview!.avgWordsPerLine.toStringAsFixed(1)} từ/dòng)',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _preview!.lines.length.clamp(0, 20),
                    itemBuilder: (ctx, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: widget.primaryColor
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _preview!.lines[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_preview!.lines.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '... và ${_preview!.lines.length - 20} dòng nữa',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_preview != null) {
                  widget.onApply(_preview!.lines);
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Áp dụng (${_preview!.totalLines} dòng)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: color,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: color,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
