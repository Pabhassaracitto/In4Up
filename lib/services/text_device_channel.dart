// lib/services/text_device_channel.dart
// Wrapper MethodChannel "in4up/textlib" (native Android — MainActivity.kt).
//
// An toàn đa nền tảng: mọi lỗi / MissingPluginException (iOS/Windows/Linux
// chưa có native) đều bị bắt → trả rỗng/false để UI hiện trạng thái
// "chưa hỗ trợ" và rơi về phương án chọn file thủ công.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TextDeviceChannel {
  static const MethodChannel _channel = MethodChannel('in4up/textlib');

  /// Quét TÙY DUYỆT tree URI (SAF) → danh sách map thô của file đọc được.
  /// Mỗi map: { uri, name, sizeBytes, dateModifiedMs, ext }.
  static Future<List<Map<String, dynamic>>> scanTree(String treeUri) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'scanTree',
        {'treeUri': treeUri},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on MissingPluginException {
      debugPrint('[TextDevice] scanTree: native không có (phi Android)');
      return const [];
    } catch (e) {
      debugPrint('[TextDevice] scanTree error: $e');
      return const [];
    }
  }

  /// Giữ persistable permission cho tree URI (gọi sau khi user chọn thư
  /// mục qua file_picker) → lần mở app sau vẫn quét được, không cần chọn lại.
  static Future<bool> keepTreePermission(String treeUri) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
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
      final path = await _channel.invokeMethod<String>(
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
}
