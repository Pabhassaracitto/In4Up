import 'package:flutter/material.dart';
import 'package:in4up_stt/models/stt_config.dart';
import 'package:in4up_stt/models/stt_model_info.dart';

import '../../../providers/player_provider.dart';

/// If this audio already has a saved LRC, ask before running Whisper again.
Future<void> confirmAndGenerateLrc(
  BuildContext context,
  PlayerProvider provider,
  WhisperModelLevel? level,
  SttSegmentGrouping grouping,
) async {
  final hit = await provider.peekCachedLrc();
  var force = false;
  if (hit != null && context.mounted) {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đã có lời thoại'),
        content: Text(
          hit.lineCount > 0
              ? 'File này đã có ${hit.lineCount} dòng lời đã lưu. Dùng lại hay tạo mới?'
              : 'File này đã có lời thoại đã lưu. Dùng lại hay tạo mới?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reuse'),
            child: const Text('Dùng bản đã lưu'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'redo'),
            child: const Text('Tạo lại'),
          ),
        ],
      ),
    );
    if (choice == 'reuse') {
      await provider.applyCachedLrc(hit: hit);
      return;
    }
    if (choice != 'redo') return;
    force = true;
  }
  if (!context.mounted) return;
  await provider.generateLrcForCurrentAudio(
    level: level,
    grouping: grouping,
    forceRegenerate: force,
  );
}
