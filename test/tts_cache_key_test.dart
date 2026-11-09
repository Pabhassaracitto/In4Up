// TTS-EDGE-VOICE-002 / TTS-VOICE-CACHE-001+002 — khoá cache TTS phải mang
// theo DANH TÍNH của bản ghi: engine + ngôn ngữ + GIỌNG + tốc độ + cao độ.
//
// Vì sao có test này (audit 0.10.3 mục 1.g — "chọn giọng nam mà giọng nữ
// đọc"): khoá cũ chỉ có `engine + ngôn ngữ + chữ`, nên một file audio đã tải
// bằng giọng mặc định (nữ) được phát lại cho MỌI giọng của cùng ngôn ngữ —
// người dùng chọn Nam Minh nhưng vẫn nghe Hoài My.
//
// Kèm phần dọn cache một lần khi phiên bản khoá đổi (TTS-VOICE-CACHE-002):
// người dùng cũ đã có file ghi theo khoá không-giọng trong `tts_cache/`.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/cache/tts_cache.dart';

void main() {
  const text = 'Hôm nay trời đẹp.';
  const lang = 'vi-VN';
  const engine = 'edge_tts';

  String key({
    String content = text,
    String language = lang,
    String engineId = engine,
    String? voiceId,
    double speed = 1.0,
    double pitch = 1.0,
  }) =>
      TtsCache.makeKey(
        content,
        language,
        engineId,
        voiceId: voiceId,
        speed: speed,
        pitch: pitch,
      );

  group('TtsCache.makeKey — giọng là một phần danh tính bản ghi', () {
    test('cùng tham số ⇒ khoá ổn định (gọi lại nhiều lần)', () {
      final first = key(voiceId: 'vi-VN-NamMinhNeural');
      expect(key(voiceId: 'vi-VN-NamMinhNeural'), first);
      expect(
        TtsCache.makeKey(
          text,
          lang,
          engine,
          voiceId: 'vi-VN-NamMinhNeural',
          speed: 1.0,
          pitch: 1.0,
        ),
        first,
        reason: 'khoá phải là hàm thuần của (chữ, ngôn ngữ, engine, giọng, '
            'tốc độ, cao độ) — không phụ thuộc thời gian/ngẫu nhiên',
      );
      expect(first, hasLength(32), reason: 'md5 hex');
    });

    test('đổi GIỌNG ⇒ khoá đổi (bài kiểm tra quan trọng nhất)', () {
      final male = key(voiceId: 'vi-VN-NamMinhNeural');
      final female = key(voiceId: 'vi-VN-HoaiMyNeural');
      expect(male, isNot(female));
      expect(key(voiceId: null), isNot(male),
          reason: 'chưa chọn giọng (engine tự mặc định) là danh tính KHÁC');
      expect(key(voiceId: null), isNot(female));
    });

    test('giọng rỗng/khoảng trắng = "chưa chọn giọng" (một khoá duy nhất)', () {
      expect(key(voiceId: '   '), key(voiceId: null));
      expect(key(voiceId: ''), key());
    });

    test('khoá cắt khoảng trắng thừa của voiceId', () {
      expect(key(voiceId: ' vi-VN-NamMinhNeural '),
          key(voiceId: 'vi-VN-NamMinhNeural'));
    });

    test('đổi TỐC ĐỘ hoặc CAO ĐỘ ⇒ khoá đổi', () {
      final base = key(voiceId: 'vi-VN-NamMinhNeural');
      expect(key(voiceId: 'vi-VN-NamMinhNeural', speed: 1.5), isNot(base));
      expect(key(voiceId: 'vi-VN-NamMinhNeural', pitch: 1.2), isNot(base));
      expect(
        key(voiceId: 'vi-VN-NamMinhNeural', speed: 1.5, pitch: 1.2),
        isNot(base),
      );
      expect(
        key(voiceId: 'vi-VN-NamMinhNeural', speed: 1.5),
        isNot(key(voiceId: 'vi-VN-NamMinhNeural', pitch: 1.5)),
        reason: 'tốc độ và cao độ không được trộn vào cùng một thành phần',
      );
    });

    test('tốc độ/cao độ được lượng tử 2 chữ số thập phân', () {
      // Ghi lại bằng test để người sau không "sửa" nhầm: 1.001 và 1.0 là CÙNG
      // một tham số phát (bước chỉnh trong UI lớn hơn 0.01 rất nhiều).
      expect(key(voiceId: 'x', speed: 1.001), key(voiceId: 'x', speed: 1.0));
      expect(key(voiceId: 'x', speed: 1.05), isNot(key(voiceId: 'x')));
    });

    test('đổi engine / ngôn ngữ / chữ ⇒ khoá đổi', () {
      final base = key(voiceId: 'vi-VN-NamMinhNeural');
      expect(key(voiceId: 'vi-VN-NamMinhNeural', engineId: 'piper_tts'),
          isNot(base));
      expect(
          key(voiceId: 'vi-VN-NamMinhNeural', language: 'en-US'), isNot(base));
      expect(key(voiceId: 'vi-VN-NamMinhNeural', content: 'Câu khác'),
          isNot(base));
    });

    test('cùng giọng cho hai ngôn ngữ khác nhau vẫn tách bản ghi', () {
      expect(
        key(voiceId: 'vi-VN-NamMinhNeural', language: 'vi-VN'),
        isNot(key(voiceId: 'vi-VN-NamMinhNeural', language: 'vi')),
      );
    });
  });

  group('TtsCache — phiên bản khoá + dọn cache cũ', () {
    test('phiên bản hiện tại phải >= 2 (>=1 là công thức KHÔNG có giọng)', () {
      expect(
        TtsCache.keyVersion,
        greaterThanOrEqualTo(2),
        reason: 'bản 1 ghi file theo khoá không-giọng; hạ về 1 là tái hiện '
            'đúng lỗi "chọn giọng nam mà giọng nữ đọc"',
      );
    });

    test('máy mới (chưa ghi phiên bản) ⇒ không xoá gì', () {
      expect(TtsCache.shouldWipeForStoredVersion(null), isFalse);
    });

    test('phiên bản cũ hơn ⇒ xoá cache cũ một lần', () {
      expect(TtsCache.shouldWipeForStoredVersion(1), isTrue);
      expect(TtsCache.shouldWipeForStoredVersion(0), isTrue);
    });

    test('đúng phiên bản hiện tại ⇒ giữ nguyên cache', () {
      expect(TtsCache.shouldWipeForStoredVersion(TtsCache.keyVersion), isFalse);
    });

    test('phiên bản mới hơn (app hạ cấp) ⇒ xoá để tránh đọc sai định dạng', () {
      expect(
        TtsCache.shouldWipeForStoredVersion(TtsCache.keyVersion + 1),
        isTrue,
      );
    });
  });
}
