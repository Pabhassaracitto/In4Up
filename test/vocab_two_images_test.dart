// test/vocab_two_images_test.dart
//
// VOCAB-MEDIA-003 (ADR-0012) — 1 hoặc 2 ảnh mỗi từ:
//  1. Dữ liệu CŨ (không có key `imageUrl2`) đọc bình thường (không migration).
//  2. Round-trip toJson → fromJson giữ nguyên cả 2 ảnh; key chỉ ghi khi có giá
//     trị (file cũ không phình thêm key null).
//  3. `mediaPaths` lọc null/rỗng, slot 1 trước slot 2.
//  4. `setMediaSlot`: xoá slot 1 khi có slot 2 ⇒ slot 2 LÊN THAY (không mất
//     dữ liệu); xoá slot 2 chỉ xoá slot 2.
//  5. `swapMediaSlots`: hoán đổi ảnh chính ↔ ảnh phụ; no-op khi slot 2 trống.
//  6. MemoryItem: cùng ngữ nghĩa additive + `removePrimaryMedia` promote.
//  7. MemoryItem round-trip: item cũ không có `imageUrl2` vẫn parse (null).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/screens/memory_mode/models/memory_item.dart';

WordEntry _entry({String? imageUrl, String? imageUrl2}) => WordEntry(
      id: 'w_1',
      word: 'butterfly',
      meaning: 'con bướm',
      language: 'en',
      imageUrl: imageUrl,
      imageUrl2: imageUrl2,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

MemoryItem _item({String? imageUrl, String? imageUrl2}) => MemoryItem(
      id: 'mem_1',
      word: 'butterfly',
      meaning: 'con bướm',
      imageUrl: imageUrl,
      imageUrl2: imageUrl2,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('WordEntry.imageUrl2 — additive (dữ liệu cũ vẫn mở được)', () {
    test('JSON cũ KHÔNG có key imageUrl2 → parse ra null, không ném lỗi', () {
      final json = _entry(imageUrl: 'vocabulary_images/a.webp').toJson()
        ..remove('imageUrl2');
      final restored = WordEntry.fromJson(json);
      expect(restored.imageUrl, 'vocabulary_images/a.webp');
      expect(restored.imageUrl2, isNull);
      expect(restored.mediaPaths, ['vocabulary_images/a.webp']);
    });

    test('toJson chỉ ghi imageUrl2 khi có giá trị (file cũ không phình)', () {
      final single = _entry(imageUrl: 'vocabulary_images/a.webp').toJson();
      expect(single.containsKey('imageUrl2'), isFalse);

      final blank = _entry(imageUrl2: '   ').toJson();
      expect(blank.containsKey('imageUrl2'), isFalse);

      final two = _entry(
        imageUrl: 'vocabulary_images/a.webp',
        imageUrl2: 'vocabulary_images/b.json',
      ).toJson();
      expect(two['imageUrl2'], 'vocabulary_images/b.json');
    });

    test('round-trip giữ nguyên cả 2 ảnh (ảnh tĩnh + Lottie)', () {
      final entry = _entry(
        imageUrl: 'vocabulary_images/a.webp',
        imageUrl2: 'https://lottie.host/x/butterfly.json',
      );
      final restored = WordEntry.fromJson(entry.toJson());
      expect(restored.imageUrl, 'vocabulary_images/a.webp');
      expect(restored.imageUrl2, 'https://lottie.host/x/butterfly.json');
      expect(restored.mediaPaths, [
        'vocabulary_images/a.webp',
        'https://lottie.host/x/butterfly.json',
      ]);
    });

    test('mediaPaths: lọc null/rỗng, chỉ 1 slot vẫn đúng', () {
      expect(_entry().mediaPaths, isEmpty);
      expect(_entry(imageUrl: '  ').mediaPaths, isEmpty);
      expect(_entry(imageUrl: 'a.webp').mediaPaths, ['a.webp']);
      // slot 2 có mà slot 1 rỗng (dữ liệu méo) → vẫn trả slot 2.
      expect(_entry(imageUrl2: 'b.webp').mediaPaths, ['b.webp']);
    });

    test('hasSecondaryMedia chỉ true khi slot 2 có giá trị thật', () {
      expect(_entry(imageUrl: 'a.webp').hasSecondaryMedia, isFalse);
      expect(_entry(imageUrl: 'a.webp', imageUrl2: ' ').hasSecondaryMedia,
          isFalse);
      expect(_entry(imageUrl: 'a.webp', imageUrl2: 'b.json').hasSecondaryMedia,
          isTrue);
    });
  });

  group('WordEntry.setMediaSlot — xoá ảnh chính KHÔNG mất dữ liệu', () {
    test('xoá slot 1 khi có slot 2 → ảnh phụ LÊN THAY (promote)', () {
      final entry = _entry(imageUrl: 'a.webp', imageUrl2: 'b.json')
        ..setMediaSlot(1, null);
      expect(entry.imageUrl, 'b.json');
      expect(entry.imageUrl2, isNull);
      expect(entry.mediaPaths, ['b.json']);
    });

    test('xoá slot 1 khi chỉ có 1 ảnh → xoá hẳn', () {
      final entry = _entry(imageUrl: 'a.webp')..setMediaSlot(1, null);
      expect(entry.imageUrl, isNull);
      expect(entry.imageUrl2, isNull);
      expect(entry.mediaPaths, isEmpty);
    });

    test('xoá slot 2 chỉ xoá slot 2, ảnh chính còn nguyên', () {
      final entry = _entry(imageUrl: 'a.webp', imageUrl2: 'b.json')
        ..setMediaSlot(2, null);
      expect(entry.imageUrl, 'a.webp');
      expect(entry.imageUrl2, isNull);
    });

    test('đặt slot 2 khi slot 1 trống: KHÔNG tự bịa slot 1', () {
      final entry = _entry()..setMediaSlot(2, 'b.json');
      expect(entry.imageUrl, isNull);
      expect(entry.imageUrl2, 'b.json');
    });

    test('chuỗi trắng = xoá; slot lạ (3) = no-op', () {
      final entry = _entry(imageUrl: 'a.webp', imageUrl2: 'b.json')
        ..setMediaSlot(3, 'c.webp');
      expect(entry.imageUrl, 'a.webp');
      expect(entry.imageUrl2, 'b.json');

      entry.setMediaSlot(2, '   ');
      expect(entry.imageUrl2, isNull);
      expect(entry.imageUrl, 'a.webp');
    });
  });

  group('WordEntry.swapMediaSlots — "Đặt làm ảnh chính"', () {
    test('hoán đổi 2 slot', () {
      final entry = _entry(imageUrl: 'a.webp', imageUrl2: 'b.json')
        ..swapMediaSlots();
      expect(entry.imageUrl, 'b.json');
      expect(entry.imageUrl2, 'a.webp');
    });

    test('slot 2 trống → no-op (giữ invariant slot 1 không trống)', () {
      final entry = _entry(imageUrl: 'a.webp')..swapMediaSlots();
      expect(entry.imageUrl, 'a.webp');
      expect(entry.imageUrl2, isNull);
    });

    test('swap 2 lần về đúng trạng thái đầu', () {
      final before = _entry(imageUrl: 'a.webp', imageUrl2: 'b.json');
      final after = _entry(imageUrl: 'a.webp', imageUrl2: 'b.json')
        ..swapMediaSlots()
        ..swapMediaSlots();
      expect(after.imageUrl, before.imageUrl);
      expect(after.imageUrl2, before.imageUrl2);
    });
  });

  group('MemoryItem.imageUrl2 — additive + promote', () {
    test('item cũ không có key imageUrl2 → parse null', () {
      final json = _item(imageUrl: 'a.webp').toJson()..remove('imageUrl2');
      final restored = MemoryItem.fromJson(json);
      expect(restored.imageUrl, 'a.webp');
      expect(restored.imageUrl2, isNull);
    });

    test('toJson chỉ ghi imageUrl2 khi có giá trị', () {
      expect(_item(imageUrl: 'a.webp').toJson().containsKey('imageUrl2'),
          isFalse);
      expect(
        _item(imageUrl: 'a.webp', imageUrl2: 'b.json')
            .toJson()
            .containsKey('imageUrl2'),
        isTrue,
      );
    });

    test('round-trip giữ cả 2 ảnh', () {
      final restored = MemoryItem.fromJson(
        _item(imageUrl: 'a.webp', imageUrl2: 'b.json').toJson(),
      );
      expect(restored.imageUrl, 'a.webp');
      expect(restored.imageUrl2, 'b.json');
    });

    test('withImageUrl2: set + xoá (chuỗi trắng cũng coi là xoá)', () {
      final set = _item(imageUrl: 'a.webp').withImageUrl2('b.json');
      expect(set.imageUrl2, 'b.json');
      expect(set.withImageUrl2(null).imageUrl2, isNull);
      expect(set.withImageUrl2('  ').imageUrl2, isNull);
      // xoá slot 2 không đụng slot 1
      expect(set.withImageUrl2(null).imageUrl, 'a.webp');
    });

    test('removePrimaryMedia: có ảnh phụ → promote; không → xoá hẳn', () {
      final promoted =
          _item(imageUrl: 'a.webp', imageUrl2: 'b.json').removePrimaryMedia();
      expect(promoted.imageUrl, 'b.json');
      expect(promoted.imageUrl2, isNull);

      final cleared = _item(imageUrl: 'a.webp').removePrimaryMedia();
      expect(cleared.imageUrl, isNull);
      expect(cleared.imageUrl2, isNull);
    });

    test('immutable: bản gốc không đổi sau withImageUrl2/removePrimaryMedia',
        () {
      final original = _item(imageUrl: 'a.webp', imageUrl2: 'b.json');
      original.removePrimaryMedia();
      original.withImageUrl2(null);
      expect(original.imageUrl, 'a.webp');
      expect(original.imageUrl2, 'b.json');
    });
  });
}
