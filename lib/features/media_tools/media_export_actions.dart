// lib/features/media_tools/media_export_actions.dart
//
// AVTOOL-003 (PLAN-047 P2) — HÀNH ĐỘNG dùng chung cho MỌI lối vào UI.
//
// Vì sao cần lớp này: mỗi bề mặt (tab Nghe, video, YouTube, âm mục, TTS) chỉ
// nên viết 1 dòng (`await exportClipFromPlayer(context, player)`) thay vì tự
// dựng request. Nhờ vậy luật "mọi bản xuất đều giữ LRC + đăng ký thư viện"
// nằm ở MỘT chỗ, không phải nhắc lại 6 lần (bài học ADR-0024: 2 nơi gọi 2
// setter khác nhau ⇒ lệch trạng thái).

import 'package:in4up/core/language/localized_material.dart';
// `show Text` từ material sẽ che shim `Text` của `localized_material.dart`
// (luật #5) ⇒ đã bỏ `Text` khỏi danh sách show.
import 'package:flutter/material.dart' show BuildContext;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../video/models/video_info.dart';
import 'models/media_export_models.dart';
import 'services/media_export_service.dart';
import 'services/media_ffmpeg_engine.dart';
import 'widgets/media_export_sheet.dart';
import 'widgets/ffmpeg_install_sheet.dart';

/// Xuất ĐOẠN A–B đang chọn (hoặc [fallbackDuration] nếu chưa đặt B).
///
/// Đây là bề mặt giá trị cao nhất: người dùng đang luyện một câu, bấm là có
/// file ngắn mang theo (kèm LRC đã dịch mốc ⇒ còn karaoke + lặp A–B).
Future<MediaExportResult?> exportClipFromPlayer(
  BuildContext context,
  PlayerProvider player, {
  Duration fallbackDuration = const Duration(seconds: 30),
}) async {
  final path = player.currentSongPath;
  if (path == null || path.isEmpty) return null;

  final start = player.loopStart ?? player.state.position;
  final end = player.loopEnd;
  final duration = end != null && end > start
      ? end - start
      : fallbackDuration;

  if (!await _ensureReady(context)) return null;
  if (!context.mounted) return null;

  final hasLrc = await _hasSourceLrc(path);

  return showMediaExportSheet(
    context,
    initialRequest: MediaExportRequest(
      inputPath: path,
      preset: MediaExportPreset.mp3Standard,
      scope: MediaExportScope.clip,
      start: start,
      duration: duration,
      title: player.currentSongTitle ?? p.basename(path),
      keepLrc: hasLrc,
    ),
    knownDuration: duration,
    hasSourceLrc: hasLrc,
  );
}

/// Xuất TOÀN BỘ file đang phát (chuyển định dạng / lấy âm thanh).
Future<MediaExportResult?> exportFullAudio(
  BuildContext context, {
  required String audioPath,
  String? title,
  Duration? knownDuration,
}) async {
  if (!await _ensureReady(context)) return null;
  if (!context.mounted) return null;
  final hasLrc = await _hasSourceLrc(audioPath);
  return showMediaExportSheet(
    context,
    initialRequest: MediaExportRequest(
      inputPath: audioPath,
      preset: MediaExportPreset.recommended(
        inputExtension: p.extension(audioPath),
      ),
      title: title ?? p.basename(audioPath),
      keepLrc: hasLrc,
    ),
    knownDuration: knownDuration,
    hasSourceLrc: hasLrc,
  );
}

/// Xuất ÂM THANH từ video (giữ cả đoạn nếu [start]/[duration] được truyền).
Future<MediaExportResult?> exportAudioFromVideo(
  BuildContext context,
  VideoInfo video, {
  Duration? clipStart,
  Duration? clipDuration,
  Future<void> Function(String path)? openInListenTab,
}) async {
  if (!await _ensureReady(context)) return null;
  if (!context.mounted) return null;
  final isClip = clipStart != null;
  return showMediaExportSheet(
    context,
    initialRequest: MediaExportRequest(
      inputPath: video.filePath,
      preset: isClip
          ? MediaExportPreset.mp3Standard
          : MediaExportPreset.m4aCopy,
      scope: isClip ? MediaExportScope.clip : MediaExportScope.full,
      inputKind: MediaExportInputKind.video,
      start: clipStart ?? Duration.zero,
      duration: clipDuration,
      title: video.title,
      keepLrc: false,
    ),
    knownDuration: isClip ? clipDuration : video.duration,
    hasSourceLrc: false,
    openInListenTab: openInListenTab,
  );
}

/// Tách theo MỤC LỤC (chương) — mỗi chương 1 file, tên = tiêu đề chương.
///
/// [chapterPositions] lấy từ `SoundlistProvider` (`SoundChapter.position`),
/// đã sắp tăng dần.
Future<MediaExportResult?> exportByChapters(
  BuildContext context, {
  required String audioPath,
  required String title,
  required List<(Duration position, String chapterTitle)> chapterPositions,
  Duration? totalDuration,
}) async {
  if (chapterPositions.isEmpty) return null;
  if (!await _ensureReady(context)) return null;
  if (!context.mounted) return null;

  final sorted = [...chapterPositions]
    ..sort((a, b) => a.$1.compareTo(b.$1));

  final slices = <MediaExportSlice>[];
  for (var i = 0; i < sorted.length; i++) {
    final start = sorted[i].$1;
    final next = i + 1 < sorted.length ? sorted[i + 1].$1 : totalDuration;
    final duration = next == null ? null : next - start;
    if (duration != null && duration.inMilliseconds <= 0) continue;
    slices.add(MediaExportSlice(
      start: start,
      duration: duration,
      title: sorted[i].$2,
    ));
  }
  if (slices.isEmpty) return null;

  final hasLrc = await _hasSourceLrc(audioPath);
  return showMediaExportSheet(
    context,
    initialRequest: MediaExportRequest(
      inputPath: audioPath,
      preset: MediaExportPreset.mp3Standard,
      scope: MediaExportScope.chapters,
      slices: slices,
      title: title,
      keepLrc: hasLrc,
    ),
    knownDuration: totalDuration,
    hasSourceLrc: hasLrc,
  );
}

Future<bool> _ensureReady(BuildContext context) async {
  final engine = MediaFfmpegEngine();
  if (await engine.ensureAvailable()) return true;
  if (!context.mounted) return false;
  // Desktop thiếu FFmpeg: hiện hộp thoại tải (owner chọn: tải khi cần).
  return ensureFfmpegReady(context);
}

Future<bool> _hasSourceLrc(String audioPath) async {
  try {
    final service = MediaExportService();
    // Dùng đúng phép đọc của service để không có "luật thứ hai".
    final lrc = await service.sourceLrcPreview(audioPath);
    return lrc != null && lrc.trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}
