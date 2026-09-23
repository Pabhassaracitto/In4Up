// lib/services/video_library_channel.dart
// Wrapper MethodChannel "in4up/videolib" (native Android — MainActivity.kt).
//
// Cùng khuôn với `audio_library_channel.dart` (thư viện nhạc quét MediaStore):
// mọi lỗi / MissingPluginException (iOS/Windows/Linux chưa có native) đều bị
// bắt → trả rỗng/null để UI rơi về "chọn file thủ công" thay vì crash.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoLibraryChannel {
  static const MethodChannel _channel = MethodChannel('in4up/videolib');

  /// Nền tảng có native quét (MediaStore là Android).
  static bool get isSupported => !kIsWeb && _isAndroid;

  // Tránh import dart:io ở tầng channel: đọc qua defaultTargetPlatform.
  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Quét MediaStore.Video (Android) → danh sách map thô:
  /// { id, uri, title, displayName, durationMs, sizeBytes, dateAddedSec,
  ///   width, height }.
  static Future<List<Map<String, dynamic>>> scanMediaStore() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('scanMediaStore');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[VideoLibrary] scanMediaStore error: $e');
      return const [];
    }
  }

  /// Copy content:// sang cache dir → trả path file thật (video_player cần
  /// File path ổn định; content:// có thể mất quyền sau một thời gian).
  /// Nếu [uri] không phải content:// → trả nguyên uri. Lỗi → null.
  static Future<String?> copyContentToCache(String uri) async {
    if (!uri.startsWith('content://')) return uri;
    try {
      return await _channel.invokeMethod<String>(
        'copyContentToCache',
        {'uri': uri},
      );
    } catch (e) {
      debugPrint('[VideoLibrary] copyContentToCache error: $e');
      return null;
    }
  }
}
