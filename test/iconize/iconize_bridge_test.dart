// test/iconize/iconize_bridge_test.dart
//
// ICONIZE-001c — Bridge-to-English (vi), nguồn icon user (tầng 1 fallback)
// và posHint từ cú pháp. Chạy trên ASSET THẬT + OfflineDictionary thật.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/iconize/data/iconize_binary.dart';
import 'package:in4up/features/iconize/engine/iconize_bridge.dart';
import 'package:in4up/features/iconize/engine/iconize_engine.dart';
import 'package:in4up/features/iconize/engine/iconize_icon_source.dart';
import 'package:in4up/features/iconize/engine/iconize_lemmatizer.dart';
import 'package:in4up/features/iconize/models/iconize_span.dart';
import 'package:in4up/features/translation/data/offline_dictionary.dart';

class _FakeUserIconSource implements IconizeIconSource {
  final Map<String, String> byLemma;
  _FakeUserIconSource(this.byLemma);

  @override
  String? resolve(String lemma, IconizePos pos) => byLemma[lemma];

  @override
  IconizeSource get sourceKind => IconizeSource.userVocabImage;
}

DefaultIconizeEngine _engine({
  List<IconizeIconSource> userSources = const [],
  EnglishBridgeDictionary? bridge,
}) {
  return DefaultIconizeEngine(
    concreteness: ConcretenessTable(
        File('assets/iconize/concreteness.bin').readAsBytesSync()),
    iconIndex: IconIndexTable(
        File('assets/iconize/icon_index.bin').readAsBytesSync()),
    iconsBundle: IconsBundle(
        File('assets/iconize/icons_bundle.bin').readAsBytesSync()),
    lemmatizer: IconizeLemmatizer.fromJsonString(
        File('assets/iconize/irregular_lemmas.json').readAsStringSync()),
    userSources: userSources,
    bridge: bridge,
  );
}

void main() {
  final bridge =
      EnglishBridgeDictionary.fromEnViEntries(OfflineDictionary.entries);

  group('EnglishBridgeDictionary', () {
    test('đảo nghĩa đơn: mưa→rain, tuyết→snow, nước→water', () {
      expect(bridge.englishCandidates('mưa'), contains('rain'));
      expect(bridge.englishCandidates('tuyết'), contains('snow'));
      expect(bridge.englishCandidates('nước'), contains('water'));
    });

    test('bóc loại từ: "cái cây"→cây→tree, "cuốn sách"→sách→book', () {
      expect(bridge.englishCandidates('cây'), contains('tree'));
      expect(bridge.englishCandidates('sách'), contains('book'));
    });

    test('KHÔNG bóc "mặt": trời không được map sang sun', () {
      expect(bridge.englishCandidates('trời'), isEmpty);
    });

    test('từ không có trong từ điển → rỗng (giữ chữ)', () {
      expect(bridge.englishCandidates('xyz'), isEmpty);
      expect(bridge.entryCount, greaterThan(100));
    });
  });

  group('engine + bridge: câu tiếng Việt (density high)', () {
    final engine = _engine(bridge: bridge);

    Future<Set<String>> surfaces(String text) async {
      final r = await engine.iconize(text,
          langCode: 'vi', density: IconizeDensity.high);
      expect(r.plainText, text);
      return r.spans.map((s) => s.surfaceForm).toSet();
    }

    test('Mưa rơi mãi trên chiếc giường nhỏ. → mưa + giường', () async {
      expect(await surfaces('Mưa rơi mãi trên chiếc giường nhỏ.'),
          {'Mưa', 'giường'});
    });

    test('Nước và lửa không hợp nhau. → nước + lửa', () async {
      expect(await surfaces('Nước và lửa không hợp nhau.'),
          {'Nước', 'lửa'});
    });

    test('span vi mang lemma EN + icon bundle', () async {
      final r = await engine.iconize('Tuyết rơi ngoài cửa sổ đêm nay.',
          langCode: 'vi', density: IconizeDensity.high);
      final tuyet =
          r.spans.where((s) => s.surfaceForm == 'Tuyết').toList();
      expect(tuyet, hasLength(1));
      expect(tuyet.single.lemma, 'snow');
      expect(tuyet.single.pos, 'NOUN');
      expect(tuyet.single.iconAssetRef, startsWith('bundle:'));
    });

    test('từ ngoài từ điển / trừu tượng → giữ chữ', () async {
      expect(await surfaces('Tự do là điều quý giá.'), isEmpty);
    });
  });

  group('nguồn icon user (tầng 1 fallback)', () {
    test('ảnh user thắng bundle cho cùng lemma', () async {
      final engine = _engine(userSources: [
        _FakeUserIconSource({'cat': 'file:/data/user/cat.webp'}),
      ]);
      final r = await engine.iconize('The cat catches the mouse.',
          langCode: 'en', density: IconizeDensity.high);
      final cat = r.spans.singleWhere((s) => s.lemma == 'cat');
      expect(cat.iconAssetRef, 'file:/data/user/cat.webp');
      expect(cat.source, IconizeSource.userVocabImage);
      final mouse = r.spans.singleWhere((s) => s.lemma == 'mouse');
      expect(mouse.source, IconizeSource.localTwemoji);
    });

    test('icon user vẫn bị cổng concreteness chặn (freedom)', () async {
      final engine = _engine(userSources: [
        _FakeUserIconSource({'freedom': 'file:/x.webp'}),
      ]);
      final r = await engine.iconize('Freedom is a beautiful idea.',
          langCode: 'en', density: IconizeDensity.high);
      expect(r.spans, isEmpty);
    });
  });

  group('posHint từ cú pháp (blueprint 3.4)', () {
    final engine = _engine();

    test('không hint: "taste" bị Dom_Pos coi là danh từ → có icon',
        () async {
      final r = await engine.iconize('Apples taste sweet in early winter.',
          langCode: 'en', density: IconizeDensity.high);
      expect(r.spans.map((s) => s.surfaceForm), contains('taste'));
    });

    test('hint VERB cho "taste" → giữ chữ, Apples vẫn có icon', () async {
      final r = await engine.iconize(
        'Apples taste sweet in early winter.',
        langCode: 'en',
        density: IconizeDensity.high,
        posHint: (start, surface) =>
            surface == 'taste' ? IconizePos.verb : null,
      );
      expect(r.spans.map((s) => s.surfaceForm).toSet(), {'Apples'});
    });

    test('hint NOUN + icon user mở từ Dom_Pos=VERB ("kiss")', () async {
      final withUser = _engine(userSources: [
        _FakeUserIconSource({'kiss': 'file:/u/kiss.webp'}),
      ]);
      // Không hint: Dom_Pos VERB chặn từ cổng POS — kể cả có icon user.
      final noHint = await withUser.iconize('She gave him a quick kiss.',
          langCode: 'en', density: IconizeDensity.high);
      expect(noHint.spans, isEmpty);
      // Hint NOUN: qua cổng POS (conc 4.5 >= 4.0), icon user cấp ref —
      // không cần index bundle (kiss|NOUN không tồn tại trong index).
      final hinted = await withUser.iconize(
        'She gave him a quick kiss.',
        langCode: 'en',
        density: IconizeDensity.high,
        posHint: (start, surface) =>
            surface == 'kiss' ? IconizePos.noun : null,
      );
      expect(hinted.spans, hasLength(1));
      expect(hinted.spans.single.lemma, 'kiss');
      expect(hinted.spans.single.iconAssetRef, 'file:/u/kiss.webp');
      expect(hinted.spans.single.source, IconizeSource.userVocabImage);
    });
  });
}
