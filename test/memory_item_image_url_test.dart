// test/memory_item_image_url_test.dart
//
// LOTTIE-001 — MemoryItem.imageUrl: additive field (item cũ không có key
// vẫn parse), round-trip JSON, và withImageUrl set/clear.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/memory_mode/models/memory_item.dart';

MemoryItem _item({String? imageUrl}) => MemoryItem(
      id: 'mem_1',
      word: 'butterfly',
      meaning: 'con bướm',
      imageUrl: imageUrl,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('MemoryItem.imageUrl (LOTTIE-001)', () {
    test('toJson → fromJson round-trip giữ nguyên imageUrl', () {
      final item = _item(
        imageUrl: 'https://lottie.host/xxx/butterfly.json',
      );
      final restored = MemoryItem.fromJson(item.toJson());
      expect(restored.imageUrl, 'https://lottie.host/xxx/butterfly.json');
      expect(restored.id, item.id);
      expect(restored.word, item.word);
      expect(restored.meaning, item.meaning);
    });

    test('JSON cũ không có key imageUrl → parse bình thường (null)', () {
      final json = _item().toJson()..remove('imageUrl');
      final restored = MemoryItem.fromJson(json);
      expect(restored.imageUrl, isNull);
    });

    test('withImageUrl: set mới', () {
      final item = _item().withImageUrl('vocabulary_images/ab.json');
      expect(item.imageUrl, 'vocabulary_images/ab.json');
      // immutable: bản gốc không đổi.
    });

    test('withImageUrl(null) → bỏ hẳn minh họa', () {
      final item =
          _item(imageUrl: 'vocabulary_images/ab.json').withImageUrl(null);
      expect(item.imageUrl, isNull);
    });

    test('withImageUrl(chuỗi trắng) → cũng coi là bỏ', () {
      final item =
          _item(imageUrl: 'vocabulary_images/ab.json').withImageUrl('   ');
      expect(item.imageUrl, isNull);
    });

    test('round-trip sau update: path local Lottie vẫn nguyên', () {
      final item = _item()
          .withImageUrl('vocabulary_images/9f8e7d6c5b4a3210.json')
          .withImageUrl(null)
          .withImageUrl('vocabulary_images/0123456789abcdef.json');
      final restored = MemoryItem.fromJson(item.toJson());
      expect(restored.imageUrl, 'vocabulary_images/0123456789abcdef.json');
    });
  });
}
