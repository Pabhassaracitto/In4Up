// PARAKEET-002 — Parakeet phải DÙNG ĐƯỢC ở các màn thật, không chỉ nằm trong
// Settings.
//
// Bối cảnh: model Parakeet đã import xong, thẻ trong Quản lý Model AI báo "đã
// cài", nhưng:
//   - dropdown ngôn ngữ của Cabin chỉ có 12 ngôn ngữ → **22/25 ngôn ngữ của
//     Parakeet không chọn được** (es/it/pt/nl/pl/ru/uk/sv/…);
//   - chip model ở tab Nghe chỉ có Whisper → không có cách nào chọn Parakeet;
//   - `SttEngineType.sherpa` KHÔNG có nhánh trong `transcribeFile` (rơi vào
//     native = speech_to_text, vốn không transcribe file);
//   - quick capture chỉ lấy `profile.language` (phần tử ĐẦU của Parakeet = en)
//     nên app tiếng Đức/Pháp không bao giờ chạy Parakeet.
//
// Test này khoá các quyết định THUẦN (không cần thiết bị/plugin):
//   1. `kAsrLanguageDisplayNames` phủ đủ mọi ngôn ngữ có profile offline;
//   2. `cabinLanguageOptions()` chứa đủ 25 ngôn ngữ Parakeet, giữ thứ tự cũ;
//   3. `AsrModelRouter.installedLanguages` trả MỌI ngôn ngữ của model đã cài;
//   4. `offlineFileProfile` chỉ trả profile OFFLINE (không bao giờ trả model
//      streaming — SHERPA-STREAM-001: file STT + encoder streaming = SIGABRT);
//   5. cabin `planCabinAsr` với Parakeet đã cài ⇒ canStart + route VAD;
//   6. quick capture chọn đúng ngôn ngữ app khi máy chỉ cài Parakeet.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_asr_plan.dart';
import 'package:in4up/screens/home/quick_capture/quick_capture_stt_sources.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';

bool Function(String) installedOnly(Set<String> profileIds) =>
    (String id) => profileIds.contains(id);

/// 25 ngôn ngữ Parakeet (trừ 'en' đã có profile EN streaming riêng).
const List<String> _parakeetOnlyLanguages = [
  'bg', 'hr', 'cs', 'da', 'nl', 'et', 'fi', 'fr', 'de', 'el', 'hu', 'it',
  'lv', 'lt', 'mt', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl', 'es', 'sv', 'uk',
];

void main() {
  group('PARAKEET-002 — tên hiển thị ngôn ngữ', () {
    test('phủ đủ mọi ngôn ngữ có profile offline', () {
      for (final language in AsrModelRouter.supportedLanguages) {
        expect(kAsrLanguageDisplayNames.containsKey(language), isTrue,
            reason: 'ngôn ngữ $language thiếu tên hiển thị');
      }
      // Không khai báo thừa ngôn ngữ mà app chưa có model nào.
      for (final language in kAsrLanguageDisplayNames.keys) {
        expect(AsrModelRouter.supportedLanguages, contains(language),
            reason: '$language có tên nhưng không có profile offline nào');
      }
    });

    test('languageDisplayName: có tên thì dùng tên, không thì mã viết hoa', () {
      expect(AsrModelRouter.languageDisplayName('fr'), contains('French'));
      expect(AsrModelRouter.languageDisplayName(' FR '), contains('French'));
      expect(AsrModelRouter.languageDisplayName('zh'), 'ZH');
    });
  });

  group('PARAKEET-002 — dropdown ngôn ngữ Cabin', () {
    test('giữ nguyên 12 ngôn ngữ cũ ở ĐẦU (user cũ không bị xáo danh sách)', () {
      final options = cabinLanguageOptions();
      final keys = options.keys.toList();
      expect(keys.take(kCabinBaseLanguages.length),
          kCabinBaseLanguages.keys.toList());
      expect(keys.first, 'en');
      expect(keys[1], 'vi');
    });

    test('có ĐỦ 25 ngôn ngữ Parakeet (trước đây thiếu 22)', () {
      final options = cabinLanguageOptions();
      for (final language in _parakeetOnlyLanguages) {
        expect(options.containsKey(language), isTrue,
            reason: 'dropdown Cabin thiếu ngôn ngữ Parakeet "$language"');
      }
      // 12 ngôn ngữ nền + 22 ngôn ngữ Parakeet mới (fr/de đã có sẵn).
      expect(options.length, kCabinBaseLanguages.length + 22);
    });

    test('không có mã trùng và mọi giá trị đều không rỗng', () {
      final options = cabinLanguageOptions();
      expect(options.length, options.keys.toSet().length);
      for (final entry in options.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: 'nhãn rỗng: ${entry.key}');
      }
    });
  });

  group('PARAKEET-002 — model đã cài ↔ ngôn ngữ', () {
    test('installedLanguages: Parakeet đã cài ⇒ đủ 25 ngôn ngữ', () {
      final installed = AsrModelRouter.installedLanguages(
        isInstalled: installedOnly({kParakeetProfileId}),
      );
      expect(installed.length, 25);
      expect(installed, containsAll(['en', 'de', 'fr', 'es', 'it', 'uk']));
    });

    test('installedLanguages: chưa cài gì ⇒ rỗng; VI ⇒ chỉ vi', () {
      expect(AsrModelRouter.installedLanguages(isInstalled: installedOnly({})),
          isEmpty);
      expect(
        AsrModelRouter.installedLanguages(
          isInstalled: installedOnly({'asr-vi-30M-int8'}),
        ),
        ['vi'],
      );
    });

    test('offlineFileProfile: ngôn ngữ châu Âu route về Parakeet', () {
      final installed = installedOnly({kParakeetProfileId});
      for (final language in ['fr', 'de', 'es', 'pt']) {
        expect(
          AsrModelRouter.offlineFileProfile(language, isInstalled: installed)?.id,
          kParakeetProfileId,
        );
      }
    });

    test('offlineFileProfile KHÔNG trả model streaming (file STT sẽ SIGABRT)',
        () {
      // Máy chỉ có EN streaming: transcribe file bằng nó = crash native.
      expect(
        AsrModelRouter.offlineFileProfile(
          'en',
          isInstalled: installedOnly({'asr-en-20M-streaming-int8'}),
        ),
        isNull,
      );
      // Có Parakeet (offline) ⇒ EN dùng Parakeet cho file là hợp lệ.
      expect(
        AsrModelRouter.offlineFileProfile(
          'en',
          isInstalled: installedOnly({kParakeetProfileId}),
        )?.id,
        kParakeetProfileId,
      );
      // VI offline dùng được cho file.
      expect(
        AsrModelRouter.offlineFileProfile(
          'vi',
          isInstalled: installedOnly({'asr-vi-30M-int8'}),
        )?.id,
        'asr-vi-30M-int8',
      );
    });

    test('offlineFileProfile: chưa cài ⇒ null (không bịa model)', () {
      expect(
        AsrModelRouter.offlineFileProfile('fr', isInstalled: installedOnly({})),
        isNull,
      );
    });
  });

  group('PARAKEET-002 — Cabin live dùng Parakeet', () {
    test('Parakeet đã cài + chọn tiếng Đức ⇒ canStart, route VAD offline', () {
      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: 'de-DE',
        isInstalled: installedOnly({kParakeetProfileId}),
      );
      expect(plan.requestedLanguage, 'de');
      expect(plan.canStart, isTrue);
      expect(plan.hasModel, isTrue);
      expect(plan.profile?.family, SherpaAsrFamily.parakeet);
      // Parakeet không có bản streaming ⇒ live = OfflineRecognizer + Silero VAD.
      expect(plan.liveRoute, AsrLiveRoute.simulatedOffline);
      expect(plan.canTranscribeFiles, isTrue);
      expect(plan.fallbackLanguage, isNull);
    });

    test('chưa cài Parakeet + chọn tiếng Tây Ban Nha ⇒ báo thiếu đúng profile',
        () {
      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: 'es',
        isInstalled: installedOnly({}),
      );
      expect(plan.canStart, isFalse);
      expect(plan.issue, AsrModelIssue.profileNotInstalled);
      expect(plan.profile?.id, kParakeetProfileId);
    });

    test('EN streaming không dùng được cho file nhưng vẫn live được', () {
      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: 'en',
        isInstalled: installedOnly({'asr-en-20M-streaming-int8'}),
      );
      expect(plan.canStart, isTrue);
      expect(plan.liveRoute, AsrLiveRoute.onlineStreaming);
      expect(plan.canTranscribeFiles, isFalse);
    });
  });

  group('PARAKEET-002 — quick capture dùng ngôn ngữ của Parakeet', () {
    test('máy chỉ cài Parakeet + app tiếng Đức ⇒ nhận diện tiếng Đức', () {
      final installed = AsrModelRouter.installedLanguages(
        isInstalled: installedOnly({kParakeetProfileId}),
      );
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'de',
          sherpaLanguages: installed,
        ),
        'de',
      );
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'uk',
          sherpaLanguages: installed,
        ),
        'uk',
      );
    });

    test('app tiếng Nhật (Parakeet không có) ⇒ vẫn fallback VI như cũ', () {
      final installed = AsrModelRouter.installedLanguages(
        isInstalled: installedOnly({kParakeetProfileId, 'asr-vi-30M-int8'}),
      );
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'ja',
          sherpaLanguages: installed,
        ),
        'vi',
      );
    });
  });
}
