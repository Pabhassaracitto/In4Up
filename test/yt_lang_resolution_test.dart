// YT-AUDIT-04 (IN4-103) — Ngôn ngữ đích của bản dịch phụ đề YouTube.
//
// Câu hỏi của owner (2026-10-20):
//   "Ngôn ngữ đích nên là English hay là ngôn ngữ trong Cài đặt Home?"
// Chốt: mặc định = CÀI ĐẶT HOME, có override từng video; English là một lựa
// chọn trong menu, KHÔNG phải mặc định. Pha lén `target == 'en' ? 'vi'` cũ bị
// xoá — nếu vẫn phải rớt về `vi` thì phải BÁO RA, không im lặng.
//
// Test thuần (không cần Flutter binding / máy thật).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';

void main() {
  group('resolveTargetLang — mặc định theo Cài đặt Home', () {
    test('Home để Việt ⇒ dịch sang Việt', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        homeTargetLang: 'vi',
      );
      expect(r.lang, 'vi');
      expect(r.fellBack, isFalse);
    });

    test('Home để Nhật ⇒ dịch sang Nhật (không ép về Việt)', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        homeTargetLang: 'ja',
      );
      expect(r.lang, 'ja');
      expect(r.fellBack, isFalse);
    });

    test('Home rỗng ⇒ rớt về Việt', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        homeTargetLang: '',
      );
      expect(r.lang, 'vi');
    });
  });

  group('resolveTargetLang — override từng video thắng Home', () {
    test('chọn English ⇒ dịch sang English (hợp lệ, không bị đổi lén)', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'ja',
        overrideTargetLang: 'en',
        homeTargetLang: 'vi',
      );
      expect(r.lang, 'en');
      expect(r.fellBack, isFalse,
          reason: 'phụ đề gốc ja ≠ en ⇒ dịch Anh là có nghĩa');
    });

    test('chọn Pháp ⇒ dịch sang Pháp', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        overrideTargetLang: 'fr',
        homeTargetLang: 'vi',
      );
      expect(r.lang, 'fr');
      expect(r.fellBack, isFalse);
    });

    test('override rỗng ⇒ coi như không override, bám Home', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        overrideTargetLang: '   ',
        homeTargetLang: 'vi',
      );
      expect(r.lang, 'vi');
    });

    test('viết hoa / khoảng trắng được chuẩn hoá', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'EN',
        overrideTargetLang: ' VI ',
        homeTargetLang: 'ja',
      );
      expect(r.lang, 'vi');
    });
  });

  group('resolveTargetLang — đích trùng phụ đề gốc ⇒ rớt vi NHƯNG BÁO', () {
    test('phụ đề en + Home en ⇒ vi, fellBack = true', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        homeTargetLang: 'en',
      );
      expect(r.lang, 'vi');
      expect(r.fellBack, isTrue,
          reason: 'phải báo để UI hiện dòng giải thích, không lén đổi');
    });

    test('phụ đề en + override en ⇒ vi, fellBack = true', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'en',
        overrideTargetLang: 'en',
        homeTargetLang: 'vi',
      );
      expect(r.lang, 'vi');
      expect(r.fellBack, isTrue);
    });

    test('phụ đề a.en (auto-generated) + Home en ⇒ vi, fellBack = true', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'a.en',
        homeTargetLang: 'en',
      );
      expect(r.lang, 'vi');
      expect(r.fellBack, isTrue);
    });

    test('phụ đề ja + Home ja ⇒ vi, fellBack = true', () {
      final r = YtLearningSettings.resolveTargetLang(
        subtitleLang: 'ja',
        homeTargetLang: 'ja',
      );
      expect(r.lang, 'vi');
      expect(r.fellBack, isTrue);
    });
  });

  group('copyWith — sentinel phân biệt "giữ nguyên" và "về theo Home"', () {
    test('không truyền targetLang ⇒ GIỮ nguyên giá trị cũ', () {
      const s = YtLearningSettings(targetLang: 'ja');
      expect(s.copyWith(subtitleLang: 'en').targetLang, 'ja');
    });

    test('truyền null ⇒ XOÁ override, quay lại theo Cài đặt Home', () {
      const s = YtLearningSettings(targetLang: 'ja');
      expect(s.copyWith(targetLang: null).targetLang, isNull);
    });

    test('truyền chuỗi ⇒ ghi đè', () {
      const s = YtLearningSettings(targetLang: 'ja');
      expect(s.copyWith(targetLang: 'ko').targetLang, 'ko');
    });

    test('từ mặc định (null) vẫn đặt được override', () {
      const s = YtLearningSettings();
      expect(s.targetLang, isNull);
      expect(s.copyWith(targetLang: 'en').targetLang, 'en');
    });
  });

  group('JSON — 2 khoá ngôn ngữ sống sót qua round-trip', () {
    test('mặc định: subtitleLang en, targetLang null', () {
      const s = YtLearningSettings();
      final decoded = YtLearningSettings.fromJson(s.toJson());
      expect(decoded.subtitleLang, 'en');
      expect(decoded.targetLang, isNull);
    });

    test('override English được giữ nguyên, KHÔNG bị đổi thành vi', () {
      const s = YtLearningSettings(
        subtitleLang: 'ja',
        targetLang: 'en',
      );
      final decoded = YtLearningSettings.fromJson(s.toJson());
      expect(decoded.subtitleLang, 'ja');
      expect(decoded.targetLang, 'en',
          reason: 'English là lựa chọn hợp lệ, không bị ép về Việt');
    });

    test('dữ liệu CŨ (thiếu 2 khoá) ⇒ en + theo Home, không crash', () {
      final decoded = YtLearningSettings.fromJson(<String, dynamic>{
        'translationMode': 'withTranslation',
        'subtitleLayout': 'stacked',
        'frequencyRankThreshold': 300,
      });
      expect(decoded.subtitleLang, 'en');
      expect(decoded.targetLang, isNull);
    });
  });
}
