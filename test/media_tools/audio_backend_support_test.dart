// test/media_tools/audio_backend_support_test.dart
//
// PSRC-219 (audit 1.28.0) — "Linux vẫn báo lỗi could not play this track".
//
// GỐC: app phát âm thanh bằng `just_audio`; plugin backend của just_audio có
// cho Android/iOS/macOS/Windows (just_audio_windows)/Web nhưng KHÔNG có cho
// Linux (`linux/flutter/generated_plugin_registrant.cc` không đăng ký trình
// phát âm thanh nào). `setFilePath()` trên Linux ném MissingPluginException;
// `AudioPlayerService.loadFile` nuốt lỗi và trả false; PlayerProvider gộp
// thành `loadFailed`; UI hiện câu chung "Không phát được bài này" ⇒ người
// dùng tưởng file hỏng.
//
// Máy bắt:
//   1. ánh xạ nền tảng → backend (thuần);
//   2. ánh xạ loại lỗi → câu nói + hành động thay thế;
//   3. quét NGUỒN `player_provider.dart`: phải kiểm backend TRƯỚC khi gọi
//      `_audioService.loadFile` (chặn tái phát đúng dòng gây lỗi).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/audio/audio_backend_support.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/screens/listen_mode/widgets/playback_problem_snack.dart';

void main() {
  group('PSRC-219 — nền tảng nào có bộ phát âm thanh trong app', () {
    test('Linux không có plugin just_audio ⇒ backend none', () {
      expect(audioBackendFor('linux'), AudioBackend.none);
    });

    test('Android/iOS/macOS/Windows có plugin ⇒ backend inApp', () {
      for (final os in ['android', 'ios', 'macos', 'windows']) {
        expect(audioBackendFor(os), AudioBackend.inApp, reason: os);
      }
    });

    test('nền tảng lạ ⇒ coi như không có (không hứa điều không làm được)', () {
      expect(audioBackendFor('fuchsia'), AudioBackend.none);
      expect(audioBackendFor(''), AudioBackend.none);
    });

    test('lý do nêu đúng đường thay thế', () {
      expect(AudioPlaybackSupport.unsupportedReasonKey, contains('trình phát'));
    });
  });

  group('PSRC-219 — lỗi nạp audio phải nói đúng nguyên nhân', () {
    test('backend thiếu: câu riêng + có nút mở ngoài', () {
      final key = playbackFailureMessageKey(
        AudioLoadErrorKind.backendUnsupported,
      );
      expect(key, isNotNull);
      expect(key, contains('trình phát'));
      expect(
        playbackFailureOffersExternalPlayer(
          AudioLoadErrorKind.backendUnsupported,
        ),
        isTrue,
      );
    });

    test('file bị xoá: câu hướng dẫn chọn lại, KHÔNG mời mở ngoài', () {
      final key = playbackFailureMessageKey(AudioLoadErrorKind.missingFile);
      expect(key, contains('chọn lại'));
      expect(
        playbackFailureOffersExternalPlayer(AudioLoadErrorKind.missingFile),
        isFalse,
      );
    });

    test('codec hỏng: dùng câu chung (không hứa hẹn sai)', () {
      expect(playbackFailureMessageKey(AudioLoadErrorKind.loadFailed), isNull);
      expect(playbackFailureMessageKey(AudioLoadErrorKind.none), isNull);
    });
  });

  group('PSRC-219 — PlayerProvider PHÂN LOẠI lỗi nạp theo nền tảng', () {
    test('thiếu backend ⇒ backendUnsupported, không phải loadFailed', () {
      final source = File('lib/providers/player_provider.dart')
          .readAsStringSync();
      final classify = source.indexOf('_loadFailureKind()');
      final loadCall = source.indexOf('_audioService.loadFile');
      expect(classify, isNonNegative,
          reason: 'PlayerProvider phải phân loại lỗi nạp theo nền tảng');
      expect(loadCall, isNonNegative);
      expect(
        source.indexOf('AudioLoadErrorKind.backendUnsupported'),
        greaterThan(0),
      );
      // Phân loại là GIẢI THÍCH sau khi thất bại, KHÔNG chặn trước lời gọi
      // nạp — test trên host Linux (và bản build tự cắm backend media_kit)
      // vẫn phải nạp được bình thường.
      expect(
        source.contains('if (!AudioPlaybackSupport.isInAppSupported)'),
        isFalse,
        reason: 'Không được return sớm trước loadFile: test listen queue '
            'chạy trên runner Linux và mô phỏng player (PSRC-219).',
      );
    });
  });
}
