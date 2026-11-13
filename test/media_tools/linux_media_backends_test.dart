// test/media_tools/linux_media_backends_test.dart
//
// PSRC-219 (beta 1.29.0, lane L2) — Linux "could not play this track".
//
// Bản sửa đầu (fix(PSRC-219)) chỉ làm cho thông báo TRUNG THỰC (nói đúng là
// máy thiếu bộ phát) + mở bằng trình phát của hệ thống. Bản này cắm backend
// PHÁT THẬT cho Linux: `just_audio_media_kit` + `media_kit_libs_linux`
// (media_kit dlopen `libmpv.so.2` lúc chạy).
//
// Máy bắt:
//   1. `findLibMpvInLdconfig` (hàm THUẦN) — đọc đúng đường dẫn libmpv và ưu
//      tiên `.so.2`;
//   2. quét NGUỒN: chỉ cắm backend khi có libmpv, và cắm TRƯỚC khi app tạo
//      player đầu tiên (main) — nếu không máy thiếu libmpv sẽ chết lúc khởi
//      động thay vì rơi về fallback;
//   3. quét NGUỒN: `AudioPlaybackSupport` hỏi cờ RUNTIME (không đoán theo
//      `Platform.isLinux`) để máy thiếu libmpv vẫn nhận câu báo đúng.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/linux_media_backends.dart';

/// Các dòng KHAI BÁO dependency trong `pubspec.yaml` (đã bỏ comment).
///
/// Phải bỏ comment: chính ghi chú trong pubspec có nhắc tên các gói
/// `media_kit_libs_*` của nền tảng khác, quét nguyên văn sẽ báo sai
/// (CI run 43552055609 đỏ đúng vì lý do này).
String pubspecDependencyLines() {
  return File('pubspec.yaml')
      .readAsStringSync()
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('#'))
      .join('\n');
}

void main() {
  group('PSRC-219 — dò libmpv từ ldconfig -p', () {
    test('đọc đúng đường dẫn (mẫu thật Ubuntu 24.04)', () {
      const output = '''
	libmpv.so.2 (libc6,x86-64) => /lib/x86_64-linux-gnu/libmpv.so.2
	libmpv.so (libc6,x86-64) => /lib/x86_64-linux-gnu/libmpv.so
''';
      expect(
        findLibMpvInLdconfig(output),
        '/lib/x86_64-linux-gnu/libmpv.so.2',
      );
    });

    test('ưu tiên .so.2 dù .so.1 xuất hiện trước', () {
      const output = '''
	libmpv.so.1 (libc6,x86-64) => /usr/lib/libmpv.so.1
	libmpv.so.2 (libc6,x86-64) => /usr/lib/libmpv.so.2
''';
      expect(findLibMpvInLdconfig(output), '/usr/lib/libmpv.so.2');
    });

    test('chỉ có .so.1 (Ubuntu 22.04 / mpv 0.34) ⇒ vẫn dùng được', () {
      const output =
          '\tlibmpv.so.1 (libc6,x86-64) => /usr/lib/x86_64-linux-gnu/libmpv.so.1\n';
      expect(
        findLibMpvInLdconfig(output),
        '/usr/lib/x86_64-linux-gnu/libmpv.so.1',
      );
    });

    test('máy không có libmpv ⇒ null (rơi về fallback mở ngoài)', () {
      const output = '''
	libavcodec.so.60 (libc6,x86-64) => /lib/x86_64-linux-gnu/libavcodec.so.60
	libmpv-something-else (libc6) => /nope
''';
      expect(findLibMpvInLdconfig(output), isNull);
      expect(findLibMpvInLdconfig(''), isNull);
    });
  });

  group('PSRC-219 — chỉ cắm backend khi máy THẬT SỰ có libmpv', () {
    String readSource(String path) => File(path).readAsStringSync();

    test('kiểm libmpv TRƯỚC khi ensureInitialized', () {
      final source = readSource('lib/services/linux_media_backends_io.dart');
      final guardLinux = source.indexOf('!Platform.isLinux');
      final probe = source.indexOf('final libmpv = locateLibMpv();');
      final initAudio = source.indexOf('JustAudioMediaKit.ensureInitialized');

      expect(guardLinux, isNonNegative, reason: 'phải chặn ngoài Linux');
      expect(probe, isNonNegative, reason: 'phải dò libmpv');
      expect(initAudio, isNonNegative);
      expect(guardLinux, lessThan(probe));
      expect(
        probe,
        lessThan(initAudio),
        reason: 'Máy thiếu libmpv phải rơi về fallback, KHÔNG được gọi '
            'ensureInitialized trước khi biết có libmpv.',
      );
      expect(source.contains('catch (e)'), isTrue,
          reason: 'Cắm backend lỗi không được làm chết app');
    });

    test('main() cắm backend sau ensureInitialized và trước runApp', () {
      final main = readSource('lib/main.dart');
      final binding = main.indexOf('WidgetsFlutterBinding.ensureInitialized()');
      final install = main.indexOf('LinuxMediaBackends.install()');
      final runApp = main.indexOf('runApp(');
      expect(binding, isNonNegative);
      expect(install, isNonNegative,
          reason: 'Thiếu lệnh cắm backend thì Linux vẫn lỗi (PSRC-219)');
      expect(runApp, isNonNegative);
      expect(binding, lessThan(install));
      expect(install, lessThan(runApp));
    });

    test('pubspec khai báo đúng gói backend (Linux-only libs)', () {
      final pubspec = pubspecDependencyLines();
      expect(pubspec.contains('just_audio_media_kit:'), isTrue);
      expect(pubspec.contains('media_kit_libs_linux:'), isTrue);
      expect(
        pubspec.contains('media_kit_libs_android') ||
            pubspec.contains('media_kit_libs_ios') ||
            pubspec.contains('media_kit_libs_macos'),
        isFalse,
        reason: 'Chỉ Linux cần media_kit; kéo libs của nền tảng khác sẽ tăng '
            'dung lượng APK/IPA vô ích (libmpv ~10–15 MB mỗi ABI).',
      );
    });

    test('AudioPlaybackSupport hỏi cờ RUNTIME cho Linux', () {
      final support = readSource('lib/audio/audio_backend_support.dart');
      expect(support.contains('LinuxMediaBackends.ready'), isTrue,
          reason: 'Phải hỏi cờ runtime, không hard-code "Linux = không phát '
              'được" — nếu không máy ĐÃ có libmpv vẫn bị chặn.');
    });

    test('bản web không kéo dart:io/plugin (facade có điều kiện)', () {
      final facade = readSource('lib/services/linux_media_backends.dart');
      expect(facade.contains("if (dart.library.io)"), isTrue);
      final stub = readSource('lib/services/linux_media_backends_stub.dart');
      expect(stub.contains('static bool get ready => false;'), isTrue);
      expect(stub.contains("import 'dart:io'"), isFalse,
          reason: 'Bản web không được import dart:io');
    });
  });
}
