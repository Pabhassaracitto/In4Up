// AGENTS.md — Quy tắc vàng #5 (máy bắt):
//   Locale ≠ tiếng Việt → chrome UI không được còn tiếng Việt.
//   Thiếu bản dịch ngôn ngữ đó thì hiện English. Không bao giờ fallback về vi.
//
// Test này là "máy bắt" cho catalog đã review:
//   1. Mọi giá trị dịch trong generatedUiTranslations (mọi locale ≠ vi)
//      không chứa ký tự tiếng Việt (bộ ký tự không trùng với Romance
//      fr/es/pt/it — tránh false positive trên é/è/á/ó...).
//   2. Mọi entry phải có giá trị 'en' (canonical fallback — thứ tự
//      "locale có sẵn → en", không đoán).
//   3. English fallbacks legacy + legacy_ui_english_overrides.json
//      không chứa ký tự tiếng Việt.
//
// KHÔNG áp dụng cho: nội dung user, từ vựng/nghĩa user nhập, output AI,
// transcript STT, tiêu đề chương auto-TOC (những thứ đó không nằm trong
// catalog chrome này).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/generated_legacy_ui_fallbacks.dart';
import 'package:in4up/core/language/generated_ui_translations.dart';
import 'package:in4up/core/language/language_roadmap.dart';

/// Ký tự tiếng Việt KHÔNG trùng với chữ cái có dấu của Romance languages
/// (fr/es/pt/it). Ví dụ: `é`/`è`/`á`/`ó`/`ù` là fr/es — không flag;
/// `ế`/`ị`/`ờ`/`đ`/`ơ`/`ư` là Việt — flag.
final RegExp _vietnameseOnly = RegExp(
  // đ, ơ, ư — duy nhất tiếng Việt
  r'[đĐơƠưƯ]'
  // a + thanh (loại à á ã — fr/es/pt)
  r'|[ảạằắẳẵặầấẩẫậ]'
  // e + thanh (loại è é — fr)
  r'|[ẻẽẹềếểễệ]'
  // i + thanh (loại ì — it)
  r'|[ỉĩị]'
  // o + thanh (loại ó ò — es/fr)
  r'|[ỏọồốổỗộờớởỡợ]'
  // u + thanh (loại ù — fr)
  r'|[ủũụừứửữự]'
  // y + thanh (loại ý — es/pt)
  r'|[ỳỷỹỵ]',
);

void main() {
  group('Rule 5 — chrome UI không tiếng Việt khi locale ≠ vi', () {
    test('generatedUiTranslations: mọi locale ≠ vi không có ký tự Việt', () {
      final violations = <String>[];
      for (final entry in generatedUiTranslations.entries) {
        for (final localeValue in entry.value.entries) {
          if (localeValue.key == 'vi') continue;
          final match = _vietnameseOnly.firstMatch(localeValue.value);
          if (match != null) {
            violations.add(
              "'${entry.key}' [${localeValue.key}] → "
              "'${localeValue.value}' (ký tự: '${match.group(0)}')",
            );
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Catalog chrome còn tiếng Việt ở locale ≠ vi '
            '(rule #5: phải hiện English, không fallback vi):\n'
            '${violations.take(10).join('\n')}',
      );
    });

    test('generatedUiTranslations: mọi entry có giá trị en (canonical fallback)',
        () {
      final missing = generatedUiTranslations.entries
          .where((e) => !e.value.containsKey('en') ||
              e.value['en']!.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(
        missing,
        isEmpty,
        reason: 'Entry thiếu bản dịch en (rule #5: thứ tự locale → en, '
            'không đoán):\n${missing.take(10).join('\n')}',
      );
    });

    test('generatedLegacyUiEnglishFallbacks: English không có ký tự Việt', () {
      final violations = <String>[];
      for (final entry in generatedLegacyUiEnglishFallbacks.entries) {
        final match = _vietnameseOnly.firstMatch(entry.value);
        if (match != null) {
          violations.add(
            "'${entry.key}' → '${entry.value}' (ký tự: '${match.group(0)}')",
          );
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'English fallbacks còn tiếng Việt:\n'
            '${violations.take(10).join('\n')}',
      );
    });

    test('legacy_ui_english_overrides.json: English không có ký tự Việt', () {
      final file = File('tool/legacy_ui_english_overrides.json');
      expect(file.existsSync(), isTrue,
          reason: 'Thiếu file overrides — pipeline rule #5 bị hỏng');
      final overrides =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final violations = <String>[];
      overrides.forEach((key, value) {
        if (value is! String) return;
        final match = _vietnameseOnly.firstMatch(value);
        if (match != null) {
          violations.add(
            "'$key' → '$value' (ký tự: '${match.group(0)}')",
          );
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'Overrides English còn tiếng Việt:\n'
            '${violations.take(10).join('\n')}',
      );
    });
  });

  // ============================================================
  // ADR-0002 — Lộ trình phủ ngôn ngữ: vi → en → hi/zh/si → …
  // (máy bắt, group tách để dễ tìm; node này chạy trong cùng file để
  // CI app_analyze.yml không cần đổi workflow.)
  // ============================================================
  group('ADR-0002 — Rule #5 ở tầng ARB (locale ≠ vi không còn tiếng Việt)', () {
    final arbDir = Directory('lib/l10n');
    Map<String, String> loadArb(String path) {
      final data =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      return {
        for (final e in data.entries)
          if (!e.key.startsWith('@') && e.value is String)
            e.key: e.value as String,
      };
    }

    final en = loadArb('lib/l10n/app_en.arb');
    final rolloutLocales = arbDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.startsWith('app_') && name.endsWith('.arb'))
        .map((name) => name.substring(4, name.length - 4))
        .where((loc) => loc != 'en' && loc != 'vi')
        .toList()
      ..sort();

    test('mọi locale ≠ vi có đủ key như app_en.arb', () {
      final violations = <String>[];
      for (final loc in rolloutLocales) {
        final msgs = loadArb('lib/l10n/app_$loc.arb');
        final missing = en.keys.toSet().difference(msgs.keys.toSet());
        final extra = msgs.keys.toSet().difference(en.keys.toSet());
        if (missing.isNotEmpty || extra.isNotEmpty) {
          violations.add('$loc: thiếu ${missing.length}, thừa ${extra.length}');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'ARB lệch key với template en → gen-l10n fallback lẫn lộn:\n'
            '${violations.join('\n')}',
      );
    });

    test('mọi locale ≠ vi không có ký tự Việt trong giá trị ARB', () {
      final violations = <String>[];
      for (final loc in rolloutLocales) {
        final msgs = loadArb('lib/l10n/app_$loc.arb');
        for (final e in msgs.entries) {
          final m = _vietnameseOnly.firstMatch(e.value);
          if (m != null) {
            violations.add("$loc ['${e.key}'] chứa '${m.group(0)}'");
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Rule #5: locale ≠ vi thiếu dịch thì phải là English, '
            'không được là tiếng Việt:\n${violations.take(10).join('\n')}',
      );
    });
  });

  group('ADR-0002 — sàn ratchet & độ phủ (phủ dần, không lùi)', () {
    Map<String, String> loadArb(String path) {
      final data =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      return {
        for (final e in data.entries)
          if (!e.key.startsWith('@') && e.value is String)
            e.key: e.value as String,
      };
    }

    final en = loadArb('lib/l10n/app_en.arb');
    final keepData =
        jsonDecode(File('tool/lang_keep_english.json').readAsStringSync())
            as Map<String, dynamic>;
    final keepGlobal =
        (keepData['keepEnglish'] as List).cast<String>().toSet();
    final keepByLocale =
        (keepData['keepEnglishByLocale'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as List).cast<String>().toSet()));
    final floorsJson =
        (jsonDecode(File('tool/lang_rollout_floors.json').readAsStringSync())
                as Map<String, dynamic>)['floors']
            as Map<String, dynamic>;

    final locales = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.startsWith('app_') && name.endsWith('.arb'))
        .map((name) => name.substring(4, name.length - 4))
        .where((loc) => loc != 'en' && loc != 'vi')
        .toList()
      ..sort();

    test('coverageFloors (Dart) == tool/lang_rollout_floors.json', () {
      expect(
        {...LanguageRollout.coverageFloors.keys}
            .difference(floorsJson.keys.toSet()),
        isEmpty,
        reason: 'Locale có sàn trong Dart nhưng thiếu trong JSON (hoặc ngược lại)',
      );
      for (final e in floorsJson.entries) {
        expect(
          LanguageRollout.coverageFloors[e.key],
          (e.value as num).toDouble(),
          reason: "Sàn lệch nhau ở '${e.key}' — cập nhật đồng bộ 2 nơi "
              '(language_roadmap.dart + lang_rollout_floors.json). '
              'Sàn chỉ được RA LÊN.',
        );
      }
    });

    test('tier T2 == 4 ngôn ngữ ưu tiên hi/zh/zh_TW/si', () {
      final t2 = LanguageRollout.tiers.firstWhere((t) => t.id == 'T2');
      expect({...t2.locales}, {...LanguageRollout.priorityLocales});
      // vi/en là bậc neo T0/T1, không thuộc rollout.
      expect(LanguageRollout.isPriority('vi'), isFalse);
      expect(LanguageRollout.isPriority('en'), isFalse);
      expect(LanguageRollout.tierOf('vi')!.id, 'T0');
      expect(LanguageRollout.tierOf('en')!.id, 'T1');
      // Canonicalize: language-tag `zh-TW`/`zh-Hant` phải ra đúng T2 + sàn.
      expect(LanguageRollout.tierOf('zh-TW')!.id, 'T2');
      expect(LanguageRollout.tierOf('zh-Hant')!.id, 'T2');
      expect(LanguageRollout.tierOf('zh')!.id, 'T2');
      expect(LanguageRollout.floorFor('zh_TW'), 1.0);
      expect(LanguageRollout.floorFor('zh-TW'), 1.0);
      expect(LanguageRollout.floorFor('si'), 1.0);
      expect(LanguageRollout.tierOf('fr')!.id, 'T3');
    });

    test('mọi locale ≥ sàn độ phủ', () {
      final violations = <String>[];
      for (final loc in locales) {
        final keep = keepGlobal.union(keepByLocale[loc] ?? const <String>{});
        final total = en.length - keep.length;
        final msgs = loadArb('lib/l10n/app_$loc.arb');
        var translated = 0;
        for (final e in en.entries) {
          if (keep.contains(e.key)) continue;
          if (msgs[e.key] != e.value) translated++;
        }
        final coverage = translated / total;
        final floor = LanguageRollout.floorFor(loc);
        if (coverage + 1e-9 < floor) {
          violations.add(
            '$loc: độ phủ ${coverage.toStringAsFixed(4)} '
            '($translated/$total message) < sàn $floor',
          );
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Độ phủ tụt dưới sàn ratchet — lùi lộ trình. '
            'Phục hồi bản dịch hoặc nâng sàn bằng ADR (chỉ tăng):\n'
            '${violations.join('\n')}',
      );
    });

    test('T2 ưu tiên phủ 100% (wave 1) — key mới phải dịch đủ 4 locale', () {
      final violations = <String>[];
      for (final loc in LanguageRollout.priorityLocales) {
        final keep = keepGlobal.union(keepByLocale[loc] ?? const <String>{});
        final msgs = loadArb('lib/l10n/app_$loc.arb');
        final englishLeft = [
          for (final e in en.entries)
            if (!keep.contains(e.key) && msgs[e.key] == e.value) e.key,
        ];
        if (englishLeft.isNotEmpty) {
          violations.add('$loc còn English: ${englishLeft.take(5).join(', ')}');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'T2 đã đạt 100% ở wave 1 (2026-08-22) — '
            'thêm key mới phải dịch đủ hi/zh/zh_TW/si ngay trong cùng PR:\n'
            '${violations.join('\n')}',
      );
    });

    test('key keep-English tồn tại và đúng chính sách', () {
      final violations = <String>[];
      for (final key in keepGlobal) {
        if (!en.containsKey(key)) {
          violations.add('keepEnglish toàn cục: key "$key" không có trong ARB');
        }
      }
      keepByLocale.forEach((loc, keys) {
        if (!locales.contains(loc)) {
          violations.add('keepEnglishByLocale: locale "$loc" không tồn tại');
          return;
        }
        for (final key in keys) {
          if (!en.containsKey(key)) {
            violations.add('keepEnglishByLocale $loc: key "$key" không có');
          }
        }
      });
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
