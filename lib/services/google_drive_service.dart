//
// Google Drive integration cho in4up
// Cho phép duyệt và stream/tải file âm thanh từ Google Drive
//
// SETUP:
// 1. Thêm vào pubspec.yaml:
//    google_sign_in: ^6.2.1
//    googleapis: ^13.2.0
//    http: ^1.2.1 (đã có)
//
// 2. Android: thêm SHA-1 fingerprint vào Firebase Console
//    + bật Google Sign-In trong Authentication
//
// 3. iOS: thêm GoogleService-Info.plist + URL scheme
//
// 4. Bật Google Drive API tại:
//    https://console.cloud.google.com/ → APIs & Services → Library

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─── Model: file / thư mục từ Drive ─────────────────────
class DriveItem {
  final String id;
  final String name;
  final String? mimeType;
  final int? size;
  final String? thumbnailLink;
  final DateTime? modifiedTime;
  final bool isFolder;

  const DriveItem({
    required this.id,
    required this.name,
    this.mimeType,
    this.size,
    this.thumbnailLink,
    this.modifiedTime,
    required this.isFolder,
  });

  /// Extension của file
  String get extension {
    final parts = name.split('.');
    if (parts.length > 1) return parts.last.toLowerCase();
    return '';
  }

  /// Label kích thước
  String get sizeLabel {
    if (size == null) return '';
    if (size! >= 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size! >= 1024) {
      return '${(size! / 1024).toStringAsFixed(0)} KB';
    }
    return '$size B';
  }

  factory DriveItem.fromFile(drive.File f) {
    return DriveItem(
      id: f.id ?? '',
      name: f.name ?? 'Untitled',
      mimeType: f.mimeType,
      size: f.size != null ? int.tryParse(f.size!) : null,
      thumbnailLink: f.thumbnailLink,
      modifiedTime: f.modifiedTime,
      isFolder: f.mimeType == 'application/vnd.google-apps.folder',
    );
  }
}

// ─── MIME types âm thanh hỗ trợ ──────────────────────────
const _audioMimes = {
  'audio/mpeg', // mp3
  'audio/mp4', // m4a, mp4
  'audio/x-m4a',
  'audio/ogg', // ogg
  'audio/wav', // wav
  'audio/x-wav',
  'audio/flac', // flac
  'audio/x-flac',
  'audio/aac', // aac
  'audio/webm',
};

const _audioExtensions = {
  'mp3',
  'm4a',
  'mp4',
  'ogg',
  'wav',
  'flac',
  'aac',
  'webm',
  'm4b',
  'opus',
};

bool _isAudioFile(DriveItem item) {
  if (item.isFolder) return false;
  if (_audioMimes.contains(item.mimeType)) return true;
  return _audioExtensions.contains(item.extension);
}

// ─── HTTP client dùng Google auth ────────────────────────
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;

  _AuthenticatedClient(this._headers) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}

// ─── Google Drive Service ─────────────────────────────────
class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService _instance = GoogleDriveService._();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._();

  static const _scopes = [
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;

  bool _isLoading = false;
  String? _error;

  // Cache breadcrumb navigation
  final List<({String id, String name})> _breadcrumb = [
    (id: 'root', name: 'My Drive'),
  ];

  // Getters
  bool get isSignedIn => _account != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  GoogleSignInAccount? get account => _account;
  List<({String id, String name})> get breadcrumb =>
      List.unmodifiable(_breadcrumb);
  String get currentFolderId => _breadcrumb.last.id;
  String get currentFolderName => _breadcrumb.last.name;

  // ── Sign In ───────────────────────────────────────────
  Future<bool> signIn() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Thử sign in im lặng trước
      _account = await _googleSignIn.signInSilently();
      _account ??= await _googleSignIn.signIn();

      if (_account == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _initDriveApi();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Enter';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _initDriveApi() async {
    final headers = await _account!.authHeaders;
    final client = _AuthenticatedClient(headers);
    _driveApi = drive.DriveApi(client);
  }

  // ── Sign Out ──────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _driveApi = null;
    _breadcrumb.clear();
    _breadcrumb.add((id: 'root', name: 'My Drive'));
    notifyListeners();
  }

  // ── List files/folders ───────────────────────────────
  Future<List<DriveItem>> listItems({
    String? folderId,
    bool audioOnly = false,
    String? nameFilter,
  }) async {
    if (_driveApi == null) {
      if (!await signIn()) return [];
    }

    try {
      final folder = folderId ?? currentFolderId;
      final results = <DriveItem>[];

      // Xây dựng query
      String query = "'$folder' in parents and trashed = false";

      if (audioOnly) {
        // Lấy cả thư mục + file âm thanh
        final audioMimeQuery =
            _audioMimes.map((m) => "mimeType = '$m'").join(' or ');
        query +=
            " and (mimeType = 'application/vnd.google-apps.folder' or $audioMimeQuery)";
      }

      if (nameFilter != null && nameFilter.isNotEmpty) {
        query += " and name contains '$nameFilter'";
      }

      String? pageToken;
      do {
        final fileList = await _driveApi!.files.list(
          q: query,
          spaces: 'drive',
          $fields:
              'nextPageToken, files(id, name, mimeType, size, thumbnailLink, modifiedTime)',
          orderBy: 'folder, name',
          pageSize: 100,
          pageToken: pageToken,
        );

        final items =
            (fileList.files ?? []).map((f) => DriveItem.fromFile(f)).toList();

        // Filter thêm bằng extension nếu cần
        if (audioOnly) {
          results.addAll(items.where(
            (item) => item.isFolder || _isAudioFile(item),
          ));
        } else {
          results.addAll(items);
        }

        pageToken = fileList.nextPageToken;
      } while (pageToken != null);

      return results;
    } catch (e) {
      debugPrint('GoogleDriveService.listItems error: $e');
      // Token có thể hết hạn → refresh
      if (e.toString().contains('401') || e.toString().contains('403')) {
        await _refreshToken();
        return listItems(
            folderId: folderId, audioOnly: audioOnly, nameFilter: nameFilter);
      }
      _error = 'Content';
      notifyListeners();
      return [];
    }
  }

  Future<void> _refreshToken() async {
    try {
      await _account!.clearAuthCache();
      await _initDriveApi();
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }
  }

  // ── Navigate into folder ─────────────────────────────
  void enterFolder(DriveItem folder) {
    if (!folder.isFolder) return;
    _breadcrumb.add((id: folder.id, name: folder.name));
    notifyListeners();
  }

  void navigateToIndex(int index) {
    if (index < 0 || index >= _breadcrumb.length) return;
    _breadcrumb.removeRange(index + 1, _breadcrumb.length);
    notifyListeners();
  }

  void goBack() {
    if (_breadcrumb.length > 1) {
      _breadcrumb.removeLast();
      notifyListeners();
    }
  }

  // ── Get streaming URL ────────────────────────────────
  // just_audio có thể stream trực tiếp từ URL với headers
  Future<({String url, Map<String, String> headers})?> getStreamInfo(
      String fileId) async {
    if (_driveApi == null) return null;
    try {
      final headers = await _account!.authHeaders;
      final url = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
      return (url: url, headers: headers);
    } catch (e) {
      debugPrint('getStreamInfo error: $e');
      return null;
    }
  }

  // ── Download to cache ────────────────────────────────
  /// Tải file về cache local để phát offline
  Future<String?> downloadToCache(DriveItem item,
      {void Function(double)? onProgress}) async {
    if (_driveApi == null) return null;

    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFolder = Directory('${cacheDir.path}/drive_cache');
      if (!await cacheFolder.exists()) {
        await cacheFolder.create(recursive: true);
      }

      // Dùng id để tạo tên file cache (unique + stable)
      final safeExt = item.extension.isNotEmpty ? '.${item.extension}' : '';
      final cachePath = '${cacheFolder.path}/${item.id}$safeExt';

      // Đã cache rồi?
      final cached = File(cachePath);
      if (await cached.exists() && await cached.length() > 1000) {
        debugPrint('Drive cache HIT: ${item.name}');
        return cachePath;
      }

      // Download
      final headers = await _account!.authHeaders;
      final url =
          'https://www.googleapis.com/drive/v3/files/${item.id}?alt=media';

      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);

      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        debugPrint('Drive download error: ${response.statusCode}');
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      int received = 0;
      final sink = cached.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(received / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      debugPrint('Drive download done: ${item.name} → $cachePath');
      return cachePath;
    } catch (e) {
      debugPrint('Drive download error: $e');
      return null;
    }
  }

  // ── Tìm kiếm âm thanh toàn Drive ─────────────────────
  Future<List<DriveItem>> searchAudio(String query) async {
    if (_driveApi == null) {
      if (!await signIn()) return [];
    }

    try {
      final audioMimeQuery =
          _audioMimes.map((m) => "mimeType = '$m'").join(' or ');
      final q =
          "($audioMimeQuery) and name contains '$query' and trashed = false";

      final fileList = await _driveApi!.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size, thumbnailLink, modifiedTime)',
        orderBy: 'name',
        pageSize: 50,
      );

      return (fileList.files ?? [])
          .map((f) => DriveItem.fromFile(f))
          .where((item) => _isAudioFile(item))
          .toList();
    } catch (e) {
      debugPrint('Drive search error: $e');
      return [];
    }
  }

  // ── Cache management ──────────────────────────────────
  Future<double> getCacheSizeMB() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final folder = Directory('${cacheDir.path}/drive_cache');
      if (!await folder.exists()) return 0;

      double total = 0;
      await for (final entity in folder.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final folder = Directory('${cacheDir.path}/drive_cache');
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } catch (_) {}
  }
}