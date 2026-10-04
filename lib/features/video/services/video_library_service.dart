// lib/features/video/services/video_library_service.dart
// I4U18-VIDEO-LIB-001 — Thư viện video: quét thư mục (SAF) + import file +
// yêu thích + vị trí phát gần nhất + ghép phụ đề.
//
// Chỉ mục lưu ở manifest.json (ứng dụng), tree URI đã chọn lưu ở
// SharedPreferences. Mọi logic "khó đúng" (merge, subtitle, filter) nằm ở
// VideoLibraryLogic (test được); service chỉ điều phối I/O.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_info.dart';
import 'video_device_channel.dart';
import 'video_library_logic.dart';

/// Service quản lý thư viện video.
class VideoLibraryService {
  static VideoLibraryService? _instance;
  static VideoLibraryService get instance =>
      _instance ??= VideoLibraryService._();
  VideoLibraryService._();

  static const String _treeUriKey = 'in4up_video_tree_uri_v1';

  final List<VideoInfo> _videos = [];
  bool _initialized = false;
  String? _treeUri;

  List<VideoInfo> get videos => List.unmodifiable(_videos);
  String? get treeUri => _treeUri;
  bool get hasFolder => (_treeUri ?? '').isNotEmpty;

  /// Tên thư mục hiển thị (từ tree URI đã chọn).
  String get folderLabel =>
      _treeUri == null ? '' : VideoLibraryLogic.folderLabel(_treeUri!);

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadManifest();
    try {
      final prefs = await SharedPreferences.getInstance();
      _treeUri = prefs.getString(_treeUriKey);
    } catch (_) {}
  }

  /// Nền tảng hỗ trợ quét thư mục (Android).
  bool get folderScanSupported => VideoDeviceChannel.supported;

  /// Mở SAF folder picker → lưu tree URI → quét.
  /// Trả `true` nếu người dùng chọn (hủy → false).
  Future<bool> pickAndScanFolder() async {
    await ensureInitialized();
    var uri = await VideoDeviceChannel.pickFolder();
    if (uri == null || uri.isEmpty) return false;
    final canonical = await VideoDeviceChannel.normalizeTreeUri(uri);
    if (canonical != null && canonical.isNotEmpty) uri = canonical;
    await VideoDeviceChannel.keepTreePermission(uri);
    _treeUri = uri;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_treeUriKey, uri);
    } catch (_) {}
    await scanFolder();
    return true;
  }

  /// Quét lại thư mục đã chọn (đệ quy) + ghép phụ đề + hợp nhất chỉ mục.
  /// NÉM [VideoScanException] khi mất quyền / URI hỏng.
  Future<void> scanFolder() async {
    await ensureInitialized();
    final uri = _treeUri;
    if (uri == null || uri.isEmpty) return;
    final items = await VideoDeviceChannel.scanTree(uri);
    final scanned = VideoLibraryLogic.buildFromScan(items);
    final merged = VideoLibraryLogic.mergeScanned(scanned, _videos);
    _videos
      ..clear()
      ..addAll(merged);
    await _saveManifest();
  }

  /// Bỏ thư mục đã chọn (giữ các video import thủ công).
  Future<void> forgetFolder() async {
    _treeUri = null;
    _videos.removeWhere((v) => v.source == VideoSource.folder);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_treeUriKey);
    } catch (_) {}
    await _saveManifest();
  }

  /// Thêm video import thủ công (source = picked).
  Future<void> addVideo(VideoInfo video) async {
    await ensureInitialized();
    final key = VideoLibraryLogic.normalizeUri(video.filePath);
    final idx = _videos.indexWhere(
        (v) => VideoLibraryLogic.normalizeUri(v.filePath) == key);
    if (idx >= 0) {
      // Đã có → cập nhật metadata, giữ favorite/vị trí.
      _videos[idx] = _videos[idx].copyWith(
        title: video.title,
        duration: video.duration,
        subtitlePath: video.subtitlePath,
      );
    } else {
      _videos.add(video);
    }
    await _saveManifest();
  }

  Future<void> removeVideo(String videoId) async {
    await ensureInitialized();
    _videos.removeWhere((v) => v.id == videoId);
    await _saveManifest();
  }

  /// Bật/tắt yêu thích.
  Future<VideoInfo?> toggleFavorite(String videoId) async {
    final idx = _videos.indexWhere((v) => v.id == videoId);
    if (idx < 0) return null;
    final updated = _videos[idx].copyWith(favorite: !_videos[idx].favorite);
    _videos[idx] = updated;
    await _saveManifest();
    return updated;
  }

  /// Lưu vị trí phát gần nhất + thời lượng + đánh dấu đã phát (tab Gần đây).
  Future<void> updatePlayback(
    String videoId, {
    required Duration position,
    Duration? duration,
  }) async {
    final idx = _videos.indexWhere((v) => v.id == videoId);
    if (idx < 0) return;
    _videos[idx] = _videos[idx].copyWith(
      lastPositionMs: position.inMilliseconds,
      duration: (duration != null && duration.inMilliseconds > 0)
          ? duration
          : _videos[idx].duration,
      lastPlayed: DateTime.now(),
    );
    await _saveManifest();
  }

  /// Gán/cập nhật phụ đề thủ công.
  Future<void> setSubtitle(String videoId, String? subtitleUri) async {
    final idx = _videos.indexWhere((v) => v.id == videoId);
    if (idx < 0) return;
    _videos[idx] = _videos[idx].copyWith(
      subtitlePath: subtitleUri,
      clearSubtitle: subtitleUri == null,
    );
    await _saveManifest();
  }

  VideoInfo? findById(String id) {
    for (final v in _videos) {
      if (v.id == id) return v;
    }
    return null;
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
      final List<dynamic> json = jsonDecode(content) as List<dynamic>;
      _videos.clear();
      for (final item in json) {
        try {
          _videos.add(VideoInfo.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          // Skip corrupt entries
        }
      }
    } catch (e) {
      debugPrint('[VideoLibrary] load manifest error: $e');
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
      debugPrint('[VideoLibrary] save manifest error: $e');
    }
  }
}
