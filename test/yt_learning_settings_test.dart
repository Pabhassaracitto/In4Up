// YT-LR-002 / IN4-88 — Pin hành vi cài đặt học tập của chế độ YouTube.
//
// Test thuần (không cần Flutter binding / máy thật): model nằm ở
// `lib/features/youtube/models/yt_learning_settings.dart`, tách khỏi
// presentation để gate i18n khỏi quét và để test được trực tiếp.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';

void main() {
  group('YtLearningSettings — mặc định', () {
    test('có bản dịch + bố cục trên/dưới + ngưỡng 300', () {
      const s = YtLearningSettings();
      expect(s.translationMode, YtTranslationMode.withTranslation);
      expect(s.subtitleLayout, YtSubtitleLayout.stacked);
      expect(s.frequencyRankThreshold, 300);
      expect(s.showsTranslation, isTrue);
      expect(s.hidesSubtitle, isFalse);
      expect(s.blursTranslation, isFalse);
    });
  });

  group('YtTranslationMode — 4 chế độ dịch', () {
    test('withTranslation: hiện dịch, không mờ', () {
      const s = YtLearningSettings(
        translationMode: YtTranslationMode.withTranslation,
      );
      expect(s.showsTranslation, isTrue);
      expect(s.blursTranslation, isFalse);
      expect(s.hidesSubtitle, isFalse);
    });

    test('hideTranslation: không hiện dịch', () {
      const s = YtLearningSettings(
        translationMode: YtTranslationMode.hideTranslation,
      );
      expect(s.showsTranslation, isFalse);
      expect(s.hidesSubtitle, isFalse);
    });

    test('blurTranslation: vẫn render dịch nhưng bị mờ', () {
      const s = YtLearningSettings(
        translationMode: YtTranslationMode.blurTranslation,
      );
      // Phải render (để bấm hiện tạm) — UI dùng `blursTranslation` để blur.
      expect(s.showsTranslation, isTrue);
      expect(s.blursTranslation, isTrue);
    });

    test('hideSubtitle: ẩn cả gốc lẫn dịch', () {
      const s = YtLearningSettings(
        translationMode: YtTranslationMode.hideSubtitle,
      );
      expect(s.hidesSubtitle, isTrue);
      expect(s.showsTranslation, isFalse);
    });
  });

  group('YtLearningSettings.isEasy — thanh trượt tần suất', () {
    test('rank <= ngưỡng là dễ, rank > ngưỡng là khó', () {
      const s = YtLearningSettings(frequencyRankThreshold: 300);
      expect(s.isEasy(100), isTrue);
      expect(s.isEasy(300), isTrue); // biên trên: vẫn tính đã quen
      expect(s.isEasy(340), isFalse);
    });

    test('kéo thanh trượt đổi ngưỡng', () {
      const s = YtLearningSettings(frequencyRankThreshold: 100);
      expect(s.isEasy(340), isFalse);
      final widened = s.copyWith(frequencyRankThreshold: 2000);
      expect(widened.isEasy(340), isTrue);
      expect(s.isEasy(340), isFalse); // copyWith không đổi bản gốc
    });
  });

  group('YtLearningSettings — persist', () {
    test('toJson → fromJson giữ nguyên', () {
      const s = YtLearningSettings(
        translationMode: YtTranslationMode.blurTranslation,
        subtitleLayout: YtSubtitleLayout.sideBySide,
        frequencyRankThreshold: 450,
      );
      final restored = YtLearningSettings.fromJson(s.toJson());
      expect(restored.translationMode, YtTranslationMode.blurTranslation);
      expect(restored.subtitleLayout, YtSubtitleLayout.sideBySide);
      expect(restored.frequencyRankThreshold, 450);
    });

    test('dữ liệu hỏng / thiếu ⇒ về mặc định, không crash', () {
      expect(
        YtLearningSettings.fromJson(<String, dynamic>{}).translationMode,
        YtTranslationMode.withTranslation,
      );
      expect(
        YtLearningSettings.fromJson(<String, dynamic>{
          'translationMode': 'khongTonTai',
          'subtitleLayout': 42,
          'frequencyRankThreshold': null,
        }).subtitleLayout,
        YtSubtitleLayout.stacked,
      );
    });
  });
}
