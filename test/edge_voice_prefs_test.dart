import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/edge_voice_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TTS-EDGE-VOICE-001 — EdgeVoicePrefs (kho giọng Edge theo ngôn ngữ).
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

  test('set/voice round-trip theo ngôn ngữ + short code; chưa chọn → null', () async {
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
}
