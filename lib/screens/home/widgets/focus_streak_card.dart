import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/focus_provider.dart';

class FocusStreakCard extends StatelessWidget {
  const FocusStreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department,
                    color: Color(0xFFFF6B35), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NHỊP ĐIỆU HỌC TẬP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${focus.streak} ngày liên tiếp',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!focus.hasAssessedToday) ...[
            const Text(
              'Hôm nay bạn nỗ lực bao nhiêu? (1-10)',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _EffortSlider(
              initialValue: focus.lastEffortScore,
              onSave: (val) => focus.saveEffort(val),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  'Đánh giá nỗ lực hoàn tất',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EffortSlider extends StatefulWidget {
  final double initialValue;
  final Function(double) onSave;

  const _EffortSlider({required this.initialValue, required this.onSave});

  @override
  State<_EffortSlider> createState() => _EffortSliderState();
}

class _EffortSliderState extends State<_EffortSlider> {
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF6C63FF),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            valueIndicatorColor: const Color(0xFF6C63FF),
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: _val,
            min: 1,
            max: 10,
            divisions: 9,
            label: _val.toInt().toString(),
            onChanged: (v) => setState(() => _val = v),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onSave(_val),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Xác nhận nỗ lực'),
          ),
        ),
      ],
    );
  }
}
