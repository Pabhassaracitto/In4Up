// test/vocab_media_type_test.dart
//
// LOTTIE-001 — phân loại media minh họa từ vựng (ảnh tĩnh vs Lottie)
// thuần logic: đuôi .json/.lottie, query string, hoa thường, URL vs path.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/vocab_image/vocab_media_type.dart';

void main() {
  group('detectVocabMediaType', () {
    test('URL Lottie .json (LottieFiles/CDN) → lottie', () {
      expect(
        detectVocabMediaType(
            'https://assets10.lottiefiles.com/packages/lf20_abcd.json'),
        VocabMediaType.lottie,
      );
      expect(
        detectVocabMediaType('https://lottie.host/xxx-yyy/anim.json'),
        VocabMediaType.lottie,
      );
    });

    test('URL có query string/fragment vẫn nhận diện đúng', () {
      expect(
        detectVocabMediaType('https://cdn.example.com/a.json?dl=1&x=2'),
        VocabMediaType.lottie,
      );
      expect(
        detectVocabMediaType('https://cdn.example.com/a.json#frag'),
        VocabMediaType.lottie,
      );
      // Ảnh có query vẫn là ảnh tĩnh.
      expect(
        detectVocabMediaType('https://cdn.example.com/pic.webp?w=400'),
        VocabMediaType.staticImage,
      );
    });

    test('dotLottie archive (.lottie) → lottie', () {
      expect(
        detectVocabMediaType('https://cdn.example.com/pack.lottie'),
        VocabMediaType.lottie,
      );
    });

    test('không phân biệt hoa thường', () {
      expect(
        detectVocabMediaType('HTTPS://CDN.EXAMPLE.COM/Anim.JSON'),
        VocabMediaType.lottie,
      );
    });

    test('relative path local (đã materialize) → phân loại theo đuôi file', () {
      expect(
        detectVocabMediaType('vocabulary_images/0123abcd.json'),
        VocabMediaType.lottie,
      );
      expect(
        detectVocabMediaType('vocabulary_images/0123abcd.webp'),
        VocabMediaType.staticImage,
      );
    });

    test('null/rỗng/chỉ khoảng trắng → staticImage (mặc định an toàn)', () {
      expect(detectVocabMediaType(null), VocabMediaType.staticImage);
      expect(detectVocabMediaType(''), VocabMediaType.staticImage);
      expect(detectVocabMediaType('   '), VocabMediaType.staticImage);
    });

    test('đuôi lạ không phải json/lottie → staticImage', () {
      expect(
        detectVocabMediaType('https://cdn.example.com/readme.txt'),
        VocabMediaType.staticImage,
      );
      // ".json" nằm GIỮA chuỗi (không phải đuôi) → không tính.
      expect(
        detectVocabMediaType('https://cdn.example.com/jsonify/pic.png'),
        VocabMediaType.staticImage,
      );
    });
  });

  group('isLottieMediaUrl / isNetworkMediaUrl', () {
    test('isLottieMediaUrl sugar', () {
      expect(isLottieMediaUrl('https://x.com/a.json'), isTrue);
      expect(isLottieMediaUrl('vocabulary_images/a.json'), isTrue);
      expect(isLottieMediaUrl('https://x.com/a.png'), isFalse);
      expect(isLottieMediaUrl(null), isFalse);
    });

    test('isNetworkMediaUrl: http(s) vs relative path', () {
      expect(isNetworkMediaUrl('https://x.com/a.json'), isTrue);
      expect(isNetworkMediaUrl('http://x.com/a.png'), isTrue);
      expect(isNetworkMediaUrl('  HTTPS://x.com/a.png  '), isTrue);
      expect(isNetworkMediaUrl('vocabulary_images/a.png'), isFalse);
      expect(isNetworkMediaUrl('/abs/path/a.png'), isFalse);
      expect(isNetworkMediaUrl(null), isFalse);
    });
  });
}
