// YT-TTS-PROVIDER-001 — máy bắt cho lỗi "mở video YouTube ⇒ MÀN HÌNH TRẮNG".
//
// ─── Nguyên nhân thật (owner báo 2026-10-25, build 027f4029 / nhánh 251e) ──
// App có **HAI class trùng tên `TtsService`**:
//   • `lib/features/tts/tts_service.dart`          → `class TtsService
//     extends ChangeNotifier` (bộ máy TTS thật; `factory TtsService()` =
//     singleton).
//   • `lib/screens/read_mode/services/tts_service.dart` → `abstract class
//     TtsService` (interface mà tab Đọc dùng).
//
// `lib/main.dart` đăng ký **type thứ hai**:
//     Provider<TtsService>(create: (_) => FlutterTtsServiceImpl())
//
// Màn player YouTube lại `import '../../features/tts/tts_service.dart'` (type
// thứ nhất) rồi gọi `context.read<TtsService>()` trong `initState`.
// Provider tra theo **đúng Type** ⇒ không khớp ⇒ ném `ProviderNotFoundException`
// ngay khi mở màn ⇒ cả `YtPlayerScreen` không dựng được ⇒ người dùng chỉ thấy
// một khung trắng (không có log nào hiện ra trên UI).
//
// Sửa: dùng singleton `TtsService()` (chính là instance mà `FlutterTtsServiceImpl`
// bọc bên trong ⇒ vẫn chung giọng/engine/cài đặt với tab Đọc), KHÔNG qua Provider.
//
// Test này khoá lại cả 3 vế của lỗi để không tái phát.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/tts_service.dart' as app_tts;
import 'package:in4up/screens/read_mode/services/tts_service.dart' as read_tts;

void main() {
  group('YT-TTS-PROVIDER-001 — hai class TtsService là hai Type khác nhau', () {
    test('features/tts TtsService KHÁC read_mode TtsService', () {
      // Nếu ai đó "hợp nhất" hai class này thì test đỏ ⇒ đọc lại chú thích
      // đầu file trước khi sửa.
      expect(app_tts.TtsService, isNot(equals(read_tts.TtsService)));
    });

    test('main.dart đăng ký type read_mode (giả định của toàn bộ test này)', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(
        main.contains("import 'screens/read_mode/services/tts_service.dart';"),
        isTrue,
        reason: 'main.dart phải import type read_mode để Provider<TtsService> '
            'đăng ký ĐÚNG type đó.',
      );
      expect(
        RegExp(r'Provider<TtsService>\(').hasMatch(main),
        isTrue,
        reason: 'Thiếu Provider<TtsService> trong main.dart ⇒ mọi '
            'context.read<TtsService>() của tab Đọc sẽ nổ.',
      );
    });
  });

  group('YT-TTS-PROVIDER-001 — code YouTube KHÔNG được đọc TtsService qua Provider',
      () {
    /// Quét toàn bộ `lib/features/youtube/**` (đệ quy).
    List<File> youtubeDartFiles() {
      final dir = Directory('lib/features/youtube');
      expect(dir.existsSync(), isTrue);
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    test('không file YouTube nào gọi read<TtsService> / watch<TtsService>', () {
      final violations = <String>[];
      final pattern = RegExp(r'\b(read|watch)<TtsService>');
      for (final f in youtubeDartFiles()) {
        // Bỏ comment TRƯỚC khi quét: chú thích giải thích lỗi này có nhắc
        // đúng chuỗi `read<TtsService>()` và không được tính là vi phạm.
        final lines = f
            .readAsStringSync()
            .split('\n')
            .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
            .toList();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            violations.add('${f.path}:${i + 1} — ${lines[i].trim()}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Provider<TtsService> trong main.dart là type '
            'read_mode/services/tts_service.dart (abstract), còn code YouTube '
            'import features/tts/tts_service.dart (ChangeNotifier) — '
            'read<TtsService>() sẽ ném ProviderNotFoundException ngay trong '
            'initState ⇒ MÀN HÌNH TRẮNG. Dùng singleton `TtsService()`:\n'
            '${violations.join('\n')}',
      );
    });

    test('yt_player_screen dùng singleton (và vẫn truyền nó vào sheet/controller)',
        () {
      final src =
          File('lib/features/youtube/yt_player_screen.dart').readAsStringSync();
      expect(
        RegExp(r'late final TtsService _tts = TtsService\(\);').hasMatch(src),
        isTrue,
        reason: 'Player phải lấy bộ máy TTS qua singleton `TtsService()`.',
      );
      expect(
        src.contains('YtReadAloudController(_tts)'),
        isTrue,
        reason: 'Controller phải nhận đúng singleton đó.',
      );
      expect(
        src.contains('_tts,\n      hasTranslation: _hasTranslation,'),
        isTrue,
        reason: 'Sheet "Đọc bản dịch" cũng phải nhận singleton (không đọc lại '
            'qua Provider).',
      );
    });

    test('singleton là factory trả về cùng một instance', () {
      // Khoá hợp đồng quan trọng: nếu `TtsService()` thành constructor thường
      // thì mỗi màn hình tạo một bộ máy riêng, giọng/cài đặt không còn dùng
      // chung với tab Đọc.
      final src = File('lib/features/tts/tts_service.dart').readAsStringSync();
      expect(
        src.contains('factory TtsService() => _instance;'),
        isTrue,
        reason: 'TtsService phải là singleton — controller của YouTube dựa '
            'vào điều này để dùng chung giọng với tab Đọc.',
      );
    });
  });
}
