import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';

class SpeedControlWidget extends StatefulWidget {
  const SpeedControlWidget({super.key});

  @override
  State<SpeedControlWidget> createState() => _SpeedControlWidgetState();
}

class _SpeedControlWidgetState extends State<SpeedControlWidget> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final currentSpeed = player.state.speed;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white10,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speed, color: Color(0xFF6C63FF)),
                      SizedBox(width: 8),
                      Text(
                        'Playback Speed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Current Speed Display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getSpeedColor(currentSpeed).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${currentSpeed.toStringAsFixed(2)}x',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getSpeedColor(currentSpeed),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Speed Slider
              _buildSpeedSlider(player, currentSpeed),

              const SizedBox(height: 16),

              // Quick Speed Buttons
              _buildQuickSpeedButtons(player, currentSpeed),

              const SizedBox(height: 16),

              // Toggle Advanced
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  icon: Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  label: Text(_showAdvanced ? 'Hide Presets' : 'More Presets'),
                ),
              ),

              // Advanced Speed Presets
              if (_showAdvanced) ...[
                const SizedBox(height: 12),
                _buildSpeedCategory(
                  'Ultra Slow (Learning)',
                  [0.1, 0.15, 0.2, 0.25, 0.3],
                  player,
                  currentSpeed,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSpeedCategory(
                  'Slow Practice',
                  [0.4, 0.5, 0.6, 0.7, 0.75],
                  player,
                  currentSpeed,
                  Colors.cyan,
                ),
                const SizedBox(height: 12),
                _buildSpeedCategory(
                  'Normal',
                  [0.8, 0.9, 1.0, 1.1, 1.25],
                  player,
                  currentSpeed,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildSpeedCategory(
                  'Fast',
                  [1.5, 1.75, 2.0, 2.5, 3.0],
                  player,
                  currentSpeed,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildSpeedCategory(
                  'Ultra Fast',
                  [4.0, 5.0, 6.0, 8.0, 10.0],
                  player,
                  currentSpeed,
                  Colors.red,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedSlider(PlayerProvider player, double currentSpeed) {
    return Column(
      children: [
        // Labels
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.05x', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('1.0x', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('10.0x', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),

        // Slider with logarithmic scale
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            activeTrackColor: _getSpeedColor(currentSpeed),
            thumbColor: _getSpeedColor(currentSpeed),
          ),
          child: Slider(
            value: _speedToSlider(currentSpeed),
            min: 0,
            max: 1,
            onChanged: (value) {
              final speed = _sliderToSpeed(value);
              player.setSpeed(speed);
            },
          ),
        ),
      ],
    );
  }

  // Convert speed to slider position (logarithmic)
  double _speedToSlider(double speed) {
    const minSpeed = 0.05;
    const maxSpeed = 10.0;

    final logMin = math.log(minSpeed);
    final logMax = math.log(maxSpeed);
    final logSpeed = math.log(speed.clamp(minSpeed, maxSpeed));

    return (logSpeed - logMin) / (logMax - logMin);
  }

  // Convert slider position to speed (logarithmic)
  double _sliderToSpeed(double slider) {
    const minSpeed = 0.05;
    const maxSpeed = 10.0;

    final logMin = math.log(minSpeed);
    final logMax = math.log(maxSpeed);
    final logSpeed = logMin + slider * (logMax - logMin);

    return math.exp(logSpeed);
  }

  Widget _buildQuickSpeedButtons(PlayerProvider player, double currentSpeed) {
    const quickSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: quickSpeeds.map((speed) {
        final isSelected = (currentSpeed - speed).abs() < 0.01;

        return _buildSpeedButton(
          speed: speed,
          isSelected: isSelected,
          onTap: () => player.setSpeed(speed),
        );
      }).toList(),
    );
  }

  Widget _buildSpeedButton({
    required double speed,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _getSpeedColor(speed)
              : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: Colors.white24),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedCategory(
      String title,
      List<double> speeds,
      PlayerProvider player,
      double currentSpeed,
      Color color,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: speeds.map((speed) {
            final isSelected = (currentSpeed - speed).abs() < 0.01;

            return GestureDetector(
              onTap: () => player.setSpeed(speed),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : color.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 0.3) return Colors.blue;
    if (speed < 0.7) return Colors.cyan;
    if (speed < 1.3) return Colors.green;
    if (speed < 2.5) return Colors.orange;
    return Colors.red;
  }
}