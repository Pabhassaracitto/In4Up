import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/video_info.dart';

/// Service quản lý thư viện video
class VideoLibraryService {
  static VideoLibraryService? _instance;
  static VideoLibraryService get instance =>
      _instance ??= VideoLibraryService._();
  VideoLibraryService._();

  final List<VideoInfo> _videos = [];
  bool _initialized = false;

  List<VideoInfo> get videos => List.unmodifiable(_videos);

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadManifest();
  }

  /// Thêm video vào thư viện
  Future<void> addVideo(VideoInfo video) async {
    await ensureInitialized();
    if (_videos.any((v) => v.id == video.id)) return;
    _videos.add(video);
    await _saveManifest();
  }

  /// Xóa video khỏi thư viện
  Future<void> removeVideo(String videoId) async {
    await ensureInitialized();
    _videos.removeWhere((v) => v.id == videoId);
    await _saveManifest();
  }

  /// Tìm video theo ID
  VideoInfo? findById(String id) {
    try {
      return _videos.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<String> get _manifestPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/videos/manifest.json';
  }

  Future<void> _loadManifest() async {
    try {
      final path = await _manifestPath;
      final file = File(path);
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final List<dynamic> json = jsonDecode(content);
      _videos.clear();
      for (final item in json) {
        try {
          _videos.add(VideoInfo.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          // Skip corrupt entries
        }
      }
    } catch (e) {
      _videos.clear();
    }
  }

  Future<void> _saveManifest() async {
    try {
      final path = await _manifestPath;
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final json = _videos.map((v) => v.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      // skip
    }
  }
}
