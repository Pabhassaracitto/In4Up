// lib/services/audio_library_channel.dart
// Wrapper MethodChannel "in4up/audiolib" (native Android — MainActivity.kt).
//
// An toàn đa nền tảng: mọi lỗi / MissingPluginException (iOS/Windows chưa có
// native) đều bị bắt → trả rỗng để UI hiện trạng thái "chưa hỗ trợ".

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioLibraryChannel {
  static const MethodChannel _channel = MethodChannel('in4up/audiolib');

  /// Quét MediaStore.Audio (Android). Trả danh sách map thô.
  static Future<List<Map<String, dynamic>>> scanMediaStore() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('scanMediaStore');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[AudioLibrary] scanMediaStore error: $e');
      return const [];
    }
  }
}
