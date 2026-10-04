// lib/providers/text_device_provider.dart
// Thư viện đọc (tab Thiết bị) — quét thư mục trên máy (SAF tree, Android).
//
// Tương tự AudioLibraryProvider (thư viện nhạc quét MediaStore), nhưng văn
// bản KHÔNG có trong MediaStore (scoped storage chặn quyền đọc tùy ý) nên
// dùng cơ chế người dùng CHỌN THƯ MỤC (ACTION_OPEN_DOCUMENT_TREE — mở
// TRỰC TIẾP từ native qua TextDeviceChannel.pickFolder, xem bên dưới) +
// native DocumentsContract liệt kê đệ quy. Chỉ cần 1 lần chọn → quyền
// persist ngay trong onActivityResult → lần sau tự quét lại.
//
// ⚠️ Tại sao KHÔNG dùng FilePicker.getDirectoryPath cho luồng quét này:
// plugin trả RAW FILE PATH (/storage/3033-3963/...) chứ không phải SAF
// content:// tree URI → native DocumentsContract.getTreeDocumentId throw
// "Invalid URI", takePersistableUriPermission throw SecurityException →
// quét ra rỗng, UI báo "không tìm thấy file" dù thư mục có file.
// Lịch sử: bản cũ từng lưu raw path vào prefs → _migrateLegacyFolder()
// chuẩn hoá một lần và cố persist lại quyền.
//
// Nền tảng khác (iOS/Linux/Windows): supported = false → UI rơi về chọn
// file thủ công (FilePicker) như trước.

import 'dart:convert' show utf8;
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
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

  /// Tên thư mục hiện trên UI.
  ///
  /// Tree URI chuẩn (`content://.../tree/<volume>%3A<đường%2Fdẫn>`) hoặc
  /// legacy raw path (`/storage/.../<tên thư mục>`) đều rút ra TÊN thư mục
  /// (segment cuối) thay vì nguyên đường dẫn dài.
  /// Giải mã %XX AN TOÀN: nếu URI có percent-encoding lỗi (vd tên thư mục
  /// chứa ký tự đặc biệt), KHÔNG throw — chỉ decode các cặp %XX hợp lệ,
  /// giữ nguyên phần còn lại (tránh màn đỏ "Illegal percent encoding").
  String get folderLabel {
    final uri = _treeUri;
    if (uri == null || uri.isEmpty) return '';
    final parts = uri.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return uri;
    final last = parts.last;
    // Decode %XX an toàn: chỉ decode cặp %XX hợp lệ, giữ nguyên % lỗi.
    final decoded = safeDecodeComponent(last);
    // Tree URI chuẩn: "<volume>:<đường/dẫn/tới/thư mục>" → bỏ volume id,
    // lấy segment cuối sau dấu "/".
    final colon = decoded.lastIndexOf(':');
    final tail = colon >= 0 ? decoded.substring(colon + 1) : decoded;
    final segs = tail.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.isNotEmpty) return segs.last;
    if (tail.isNotEmpty) return tail;
    // Chọn ngay root của ổ (vd "3033-3963:") → hiện tên ổ.
    return decoded.split(':').first;
  }

  /// Uri.decodeComponent an toàn: decode %XX hợp lệ (UTF-8), giữ nguyên
  /// % lỗi — KHÔNG throw "Illegal percent encoding in URI" (tránh màn đỏ
  /// khi tên thư mục chứa ký tự làm file_picker encode sai).
  static String safeDecodeComponent(String component) {
    try {
      return Uri.decodeComponent(component);
    } catch (_) {
      // Percent-encoding lỗi → decode thủ công: %XX hợp lệ → byte UTF-8,
      // % lỗi → giữ nguyên ký tự. allowMalformed=true cho chuỗi UTF-8 gãy.
      final bytes = <int>[];
      var i = 0;
      while (i < component.length) {
        final c = component[i];
        if (c == '%' && i + 2 < component.length) {
          final code = int.tryParse(
            component.substring(i + 1, i + 3),
            radix: 16,
          );
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
    String? uri;
    try {
      // Ưu tiên picker native (ACTION_OPEN_DOCUMENT_TREE mở trực tiếp từ
      // MainActivity): trả CONTENT:// tree URI thật + đã persist quyền đọc
      // ngay trong onActivityResult. KHÔNG dùng FilePicker.getDirectoryPath
      // — hàm đó trả RAW PATH (/storage/...) khiến DocumentsContract không
      // đọc được (bug "không tìm thấy file" dù thư mục có file).
      uri = await TextDeviceChannel.pickFolder();
    } on MissingPluginException {
      // Native build bởi bản code cũ chưa có pickFolder → fallback
      // file_picker; đoạn dưới sẽ normalize raw path → content:// và cố
      // persist grant (grant tạm thời còn trong phiên ngay sau khi chọn).
      debugPrint('[TextDevice] native pickFolder chưa có → dùng file_picker');
      try {
        uri = await FilePicker.getDirectoryPath(
          dialogTitle: 'Chọn thư mục chứa tài liệu',
        );
      } catch (e) {
        debugPrint('[TextDevice] getDirectoryPath error: $e');
        return false;
      }
    } catch (e) {
      debugPrint('[TextDevice] pickFolder error: $e');
      _error = 'Không mở được trình chọn thư mục.';
      notifyListeners();
      return false;
    }
    if (uri == null || uri.isEmpty) return false; // user hủy

    // Chuẩn hoá về content:// tree URI (legacy raw path → SAF URI) rồi giữ
    // persistable permission. Với URI từ native picker: đã persist sẵn —
    // gọi lại vẫn an toàn (no-op).
    final canonical = await TextDeviceChannel.normalizeTreeUri(uri);
    if (canonical != null && canonical.isNotEmpty) uri = canonical;
    await TextDeviceChannel.keepTreePermission(uri);

    _treeUri = uri;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_treeUriKey, uri);
    } catch (e) {
      debugPrint('[TextDevice] save treeUri error: $e');
    }
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
      // TextDeviceScanException (PERMISSION_LOST/BAD_URI): message tiếng
      // Việt có hướng khắc phục — UI hiện lên + nút "Chọn thư mục khác".
      _error = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Quét lần đầu khi mở tab (idempotent).
  Future<void> ensureScanned() async {
    await init();
    await _migrateLegacyFolder();
    if (hasFolder && !_scannedOnce && !_scanning) {
      await scan();
    }
  }

  /// Bản cũ lưu RAW PATH (/storage/... từ file_picker) thay vì content://
  /// tree URI → native không quét được ("không tìm thấy file" dù có file).
  /// Chuẩn hoá một lần về SAF URI rồi cập nhật prefs; nếu grant từ lần chọn
  /// cũ còn (persisted) → quét luôn được. Không còn grant → scan báo lỗi
  /// PERMISSION_LOST rõ ràng, hướng user chọn lại thư mục (thay vì lặng
  /// lặng hiện "thư mục trống" như trước).
  Future<void> _migrateLegacyFolder() async {
    final uri = _treeUri;
    if (uri == null || uri.isEmpty || !supported) return;
    if (uri.startsWith('content://')) return; // đã chuẩn
    final canonical = await TextDeviceChannel.normalizeTreeUri(uri);
    if (canonical == null || canonical.isEmpty || canonical == uri) return;
    final kept = await TextDeviceChannel.keepTreePermission(canonical);
    _treeUri = canonical;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_treeUriKey, canonical);
    } catch (e) {
      debugPrint('[TextDevice] migrate save error: $e');
    }
    debugPrint(
      '[TextDevice] legacy folder → $canonical (keptPermission=$kept)',
    );
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
