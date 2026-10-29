// test/vocab_animation_library_test.dart
//
// VOCAB-MEDIA-003 (ADR-0013) — nguồn "Animation" của sheet chọn media:
//  1. Parser endpoint tùy chỉnh: nhận nhiều shape (`results`/`data`/`items`/
//     list thuần), CHỈ giữ link .json/.lottie tuyệt đối, lấy preview/title/
//     creator/license, tôn trọng limit, không ném khi JSON hỏng.
//  2. Parser MediaWiki Commons: `pages` là MAP, `extmetadata` bọc HTML,
//     `thumburl` rỗng ⇒ dùng chính URL gốc, lọc file không phải .json.
//  3. Config: nhãn nguồn (host của endpoint tùy chỉnh / Wikimedia Commons).
//
// Thuần logic — không gọi mạng, không plugin.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/vocab_image/vocab_animation_library.dart';

void main() {
  group('parseAnimationLibraryJson — endpoint tùy chỉnh', () {
    test('shape {results:[…]}: nhận link .json + preview + credit', () {
      const body = '''
{
  "results": [
    {
      "url": "https://cdn.example.com/butterfly.json",
      "preview": "https://cdn.example.com/butterfly.png",
      "title": "Butterfly",
      "creator": "Jane Doe",
      "license": "CC0",
      "source": "my-library",
      "pageUrl": "https://example.com/butterfly"
    }
  ]
}
''';
      final out = VocabAnimationLibraryService.parseAnimationLibraryJson(body);
      expect(out, hasLength(1));
      expect(out.first.imageUrl, 'https://cdn.example.com/butterfly.json');
      expect(out.first.thumbUrl, 'https://cdn.example.com/butterfly.png');
      expect(out.first.title, 'Butterfly');
      expect(out.first.creator, 'Jane Doe');
      expect(out.first.license, 'CC0');
      expect(out.first.source, 'my-library');
      expect(out.first.pageUrl, 'https://example.com/butterfly');
      expect(out.first.credit, 'Jane Doe · CC0 · my-library');
    });

    test('shape {data:[…]} + {items:[…]} + list thuần đều đọc được', () {
      const one = '{"data":[{"file":"https://x/a.lottie","name":"A"}]}';
      const two = '{"items":[{"src":"https://x/b.json","title":"B"}]}';
      const three = '[{"lottie":"https://x/c.json"}]';
      expect(VocabAnimationLibraryService.parseAnimationLibraryJson(one).single.imageUrl,
          'https://x/a.lottie');
      expect(VocabAnimationLibraryService.parseAnimationLibraryJson(two).single.title,
          'B');
      expect(VocabAnimationLibraryService.parseAnimationLibraryJson(three).single.imageUrl,
          'https://x/c.json');
    });

    test('BỎ item không phải Lottie: .png/.gif và URL tương đối', () {
      const body = '''
[
  {"url": "https://x/picture.png"},
  {"url": "https://x/anim.gif"},
  {"url": "/relative/anim.json"},
  {"url": "vocabulary_images/local.json"},
  {"url": "https://x/real.json"},
  {"url": ""}
]
''';
      final out = VocabAnimationLibraryService.parseAnimationLibraryJson(body);
      expect(out, hasLength(1));
      expect(out.single.imageUrl, 'https://x/real.json');
    });

    test('URL có query/fragment vẫn nhận (đuôi .json trước ?/#)', () {
      const body = '[{"url":"https://x/a.json?token=1#frag"}]';
      final out = VocabAnimationLibraryService.parseAnimationLibraryJson(body);
      expect(out.single.imageUrl, 'https://x/a.json?token=1#frag');
    });

    test('thiếu preview → thumbUrl = chính URL (tile tự render Lottie)', () {
      const body = '[{"url":"https://x/a.json","title":"A"}]';
      final out = VocabAnimationLibraryService.parseAnimationLibraryJson(body);
      expect(out.single.thumbUrl, out.single.imageUrl);
    });

    test('source mặc định = "custom" khi item không khai', () {
      const body = '[{"url":"https://x/a.json"}]';
      final out = VocabAnimationLibraryService.parseAnimationLibraryJson(
        body,
        source: 'custom',
      );
      expect(out.single.source, 'custom');
    });

    test('tôn trọng limit', () {
      final items = List.generate(
        10,
        (i) => '{"url":"https://x/$i.json"}',
      ).join(',');
      final out = VocabAnimationLibraryService.parseAnimationLibraryJson(
        '[$items]',
        limit: 3,
      );
      expect(out, hasLength(3));
    });

    test('JSON hỏng / rỗng → [] (không ném)', () {
      expect(VocabAnimationLibraryService.parseAnimationLibraryJson(''),
          isEmpty);
      expect(VocabAnimationLibraryService.parseAnimationLibraryJson('<html>'),
          isEmpty);
      expect(
          VocabAnimationLibraryService.parseAnimationLibraryJson('{"a":1}'),
          isEmpty);
      expect(VocabAnimationLibraryService.parseAnimationLibraryJson('[]'),
          isEmpty);
    });
  });

  group('parseCommonsAnimations — MediaWiki Commons (mặc định)', () {
    test('pages là MAP: lấy .json + thumburl, gỡ "File:" khỏi title', () {
      const body = '''
{
  "batchcomplete": "",
  "query": {
    "pages": {
      "12345": {
        "pageid": 12345,
        "title": "File:Butterfly flight animation.json",
        "imageinfo": [
          {
            "url": "https://upload.wikimedia.org/wikipedia/commons/a/ab/Butterfly_flight.json",
            "descriptionurl": "https://commons.wikimedia.org/wiki/File:Butterfly_flight_animation.json",
            "thumburl": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Butterfly_flight.json/480px-Butterfly_flight.json.jpg",
            "extmetadata": {
              "Artist": {"value": "<a href=\\"//commons.wikimedia.org/wiki/User:Jane\\">Jane Doe</a>"},
              "LicenseShortName": {"value": "CC BY-SA 4.0"}
            }
          }
        ]
      }
    }
  }
}
''';
      final out = VocabAnimationLibraryService.parseCommonsAnimations(body);
      expect(out, hasLength(1));
      final img = out.single;
      expect(img.imageUrl,
          'https://upload.wikimedia.org/wikipedia/commons/a/ab/Butterfly_flight.json');
      expect(img.thumbUrl,
          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Butterfly_flight.json/480px-Butterfly_flight.json.jpg');
      expect(img.title, 'Butterfly flight animation.json');
      expect(img.creator, 'Jane Doe');
      expect(img.license, 'CC BY-SA 4.0');
      expect(img.source, 'wikimedia');
    });

    test('bỏ file không phải .json (vd .jpg trong namespace File:)', () {
      const body = '''
{"query":{"pages":{"1":{"title":"File:Photo.jpg","imageinfo":[
  {"url":"https://upload.wikimedia.org/.../Photo.jpg","descriptionurl":"https://commons.wikimedia.org/wiki/File:Photo.jpg"}
]}}}}
''';
      expect(
          VocabAnimationLibraryService.parseCommonsAnimations(body), isEmpty);
    });

    test('thumburl thiếu/rỗng → thumbUrl = URL gốc (tile tự render Lottie)',
        () {
      const body = '''
{"query":{"pages":{"1":{"title":"File:A.json","imageinfo":[
  {"url":"https://upload.wikimedia.org/A.json","descriptionurl":"https://commons.wikimedia.org/wiki/File:A.json","thumburl":""}
]}}}}
''';
      final img = VocabAnimationLibraryService.parseCommonsAnimations(body).single;
      expect(img.thumbUrl, img.imageUrl);
    });

    test('page rỗng/không có imageinfo → bỏ qua an toàn', () {
      expect(
          VocabAnimationLibraryService.parseCommonsAnimations(
              '{"query":{"pages":{}}}'),
          isEmpty);
      expect(
          VocabAnimationLibraryService.parseCommonsAnimations(
              '{"query":{"pages":{"1":{"title":"File:X.json"}}}}'),
          isEmpty);
      expect(VocabAnimationLibraryService.parseCommonsAnimations('nope'),
          isEmpty);
    });

    test('tôn trọng limit', () {
      final pages = List.generate(
        6,
        (i) =>
            '"$i": {"title":"File:$i.json","imageinfo":[{"url":"https://upload.wikimedia.org/$i.json","descriptionurl":"https://commons.wikimedia.org/$i"}]}',
      ).join(',');
      final out = VocabAnimationLibraryService.parseCommonsAnimations(
        '{"query":{"pages":{$pages}}}',
        limit: 2,
      );
      expect(out, hasLength(2));
    });
  });

  group('VocabAnimationLibraryConfig — nhãn nguồn + cờ endpoint', () {
    test('rỗng → Wikimedia Commons, không có endpoint tùy chỉnh', () {
      const cfg = VocabAnimationLibraryConfig();
      expect(cfg.sourceLabel, 'Wikimedia Commons');
      expect(cfg.hasCustomEndpoint, isFalse);
    });

    test('có endpoint → nhãn là host (bỏ path)', () {
      const cfg = VocabAnimationLibraryConfig(
        endpoint: 'https://lottie.example.com/api/v1/animations',
      );
      expect(cfg.hasCustomEndpoint, isTrue);
      expect(cfg.sourceLabel, 'lottie.example.com');
    });

    test('endpoint không phải URL → giữ nguyên chuỗi làm nhãn', () {
      const cfg = VocabAnimationLibraryConfig(endpoint: 'my-server/anim');
      expect(cfg.sourceLabel, 'my-server/anim');
    });
  });
}
