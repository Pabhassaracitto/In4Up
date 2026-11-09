// lib/services/audio_library_channel.dart
// Wrapper MethodChannel "in4up/audiolib" (native Android — MainActivity.kt).
//
// An toàn đa nền tảng: mọi lỗi / MissingPluginException (iOS/Windows chưa có
// native) đều bị bắt → trả rỗng để UI hiện trạng thái "chưa hỗ trợ".

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The original URI remains the identity; [path] is only a playable file.
class AudioCacheResolution {
  final String path;
  final String? legacyPath;
  final bool legacyClaimable;
  final bool legacyOwned;

  const AudioCacheResolution({
    required this.path,
    this.legacyPath,
    this.legacyClaimable = false,
    this.legacyOwned = false,
  });
}

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

  /// Copy content:// sang cache dir → trả path file thật (để VAD/waveform/ffmpeg).
  /// Nếu [uri] không phải content:// → trả nguyên uri. Lỗi → null.
  static Future<String?> copyContentToCache(String uri) async {
    if (!uri.startsWith('content://')) return uri;
    try {
      final path = await _channel.invokeMethod<String>(
        'copyContentToCache',
        {'uri': uri},
      );
      return path;
    } catch (e) {
      debugPrint('[AudioLibrary] copyContentToCache error: $e');
      return null;
    }
  }

  /// Source-keyed cache plus an optional unverified legacy path. A candidate
  /// is never attached to the source without the user's explicit decision.
  static Future<AudioCacheResolution?> resolveContentToCache(String uri) async {
    if (!uri.startsWith('content://')) return AudioCacheResolution(path: uri);
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'resolveContentToCache', {'uri': uri},
      );
      if (result == null || result['status'] != 'ok' || result['path'] is! String) {
        return null;
      }
      return AudioCacheResolution(
        path: result['path'] as String,
        legacyPath: result['legacyPath'] as String?,
        legacyClaimable: result['legacyClaimable'] == true,
        legacyOwned: result['legacyOwned'] == true,
      );
    } catch (e) {
      debugPrint('[AudioLibrary] resolveContentToCache error: $e');
      return null;
    }
  }

  /// Claiming never overwrites a different cached file or another source's
  /// ownership; native rechecks those conditions immediately before writing.
  static Future<bool> claimLegacyCache(String uri) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'claimLegacyCache', {'uri': uri},
      );
      return result?['status'] == 'ok';
    } catch (e) {
      debugPrint('[AudioLibrary] claimLegacyCache error: $e');
      return false;
    }
  }

  /// Thời lượng file audio (ms) qua MediaMetadataRetriever — đọc được cả
  /// content:// lẫn đường dẫn cục bộ. Dùng làm "phao cứu sinh" cho auto-TOC:
  /// khi waveform/ffmpeg không dùng được, vẫn chia đều mục lục theo duration.
  /// Không hỗ trợ / lỗi → null (Android-only; iOS/Windows → null).
  static Future<int?> readAudioDurationMs(String uri) async {
    try {
      return await _channel.invokeMethod<int>(
        'readAudioDurationMs',
        {'uri': uri},
      );
    } catch (e) {
      debugPrint('[AudioLibrary] readAudioDurationMs error: $e');
      return null;
    }
  }
}
