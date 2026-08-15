// lib/screens/understand_mode/sheets/loop_control_sheet.dart

import 'package:flutter/material.dart';
import 'package:in4up/providers/player_provider.dart';

void showLoopControlSheet(BuildContext context, PlayerProvider player) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Điều khiển Loop',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  'A: ${_formatDuration(player.loopStart!)}',
                  style: const TextStyle(color: Colors.white),
                ),
                const Text(' → ', style: TextStyle(color: Colors.grey)),
                Text(
                  'B: ${_formatDuration(player.loopEnd!)}',
                  style: const TextStyle(color: Colors.white),
                ),
                const Spacer(),
                Text(
                  _formatDuration(player.loopEnd! - player.loopStart!),
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    player.clearLoop();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Xóa Loop'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text('Xong'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _formatDuration(Duration d) {
  final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$mins:$secs';
}
