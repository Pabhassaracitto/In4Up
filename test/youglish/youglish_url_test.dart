// PRON-001 (ADR-0015 D5) — golden test chốt URL YouGlish.
//
// Vì sao cần: PRON-001 gom 2 bản `_buildUrl()` trùng lặp (youglish_widget.dart
// và word_list/youglish_mini_sheet.dart) về `YouGlishUrl.build` với ràng buộc
// KHÔNG đổi hành vi. Test này sao chép NGUYÊN VĂN hai hàm cũ và yêu cầu bản mới
// cho ra chuỗi giống hệt trên toàn ma trận từ/ngôn ngữ/accent/autoplay.
//
// Thuần Dart, không plugin, không mạng ⇒ chạy được trong CI `app_analyze`
// (bước "PRON-001 tests").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/tools/youglish/youglish_config.dart';

/// Bản gốc của `_buildUrl()` trong `youglish_widget.dart` (trước PRON-001).
String legacyWidgetUrl({
  required String word,
  required YouGlishLanguage language,
  YouGlishAccent? accent,
  bool autoPlay = true,
}) {
  var url = 'https://youglish.com/pronounce/${Uri.encodeComponent(word)}';
  if (language == YouGlishLanguage.english && accent != null) {
    url += '/${language.code}/${accent.code}';
  } else {
    url += '/${language.code}';
  }
  url += '?embed=1';
  if (autoPlay) url += '&autoplay=1';
  return url;
}

/// Bản gốc của `_buildUrl()` trong `word_list/youglish_mini_sheet.dart`
/// (trước PRON-001) — accent luôn có, autoplay luôn bật.
String legacyMiniSheetUrl({
  required String word,
  required YouGlishLanguage lang,
  required YouGlishAccent accent,
}) {
  var url = 'https://youglish.com/pronounce/${Uri.encodeComponent(word)}';
  if (lang == YouGlishLanguage.english) {
    url += '/${lang.code}/${accent.code}';
  } else {
    url += '/${lang.code}';
  }
  url += '?embed=1&autoplay=1';
  return url;
}

const _words = [
  'hello',
  'thoroughly',
  'global warming',
  'naïve façade',
  'X-Ray',
  "don't",
  'a/b',
  '你好',
  '  padded  ',
  '',
];

void main() {
  group('YouGlishUrl.build — byte-identical với 2 bản cũ (PRON-001)', () {
    test('ma trận đủ: từ × ngôn ngữ × accent, autoplay = true', () {
      for (final word in _words) {
        for (final lang in YouGlishLanguage.values) {
          for (final accent in YouGlishAccent.values) {
            // youglish_widget cũ: screen truyền accent = null khi ≠ English.
            final widgetAccent =
                lang == YouGlishLanguage.english ? accent : null;
            expect(
              YouGlishUrl.build(
                  word: word,
                  language: lang,
                  accent: widgetAccent,
                  autoplay: true),
              legacyWidgetUrl(
                  word: word,
                  language: lang,
                  accent: widgetAccent,
                  autoPlay: true),
              reason: 'youglish_widget: "$word" / ${lang.code}',
            );
            expect(
              YouGlishUrl.build(
                  word: word,
                  language: lang,
                  accent: accent,
                  autoplay: true),
              legacyMiniSheetUrl(word: word, lang: lang, accent: accent),
              reason: 'youglish_mini_sheet: "$word" / ${lang.code}',
            );
          }
        }
      }
    });

    test('accent = null với ngôn ngữ khác English vẫn đúng', () {
      expect(
        YouGlishUrl.build(
            word: 'bonjour',
            language: YouGlishLanguage.french,
            accent: null),
        'https://youglish.com/pronounce/bonjour/french?embed=1&autoplay=1',
      );
    });

    test('autoplay = false bỏ đúng hậu tố, giữ embed', () {
      // Hành vi mới chỉ dùng ở PRON-003 (tắt autoplay mặc định) — chốt ở đây để
      // không ai "tiện tay" nối '&autoplay=0'.
      expect(
        YouGlishUrl.build(
            word: 'water',
            language: YouGlishLanguage.english,
            accent: YouGlishAccent.uk,
            autoplay: false),
        'https://youglish.com/pronounce/water/english/uk?embed=1',
      );
    });

    test('URL mặc định của tool YouGlish đúng định dạng YouGlish thật', () {
      final url = Uri.parse(YouGlishUrl.build(
        word: 'hello',
        language: YouGlishLanguage.english,
        accent: YouGlishAccent.us,
      ));
      expect(url.host, 'youglish.com');
      expect(url.pathSegments.first, 'pronounce');
      expect(url.pathSegments[1], 'hello');
      expect(url.pathSegments[2], 'english');
      expect(url.pathSegments[3], 'us');
    });
  });

  group('Enum YouGlish', () {
    test('code duy nhất + fromCode đảo ngược được', () {
      final codes = <String>{};
      for (final l in YouGlishLanguage.values) {
        expect(codes.add(l.code), isTrue, reason: 'code trùng: ${l.code}');
        expect(YouGlishLanguage.fromCode(l.code), l);
      }
      final accentCodes = <String>{};
      for (final a in YouGlishAccent.values) {
        expect(accentCodes.add(a.code), isTrue, reason: 'code trùng: ${a.code}');
        expect(YouGlishAccent.fromCode(a.code), a);
      }
    });

    test('fromCode trả null cho dữ liệu rác (không ném)', () {
      expect(YouGlishLanguage.fromCode('klingon'), isNull);
      expect(YouGlishLanguage.fromCode(null), isNull);
      expect(YouGlishAccent.fromCode(''), isNull);
    });

    test('English + 4 giọng mở rộng mà UI cũ chưa có (CAN/IE/SCO/NZ)', () {
      expect(YouGlishAccent.values.length, 7);
      // Người dùng In4Up học tiếng Việt / Hindi / Trung — enum cũ thiếu.
      expect(YouGlishLanguage.fromCode('vietnamese'), isNotNull);
      expect(YouGlishLanguage.fromCode('hindi'), isNotNull);
      expect(YouGlishLanguage.fromCode('chinese'), isNotNull);
    });

    test('mini sheet không còn cắt 5 ngôn ngữ', () {
      expect(YouGlishLanguage.values.length, greaterThan(5));
    });
  });

  group('Một nguồn sự thật (ADR-0015 D5)', () {
    test('lib/ chỉ có ĐÚNG MỘT file dựng URL pronounce', () {
      final lib = Directory('lib');
      if (!lib.existsSync()) {
        // Chạy ngoài thư mục gốc package — bỏ qua, không báo đỏ giả.
        return;
      }
      final hits = <String>[];
      for (final e in lib.listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        if (e.readAsStringSync().contains('youglish.com/pronounce')) {
          hits.add(e.path.replaceAll(r'\', '/'));
        }
      }
      expect(
        hits,
        ['lib/screens/tools/youglish/youglish_config.dart'],
        reason: 'URL builder phải nằm ở MỘT chỗ duy nhất — PRON-001',
      );
    });

    test('không còn WebViewController riêng cho YouGlish ngoài youglish_view',
        () {
      final dirs = [
        Directory('lib/screens/tools/youglish'),
        Directory('lib/screens/tools/word_list'),
      ];
      for (final d in dirs) {
        if (!d.existsSync()) continue;
        for (final e in d.listSync(recursive: true).whereType<File>()) {
          if (!e.path.endsWith('.dart')) continue;
          if (e.path.replaceAll(r'\', '/').endsWith('youglish_view.dart')) {
            continue;
          }
          expect(
            e.readAsStringSync().contains('WebViewController('),
            isFalse,
            reason: '${e.path} vẫn tự tạo WebView — phải dùng YouGlishView',
          );
        }
      }
    });
  });
}
