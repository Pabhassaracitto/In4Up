// lib/services/text_device_channel.dart
// Wrapper MethodChannel "in4up/textlib" (native Android — MainActivity.kt).
//
// An toàn đa nền tảng: mọi lỗi / MissingPluginException (iOS/Windows/Linux
// chưa có native) đều bị bắt → trả rỗng/false để UI hiện trạng thái
// "chưa hỗ trợ" và rơi về phương án chọn file thủ công.
//
// NGOẠI LỆ có chủ đích: scanTree NÉM [TextDeviceScanException] khi native
// báo PERMISSION_LOST / BAD_URI — lỗi này có hành động khắc phục (chọn lại
// thư mục); nuốt lặng sẽ khiến UI tưởng nhầm "thư mục trống" (bug:
// file_picker trả raw path /storage/... → DocumentsContract Invalid URI →
// app báo "không tìm thấy file" dù thư mục có file).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lỗi quét thư mục có hướng khắc phục rõ ràng (mất quyền / URI hỏng) —
/// message tiếng Việt hiển thị trực tiếp lên UI qua provider.error.
class TextDeviceScanException implements Exception {
  final String message;
  const TextDeviceScanException(this.message);
  @override
  String toString() => message;
}

/// Dừng quét chủ động (user bấm Dừng hoặc chọn thư mục khác khi đang quét).
class TextDeviceScanCancelledException implements Exception {
  const TextDeviceScanCancelledException();
}

typedef TextDeviceScanProgressCallback = void Function(
  int count,
  String currentFolder,
);

typedef TextDeviceMethodInvoker = Future<Object?> Function(
  String method, [
  Map<String, Object?>? arguments,
]);

class TextDeviceChannel {
  static const MethodChannel _channel = MethodChannel('in4up/textlib');

  static bool _handlerRegistered = false;
  static final Map<String, TextDeviceScanProgressCallback> _progressListeners =
      {};

  /// Seam cho unit test trên host VM (không cần Android thật).
  @visibleForTesting
  static TextDeviceMethodInvoker? invokeOverride;

  static Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final override = invokeOverride;
    if (override != null) {
      final res = await override(method, arguments);
      return res as T?;
    }
    return _channel.invokeMethod<T>(method, arguments);
  }

  static void _ensureHandlerRegistered() {
    if (_handlerRegistered || invokeOverride != null) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScanProgress') {
        final args = call.arguments;
        if (args is Map) {
          final scanId = (args['scanId'] ?? '').toString();
          final count = (args['count'] as num?)?.toInt() ?? 0;
          final folder = (args['folder'] ?? '').toString();
          _progressListeners[scanId]?.call(count, folder);
        }
      }
      return null;
    });
  }

  /// Cho phép test mô phỏng sự kiện tiến độ quét từ native.
  @visibleForTesting
  static void dispatchProgressForTesting({
    required String scanId,
    required int count,
    String folder = '',
  }) {
    _progressListeners[scanId]?.call(count, folder);
  }

  /// Mở trình chọn thư mục hệ thống (ACTION_OPEN_DOCUMENT_TREE) trực tiếp
  /// từ native → trả CONTENT:// tree URI THẬT, đã takePersistableUriPermission
  /// sẵn trong onActivityResult.
  ///
  /// Trả null = user hủy. NÉM [MissingPluginException] khi native chưa có
  /// (app build bởi bản code cũ) → caller fallback FilePicker.
  static Future<String?> pickFolder() async {
    try {
      return await _invoke<String>('pickFolder');
    } on MissingPluginException {
      rethrow; // để provider biết mà fallback file_picker
    } catch (e) {
      // PICKER_BUSY / PICKER_UNAVAILABLE... — coi như hủy, không mở thêm
      // picker khác chồng lên.
      debugPrint('[TextDevice] pickFolder error: $e');
      return null;
    }
  }

  /// Chuẩn hoá về SAF tree URI (content://): legacy raw path
  /// (/storage/3033-3963/... do file_picker trả ở bản cũ) →
  /// content://com.android.externalstorage.documents/tree/<docId>.
  /// content:// sẵn → giữ nguyên. Không đổi được → null.
  static Future<String?> normalizeTreeUri(String treeUri) async {
    try {
      return await _invoke<String>(
        'normalizeTreeUri',
        {'treeUri': treeUri},
      );
    } on MissingPluginException {
      return treeUri; // native cũ: giữ nguyên (chạy như trước, tự chịu lỗi)
    } catch (e) {
      debugPrint('[TextDevice] normalizeTreeUri error: $e');
      return null;
    }
  }

  /// Quét ĐỆ QUY tree URI (SAF) → danh sách map thô của file đọc được.
  /// Mỗi map: { uri, name, relativePath, sizeBytes, dateModifiedMs, ext }.
  ///
  /// [extensions] lọc theo đuôi file (chữ thường, KHÔNG kèm dấu chấm);
  /// null/rỗng → native dùng bộ mặc định (text). Truyền `''` để lấy cả
  /// file KHÔNG có đuôi (phontab/phonindex… của espeak-ng-data).
  ///
  /// NÉM [TextDeviceScanException] khi mất quyền (PERMISSION_LOST) hoặc
  /// đường dẫn hỏng (BAD_URI) — có hướng khắc phục, không nuốt lặng.
  static Future<List<Map<String, dynamic>>> scanTree(
    String treeUri, {
    List<String>? extensions,
    String? scanId,
    TextDeviceScanProgressCallback? onProgress,
  }) async {
    if (scanId != null && scanId.isNotEmpty && onProgress != null) {
      _ensureHandlerRegistered();
      _progressListeners[scanId] = onProgress;
    }
    try {
      final raw = await _invoke<List<dynamic>>(
        'scanTree',
        {
          'treeUri': treeUri,
          if (extensions != null && extensions.isNotEmpty)
            'extensions': extensions,
          if (scanId != null && scanId.isNotEmpty) 'scanId': scanId,
        },
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on MissingPluginException {
      debugPrint('[TextDevice] scanTree: native không có (phi Android)');
      return const [];
    } on PlatformException catch (e) {
      if (e.code == 'SCAN_CANCELLED') {
        throw const TextDeviceScanCancelledException();
      }
      if (e.code == 'PERMISSION_LOST') {
        throw const TextDeviceScanException(
          'Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). '
          'Chạm "Chọn thư mục khác" để cấp lại quyền.',
        );
      }
      if (e.code == 'BAD_URI') {
        throw const TextDeviceScanException(
          'Đường dẫn thư mục không hợp lệ — chạm "Chọn thư mục khác" '
          'để chọn lại.',
        );
      }
      debugPrint('[TextDevice] scanTree error: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      if (e is TextDeviceScanCancelledException ||
          e is TextDeviceScanException) {
        rethrow;
      }
      debugPrint('[TextDevice] scanTree error: $e');
      return const [];
    } finally {
      if (scanId != null && scanId.isNotEmpty) {
        _progressListeners.remove(scanId);
      }
    }
  }

  /// Yêu cầu native dừng lượt quét [scanId] đang chạy trên executor nền.
  static Future<void> cancelScanTree(String scanId) async {
    if (scanId.isEmpty) return;
    _progressListeners.remove(scanId);
    try {
      await _invoke<bool>('cancelScanTree', {'scanId': scanId});
    } on MissingPluginException {
      // Native bản cũ không hỗ trợ cancel — Dart vẫn bỏ qua kết quả bằng token.
    } catch (e) {
      debugPrint('[TextDevice] cancelScanTree error: $e');
    }
  }

  /// Giữ persistable permission cho tree URI (gọi sau khi user chọn thư
  /// mục) → lần mở app sau vẫn quét được, không cần chọn lại.
  /// Native tự normalize raw path legacy → SAF URI trước khi persist.
  static Future<bool> keepTreePermission(String treeUri) async {
    try {
      final ok = await _invoke<bool>(
        'keepTreePermission',
        {'treeUri': treeUri},
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('[TextDevice] keepTreePermission error: $e');
      return false;
    }
  }

  /// Copy content:// sang cache dir → trả path file thật (để loadTextFile /
  /// PdfReaderScreen — cả hai cần File path, không đọc được content://).
  /// Nếu [uri] không phải content:// → trả nguyên uri. Lỗi → null.
  static Future<String?> copyContentToCache(String uri) async {
    if (!uri.startsWith('content://')) return uri;
    try {
      final path = await _invoke<String>(
        'copyContentToCache',
        {'uri': uri},
      );
      return path;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('[TextDevice] copyContentToCache error: $e');
      return null;
    }
  }

  /// Copy 1 document SAF sang ĐƯỜNG DẪN thật do Dart chỉ định.
  ///
  /// M4U-IMPORT-002: import model (STT/Piper) cần đường dẫn file thật vì
  /// `dart:io` không đọc được `content://`. Native copy nền (file model
  /// nặng hàng trăm MB ⇒ không copy trên luồng chính).
  ///
  /// Trả true = copy thành công; false = lỗi (URI hỏng / mất quyền).
  static Future<bool> copyDocumentToPath(
    String uri,
    String destination,
  ) async {
    try {
      final ok = await _invoke<bool>(
        'copyDocumentToPath',
        {'uri': uri, 'destination': destination},
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('[TextDevice] copyDocumentToPath error: $e');
      return false;
    }
  }
}
