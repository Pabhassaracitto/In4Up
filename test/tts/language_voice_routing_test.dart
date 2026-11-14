// PSRC-230 — tab Đọc phát song ngữ bằng Sherpa/Piper phải chọn giọng THEO
// NGÔN NGỮ CỦA TỪNG CÂU.
//
// Lỗi gốc (audit v1.28.0): câu tiếng Anh trong tài liệu Việt–Anh vẫn đọc bằng
// giọng tiếng Việt vì
//   1. `PiperVoicePrefs.voiceForLang` trả giọng MẶC ĐỊNH cho mọi ngôn ngữ
//      chưa có mục riêng (giọng mặc định thường là giọng Việt);
//   2. `PiperTtsEngine` nhận `voiceId` bất kể ngôn ngữ;
//   3. `FlutterTtsServiceImpl` gọi `speak()` không bật `matchVoiceLanguage`
//      ⇒ `_selectedVoiceId` chung (giọng Việt) được dùng cho mọi câu;
//   4. `PlaybackEngine` rơi về ngôn ngữ TÀI LIỆU khi dòng không có mã riêng;
//   5. picker trong Settings ghi giọng vào `TtsService` singleton.
//
// Tất cả đều THUẦN LOGIC (SharedPreferences dùng bản mock) nên chạy trên CI.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/engines/offline_tts_engine.dart';
import 'package:in4up/features/tts/piper_voice_prefs.dart';
import 'package:in4up/models/text_item.dart';
import 'package:in4up/screens/read_mode/models/playback_recipe.dart';
import 'package:in4up/screens/read_mode/models/playback_run_token.dart';
import 'package:in4up/screens/read_mode/services/playback_engine.dart';
import 'package:in4up/screens/read_mode/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTtsService implements TtsService {
  final List<String> actions = [];
  String activeLocale = '';

  @override
  Future<void> setLanguage(String locale) async {
    activeLocale = locale;
    actions.add('language:$locale');
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    actions.add('rate:$rate');
  }

  @override
  Future<void> speak(String text) async {
    actions.add('speak:$activeLocale:$text');
  }

  @override
  void stop() => actions.add('stop');

  @override
  Future<void> dispose() async {}

  @override
  set onComplete(VoidCallback? callback) {}

  @override
  set onError(void Function(String error)? callback) {}

  @override
  set onStart(VoidCallback? callback) {}
}

void main() {
  group('PiperVoicePrefs — tên giọng → ngôn ngữ', () {
    test('bóc mã ngôn ngữ từ tên giọng theo quy ước Piper', () {
      expect(
        PiperVoicePrefs.languageOfVoiceName('en_US-lessac-medium'),
        'en-US',
      );
      expect(
        PiperVoicePrefs.languageOfVoiceName('vi_VN-vais1000-medium'),
        'vi-VN',
      );
      expect(
        PiperVoicePrefs.languageOfVoiceName('en_GB-alan-medium'),
        'en-GB',
      );
      expect(
        PiperVoicePrefs.languageOfVoiceName('voice_a'),
        '',
        reason: 'tên không mang mã ngôn ngữ ⇒ không rõ, không được đoán bừa',
      );
    });

    test('isVoiceCompatibleWithLanguage — cùng ngôn ngữ gốc là được', () {
      const vi = 'vi_VN-vais1000-medium';
      const enGb = 'en_GB-alan-medium';
      const zhCn = 'zh_CN-huayan-medium';
      expect(PiperVoicePrefs.isVoiceCompatibleWithLanguage(vi, 'vi-VN'), isTrue);
      expect(PiperVoicePrefs.isVoiceCompatibleWithLanguage(enGb, 'en-US'),
          isTrue,
          reason: 'LanguageDetector chuẩn hoá tiếng Anh về en-US');
      expect(
        PiperVoicePrefs.isVoiceCompatibleWithLanguage(vi, 'en-US'),
        isFalse,
        reason: 'giọng Việt KHÔNG được đọc câu tiếng Anh',
      );
      expect(
        PiperVoicePrefs.isVoiceCompatibleWithLanguage(zhCn, 'zh-TW'),
        isFalse,
        reason: 'giản thể và phồn thể là hai mặt chữ khác nhau',
      );
      expect(
        PiperVoicePrefs.isVoiceCompatibleWithLanguage('voice_a', 'en-US'),
        isTrue,
        reason: 'không rõ ngôn ngữ ⇒ chấp nhận (không thể phản chứng)',
      );
    });
  });

  group('PiperVoicePrefs.resolveVoiceForLanguage — bậc thang (thuần logic)', () {
    const viVoice = 'vi_VN-vais1000-medium';
    const enUs = 'en_US-lessac-medium';
    const enGb = 'en_GB-alan-medium';
    const zhCn = 'zh_CN-huayan-medium';

    String? call({
      required String language,
      Map<String, String> voices = const {},
      String? defaultVoice,
    }) =>
        PiperVoicePrefs.resolveVoiceForLanguage(
          language: language,
          perLanguageVoices: voices,
          defaultVoice: defaultVoice,
        );

    test('giọng riêng của đúng ngôn ngữ thắng tất cả', () {
      expect(
        call(
          language: 'en-GB',
          voices: {'en-US': enUs, 'en-GB': enGb},
          defaultVoice: viVoice,
        ),
        enGb,
      );
    });

    test('thiếu phương ngữ ⇒ dùng phương ngữ cùng họ (en-US ↔ en-GB)', () {
      expect(
        call(language: 'en-GB', voices: {'en-US': enUs}),
        enUs,
      );
      expect(
        call(language: 'en', voices: {'en_US-lessac-medium': enUs}),
        enUs,
        reason: 'mã ngắn `en` phải tìm được giọng tiếng Anh đã lưu',
      );
    });

    test('PSRC-230 — giọng mặc định tiếng Việt KHÔNG được dùng cho tiếng Anh',
        () {
      expect(
        call(
          language: 'en-US',
          voices: {'vi-VN': viVoice},
          defaultVoice: viVoice,
        ),
        isNull,
        reason: 'không có giọng Anh ⇒ trả null để TtsService fallback engine '
            'khác, KHÔNG đọc tiếng Anh bằng giọng Việt',
      );
      expect(
        call(language: 'vi-VN', voices: {'vi-VN': viVoice}, defaultVoice: viVoice),
        viVoice,
      );
    });

    test('tiếng Trung: không dùng chéo giản thể ↔ phồn thể', () {
      expect(
        call(language: 'zh-TW', voices: {'zh-CN': zhCn}, defaultVoice: zhCn),
        isNull,
      );
      expect(call(language: 'zh-CN', voices: {'zh-CN': zhCn}), zhCn);
    });

    test('ngôn ngữ rỗng/"other" ⇒ dùng giọng mặc định', () {
      expect(call(language: '', defaultVoice: viVoice), viVoice);
      expect(call(language: 'auto', defaultVoice: viVoice), viVoice);
      expect(call(language: '', defaultVoice: null), isNull);
    });
  });

  group('PiperVoicePrefs.voiceForLang — đọc từ kho lưu (mock)', () {
    test('PSRC-230: chỉ đặt giọng Việt thì câu tiếng Anh KHÔNG có giọng',
        () async {
      SharedPreferences.setMockInitialValues({});
      await PiperVoicePrefs.instance.setVoiceForLang(
        'vi-VN',
        'vi_VN-vais1000-medium',
      );

      expect(
        await PiperVoicePrefs.instance.voiceForLang('vi-VN'),
        'vi_VN-vais1000-medium',
      );
      expect(
        await PiperVoicePrefs.instance.voiceForLang('vi'),
        'vi_VN-vais1000-medium',
      );
      expect(
        await PiperVoicePrefs.instance.voiceForLang('en-US'),
        isNull,
        reason: 'trước PSRC-230 hàm này trả giọng Việt cho câu tiếng Anh',
      );
    });

    test('chọn giọng Anh-Anh rồi đọc câu Anh-Mỹ vẫn dùng đúng giọng Anh',
        () async {
      SharedPreferences.setMockInitialValues({});
      await PiperVoicePrefs.instance.setVoiceForLang(
        'vi-VN',
        'vi_VN-vais1000-medium',
      );
      await PiperVoicePrefs.instance.setVoiceForLang(
        'en-GB',
        'en_GB-alan-medium',
      );

      expect(
        await PiperVoicePrefs.instance.voiceForLang('en-US'),
        'en_GB-alan-medium',
      );
      expect(
        await PiperVoicePrefs.instance.voiceForLang('en'),
        'en_GB-alan-medium',
        reason: 'mã ngắn `en` trỏ tới phương ngữ vừa chọn',
      );
    });

    test('đổi phương ngữ thì dọn khoá vùng cũ (PSRC-18)', () async {
      SharedPreferences.setMockInitialValues({});
      await PiperVoicePrefs.instance.setVoiceForLang('en-GB', 'en_GB-alan-medium');
      await PiperVoicePrefs.instance.setVoiceForLang('en-US', 'en_US-lessac-medium');

      final all = await PiperVoicePrefs.instance.all();
      expect(all.containsKey('en-GB'), isFalse,
          reason: 'khoá vùng cũ phải bị dọn để lựa chọn mới có hiệu lực');
      expect(all['en-US'], 'en_US-lessac-medium');
      expect(
        await PiperVoicePrefs.instance.voiceForLang('en-GB'),
        'en_US-lessac-medium',
      );
    });
  });

  group('OfflineTtsEngine.voiceMatchesLanguage — không áp giọng sai ngôn ngữ',
      () {
    test('giọng cùng ngôn ngữ ⇒ áp; khác ngôn ngữ ⇒ bỏ qua', () {
      expect(
        OfflineTtsEngine.voiceMatchesLanguage('vi-vn-x-vif-network', 'vi-VN'),
        isTrue,
      );
      expect(
        OfflineTtsEngine.voiceMatchesLanguage('en-us-language', 'vi-VN'),
        isFalse,
      );
      expect(
        OfflineTtsEngine.voiceMatchesLanguage('vi-VN', 'vi-VN'),
        isTrue,
      );
      expect(
        OfflineTtsEngine.voiceMatchesLanguage('samsung-vi-vn-001', 'vi-VN'),
        isTrue,
      );
      expect(OfflineTtsEngine.voiceMatchesLanguage(null, 'vi-VN'), isFalse);
      expect(OfflineTtsEngine.voiceMatchesLanguage('   ', 'vi-VN'), isFalse);
    });
  });

  group('PlaybackEngine — mỗi câu đúng giọng của ngôn ngữ nó', () {
    test('dòng KHÔNG có mã ngôn ngữ được nhận diện theo nội dung câu',
        () async {
      final tts = _FakeTtsService();
      final engine = PlaybackEngine(tts);
      Object? error;

      await engine.play(
        token: const PlaybackRunToken(1),
        lines: [
          TextItem(
            id: '1',
            content: 'The quick brown fox jumps over the lazy dog',
          ),
          TextItem(id: '2', content: 'Hôm nay trời đẹp và mát mẻ'),
        ],
        recipe: PlaybackRecipe.enOnly,
        // Tài liệu khai báo tiếng Việt — bản cũ dùng mã này cho MỌI dòng.
        sourceLanguageCode: 'VI',
        targetLanguageCode: 'EN',
        onEvent: (_) {},
        onDone: () {},
        onError: (value) => error = value,
      );

      expect(error, isNull);
      expect(
        tts.actions,
        containsAllInOrder([
          'language:en-US',
          'speak:en-US:The quick brown fox jumps over the lazy dog',
          'language:vi-VN',
          'speak:vi-VN:Hôm nay trời đẹp và mát mẻ',
        ]),
        reason: 'câu tiếng Anh phải đọc bằng en-US, câu tiếng Việt bằng vi-VN',
      );
    });
  });
}
