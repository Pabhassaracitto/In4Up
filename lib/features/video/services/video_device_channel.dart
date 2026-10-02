// lib/features/video/services/video_device_channel.dart
// I4U18-VIDEO-LIB-001 — Wrapper MethodChannel "in4up/textlib" cho quét THƯ MỤC
// VIDEO (SAF tree, đệ quy trên Android).
//
// Dùng chung native channel với Thư viện đọc (scanTree đã tổng quát hoá để
// nhận tham số `extensions`). Truyền danh sách extension video + phụ đề →
// native quét đệ quy cả cây thư mục và trả về video lẫn phụ đề trong một lượt.
//
// An toàn đa nền tảng: iOS/Windows/Linux (chưa có native) → trả rỗng/false,
// UI rơi về "Thêm từng file" (FilePicker) như cũ.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_library_logic.dart';

/// Lỗi quét thư mục có hướng khắc phục (mất quyền / URI hỏng).
class VideoScanException implements Exception {
  final String message;
  const VideoScanException(this.message);
  @override
  String toString() => message;
}

class VideoDeviceChannel {
  static const MethodChannel _channel = MethodChannel('in4up/textlib');

  /// Nền tảng có native quét thư mục (Android).
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Mở SAF folder picker → content:// tree URI (đã persist quyền). null = hủy.
  static Future<String?> pickFolder() async {
    try {
      return await _channel.invokeMethod<String>('pickFolder');
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('[VideoDevice] pickFolder error: $e');
      return null;
    }
  }

  /// Chuẩn hoá raw path legacy → SAF tree URI.
  static Future<String?> normalizeTreeUri(String treeUri) async {
    try {
      return await _channel.invokeMethod<String>(
        'normalizeTreeUri',
        {'treeUri': treeUri},
      );
    } on MissingPluginException {
      return treeUri;
    } catch (e) {
      debugPrint('[VideoDevice] normalizeTreeUri error: $e');
      return null;
    }
  }

  /// Giữ persistable permission cho tree URI.
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
      debugPrint('[VideoDevice] keepTreePermission error: $e');
      return false;
    }
  }

  /// Quét ĐỆ QUY tree URI → danh sách item thô (video + phụ đề).
  /// NÉM [VideoScanException] khi mất quyền / URI hỏng (có hướng khắc phục).
  static Future<List<VideoScanItem>> scanTree(String treeUri) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'scanTree',
        {
          'treeUri': treeUri,
          'extensions': videoScanExtensions,
        },
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => VideoScanItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_LOST') {
        throw const VideoScanException(
          'Quyền đọc thư mục đã mất (do gỡ hoặc cập nhật app). '
          'Chạm "Chọn thư mục khác" để cấp lại quyền.',
        );
      }
      if (e.code == 'BAD_URI') {
        throw const VideoScanException(
          'Đường dẫn thư mục không hợp lệ — chạm "Chọn thư mục khác" để chọn lại.',
        );
      }
      debugPrint('[VideoDevice] scanTree error: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('[VideoDevice] scanTree error: $e');
      return const [];
    }
  }

  /// Copy content:// → file cache (để đọc phụ đề bằng File / phát ổn định).
  static Future<String?> copyContentToCache(String uri) async {
    if (!uri.startsWith('content://')) return uri;
    try {
      return await _channel.invokeMethod<String>(
        'copyContentToCache',
        {'uri': uri},
      );
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('[VideoDevice] copyContentToCache error: $e');
      return null;
    }
  }
}
