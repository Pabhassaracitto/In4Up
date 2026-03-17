//
// Download audio từ YouTube dùng youtube_explode_dart
// Trả về Stream<YtDownloadEvent> để UI cập nhật progress

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/yt_video.dart';

// ─── Events ──────────────────────────────────────────────────

sealed class YtDownloadEvent {}

class YtDownloadProgress extends YtDownloadEvent {
  final double progress;      // 0.0 → 1.0
  final String progressText;  // "2.3 / 8.1 MB"
  YtDownloadProgress(this.progress, this.progressText);
}

class YtDownloadDone extends YtDownloadEvent {
  final String filePath;
  YtDownloadDone(this.filePath);
}

class YtDownloadFailed extends YtDownloadEvent {
  final String message;
  YtDownloadFailed(this.message);
}

// ─── Downloader ───────────────────────────────────────────────

class YtDownloader {
  YtDownloader._();
  static final YtDownloader instance = YtDownloader._();

  StreamSubscription<List<int>>? _sub;
  bool _cancelled = false;

  /// Bắt đầu download, trả về Stream để listen
  Stream<YtDownloadEvent> download(YtVideo video) async* {
    _cancelled = false;
    final yt = YoutubeExplode();

    try {
      yield YtDownloadProgress(0.05, 'Đang chuẩn bị...');

      final manifest =
          await yt.videos.streamsClient.getManifest(video.id);

      // Ưu tiên M4A (AAC) → tương thích tốt nhất với just_audio
      final mp4 = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      final streamInfo =
          mp4.isNotEmpty ? mp4.first : manifest.audioOnly.withHighestBitrate();

      final totalBytes = streamInfo.size.totalBytes;
      final ext = streamInfo.container.name;

      // Chuẩn bị file
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/youtube_downloads');
      if (!await folder.exists()) await folder.create(recursive: true);

      final safe = video.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .substring(0, video.title.length.clamp(0, 60));
      final filePath = '${folder.path}/$safe.$ext';

      final file = File(filePath);
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();

      int downloaded = 0;
      final completer = Completer<YtDownloadEvent>();
      final ctrl = StreamController<YtDownloadEvent>();

      _sub = yt.videos.streamsClient.get(streamInfo).listen(
        (chunk) {
          if (_cancelled) return;
          sink.add(chunk);
          downloaded += chunk.length;
          final pct = totalBytes > 0 ? downloaded / totalBytes : 0.5;
          final dlMb = (downloaded / 1048576).toStringAsFixed(1);
          final totMb = (totalBytes / 1048576).toStringAsFixed(1);
          ctrl.add(YtDownloadProgress(
              pct.clamp(0.0, 0.99), '$dlMb / $totMb MB'));
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          yt.close();
          if (_cancelled) {
            if (await file.exists()) await file.delete();
            completer.complete(YtDownloadFailed('Đã hủy'));
          } else {
            completer.complete(YtDownloadDone(filePath));
          }
          ctrl.close();
        },
        onError: (e) async {
          await sink.close();
          yt.close();
          if (await file.exists()) await file.delete();
          completer.complete(YtDownloadFailed(_friendlyError(e.toString())));
          ctrl.close();
        },
        cancelOnError: true,
      );

      yield* ctrl.stream;
      yield await completer.future;
    } catch (e) {
      yt.close();
      yield YtDownloadFailed(_friendlyError(e.toString()));
    }
  }

  void cancel() {
    _cancelled = true;
    _sub?.cancel();
    _sub = null;
  }

  String _friendlyError(String raw) {
    if (raw.contains('unplayable') || raw.contains('Unplayable')) {
      return 'Video bị giới hạn tải xuống';
    }
    if (raw.contains('unavailable')) return 'Video không khả dụng';
    if (raw.contains('Socket') || raw.contains('Network')) {
      return 'Lỗi mạng — kiểm tra kết nối';
    }
    return 'Lỗi: ${raw.substring(0, raw.length.clamp(0, 60))}';
  }
}
