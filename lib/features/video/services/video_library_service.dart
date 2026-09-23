// lib/features/video/services/video_library_service.dart
// Thư viện video — HỌC THEO ĐÚNG CHẾ ĐỘ QUÉT CỦA THƯ VIỆN NGHE + ĐỌC:
//
//  - Như thư viện NHẠC (AudioLibraryProvider/Service): quét MediaStore toàn
//    máy qua MethodChannel Android, merge de-dupe theo URI, giữ lastPlayed,
//    entry quét được mà file đã xóa → rớt khỏi danh sách.
//  - Như thư viện ĐỌC (TextDeviceProvider): chọn THƯ MỤC một lần (SAF tree),
//    quyền được persist ⇒ các lần sau tự quét lại (quét đệ quy, lọc đuôi
//    video ở Dart).
//  - Cộng kênh CHỌN FILE thủ công (file_picker) cho iOS/Windows/Linux và
//    các thư mục ngoài MediaStore.
//
// Trước đây service này CHỈ đọc manifest.json: không có cách nào thêm video
// ⇒ 3 lối vào (tab phụ Xem, tool Video, tool Thư viện video) đều hiện
// "Thêm video để bắt đầu học" mà không có nút thêm.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/text_device_channel.dart';
import '../../../services/video_library_channel.dart';
import '../models/video_info.dart';
import 'video_import_service.dart';

/// Service quản lý thư viện video
class VideoLibraryService {
  static VideoLibraryService? _instance;
  static VideoLibraryService get instance =>
      _instance ??= VideoLibraryService._();
  VideoLibraryService._();

  static const String _treeUriKey = 'in4up_video_device_tree_uri_v1';

  /// Đuôi file được coi là video khi quét thư mục / chọn file.
  static const Set<String> videoExtensions = {
    'mp4', 'm4v', 'mkv', 'webm', 'mov', 'avi', '3gp', '3g2',
    'flv', 'wmv', 'mpg', 'mpeg', 'ts', 'm2ts', 'mts', 'ogv',
  };

  final List<VideoInfo> _videos = [];
  bool _initialized = false;
  bool _scanning = false;
  bool _permissionGranted = false;
  String? _error;
  String? _treeUri;

  List<VideoInfo> get videos => List.unmodifiable(_videos);
  bool get isScanning => _scanning;
  bool get hasPermission => _permissionGranted;
  String? get error => _error;
  int get count => _videos.length;

  /// Nền tảng có native quét MediaStore (Android).
  bool get canScanDevice => VideoLibraryChannel.isSupported;

  /// Đã chọn thư mục để quét chưa (giống thư viện đọc).
  bool get hasFolder => _treeUri != null && _treeUri!.isNotEmpty;
  String? get treeUri => _treeUri;

  /// Tên thư mục đang quét (rút từ SAF tree URI).
  String get folderLabel {
    final uri = _treeUri;
    if (uri == null || uri.isEmpty) return '';
    final parts = uri.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return uri;
    final last = parts.last;
    final decoded = _safeDecode(last);
    final colon = decoded.lastIndexOf(':');
    final tail = colon >= 0 ? decoded.substring(colon + 1) : decoded;
    final segs = tail.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.isNotEmpty) return segs.last;
    if (tail.isNotEmpty) return tail;
    return decoded.split(':').first;
  }

  // ═══ Init / persistence ═══════════════════════════════════════════════

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadTreeUri();
    await _loadManifest();
  }

  Future<void> _loadTreeUri() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _treeUri = prefs.getString(_treeUriKey);
    } catch (e) {
      debugPrint('[VideoLibrary] load treeUri error: $e');
    }
  }

  Future<void> _saveTreeUri(String? uri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (uri == null || uri.isEmpty) {
        await prefs.remove(_treeUriKey);
      } else {
        await prefs.setString(_treeUriKey, uri);
      }
    } catch (e) {
      debugPrint('[VideoLibrary] save treeUri error: $e');
    }
  }

  // ═══ Quyền truy cập (như thư viện nhạc) ═══════════════════════════════

  /// Android 13+: READ_MEDIA_VIDEO · Android ≤12: READ_EXTERNAL_STORAGE.
  Future<bool> ensurePermission() async {
    Permission permission = Permission.videos;
    var status = await permission.status;
    if (!status.isGranted) {
      status = await permission.request();
    }
    if (!status.isGranted) {
      // Một số máy đời cũ / ROM tuỳ biến: Permission.videos không map đúng →
      // thử quyền storage truyền thống trước khi bỏ cuộc.
      final storage = await Permission.storage.request();
      _permissionGranted = storage.isGranted;
    } else {
      _permissionGranted = true;
    }
    return _permissionGranted;
  }

  // ═══ Quét ═════════════════════════════════════════════════════════════

  /// Quét MediaStore.Video (toàn máy, Android).
  Future<int> scanDevice({bool requirePermission = true}) async {
    if (!canScanDevice) {
      _error = 'unsupported';
      return 0;
    }
    if (requirePermission) {
      final granted = await ensurePermission();
      if (!granted) {
        _error = 'permission';
        return 0;
      }
    }
    await ensureInitialized();
    if (_scanning) return _videos.length;
    _scanning = true;
    _error = null;
    try {
      final raw = await VideoLibraryChannel.scanMediaStore();
      final scanned = <VideoInfo>[];
      for (final map in raw) {
        final uri = (map['uri'] ?? '').toString();
        if (uri.isEmpty) continue;
        final title = ((map['title'] as String?) ?? '').trim();
        final displayName = ((map['displayName'] as String?) ?? '').trim();
        final name = title.isNotEmpty ? title : displayName;
        if (name.isEmpty) continue;
        final durationMs = (map['durationMs'] as int?) ?? 0;
        final size = (map['sizeBytes'] as int?) ?? 0;
        final addedSec = (map['dateAddedSec'] as int?) ?? 0;
        scanned.add(
          VideoInfo(
            id: _idFromKey(uri),
            title: name,
            filePath: uri,
            duration: Duration(milliseconds: durationMs),
            addedAt: DateTime.fromMillisecondsSinceEpoch(
              addedSec > 0 ? addedSec * 1000 : DateTime.now().millisecondsSinceEpoch,
            ),
            source: VideoSource.media,
            sourceUri: uri,
            sizeBytes: size,
          ),
        );
      }
      _videos
        ..clear()
        ..addAll(mergeScanned(scanned, _videos, replaceSource: VideoSource.media));
      await _saveManifest();
      return _videos.length;
    } catch (e) {
      _error = e.toString();
      return _videos.length;
    } finally {
      _scanning = false;
    }
  }

  /// Chọn thư mục (SAF) rồi quét đệ quy — như tab Thiết bị của thư viện đọc.
  Future<bool> pickFolder() async {
    if (!canScanDevice) return false;
    final uri = await TextDeviceChannel.pickFolder();
    if (uri == null || uri.isEmpty) return false; // user huỷ
    final canonical = await TextDeviceChannel.normalizeTreeUri(uri);
    final finalUri = (canonical != null && canonical.isNotEmpty) ? canonical : uri;
    await TextDeviceChannel.keepTreePermission(finalUri);
    _treeUri = finalUri;
    _error = null;
    await _saveTreeUri(finalUri);
    await scanFolder();
    return true;
  }

  /// Quét lại thư mục đã chọn.
  Future<int> scanFolder() async {
    final uri = _treeUri;
    if (uri == null || uri.isEmpty || !canScanDevice) return 0;
    await ensureInitialized();
    if (_scanning) return _videos.length;
    _scanning = true;
    _error = null;
    try {
      final raw = await TextDeviceChannel.scanTree(uri);
      final scanned = <VideoInfo>[];
      for (final map in raw) {
        final fileUri = (map['uri'] ?? '').toString();
        final name = (map['name'] ?? '').toString();
        if (fileUri.isEmpty || name.isEmpty) continue;
        if (!_hasVideoExtension(name)) continue;
        final size = (map['sizeBytes'] as int?) ?? 0;
        final modified =
            (map['dateModifiedMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
        scanned.add(
          VideoInfo(
            id: _idFromKey(fileUri),
            title: name,
            filePath: fileUri,
            duration: Duration.zero,
            addedAt: DateTime.fromMillisecondsSinceEpoch(modified),
            source: VideoSource.folder,
            sourceUri: fileUri,
            sizeBytes: size,
          ),
        );
      }
      _videos
        ..clear()
        ..addAll(
            mergeScanned(scanned, _videos, replaceSource: VideoSource.folder));
      await _saveManifest();
      return _videos.length;
    } catch (e) {
      _error = e.toString();
      return _videos.length;
    } finally {
      _scanning = false;
    }
  }

  /// Bỏ chọn thư mục (dừng quét thư mục).
  Future<void> forgetFolder() async {
    _videos.removeWhere((v) => v.source == VideoSource.folder);
    _treeUri = null;
    _error = null;
    await _saveTreeUri(null);
    await _saveManifest();
  }

  // ═══ Chọn file thủ công (mọi nền tảng) ════════════════════════════════

  /// Thêm file do người dùng chọn: copy vào bộ nhớ app (tránh mất khi hệ
  /// thống dọn cache) rồi lưu vào thư viện.
  Future<int> addPickedFiles(List<VideoPick> picks) async {
    if (picks.isEmpty) return 0;
    await ensureInitialized();
    var added = 0;
    for (final pick in picks) {
      try {
        final imported = await VideoImportService.instance.ensurePersistent(
          sourcePath: pick.path,
          displayName: pick.name,
        );
        final existingIndex =
            _videos.indexWhere((v) => v.filePath == imported.path);
        if (existingIndex >= 0) continue; // đã có trong thư viện
        _videos.insert(
          0,
          VideoInfo(
            id: _idFromKey(imported.path),
            title: imported.displayName,
            filePath: imported.path,
            duration: Duration.zero,
            addedAt: DateTime.now(),
            source: VideoSource.picked,
            sourceUri: pick.originalUri,
            sizeBytes: imported.sizeBytes,
          ),
        );
        added++;
      } catch (e) {
        debugPrint('[VideoLibrary] import picked file error: $e');
      }
    }
    if (added > 0) await _saveManifest();
    return added;
  }

  // ═══ CRUD ═════════════════════════════════════════════════════════════

  Future<void> removeVideo(String videoId) async {
    await ensureInitialized();
    _videos.removeWhere((v) => v.id == videoId);
    await _saveManifest();
  }

  Future<void> markPlayed(String videoId, {Duration? duration}) async {
    await ensureInitialized();
    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index < 0) return;
    _videos[index] = _videos[index].copyWith(
      lastPlayedAt: DateTime.now(),
      duration: duration ?? _videos[index].duration,
    );
    await _saveManifest();
  }

  VideoInfo? findById(String id) {
    for (final v in _videos) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Đường dẫn PHÁT ĐƯỢC: content:// → copy sang cache (video_player không
  /// phát content:// ổn định). File thật bị mất ⇒ thử resolve lại từ URI gốc.
  Future<String> resolvePlayablePath(VideoInfo video) async {
    final path = video.filePath;
    if (!path.startsWith('content://')) {
      if (File(path).existsSync()) return path;
      final sourceUri = video.sourceUri;
      if (sourceUri != null && sourceUri.startsWith('content://')) {
        final resolved =
            await VideoLibraryChannel.copyContentToCache(sourceUri);
        if (resolved != null) {
          await _updateStoredPath(video.id, resolved);
          return resolved;
        }
      }
      return path;
    }
    final resolved = await VideoLibraryChannel.copyContentToCache(path);
    return resolved ?? path;
  }

  Future<void> _updateStoredPath(String id, String newPath) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index < 0) return;
    _videos[index] = _videos[index].copyWith(filePath: newPath);
    await _saveManifest();
  }

  /// Tìm theo tên (không dấu, contains) — như thư viện nhạc/đọc.
  List<VideoInfo> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return videos;
    return _videos
        .where((v) => v.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  // ═══ PURE helpers (test được) ═════════════════════════════════════════

  /// Key nhận diện một video: content URI nếu có, ngược lại path.
  static String keyOf(VideoInfo video) =>
      (video.sourceUri ?? video.filePath).toLowerCase();

  static String _idFromKey(String key) =>
      md5.convert(utf8.encode(key)).toString().substring(0, 16);

  /// Decode %XX an toàn cho nhãn thư mục SAF URI (cùng thuật toán với
  /// TextDeviceProvider._safeDecode — copy để không phụ thuộc).
  static String _safeDecode(String component) {
    try {
      return Uri.decodeComponent(component);
    } catch (_) {
      final bytes = <int>[];
      var i = 0;
      while (i < component.length) {
        final c = component[i];
        if (c == '%' && i + 2 < component.length) {
          final code =
              int.tryParse(component.substring(i + 1, i + 3), radix: 16);
          if (code != null) {
            bytes.add(code);
            i += 3;
            continue;
          }
        }
        bytes.addAll(utf8.encode(c));
        i++;
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static bool _hasVideoExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return false;
    return videoExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  /// Hợp nhất danh sách vừa quét với chỉ mục cũ (cùng thuật toán với
  /// `AudioLibraryService.mergeScanned`):
  ///  - entry mới → thêm (giữ lastPlayed của bản cũ nếu đã có);
  ///  - entry cũ thuộc CHÍNH nguồn vừa quét mà không còn → coi như đã xóa;
  ///  - entry nguồn khác (chọn tay) luôn giữ.
  static List<VideoInfo> mergeScanned(
    List<VideoInfo> scanned,
    List<VideoInfo> existing, {
    required VideoSource replaceSource,
  }) {
    final byKey = <String, VideoInfo>{for (final v in existing) keyOf(v): v};
    final merged = <VideoInfo>[];
    final seen = <String>{};

    for (final video in scanned) {
      final key = keyOf(video);
      if (seen.contains(key)) continue;
      seen.add(key);
      final old = byKey[key];
      merged.add(old != null ? video.copyWith(lastPlayedAt: old.lastPlayedAt) : video);
      byKey.remove(key);
    }

    for (final old in byKey.values) {
      if (old.source != replaceSource && !seen.contains(keyOf(old))) {
        merged.add(old);
      }
    }

    merged.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return merged;
  }

  // ═══ Manifest ═════════════════════════════════════════════════════════

  Future<String> get _manifestPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'videos', 'manifest.json');
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

/// File do người dùng chọn qua file_picker.
class VideoPick {
  final String path;
  final String name;

  /// content:// URI gốc nếu có (để resolve lại khi file cache bị xóa).
  final String? originalUri;

  const VideoPick({required this.path, required this.name, this.originalUri});
}
