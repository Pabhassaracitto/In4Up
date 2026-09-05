// lib/providers/text_device_provider.dart
// Thư viện đọc (tab Thiết bị) — quét thư mục trên máy (SAF tree, Android).
//
// Tương tự AudioLibraryProvider (thư viện nhạc quét MediaStore), nhưng văn
// bản KHÔNG có trong MediaStore (scoped storage chặn quyền đọc tùy ý) nên
// dùng cơ chế người dùng CHỌN THƯ MỤC (ACTION_OPEN_DOCUMENT_TREE qua
// file_picker) + native DocumentsContract liệt kê đệ quy. Chỉ cần 1 lần
// chọn → quyền persist (keepTreePermission) → lần sau tự quét lại.
//
// Nền tảng khác (iOS/Linux/Windows): supported = false → UI rơi về chọn
// file thủ công (FilePicker) như trước.

import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/text_device_entry.dart';
import '../services/text_device_channel.dart';

class TextDeviceProvider extends ChangeNotifier {
  static const String _treeUriKey = 'in4up_read_device_tree_uri_v1';

  List<TextDeviceEntry> _entries = [];
  bool _scanning = false;
  bool _scannedOnce = false;
  bool _initialized = false;
  String? _treeUri;
  String? _error;

  List<TextDeviceEntry> get entries => List.unmodifiable(_entries);
  bool get isScanning => _scanning;
  bool get hasScannedOnce => _scannedOnce;
  bool get initialized => _initialized;
  String? get error => _error;
  String? get treeUri => _treeUri;
  int get count => _entries.length;

  /// Nền tảng có native scan (Android).
  bool get supported => !kIsWeb && Platform.isAndroid;

  /// Đã chọn thư mục chưa?
  bool get hasFolder => _treeUri != null && _treeUri!.isNotEmpty;

  /// Tên thư mục (segment cuối của tree URI) để hiện trên UI.
  String get folderLabel {
    final uri = _treeUri;
    if (uri == null || uri.isEmpty) return '';
    final parts = uri.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return uri;
    final last = parts.last;
    // URI dạng .../tree/primary%3ADocuments — giải mã %3A → ':'
    final decoded = Uri.decodeComponent(last);
    final colon = decoded.lastIndexOf(':');
    return colon >= 0 ? decoded.substring(colon + 1) : decoded;
  }

  /// Nạp tree URI đã lưu (gọi 1 lần lúc app khởi động — nhẹ, không quét).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _treeUri = prefs.getString(_treeUriKey);
    } catch (e) {
      debugPrint('[TextDevice] init error: $e');
    }
    notifyListeners();
  }

  /// Mở trình chọn thư mục hệ thống (SAF) → lưu URI → giữ quyền → quét.
  /// Trả về true nếu user chọn (hủy → false).
  Future<bool> pickFolder() async {
    if (!supported) return false;
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Chọn thư mục chứa tài liệu',
      );
    } catch (e) {
      debugPrint('[TextDevice] getDirectoryPath error: $e');
      return false;
    }
    if (path == null || path.isEmpty) return false;

    _treeUri = path;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_treeUriKey, path);
    } catch (e) {
      debugPrint('[TextDevice] save treeUri error: $e');
    }
    // Giữ persistable permission (an toàn nếu file_picker chưa tự giữ).
    await TextDeviceChannel.keepTreePermission(path);
    notifyListeners();
    await scan();
    return true;
  }

  /// Quét lại thư mục đã chọn (chỉ quét khi đã chọn + nền tảng hỗ trợ).
  Future<void> scan() async {
    final uri = _treeUri;
    if (uri == null || uri.isEmpty || !supported) return;
    if (_scanning) return;
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await TextDeviceChannel.scanTree(uri);
      _entries = raw
          .where((m) => (m['uri'] ?? '').toString().isNotEmpty)
          .map(TextDeviceEntry.fromMap)
          .toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      _scannedOnce = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Quét lần đầu khi mở tab (idempotent).
  Future<void> ensureScanned() async {
    await init();
    if (hasFolder && !_scannedOnce && !_scanning) {
      await scan();
    }
  }

  /// Bỏ chọn thư mục (xóa quyền ghi nhớ + làm trống danh sách).
  Future<void> forgetFolder() async {
    _treeUri = null;
    _entries = [];
    _scannedOnce = false;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_treeUriKey);
    } catch (e) {
      debugPrint('[TextDevice] forgetFolder error: $e');
    }
    notifyListeners();
  }

  /// Tìm theo tên (chữ thường, contains).
  List<TextDeviceEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.name.toLowerCase().contains(q))
        .toList();
  }
}
