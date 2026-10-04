// IMG-WEB-001 — Tìm hình trên mạng cho từ vựng: parser + query.
//
// Parser chạy trên JSON mẫu đúng shape thật của Openverse và MediaWiki
// Commons (không gọi mạng). Đây là chỗ dễ hỏng nhất: Openverse đổi key
// `results` → `result`, Commons trả `pages` là MAP (không phải list), và
// `extmetadata` bọc HTML trong `{"value": "<a …>Name</a>"}`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/vocab_image/vocab_image_api_config.dart';
import 'package:in4up/features/vocab_image/vocab_image_web_service.dart';

void main() {
  group('parseOpenverse', () {
    const openverseBody = '''
{
  "result_count": 12000,
  "page_count": 500,
  "page_size": 3,
  "results": [
    {
      "id": "6nc22we6",
      "title": "Papilio machaon (butterfly)",
      "url": "https://live.staticflickr.com/4041/4444444_b.jpg",
      "thumbnail": "https://api.openverse.org/v1/images/6nc22we6/thumb/",
      "provider": "flickr",
      "source": "flickr",
      "license": "by-sa",
      "license_version": "2.0",
      "foreign_landing_url": "https://www.flickr.com/photos/x/4444444",
      "creator": "Jane Doe"
    },
    {
      "id": "abcd1234",
      "title": "no image url here",
      "thumbnail": "https://api.openverse.org/v1/images/abcd1234/thumb/",
      "creator": "Nobody",
      "license": "cc0",
      "foreign_landing_url": "https://example.org/2",
      "url": null
    },
    {
      "id": "rel88",
      "title": "relative thumbnail",
      "url": "https://upload.example/3.jpg",
      "thumbnail": "/v1/images/rel88/thumb/",
      "license": "by",
      "detail_url": "https://api.openverse.org/v1/images/rel88/"
    }
  ]
}''';

    test('map đủ field, bỏ item thiếu url', () {
      final items = VocabImageWebService.parseOpenverse(openverseBody);
      expect(items.length, 2);
      expect(items.first.title, 'Papilio machaon (butterfly)');
      expect(items.first.imageUrl, 'https://live.staticflickr.com/4041/4444444_b.jpg');
      expect(items.first.thumbUrl, 'https://api.openverse.org/v1/images/6nc22we6/thumb/');
      expect(items.first.pageUrl, 'https://www.flickr.com/photos/x/4444444');
      expect(items.first.creator, 'Jane Doe');
      expect(items.first.license, 'by-sa');
      expect(items.first.source, 'flickr');
    });

    test('thumbnail tương đối → dùng ảnh gốc; pageUrl fallback detail_url', () {
      final items = VocabImageWebService.parseOpenverse(openverseBody);
      final third = items.last;
      expect(third.thumbUrl, third.imageUrl);
      expect(third.pageUrl, 'https://api.openverse.org/v1/images/rel88/');
      expect(third.creator, isNull);
      expect(third.credit, 'by · openverse');
    });

    test('key "result" (bản API cũ) cũng đọc được', () {
      final body = jsonEncode({
        'result': [
          {'title': 'x', 'url': 'https://cdn.example/x.jpg'},
        ],
      });
      final items = VocabImageWebService.parseOpenverse(body);
      expect(items.length, 1);
      expect(items.single.imageUrl, 'https://cdn.example/x.jpg');
      expect(items.single.source, 'openverse');
    });

    test('JSON rác / sai shape → rỗng, không ném', () {
      expect(VocabImageWebService.parseOpenverse('not json'), isEmpty);
      expect(VocabImageWebService.parseOpenverse('[]'), isEmpty);
      expect(VocabImageWebService.parseOpenverse('{"results": {}}'), isEmpty);
      expect(VocabImageWebService.parseOpenverse('{}'), isEmpty);
    });

    test('limit được tôn trọng', () {
      final items = VocabImageWebService.parseOpenverse(openverseBody, limit: 1);
      expect(items.length, 1);
    });
  });

  group('parseCommons', () {
    const commonsBody = '''
{
  "continue": {"gsroffset": 20, "continue": "||"},
  "query": {
    "searchinfo": {"totalhits": 5123},
    "pages": {
      "13746368": {
        "pageid": 13746368,
        "ns": 6,
        "title": "File:Papilio machaon MHNT CUT 2010 0 367 Dosneufs female.jpg",
        "index": 2,
        "imageinfo": [
          {
            "url": "https://upload.wikimedia.org/wikipedia/commons/3/3a/Papilio_machaon.jpg",
            "descriptionurl": "https://commons.wikimedia.org/wiki/File:Papilio_machaon.jpg",
            "thumburl": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Papilio_machaon.jpg/480px-Papilio_machaon.jpg",
            "extmetadata": {
              "LicenseShortName": {"value": "CC BY-SA 3.0", "hidden": ""},
              "Artist": {"value": "<a href=\\"//commons.example/User:A\\">User A</a>"}
            }
          }
        ]
      },
      "99999": {
        "pageid": 99999,
        "ns": 6,
        "title": "File:NoInfo.jpg"
      }
    }
  }
}''';

    test('pages là map → vẫn parse; bỏ page không có imageinfo', () {
      final items = VocabImageWebService.parseCommons(commonsBody);
      expect(items.length, 1);
      final image = items.single;
      expect(image.source, 'wikimedia');
      expect(image.imageUrl,
          'https://upload.wikimedia.org/wikipedia/commons/3/3a/Papilio_machaon.jpg');
      expect(image.thumbUrl, contains('480px-Papilio_machaon.jpg'));
      expect(image.pageUrl,
          'https://commons.wikimedia.org/wiki/File:Papilio_machaon.jpg');
      expect(image.title, isNot(startsWith('File:')));
      expect(image.creator, 'User A');
      expect(image.license, 'CC BY-SA 3.0');
      expect(image.credit, 'User A · CC BY-SA 3.0 · wikimedia');
    });

    test('HTML trong extmetadata được gỡ thẻ', () {
      final body = jsonEncode({
        'query': {
          'pages': {
            '1': {
              'title': 'File:a.jpg',
              'imageinfo': [
                {
                  'url': 'https://upload.example/a.jpg',
                  'extmetadata': {
                    'Artist': {
                      'value': '<span xmlns:dct="x" property="dct:title">'
                          'Bob &amp; Alice</span>'
                    },
                    'LicenseShortName': {'value': ' Public Domain '},
                  },
                }
              ],
            }
          }
        }
      });
      final image = VocabImageWebService.parseCommons(body).single;
      expect(image.creator, 'Bob & Alice');
      expect(image.license, 'Public Domain');
    });

    test('JSON rác / mediaWiki error → rỗng, không ném', () {
      expect(VocabImageWebService.parseCommons('<html>502</html>'), isEmpty);
      expect(VocabImageWebService.parseCommons('{"error":{"code":"noapi"}}'), isEmpty);
      expect(VocabImageWebService.parseCommons('{"query":{}}'), isEmpty);
    });
  });

  group('buildQuery — từ khóa từ word + meaning', () {
    test('nối từ + nghĩa', () {
      expect(
        VocabImageWebService.buildQuery(word: 'pavilion', meaning: 'cái đình'),
        'pavilion cái đình',
      );
    });

    test('thiếu một vế → dùng vế còn lại', () {
      expect(VocabImageWebService.buildQuery(word: 'bướm'), 'bướm');
      expect(VocabImageWebService.buildQuery(meaning: 'moth'), 'moth');
      expect(VocabImageWebService.buildQuery(word: '  ', meaning: '  '), '');
      expect(VocabImageWebService.buildQuery(), '');
    });

    test('nghĩa quá dài bị cắt (API chỉ cần vài từ định hình)', () {
      final longMeaning = 'a very long definition that keeps going and going forever '.trim();
      final q = VocabImageWebService.buildQuery(
        word: 'definition',
        meaning: longMeaning,
      );
      expect(q.startsWith('definition '), isTrue);
      expect(q.length, lessThanOrEqualTo('definition '.length + 48));
    });
  });

  group('looksLikeImage — chặn HTML giả làm ảnh', () {
    Uint8List bytes(List<int> v) => Uint8List.fromList(v);

    test('nhận diện JPEG/PNG/GIF/WebP', () {
      expect(VocabImageWebService.looksLikeImage(bytes([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(8, 0)])), isTrue);
      expect(VocabImageWebService.looksLikeImage(bytes([0x89, 0x50, 0x4E, 0x47, ...List.filled(8, 0)])), isTrue);
      expect(VocabImageWebService.looksLikeImage(bytes([0x47, 0x49, 0x46, 0x38, ...List.filled(8, 0)])), isTrue);
      expect(
        VocabImageWebService.looksLikeImage(
          bytes([0x52, 0x49, 0x46, 0x46, 0x20, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]),
        ),
        isTrue,
      );
    });

    test('từ chối HTML/RSS/file cụt', () {
      expect(VocabImageWebService.looksLikeImage(bytes(utf8.encode('<!doctype html><html>'))), isFalse);
      expect(VocabImageWebService.looksLikeImage(bytes([])), isFalse);
      expect(VocabImageWebService.looksLikeImage(bytes([0x25, 0x50, 0x44, 0x46])), isFalse); // %PDF
    });
  });

  group('parsePexels (API key bắt buộc)', () {
    const pexelsBody = '''
{
  "total_results": 4321,
  "page": 1,
  "per_page": 2,
  "photos": [
    {
      "id": 123,
      "width": 4000, "height": 3000,
      "url": "https://www.pexels.com/photo/a-butterfly-123/",
      "alt": "A butterfly on a flower",
      "src": {
        "original": "https://images.pexels.com/photos/123/pexels-photo-123.jpeg",
        "large2x": "https://images.pexels.com/photos/123/pexels-photo-123.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=650&w=940",
        "medium": "https://images.pexels.com/photos/123/pexels-photo-123.jpeg?auto=compress&cs=tinysrgb&h=350",
        "thumbnail": "https://images.pexels.com/photos/123/pexels-photo-123.jpeg?auto=compress&cs=tinysrgb&dpr=1&fit=crop&h=200&w=280"
      },
      "user": {"id": 7, "name": "Jane Photographer"}
    },
    {
      "id": 124,
      "url": "https://www.pexels.com/photo/no-src/",
      "src": null
    }
  ]
}''';

    test('map src.large2x → ảnh đầy đủ, medium → thumbnail', () {
      final items = VocabImageWebService.parsePexels(pexelsBody);
      expect(items.length, 1); // item không có src bị bỏ
      final image = items.single;
      expect(image.title, 'A butterfly on a flower');
      expect(image.imageUrl, contains('dpr=2')); // src.large2x
      expect(image.thumbUrl, contains('h=350'));
      expect(image.pageUrl, contains('/photo/a-butterfly-123/'));
      expect(image.creator, 'Jane Photographer');
      expect(image.license, 'Pexels License');
      expect(image.source, 'pexels');
      expect(image.credit, 'Jane Photographer · Pexels License · pexels');
    });

    test('body lỗi/rỗng → rỗng', () {
      expect(VocabImageWebService.parsePexels('{"photos": null}'), isEmpty);
      expect(VocabImageWebService.parsePexels('rate limit'), isEmpty);
      expect(VocabImageWebService.parsePexels('{"photos": []}'), isEmpty);
    });
  });

  group('parseUnsplash (Access Key bắt buộc)', () {
    const unsplashBody = '''
{
  "total": 100,
  "total_pages": 5,
  "results": [
    {
      "id": "abc",
      "description": "butterfly macro",
      "alt_description": "Butterfly wings",
      "urls": {
        "raw": "https://images.unsplash.com/photo-1?ixlib=rb-4",
        "full": "https://images.unsplash.com/photo-1?q=80&w=1980",
        "regular": "https://images.unsplash.com/photo-1?q=80&w=1080",
        "small": "https://images.unsplash.com/photo-1?q=80&w=400"
      },
      "links": {"html": "https://unsplash.com/photos/abc"},
      "user": {"name": "John Shooter"}
    },
    {
      "id": "def",
      "urls": {}
    }
  ]
}''';

    test('map đủ field; bỏ photo không có urls.regular/full', () {
      final items = VocabImageWebService.parseUnsplash(unsplashBody);
      expect(items.length, 1);
      final image = items.single;
      expect(image.title, 'Butterfly wings');
      expect(image.thumbUrl, contains('w=400'));
      expect(image.imageUrl, contains('w=1980'));
      expect(image.pageUrl, 'https://unsplash.com/photos/abc');
      expect(image.creator, 'John Shooter');
      expect(image.license, 'Unsplash License');
    });

    test('mô tả thay alt_description khi thiếu', () {
      final body = jsonEncode({
        'results': [
          {
            'description': 'an old temple',
            'urls': {'regular': 'https://images.unsplash.com/x?w=1080'},
          }
        ]
      });
      final image = VocabImageWebService.parseUnsplash(body).single;
      expect(image.title, 'an old temple');
      expect(image.imageUrl, image.thumbUrl); // không có small → dùng regular
    });
  });

  group('VocabImageApiSettings — key là điều kiện dùng nguồn', () {
    const noKeys = VocabImageApiSettings(
      provider: VocabImageProvider.pexels,
      keys: {},
      hasBuildTimeKey: false,
    );
    const withPexelsKey = VocabImageApiSettings(
      provider: VocabImageProvider.pexels,
      keys: {'pexels': '  secret-key  '},
      hasBuildTimeKey: false,
    );

    test('provider cần key + chưa có key → không usable', () {
      expect(noKeys.selectedProviderUsable, isFalse);
      expect(withPexelsKey.selectedProviderUsable, isTrue);
      expect(withPexelsKey.keyFor(VocabImageProvider.pexels), 'secret-key');
      expect(noKeys.keyFor(VocabImageProvider.pexels), isNull);
    });

    test('nguồn không cần key luôn usable (fallback)', () {
      const openverse = VocabImageApiSettings(
        provider: VocabImageProvider.openverse,
        keys: {},
        hasBuildTimeKey: false,
      );
      expect(openverse.selectedProviderUsable, isTrue);
    });

    test('searchOrder: provider đã chọn trước, chỉ thêm nguồn dùng được', () {
      expect(noKeys.searchOrder(), [
        VocabImageProvider.pexels, // vẫn đứng đầu, nhưng search() sẽ bỏ qua
        VocabImageProvider.openverse,
        VocabImageProvider.wikimedia,
      ]);
      const unsplashKeyed = VocabImageApiSettings(
        provider: VocabImageProvider.unsplash,
        keys: {'unsplash': 'k', 'pexels': 'p'},
        hasBuildTimeKey: false,
      );
      expect(unsplashKeyed.searchOrder(), [
        VocabImageProvider.unsplash,
        VocabImageProvider.pexels,
        VocabImageProvider.openverse,
        VocabImageProvider.wikimedia,
      ]);
    });

    test('key build-time chỉ dùng cho provider build chọn', () {
      const buildPexels = VocabImageApiSettings(
        provider: VocabImageProvider.pexels,
        keys: {},
        hasBuildTimeKey: true,
        buildTimeProvider: 'pexels',
      );
      // buildTimeKey rỗng khi test không chạy với --dart-define → null.
      expect(
        buildPexels.keyFor(VocabImageProvider.pexels),
        VocabImageApiSettings.buildTimeKey.isEmpty
            ? isNull
            : VocabImageApiSettings.buildTimeKey,
      );
      const buildOther = VocabImageApiSettings(
        provider: VocabImageProvider.unsplash,
        keys: {},
        hasBuildTimeKey: true,
        buildTimeProvider: 'pexels',
      );
      // KHÔNG được đưa key Pexels cho Unsplash (sai nguồn, lộ key).
      expect(buildOther.keyFor(VocabImageProvider.unsplash), isNull);
    });

    test('resolveDefaultProvider: prefs > build-time > pexels', () {
      expect(VocabImageApiSettings.resolveDefaultProvider('openverse'),
          VocabImageProvider.openverse);
      expect(VocabImageApiSettings.resolveDefaultProvider('WIKIMEDIA'),
          VocabImageProvider.wikimedia);
      expect(VocabImageApiSettings.resolveDefaultProvider('bogus'),
          VocabImageProvider.pexels);
      expect(VocabImageApiSettings.resolveDefaultProvider(null),
          VocabImageProvider.pexels);
    });

    test('storageKeyName theo provider (không trùng nhau)', () {
      final names = VocabImageProvider.values
          .map((p) => p.storageKeyName)
          .toList();
      expect(names.toSet().length, names.length);
      expect(names, contains('vocab_image_key_pexels'));
    });
  });
}
