//
// FIX kẹt 5%: dùng await for trực tiếp trên stream (theo cách của yt_service_explode.dart)
//             Bỏ StreamController trung gian gây race condition
// THÊM: chọn chất lượng audio (cao/trung/thấp + chọn cụ thể)
// THÊM: cancel thực sự bằng flag check trong await for

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/yt_video.dart';

// ─── Audio Quality ────────────────────────────────────────

enum YtAudioQuality {
  highest('Content', null),
  medium('Content', 128000),
  low('Content', 64000);

  final String label;
  final int? maxBitrateBps;

  const YtAudioQuality(this.label, this.maxBitrateBps);
}

// ─── Events ──────────────────────────────────────────────

sealed class YtDownloadEvent {}

class YtDownloadProgress extends YtDownloadEvent {
  final double progress; // 0.0 → 1.0
  final String progressText;
  YtDownloadProgress(this.progress, this.progressText);
}

class YtDownloadDone extends YtDownloadEvent {
  final String filePath;
  final String quality; // e.g. "128kbps"
  YtDownloadDone(this.filePath, {this.quality = ''});
}

class YtDownloadFailed extends YtDownloadEvent {
  final String message;
  YtDownloadFailed(this.message);
}

// ─── Downloader ───────────────────────────────────────────

class YtDownloader {
  YtDownloader._();
  static final YtDownloader instance = YtDownloader._();

  bool _cancelled = false;

  /// Lấy danh sách stream audio có sẵn để hiển thị lựa chọn chất lượng
  Future<List<AudioOnlyStreamInfo>> getAudioStreams(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest =
          await yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.audioOnly.toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      return streams;
    } catch (e) {
      debugPrint('getAudioStreams error: $e');
      return [];
    } finally {
      yt.close();
    }
  }

  /// Download audio — trả về Stream<YtDownloadEvent>
  Stream<YtDownloadEvent> download(
    YtVideo video, {
    YtAudioQuality quality = YtAudioQuality.highest,
    AudioOnlyStreamInfo? specificStream,
  }) {
    final ctrl = StreamController<YtDownloadEvent>();
    _doDownload(ctrl, video,
        quality: quality, specificStream: specificStream);
    return ctrl.stream;
  }

  Future<void> _doDownload(
    StreamController<YtDownloadEvent> ctrl,
    YtVideo video, {
    required YtAudioQuality quality,
    AudioOnlyStreamInfo? specificStream,
  }) async {
    _cancelled = false;
    final yt = YoutubeExplode();

    void emit(YtDownloadEvent e) {
      if (!ctrl.isClosed) ctrl.add(e);
    }

    void fail(String msg) {
      emit(YtDownloadFailed(msg));
      if (!ctrl.isClosed) ctrl.close();
    }

    try {
      emit(YtDownloadProgress(0.03, 'Content'));

      // ── Step 1: Video info ──────────────────────────────
      final videoObj = await yt.videos.get(video.id);
      if (_cancelled) {
        yt.close();
        fail('Cancel');
        return;
      }

      emit(YtDownloadProgress(0.07, 'Content'));

      // ── Step 2: Manifest ───────────────────────────────
      final manifest =
          await yt.videos.streamsClient.getManifest(video.id);
      if (_cancelled) {
        yt.close();
        fail('Cancel');
        return;
      }

      final allAudio = manifest.audioOnly.toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      if (allAudio.isEmpty) {
        yt.close();
        fail('Search');
        return;
      }

      // ── Step 3: Chọn stream ────────────────────────────
      final streamInfo =
          specificStream ?? _selectStream(allAudio, quality);
      final totalBytes = streamInfo.size.totalBytes;
      final ext = streamInfo.container.name;
      final kbps = streamInfo.bitrate.bitsPerSecond ~/ 1000;

      emit(YtDownloadProgress(
          0.10, 'Content'));

      // ── Step 4: Chuẩn bị file ─────────────────────────
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/youtube_downloads');
      if (!await folder.exists()) await folder.create(recursive: true);

      final safeTitle = _sanitize(videoObj.title);
      final filePath = '${folder.path}/$safeTitle.$ext';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      final output = file.openWrite();
      int downloaded = 0;

      // ── Step 5: Download với await for trực tiếp ──────
      // QUAN TRỌNG: await for trực tiếp (không StreamController trung gian)
      // Đây là fix chính cho bug kẹt 5% — theo đúng cách của yt_service_explode.dart
      try {
        await for (final chunk
            in yt.videos.streamsClient.get(streamInfo)) {
          if (_cancelled) break;

          output.add(chunk);
          downloaded += chunk.length;

          final pct = totalBytes > 0
              ? 0.10 + (downloaded / totalBytes) * 0.88
              : 0.50;
          final dlMb = (downloaded / 1048576).toStringAsFixed(1);
          final totMb = (totalBytes / 1048576).toStringAsFixed(1);

          emit(YtDownloadProgress(
              pct.clamp(0.0, 0.98), '$dlMb / $totMb MB'));
        }
      } finally {
        await output.flush();
        await output.close();
      }

      yt.close();

      // ── Step 6: Kết quả ───────────────────────────────
      if (_cancelled) {
        if (await file.exists()) await file.delete();
        fail('Cancel');
        return;
      }

      final finalSize = await file.length();
      if (finalSize < 1000) {
        if (await file.exists()) await file.delete();
        fail('Retry');
        return;
      }

      emit(YtDownloadDone(filePath, quality: '${kbps}kbps'));
      if (!ctrl.isClosed) ctrl.close();
    } catch (e) {
      yt.close();
      fail(_friendlyError(e.toString()));
    }
  }

  /// Hủy download đang chạy
  void cancel() {
    _cancelled = true;
  }

  // ─── Helpers ─────────────────────────────────────────

  AudioOnlyStreamInfo _selectStream(
    List<AudioOnlyStreamInfo> streams,
    YtAudioQuality quality,
  ) {
    if (quality == YtAudioQuality.highest) {
      // Ưu tiên mp4/aac — tương thích tốt hơn với just_audio
      final mp4 = streams
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();
      return mp4.isNotEmpty ? mp4.first : streams.first;
    }

    final maxBps = quality.maxBitrateBps!;
    final candidates =
        streams.where((s) => s.bitrate.bitsPerSecond <= maxBps).toList();

    // Lấy bitrate cao nhất trong giới hạn; không có → lấy thấp nhất
    return candidates.isNotEmpty ? candidates.first : streams.last;
  }

  String _sizeLabel(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _sanitize(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .substring(0, name.length.clamp(0, 80));

  String _friendlyError(String raw) {
    if (raw.contains('unplayable') || raw.contains('Unplayable')) {
      return 'Content';
    }
    if (raw.contains('unavailable')) return 'Content';
    if (raw.contains('SocketException') || raw.contains('Network')) {
      return 'Content';
    }
    if (raw.contains('403')) return 'Content';
    if (raw.contains('429')) return 'Rate limit, Retry sau';
    return 'Content';
  }
}