import 'package:in4up/core/language/localized_material.dart';

/// ═══════════════════════════════════════════════════════════════
///  SKILL SLIDERS
///
///  Widget để điều chỉnh % Hiểu/Nghe/Đọc trực tiếp
/// ═══════════════════════════════════════════════════════════════
class SkillSliders extends StatefulWidget {
  final double understand;
  final double listen;
  final double read;
  final Function(double u, double l, double r) onChanged;
  final bool compact;

  const SkillSliders({
    super.key,
    required this.understand,
    required this.listen,
    required this.read,
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<SkillSliders> createState() => _SkillSlidersState();
}

class _SkillSlidersState extends State<SkillSliders> {
  late double _u, _l, _r;

  @override
  void initState() {
    super.initState();
    _u = widget.understand;
    _l = widget.listen;
    _r = widget.read;
  }

  @override
  void didUpdateWidget(SkillSliders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.understand != widget.understand ||
        oldWidget.listen != widget.listen ||
        oldWidget.read != widget.read) {
      _u = widget.understand;
      _l = widget.listen;
      _r = widget.read;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildFull() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _slider(
          label: '🔵 HIỂU',
          value: _u,
          color: const Color(0xFF42A5F5),
          onChanged: (v) {
            setState(() => _u = v);
            widget.onChanged(_u, _l, _r);
          },
        ),
        const SizedBox(height: 8),
        _slider(
          label: '🟢 NGHE',
          value: _l,
          color: const Color(0xFF66BB6A),
          onChanged: (v) {
            setState(() => _l = v);
            widget.onChanged(_u, _l, _r);
          },
        ),
        const SizedBox(height: 8),
        _slider(
          label: '🔴 ĐỌC',
          value: _r,
          color: const Color(0xFFEF5350),
          onChanged: (v) {
            setState(() => _r = v);
            widget.onChanged(_u, _l, _r);
          },
        ),
        const SizedBox(height: 16),
        _quickButtons(),
      ],
    );
  }

  Widget _buildCompact() {
    return Row(
      children: [
        _compactSlider(_u, const Color(0xFF42A5F5), (v) {
          setState(() => _u = v);
          widget.onChanged(_u, _l, _r);
        }),
        const SizedBox(width: 8),
        _compactSlider(_l, const Color(0xFF66BB6A), (v) {
          setState(() => _l = v);
          widget.onChanged(_u, _l, _r);
        }),
        const SizedBox(width: 8),
        _compactSlider(_r, const Color(0xFFEF5350), (v) {
          setState(() => _r = v);
          widget.onChanged(_u, _l, _r);
        }),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 45,
          child: Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _compactSlider(
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _quickButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _quickBtn('Chưa biết gì', () {
          setState(() {
            _u = 0.1;
            _l = 0.1;
            _r = 0.1;
          });
          widget.onChanged(_u, _l, _r);
        }, Colors.grey),
        _quickBtn('Chỉ Hiểu', () {
          setState(() {
            _u = 0.8;
            _l = 0.2;
            _r = 0.2;
          });
          widget.onChanged(_u, _l, _r);
        }, const Color(0xFF42A5F5)),
        _quickBtn('Chỉ Nghe', () {
          setState(() {
            _u = 0.2;
            _l = 0.8;
            _r = 0.2;
          });
          widget.onChanged(_u, _l, _r);
        }, const Color(0xFF66BB6A)),
        _quickBtn('Chỉ Đọc', () {
          setState(() {
            _u = 0.2;
            _l = 0.2;
            _r = 0.8;
          });
          widget.onChanged(_u, _l, _r);
        }, const Color(0xFFEF5350)),
        _quickBtn('Thành thạo', () {
          setState(() {
            _u = 0.95;
            _l = 0.95;
            _r = 0.95;
          });
          widget.onChanged(_u, _l, _r);
        }, const Color(0xFFFFD54F)),
      ],
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
