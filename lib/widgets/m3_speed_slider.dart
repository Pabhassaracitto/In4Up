import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class M3SpeedSlider extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onChanged;

  const M3SpeedSlider({
    super.key,
    required this.currentSpeed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white, 
          fontWeight: FontWeight.bold
        ),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        showValueIndicator: ShowValueIndicator.always,
      ),
      child: Slider(
        value: currentSpeed.clamp(0.05, 10.0),
        min: 0.05,
        max: 10.0,
        divisions: 100,
        label: '${currentSpeed.toStringAsFixed(2)}x',
        onChanged: (val) {
          double finalVal = val;
          // Logic snap về 1.0x khi gần kề (sai số 0.1)
          if ((val - 1.0).abs() < 0.1) finalVal = 1.0;
          onChanged(finalVal);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}