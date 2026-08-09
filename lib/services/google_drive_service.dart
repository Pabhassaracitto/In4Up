import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─── Data Model ───────────────────────────────────────────
class DriveItem {
  final String id;
  final String name;
  final String mimeType;
  final int? size;

  DriveItem({
    required this.id,
    required this.name,
    required this.mimeType,
    this.size,
  });

  bool get isFolder =>
      mimeType == 'application/vnd.google-apps.folder';

  String get extension {
    final idx = name.lastIndexOf('.');
    return idx != -1 ? name.substring(idx + 1).toLowerCase() : '';
  }

  String get sizeLabel {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Authenticated Client ──────────────────────────────────
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
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

  // ── Sign In & Out ─────────────────────────────────────────
  Future<bool> signIn() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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
      _error = 'Lỗi đăng nhập: $e';
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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _driveApi = null;
    _breadcrumb.clear();
    _breadcrumb.add((id: 'root', name: 'My Drive'));
    notifyListeners();
  }

  // ── Navigation ────────────────────────────────────────────
  void enterFolder(DriveItem item) {
    if (!item.isFolder) return;
    _breadcrumb.add((id: item.id, name: item.name));
    notifyListeners();
  }

  void goBack() {
    if (_breadcrumb.length > 1) {
      _breadcrumb.removeLast();
      notifyListeners();
    }
  }

  void navigateToIndex(int index) {
    if (index >= 0 && index < _breadcrumb.length) {
      _breadcrumb.removeRange(index + 1, _breadcrumb.length);
      notifyListeners();
    }
  }

 // ── File Operations ───────────────────────────────────────
  Future<List<DriveItem>> listItems({bool audioOnly = true}) async {
    if (_driveApi == null) return [];

    try {
      String q = "'$currentFolderId' in parents and trashed = false";
      if (audioOnly) {
        q += " and (mimeType contains 'audio/' or mimeType = 'application/vnd.google-apps.folder')";
      }

      // Đã bỏ $fields: 'files(...)'$
      final fileList = await _driveApi!.files.list(
        q: q,
        pageSize: 100,
        orderBy: 'folder,name',
      );

      return (fileList.files ?? [])
          .map((f) => DriveItem(
                id: f.id ?? '',
                name: f.name ?? 'Không tên',
                mimeType: f.mimeType ?? '',
                size: f.size != null ? int.tryParse(f.size!) : null,
              ))
          .toList();
    } catch (e) {
      _error = 'Lỗi tải danh sách: $e';
      notifyListeners();
      return [];
    }
  }

  Future<List<DriveItem>> searchAudio(String query) async {
    if (_driveApi == null || query.trim().isEmpty) return [];

    try {
      final safeQuery = query.replaceAll("'", "\\'");
      final q = "trashed = false and mimeType contains 'audio/' and name contains '$safeQuery'";

      // Đã bỏ $fields: 'files(...)'$
      final fileList = await _driveApi!.files.list(
        q: q,
        pageSize: 50,
      );

      return (fileList.files ?? [])
          .map((f) => DriveItem(
                id: f.id ?? '',
                name: f.name ?? 'Không tên',
                mimeType: f.mimeType ?? '',
                size: f.size != null ? int.tryParse(f.size!) : null,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<({String url, Map<String, String> headers})?> getStreamInfo(String fileId) async {
    if (_account == null) return null;
    final headers = await _account!.authHeaders;
    final url = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
    return (url: url, headers: headers);
  }

  Future<String?> downloadToCache(
    DriveItem item, {
    void Function(double progress)? onProgress,
  }) async {
    if (_driveApi == null) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final saveFile = File('${tempDir.path}/${item.id}_${item.name}');

      if (await saveFile.exists() && (item.size == null || await saveFile.length() == item.size)) {
        return saveFile.path;
      }

      final drive.Media media = await _driveApi!.files.get(
        item.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final totalBytes = item.size ?? 0;
      int downloadedBytes = 0;
      final sink = saveFile.openWrite();

      await for (final chunk in media.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await sink.close();
      return saveFile.path;
    } catch (e) {
      return null;
    }
  }
}