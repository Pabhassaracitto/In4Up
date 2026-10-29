import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/edge_voice_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TTS-EDGE-VOICE-001 — EdgeVoicePrefs (kho giọng Edge theo ngôn ngữ).
/// TTS-EDGE-VOICE-003 — bậc thang "giọng riêng → giọng GHIM → mặc định"
/// (hướng đã chọn cho tài liệu LẪN Việt–Anh ở phần nghiệm thu máy thật).
void main() {
  test('normalizeLang — đồng bộ với PiperVoicePrefs', () {
    expect(EdgeVoicePrefs.normalizeLang('vi-VN'), 'vi-VN');
    expect(EdgeVoicePrefs.normalizeLang('vi_vn'), 'vi-VN');
    expect(EdgeVoicePrefs.normalizeLang('vi'), 'vi');
    expect(EdgeVoicePrefs.normalizeLang('en-US'), 'en-US');
    expect(EdgeVoicePrefs.normalizeLang('  en-us  '), 'en-US');
    expect(EdgeVoicePrefs.normalizeLang('auto'), '');
    expect(EdgeVoicePrefs.normalizeLang('   '), '');
  });

  test('set/voice round-trip theo ngôn ngữ + short code; chưa chọn → null',
      () async {
    SharedPreferences.setMockInitialValues({});
    await EdgeVoicePrefs.instance.setVoiceForLang(
      'vi-VN',
      'vi-VN-NamMinhNeural',
    );
    expect(
      await EdgeVoicePrefs.instance.voiceForLang('vi-VN'),
      'vi-VN-NamMinhNeural',
    );
    // Short code `vi` trỏ về cùng giọng đã chọn cho `vi-VN`.
    expect(
      await EdgeVoicePrefs.instance.voiceForLang('vi'),
      'vi-VN-NamMinhNeural',
    );
    // Ngôn ngữ KHÁC chưa bao giờ được set trong test này → null
    // (engine sẽ tự chọn giọng mặc định theo ngôn ngữ).
    expect(await EdgeVoicePrefs.instance.voiceForLang('fr-FR'), isNull);
  });

  group('resolveVoiceForLanguage — bậc thang giọng (thuần logic)', () {
    String? call({
      String? perLanguageVoice,
      String? pinnedVoice,
      bool pinAll = false,
    }) =>
        EdgeVoicePrefs.resolveVoiceForLanguage(
          perLanguageVoice: perLanguageVoice,
          pinnedVoice: pinnedVoice,
          pinAll: pinAll,
        );

    test('chưa chọn gì, chưa ghim ⇒ null (engine dùng mặc định)', () {
      expect(call(), isNull);
      expect(call(perLanguageVoice: '  '), isNull);
      expect(call(pinnedVoice: 'vi-VN-NamMinhNeural'), isNull,
          reason: 'có giọng ghim nhưng công tắc TẮT ⇒ không áp dụng');
    });

    test('giọng riêng của ngôn ngữ luôn thắng giọng ghim', () {
      expect(
        call(
          perLanguageVoice: 'en-US-GuyNeural',
          pinnedVoice: 'vi-VN-NamMinhNeural',
          pinAll: true,
        ),
        'en-US-GuyNeural',
      );
    });

    test('GHIM bật ⇒ dòng ngoại ngữ dùng giọng ghim (hết Aria mặc định)', () {
      expect(
        call(pinnedVoice: 'vi-VN-NamMinhNeural', pinAll: true),
        'vi-VN-NamMinhNeural',
      );
    });

    test('ghim bật nhưng chưa có giọng ghim ⇒ null (không đoán bừa)', () {
      expect(call(pinAll: true), isNull);
      expect(call(pinnedVoice: '   ', pinAll: true), isNull);
    });

    test('cắt khoảng trắng thừa của cả hai nguồn giọng', () {
      expect(
        call(perLanguageVoice: ' en-US-GuyNeural ', pinAll: true),
        'en-US-GuyNeural',
      );
      expect(
        call(pinnedVoice: ' vi-VN-NamMinhNeural ', pinAll: true),
        'vi-VN-NamMinhNeural',
      );
    });
  });

  group('EdgeVoicePrefs — ghim giọng cho mọi ngôn ngữ', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('mặc định TẮT và chưa ghim giọng', () async {
      expect(await EdgeVoicePrefs.instance.pinAllLanguages, isFalse);
      expect(await EdgeVoicePrefs.instance.pinnedVoice, isNull);
    });

    test('bật ghim rồi thì ngôn ngữ CHƯA chọn đọc bằng giọng ghim', () async {
      await EdgeVoicePrefs.instance
          .setPinAllLanguages(true, voiceId: 'vi-VN-NamMinhNeural');
      expect(await EdgeVoicePrefs.instance.pinnedVoice, 'vi-VN-NamMinhNeural');
      expect(
        await EdgeVoicePrefs.instance.voiceForLang('en-US'),
        'vi-VN-NamMinhNeural',
        reason: 'câu tiếng Anh trong tài liệu tiếng Việt — audit 1.g',
      );
      // Ngôn ngữ đã chọn giọng riêng vẫn giữ giọng riêng.
      await EdgeVoicePrefs.instance
          .setVoiceForLang('vi-VN', 'vi-VN-HoaiMyNeural');
      expect(
        await EdgeVoicePrefs.instance.voiceForLang('vi-VN'),
        'vi-VN-HoaiMyNeural',
      );
      expect(
        await EdgeVoicePrefs.instance.voiceForLang('en-US'),
        'vi-VN-NamMinhNeural',
      );
    });

    test('tắt ghim ⇒ quay lại đúng hành vi cũ (null cho ngôn ngữ lạ)', () async {
      await EdgeVoicePrefs.instance
          .setPinAllLanguages(true, voiceId: 'vi-VN-NamMinhNeural');
      await EdgeVoicePrefs.instance.setPinAllLanguages(false);
      expect(await EdgeVoicePrefs.instance.voiceForLang('en-US'), isNull);
    });

    test('chọn giọng ở nhóm "ngôn ngữ khác" = ghim + bật công tắc', () async {
      await EdgeVoicePrefs.instance.setVoiceForLang('other', 'ja-JP-KeitaNeural');
      expect(await EdgeVoicePrefs.instance.pinAllLanguages, isTrue);
      expect(await EdgeVoicePrefs.instance.pinnedVoice, 'ja-JP-KeitaNeural');
      expect(
        await EdgeVoicePrefs.instance.voiceForLang('de-DE'),
        'ja-JP-KeitaNeural',
      );
    });

    test('all() chỉ liệt kê giọng RIÊNG theo ngôn ngữ (không lẫn ô ghim)',
        () async {
      await EdgeVoicePrefs.instance
          .setPinAllLanguages(true, voiceId: 'vi-VN-NamMinhNeural');
      await EdgeVoicePrefs.instance
          .setVoiceForLang('en-US', 'en-US-GuyNeural');
      final all = await EdgeVoicePrefs.instance.all();
      expect(all['en-US'], 'en-US-GuyNeural');
      expect(all['en'], 'en-US-GuyNeural',
          reason: 'short code được ghi song song');
      expect(all.containsKey('other'), isFalse);
    });
  });
}
