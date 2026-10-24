// test/iconize/iconize_engine_golden_test.dart
//
// ICONIZE-001b — bộ vàng engine: >= 50 câu chạy trên ASSET THẬT
// (assets/iconize/), kỳ vọng chính xác tập từ được icon hóa.
// Mọi kỳ vọng đã được đối chiếu nội dung icon_index.bin lúc viết test —
// nếu tool build đổi luật chọn từ, test này PHẢI đỏ (đó là mục đích).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/iconize/data/iconize_binary.dart';
import 'package:in4up/features/iconize/engine/iconize_engine.dart';
import 'package:in4up/features/iconize/engine/iconize_lemmatizer.dart';
import 'package:in4up/features/iconize/models/iconize_span.dart';

DefaultIconizeEngine _loadEngine() {
  return DefaultIconizeEngine(
    concreteness: ConcretenessTable(
        File('assets/iconize/concreteness.bin').readAsBytesSync()),
    iconIndex: IconIndexTable(
        File('assets/iconize/icon_index.bin').readAsBytesSync()),
    iconsBundle: IconsBundle(
        File('assets/iconize/icons_bundle.bin').readAsBytesSync()),
    lemmatizer: IconizeLemmatizer.fromJsonString(
        File('assets/iconize/irregular_lemmas.json').readAsStringSync()),
  );
}

/// (câu, tập surface form kỳ vọng được icon hóa) — density high.
const List<(String, Set<String>)> golden = [
  // —— Nhóm A: danh từ cụ thể cơ bản ——
  ('The cat catches the mouse.', {'cat', 'mouse'}), // câu gốc blueprint
  ('The cat sleeps all day.', {'cat'}),
  ('My dog is very old.', {'dog'}),
  ('She eats an apple every morning.', {'apple'}),
  ('That mouse ran away yesterday.', {'mouse'}),
  ('We walked to the bank today.', {'bank'}),
  ('Their house is big and new.', {'house'}),
  ('His left eye hurts a little.', {'eye'}),
  ('The tree grew very tall here.', {'tree'}),
  ('A bird sang outside my window.', {'bird', 'window'}),
  ('The fish swam in cold water.', {'fish', 'water'}),
  ('He drives an old red car.', {'car'}),
  ('The boat sailed away this morning.', {'boat'}),
  ('Trains arrive here very early today.', {'Trains'}),
  ('She broke the cup this morning.', {'cup'}),
  ('Close the door before you leave.', {'door'}),
  ('The key is not here now.', {'key'}),
  ('His hat looks funny on him.', {'hat'}),
  ('Her shoe fell off the chair.', {'shoe', 'chair'}),
  ('Put the knife and spoon away.', {'knife', 'spoon'}),
  ('The horse jumped very high today.', {'horse'}),
  ('A monkey climbed up the tree.', {'monkey', 'tree'}),
  ('The lion sleeps near the tiger.', {'lion', 'tiger'}),
  ('Our rabbit hides under the bed.', {'rabbit', 'bed'}),
  ('I like milk with my bread.', {'milk', 'bread'}),
  ('The egg fell on the floor.', {'egg', 'floor'}),
  ('She baked fresh bread this morning.', {'bread'}),
  ('The moon rose above the sky.', {'moon', 'sky'}),
  ('Stars shine bright every single night.', {'Stars', 'night'}),
  ('Heavy rain fell on the street.', {'rain'}),
  ('Snow covered the whole street today.', {'Snow'}),
  ('The fire burned all night long.', {'fire', 'night'}),
  ('He plays the piano very well.', {'piano'}),
  ('She plays guitar and drums loudly.', {'guitar', 'drums'}),
  ('My phone fell into the water.', {'phone', 'water'}),
  ('The camera broke again this morning.', {'camera'}),
  ('Her ring shines in the sun.', {'ring', 'sun'}),
  ('His heart beats fast when running.', {'heart'}),
  ('My nose and ear feel cold.', {'nose', 'ear'}),
  ('Wash your hand and foot well.', {'hand', 'foot'}),
  ('Room 101 has one bed inside.', {'Room', 'bed'}),
  // —— Nhóm B: số nhiều + bất quy tắc ——
  ('Cats always chase mice in the garden.', {'Cats', 'mice', 'garden'}),
  ('The children found two eggs there.', {'children', 'eggs'}),
  ('Horses and dogs run very fast.', {'Horses', 'dogs'}),
  ('Her feet hurt a lot today.', {'feet'}),
  // —— Nhóm C: từ trừu tượng / động từ / tính từ nhạt → giữ chữ ——
  ('Freedom is a beautiful idea.', <String>{}),
  ('I think we should go now.', <String>{}),
  ('Love makes people very happy.', {'people'}), // people→person 🧑
  // —— Nhóm D: vùng cấm (URL / placeholder / code span / danh từ riêng) ——
  ('See www.example.com for the cat.', {'cat'}),
  ('The __G1__ sat near the dog.', {'dog'}),
  ('Type `cat` to see it now.', <String>{}),
  ('We visited Apple last summer there.', <String>{}),
  ('Apples fell down in early winter.', {'Apples'}),
];

void main() {
  final engine = _loadEngine();

  Future<Set<String>> surfaces(String text,
      {IconizeDensity density = IconizeDensity.high}) async {
    final r = await engine.iconize(text, langCode: 'en', density: density);
    expect(r.plainText, text, reason: 'plainText phải nguyên văn');
    return r.spans.map((s) => s.surfaceForm).toSet();
  }

  group('bộ vàng ${golden.length} câu (density high)', () {
    for (final (sentence, expected) in golden) {
      test(sentence, () async {
        expect(await surfaces(sentence), expected);
      });
    }
  });

  group('hành vi engine', () {
    test('span có offset đúng và iconAssetRef dạng bundle:', () async {
      final r = await engine.iconize('The cat catches the mouse.',
          langCode: 'en', density: IconizeDensity.high);
      expect(r.spans, hasLength(2));
      final cat = r.spans.first;
      expect(cat.surfaceForm, 'cat');
      expect('The cat catches the mouse.'.substring(cat.start, cat.end), 'cat');
      expect(cat.lemma, 'cat');
      expect(cat.pos, 'NOUN');
      expect(cat.iconAssetRef, startsWith('bundle:'));
      expect(cat.source, IconizeSource.localTwemoji);
      expect(cat.concreteness, greaterThanOrEqualTo(4.0));
      expect(r.spans, isNot(contains(predicate<IconizeSpan>(
          (s) => s.surfaceForm == 'catches', 'động từ bị icon hóa'))));
    });

    test('ngôn ngữ chưa hỗ trợ (ja) → spans rỗng', () async {
      final r = await engine.iconize('The cat catches the mouse.',
          langCode: 'ja');
      expect(r.spans, isEmpty);
      expect(r.actualIconPercent, 0);
    });

    test('vi KHÔNG có bridge → spans rỗng (engine này không gắn bridge)',
        () async {
      final r = await engine.iconize('Mưa rơi trên giường.', langCode: 'vi');
      expect(r.spans, isEmpty);
    });

    test('chuỗi rỗng → kết quả rỗng, không lỗi', () async {
      final r = await engine.iconize('', langCode: 'en');
      expect(r.spans, isEmpty);
      expect(r.actualIconPercent, 0);
    });

    test('sàn 1 icon: câu ngắn density low vẫn có đúng 1 icon', () async {
      final s = await surfaces('The cat sleeps.',
          density: IconizeDensity.low);
      expect(s, {'cat'});
    });

    test('ngân sách density đơn điệu: low <= medium <= high', () async {
      const text = 'The cat and the dog chase the mouse around the house '
          'while the bird watches from the tree near the window.';
      final low = (await engine.iconize(text,
              langCode: 'en', density: IconizeDensity.low))
          .spans
          .length;
      final med = (await engine.iconize(text,
              langCode: 'en', density: IconizeDensity.medium))
          .spans
          .length;
      final high = (await engine.iconize(text,
              langCode: 'en', density: IconizeDensity.high))
          .spans
          .length;
      expect(low, lessThanOrEqualTo(med));
      expect(med, lessThanOrEqualTo(high));
      expect(low, greaterThanOrEqualTo(1));
    });

    test('idempotency: gọi 2 lần cùng input → span y hệt', () async {
      const text = 'Cats always chase mice in the garden.';
      final a = await engine.iconize(text,
          langCode: 'en', density: IconizeDensity.high);
      final b = await engine.iconize(text,
          langCode: 'en', density: IconizeDensity.high);
      expect(a.spans.map((s) => s.toString()).toList(),
          b.spans.map((s) => s.toString()).toList());
      expect(a.plainText, b.plainText);
    });

    test('actualIconPercent không vượt ngân sách density', () async {
      const text = 'The cat and the dog chase the mouse around the house '
          'while the bird watches from the tree near the window.';
      for (final d in IconizeDensity.values) {
        final r = await engine.iconize(text, langCode: 'en', density: d);
        // +5 dung sai làm tròn của phép chia nguyên trên câu ngắn.
        expect(r.actualIconPercent,
            lessThanOrEqualTo(maxIconPercentByDensity[d]! + 5),
            reason: 'density $d vượt ngân sách');
      }
    });
  });
}
