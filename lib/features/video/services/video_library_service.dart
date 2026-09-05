import 'dart:io';

import '../models/video_info.dart';

/// Service quét và quản lý video files trên thiết bị
class VideoLibraryService {
  static VideoLibraryService? _instance;
  static VideoLibraryService get instance =>
      _instance ??= VideoLibraryService._();
  VideoLibraryService._();

  final List<VideoInfo> _videos = [];
  bool _scanned = false;

  List<VideoInfo> get videos => List.unmodifiable(_videos);
  bool get isScanned => _scanned;

  /// Quét thư mục phổ biến để tìm video
  Future<List<VideoInfo>> scanVideos({String? folderPath}) async {
    final videos = <VideoInfo>[];
    final dirs = <Directory>[];

    if (folderPath != null) {
      dirs.add(Directory(folderPath));
    } else {
      // Quét các thư mục phổ biến
      for (final path in [
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Video',
        '${Platform.environment['HOME'] ?? ''}/Videos',
        '${Platform.environment['HOME'] ?? ''}/Downloads',
      ]) {
        final dir = Directory(path);
        if (dir.existsSync()) dirs.add(dir);
      }
    }

    for (final dir in dirs) {
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final ext = entity.path.split('.').last.toLowerCase();
          if (!VideoInfo.supportedExtensions.contains(ext)) continue;

          try {
            final stat = await entity.stat();
            videos.add(VideoInfo(
              filePath: entity.path,
              fileName: entity.path.split('/').last,
              fileSizeBytes: stat.size,
              lastModified: stat.modified,
              extension: ext,
            ));
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Sắp xếp theo ngày sửa đổi (mới nhất trước)
    videos.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    _videos
      ..clear()
      ..addAll(videos);
    _scanned = true;
    return videos;
  }

  /// Tìm kiếm video theo tên
  List<VideoInfo> search(String query) {
    if (query.isEmpty) return videos;
    final lower = query.toLowerCase();
    return _videos
        .where((v) => v.fileName.toLowerCase().contains(lower))
        .toList();
  }

  /// Xóa video đã scan (reset)
  void clear() {
    _videos.clear();
    _scanned = false;
  }
}
