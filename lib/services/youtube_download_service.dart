//
// Service download audio + fetch captions từ YouTube
// Dùng youtube_explode_dart (package từ strep_app)
// ⚠️  Chỉ dùng cho personal use, không phân phối nội dung có bản quyền

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ─── Download progress model ─────────────────────────────────

enum DownloadStatus {
  idle,
  fetchingInfo,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadProgress {
  final String videoId;
  final String title;
  final DownloadStatus status;
  final double progress; // 0.0 → 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? savedPath; // path sau khi hoàn tất
  final String? errorMessage;

  const DownloadProgress({
    required this.videoId,
    required this.title,
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.savedPath,
    this.errorMessage,
  });

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? savedPath,
    String? errorMessage,
  }) =>
      DownloadProgress(
        videoId: videoId,
        title: title,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        savedPath: savedPath ?? this.savedPath,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  String get progressText {
    if (totalBytes <= 0) return '${(progress * 100).toStringAsFixed(0)}%';
    final mb = downloadedBytes / 1048576;
    final total = totalBytes / 1048576;
    return '${mb.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} MB';
  }
}

// ─── Caption line ─────────────────────────────────────────────

class YtCaptionLine {
  final Duration start;
  final Duration end;
  final String text;

  const YtCaptionLine({
    required this.start,
    required this.end,
    required this.text,
  });

  /// LRC format: [mm:ss.xx]text
  String toLrc() {
    final mm = start.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = start.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (start.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$mm:$ss.$cs]$text';
  }
}

// ─── Video info ───────────────────────────────────────────────

class YtVideoInfo {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String? thumbnailUrl;

  const YtVideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnailUrl,
  });

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Main Service ─────────────────────────────────────────────

class YoutubeDownloadService {
  static final YoutubeDownloadService _instance = YoutubeDownloadService._();
  factory YoutubeDownloadService() => _instance;
  YoutubeDownloadService._();

  final YoutubeExplode _yt = YoutubeExplode();

  // Active downloads: videoId → StreamController
  final Map<String, StreamController<DownloadProgress>> _activeDownloads = {};
  // Cancel tokens
  final Map<String, bool> _cancelFlags = {};

  // ─── Extract Video ID ───────────────────────────────────────

  static String? extractVideoId(String input) {
    final trimmed = input.trim();
    // youtube_explode_dart tự handle parsing — dùng VideoId trực tiếp
    try {
      return VideoId.parseVideoId(trimmed);
    } catch (_) {
      return null;
    }
  }

  // ─── Fetch Video Info ───────────────────────────────────────

  Future<YtVideoInfo?> fetchVideoInfo(String urlOrId) async {
    try {
      final video = await _yt.videos.get(urlOrId);
      return YtVideoInfo(
        id: video.id.value,
        title: video.title,
        author: video.author,
        duration: video.duration ?? Duration.zero,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } catch (e) {
      debugPrint('YoutubeDownloadService.fetchVideoInfo: $e');
      return null;
    }
  }

  // ─── Download Audio ─────────────────────────────────────────

  /// Download audio stream, trả về Stream<DownloadProgress>
  /// Caller listen để cập nhật UI
  Stream<DownloadProgress> downloadAudio(
    String urlOrId, {
    String? customTitle,
  }) {
    final ctrl = StreamController<DownloadProgress>();

    _doDownload(urlOrId, customTitle: customTitle, ctrl: ctrl);

    return ctrl.stream;
  }

  Future<void> _doDownload(
    String urlOrId, {
    String? customTitle,
    required StreamController<DownloadProgress> ctrl,
  }) async {
    String videoId = '';

    try {
      // ── Step 1: Fetch video info ──────────────────────────
      ctrl.add(DownloadProgress(
        videoId: videoId,
        title: customTitle ?? 'Đang tải thông tin...',
        status: DownloadStatus.fetchingInfo,
      ));

      final video = await _yt.videos.get(urlOrId);
      videoId = video.id.value;
      final title = customTitle ?? _sanitizeFilename(video.title);

      _cancelFlags[videoId] = false;
      _activeDownloads[videoId] = ctrl;

      ctrl.add(DownloadProgress(
        videoId: videoId,
        title: title,
        status: DownloadStatus.fetchingInfo,
        progress: 0.05,
      ));

      // ── Step 2: Get audio stream manifest ────────────────
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      // Chọn audio stream chất lượng cao nhất (webm/opus hoặc mp4/aac)
      // Ưu tiên mp4/aac vì tương thích tốt hơn với just_audio
      AudioOnlyStreamInfo streamInfo;
      final mp4Streams = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();

      if (mp4Streams.isNotEmpty) {
        // Chọn bitrate cao nhất trong mp4
        mp4Streams.sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        streamInfo = mp4Streams.first;
      } else {
        // Fallback: bất kỳ audio stream nào
        streamInfo = manifest.audioOnly.withHighestBitrate();
      }

      final totalBytes = streamInfo.size.totalBytes;
      final extension = streamInfo.container.name; // 'mp4' or 'webm'

      ctrl.add(DownloadProgress(
        videoId: videoId,
        title: title,
        status: DownloadStatus.downloading,
        progress: 0.1,
        totalBytes: totalBytes,
      ));

      // ── Step 3: Prepare save path ─────────────────────────
      final saveDir = await _getDownloadDirectory();
      final safeTitle = title.length > 60 ? title.substring(0, 60) : title;
      final filePath = '${saveDir.path}/$safeTitle.$extension';
      final file = File(filePath);

      // Xóa file cũ nếu tồn tại
      if (await file.exists()) await file.delete();

      // ── Step 4: Download bytes ────────────────────────────
      final stream = _yt.videos.streamsClient.get(streamInfo);
      final fileStream = file.openWrite();

      int downloaded = 0;

      await for (final chunk in stream) {
        // Kiểm tra cancel
        if (_cancelFlags[videoId] == true) {
          await fileStream.close();
          if (await file.exists()) await file.delete();
          ctrl.add(DownloadProgress(
            videoId: videoId,
            title: title,
            status: DownloadStatus.cancelled,
          ));
          ctrl.close();
          _cleanup(videoId);
          return;
        }

        fileStream.add(chunk);
        downloaded += chunk.length;

        final progress =
            totalBytes > 0 ? 0.1 + (downloaded / totalBytes) * 0.9 : 0.5;

        ctrl.add(DownloadProgress(
          videoId: videoId,
          title: title,
          status: DownloadStatus.downloading,
          progress: progress.clamp(0.0, 0.99),
          downloadedBytes: downloaded,
          totalBytes: totalBytes,
        ));
      }

      await fileStream.flush();
      await fileStream.close();

      // ── Step 5: Completed ─────────────────────────────────
      ctrl.add(DownloadProgress(
        videoId: videoId,
        title: title,
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: downloaded,
        totalBytes: totalBytes,
        savedPath: filePath,
      ));

      ctrl.close();
      debugPrint('✅ Download complete: $filePath');
    } catch (e) {
      debugPrint('YoutubeDownloadService._doDownload error: $e');
      ctrl.add(DownloadProgress(
        videoId: videoId,
        title: customTitle ?? 'Unknown',
        status: DownloadStatus.failed,
        errorMessage: _friendlyError(e.toString()),
      ));
      ctrl.close();
    } finally {
      if (videoId.isNotEmpty) _cleanup(videoId);
    }
  }

  /// Hủy download đang chạy
  void cancelDownload(String videoId) {
    _cancelFlags[videoId] = true;
  }

  // ─── Fetch Captions ─────────────────────────────────────────

  /// Fetch captions từ YouTube, trả về List<YtCaptionLine>
  Future<List<YtCaptionLine>> fetchCaptions(
    String urlOrId, {
    String languageCode = 'en',
  }) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(urlOrId);

      if (manifest.tracks.isEmpty) {
        debugPrint('No captions available for $urlOrId');
        return [];
      }

      // Tìm track theo language code
      ClosedCaptionTrackInfo? track;

      // Thử exact match trước
      track = manifest.tracks.cast<ClosedCaptionTrackInfo?>().firstWhere(
            (t) => t!.language.code == languageCode,
            orElse: () => null,
          );

      // Fallback: English nếu không tìm thấy
      if (track == null && languageCode != 'en') {
        track = manifest.tracks.cast<ClosedCaptionTrackInfo?>().firstWhere(
              (t) => t!.language.code == 'en',
              orElse: () => null,
            );
      }

      // Last resort: dùng track đầu tiên
      track ??= manifest.tracks.first;

      final captions = await _yt.videos.closedCaptions.get(track);

      return captions.captions
          .map((c) => YtCaptionLine(
                start: c.offset,
                end: c.offset + c.duration,
                text: c.text
                    .replaceAll('\n', ' ')
                    .replaceAll(RegExp(r'\s{2,}'), ' ')
                    .trim(),
              ))
          .where((c) => c.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('YoutubeDownloadService.fetchCaptions error: $e');
      return [];
    }
  }

  /// Lấy danh sách language codes có sẵn
  Future<List<({String code, String name})>> getAvailableLanguages(
      String urlOrId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(urlOrId);
      return manifest.tracks
          .map((t) => (code: t.language.code, name: t.language.name))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Convert captions → LRC string
  String captionsToLrc(
    List<YtCaptionLine> captions,
    YtVideoInfo info,
  ) {
    final buf = StringBuffer();
    buf.writeln('[ti:${info.title}]');
    buf.writeln('[ar:${info.author}]');
    buf.writeln('[by:in4up YouTube]');
    buf.writeln();
    for (final c in captions) {
      buf.writeln(c.toLrc());
    }
    return buf.toString();
  }

  /// Lưu captions thành .lrc file, trả về path
  Future<String?> saveCaptionsAsLrc(
    List<YtCaptionLine> captions,
    YtVideoInfo info,
  ) async {
    try {
      final lrcContent = captionsToLrc(captions, info);
      final dir = await _getDownloadDirectory();
      final safeTitle = _sanitizeFilename(info.title);
      final path = '${dir.path}/$safeTitle.lrc';
      await File(path).writeAsString(lrcContent, flush: true);
      debugPrint('✅ LRC saved: $path');
      return path;
    } catch (e) {
      debugPrint('YoutubeDownloadService.saveCaptionsAsLrc error: $e');
      return null;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────

  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/youtube_downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .substring(0, name.length.clamp(0, 80));
  }

  String _friendlyError(String raw) {
    if (raw.contains('VideoUnplayableException') ||
        raw.contains('unplayable')) {
      return 'Video không thể tải (bị giới hạn hoặc riêng tư)';
    }
    if (raw.contains('VideoUnavailableException') ||
        raw.contains('unavailable')) {
      return 'Video không tồn tại hoặc đã bị xóa';
    }
    if (raw.contains('SocketException') || raw.contains('NetworkException')) {
      return 'Lỗi mạng — kiểm tra kết nối internet';
    }
    if (raw.contains('403') || raw.contains('forbidden')) {
      return 'Truy cập bị từ chối (403) — thử lại sau';
    }
    return 'Lỗi: ${raw.substring(0, raw.length.clamp(0, 80))}';
  }

  void _cleanup(String videoId) {
    _activeDownloads.remove(videoId);
    _cancelFlags.remove(videoId);
  }

  /// Lấy list files đã tải trong thư mục downloads
  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      final dir = await _getDownloadDirectory();
      return dir
          .listSync()
          .where((f) =>
              f is File &&
              (f.path.endsWith('.mp4') ||
                  f.path.endsWith('.webm') ||
                  f.path.endsWith('.m4a')))
          .toList()
        ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _yt.close();
    for (final ctrl in _activeDownloads.values) {
      ctrl.close();
    }
    _activeDownloads.clear();
  }
}
