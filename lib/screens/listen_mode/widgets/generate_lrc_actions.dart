import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:path/path.dart' as p;
import 'package:in4up_stt/models/stt_config.dart';
import 'package:in4up_stt/models/stt_model_info.dart';
import 'package:in4up_stt/stt_service_facade.dart';

import '../../../providers/player_provider.dart';
import '../../../services/source_artifact_store.dart';

/// If this audio already has a saved LRC, ask before running Whisper again.
///
/// [language]: mã ngôn ngữ Whisper — 'auto' (mặc định) = Whisper tự nhận
/// diện (đa ngữ); 'vi', 'en', 'zh', 'ja', 'ko', 'pi'... khi muốn ép.
///
/// Trả về [SttTranscribeOutput?] (null khi dùng bản đã lưu / hủy) — khớp
/// kiểu closure `onGenerate` của _LrcModelSelector.
Future<SttTranscribeOutput?> confirmAndGenerateLrc(
  BuildContext context,
  PlayerProvider provider,
  WhisperModelLevel? level,
  SttSegmentGrouping grouping, {
  String language = 'auto',
  bool preferSherpa = false,
}) async {
  final audioPath = provider.currentSongPath;
  if (audioPath == null) return null;
  final hit = await provider.peekCachedLrc(path: audioPath);
  if (!context.mounted || provider.currentSongPath != audioPath) return null;
  var force = false;
  if (hit != null && context.mounted) {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đã có lời thoại'),
        content: Text(
          hit.lineCount > 0
              ? context.uiText(
                  'File này đã có ${hit.lineCount} dòng lời đã lưu. Dùng lại hay tạo mới?')
              : context.uiText(
                  'File này đã có lời thoại đã lưu. Dùng lại hay tạo mới?'),
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
      return null;
    }
    if (choice != 'redo') return null;
    force = true;
  } else if (hit == null) {
    final store = SourceArtifactStore.instance;
    var candidates = <CachedLrcHit>[];
    try {
      candidates = await store.unverifiedLrcCandidates(audioPath);
    } catch (error) {
      debugPrint('Could not inspect older LRC files: $error');
    }
    if (!context.mounted || provider.currentSongPath != audioPath) return null;
    if (candidates.isNotEmpty) {
      final choice = await showDialog<Object>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.uiText('Dữ liệu cũ chưa xác minh')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctx.uiText(
                    'Dữ liệu cũ cùng tên được giữ nguyên. Chỉ liên kết nếu bạn chắc đây là đúng file âm thanh.')),
                for (final candidate in candidates)
                  ListTile(
                    title: material.Text(
                      p.basename(candidate.lrcPath),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(ctx, candidate),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.uiText('Hủy'))),
            TextButton(onPressed: () => Navigator.pop(ctx, 'redo'),
                child: Text(ctx.uiText('Tạo lại'))),
          ],
        ),
      );
      if (!context.mounted || provider.currentSongPath != audioPath) return null;
      if (choice is CachedLrcHit) {
        var linked = false;
        try {
          linked = await store.bindUnverifiedLrc(choice);
        } catch (error) {
          debugPrint('Could not link older LRC: $error');
        }
        if (linked && provider.currentSongPath == audioPath) {
          await provider.applyCachedLrc(hit: choice);
        } else if (!linked && context.mounted && provider.currentSongPath == audioPath) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.uiText('Không thể liên kết dữ liệu cũ')),
          ));
        }
        return null;
      }
      if (choice != 'redo') return null;
      force = true;
    }
  }
  if (!context.mounted || provider.currentSongPath != audioPath) return null;
  return provider.generateLrcForCurrentAudio(
    level: level,
    grouping: grouping,
    forceRegenerate: force,
    language: language,
    // PARAKEET-002: chip "Offline (sherpa)" trong tab Nghe.
    preferSherpa: preferSherpa,
  );
}
