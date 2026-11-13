// test/media_tools/video_playback_support_test.dart
//
// PSRC-220 (audit 1.28.0) — Linux mở .mp4 ở tab View báo
// "cannot open video: UnimplementedError int() has not been implemented".
//
// GỐC: `video_player` chỉ có implementation cho Android/iOS/macOS/Web. Trên
// Linux/Windows `VideoPlayerPlatform.instance` là bản mặc định và MỌI method
// `throw UnimplementedError()`. `VideoPlayerScreen` bắt `catch (_)` → cờ
// `_initFailed` → chỉ hiện "Không phát được video này": không nói vì sao,
// không có đường xem.
//
// Máy bắt:
//   1. ánh xạ nền tảng → backend (thuần);
//   2. quét NGUỒN màn hình phát: phải kiểm backend TRƯỚC `_initPlayer()`,
//      và phải có nhánh UI mở bằng trình phát hệ thống.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/services/video_playback_support.dart';

void main() {
  group('PSRC-220 — nền tảng nào phát video trong app được', () {
    test('Linux ⇒ chỉ mở bằng trình phát ngoài', () {
      expect(
        videoPlaybackBackendFor('linux'),
        VideoPlaybackBackend.externalOnly,
      );
    });

    test('Windows cũng thiếu plugin trong cây dependency này', () {
      expect(
        videoPlaybackBackendFor('windows'),
        VideoPlaybackBackend.externalOnly,
      );
    });

    test('Android/iOS/macOS phát trong app', () {
      for (final os in ['android', 'ios', 'macos']) {
        expect(videoPlaybackBackendFor(os), VideoPlaybackBackend.inApp,
            reason: os);
      }
    });

    test('lý do nói rõ là thiếu bộ phát và có đường thay thế', () {
      expect(VideoPlaybackSupport.externalOnlyReasonKey, contains('trình phát'));
      expect(
        VideoPlaybackSupport.externalOnlyReasonKey,
        isNot(contains('hỏng')),
        reason: 'Không được để người dùng tưởng video hỏng',
      );
    });
  });

  group('PSRC-220 — màn hình phát video không đi vào nhánh UnimplementedError',
      () {
    test('kiểm backend TRƯỚC khi khởi tạo controller', () {
      final source = File(
        'lib/features/video/widgets/video_player_screen.dart',
      ).readAsStringSync();
      final guard = source.indexOf('VideoPlaybackSupport.supportsInAppPlayback');
      final init = source.indexOf('_initPlayer();');
      expect(guard, isNonNegative,
          reason: 'Phải có chốt kiểm backend video trong màn hình phát');
      expect(init, isNonNegative);
      expect(guard, lessThan(init),
          reason: 'Chốt phải đứng trước _initPlayer() — nếu không '
              'UnimplementedError vẫn xảy ra trên Linux (PSRC-220).');

      expect(source.contains('_buildExternalOnly'), isTrue);
      expect(source.contains('openFileExternally'), isTrue);
      // Tách âm thanh (FFmpeg) vẫn phải dùng được khi không có bộ phát.
      expect(source.contains('ready || _externalOnly'), isTrue);
    });
  });
}
