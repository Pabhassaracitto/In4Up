// test/great_library/pack_content_test.dart
//
// GLIB-005 — parser nội dung data/ của .i4upack: vocab/audio/image plan,
// mã lỗi ổn định, kiểm tra media/data tồn tại.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_content.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';

PackManifest _manifest(PackType? type) => PackManifest(
      id: 'p1',
      type: type,
      title: 'Pack',
      srcLang: 'en',
      dstLang: 'vi',
      license: PackLicense.ccBy,
    );

PackContents _contents(
  PackType? type, {
  Map<String, String> data = const {},
  Map<String, List<int>> media = const {},
}) {
  return PackContents(
    manifest: _manifest(type),
    dataFiles: data.map((k, v) => MapEntry(k, utf8.encode(v))),
    mediaFiles:
        media.map((k, v) => MapEntry(k, Uint8List.fromList(v))),
  );
}

void main() {
  group('VocabPack', () {
    test('parse entries.json đầy đủ trường + media tồn tại', () {
      final plan = PackContent.parse(_contents(
        PackType.vocab,
        data: {
          'entries.json': jsonEncode([
            {
              'word': 'apple',
              'meaning': 'quả táo',
              'phonetic': '/ˈæp.əl/',
              'example': 'I eat an apple.',
              'audio': 'apple.mp3',
              'image': 'apple.jpg',
            },
            {'word': 'run', 'meaning': 'chạy'},
          ]),
        },
        media: {
          'apple.mp3': [1, 2, 3],
          'apple.jpg': [4, 5],
        },
      ));
      expect(plan, isA<VocabPackPlan>());
      final vocab = plan as VocabPackPlan;
      expect(vocab.itemCount, 2);
      expect(vocab.items.first.word, 'apple');
      expect(vocab.items.first.audioName, 'apple.mp3');
      expect(vocab.items.first.imageName, 'apple.jpg');
      expect(vocab.items.last.phonetic, isNull);
    });

    test('thiếu entries.json → content-missing-data', () {
      expect(
        () => PackContent.parse(_contents(PackType.vocab)),
        throwsA(predicate((e) =>
            e is FormatException && e.message.startsWith('content-missing-data'))),
      );
    });

    test('json hỏng → content-bad-json', () {
      expect(
        () => PackContent.parse(
            _contents(PackType.vocab, data: {'entries.json': '{oops'})),
        throwsA(predicate((e) =>
            e is FormatException && e.message.startsWith('content-bad-json'))),
      );
    });

    test('không phải array → content-not-array', () {
      expect(
        () => PackContent.parse(
            _contents(PackType.vocab, data: {'entries.json': '{"a":1}'})),
        throwsA(predicate((e) =>
            e is FormatException && e.message.startsWith('content-not-array'))),
      );
    });

    test('item thiếu word → content-item-invalid', () {
      expect(
        () => PackContent.parse(_contents(PackType.vocab, data: {
          'entries.json': jsonEncode([
            {'meaning': 'không có word'}
          ])
        })),
        throwsA(predicate((e) =>
            e is FormatException &&
            e.message.startsWith('content-item-invalid'))),
      );
    });

    test('audio tham chiếu media không có → content-media-missing', () {
      expect(
        () => PackContent.parse(_contents(PackType.vocab, data: {
          'entries.json': jsonEncode([
            {'word': 'a', 'meaning': 'b', 'audio': 'ghost.mp3'}
          ])
        })),
        throwsA(predicate((e) =>
            e is FormatException &&
            e.message.startsWith('content-media-missing'))),
      );
    });
  });

  group('AudioPack', () {
    test('parse tracks.json + lrc phải nằm trong data/', () {
      final plan = PackContent.parse(_contents(
        PackType.audio,
        data: {
          'tracks.json': jsonEncode([
            {
              'file': 'talk.mp3',
              'title': 'Pháp thoại 1',
              'lrc': 'talk.lrc',
              'durationSec': 600,
            },
          ]),
          'talk.lrc': '[00:01.00] xin chào',
        },
        media: {
          'talk.mp3': [9, 9, 9]
        },
      ));
      final audio = plan as AudioPackPlan;
      expect(audio.tracks.single.title, 'Pháp thoại 1');
      expect(audio.tracks.single.lrcName, 'talk.lrc');
      expect(audio.tracks.single.durationSec, 600);
    });

    test('lrc tham chiếu data không có → content-media-missing', () {
      expect(
        () => PackContent.parse(_contents(PackType.audio, data: {
          'tracks.json': jsonEncode([
            {'file': 'a.mp3', 'lrc': 'ghost.lrc'}
          ])
        }, media: {
          'a.mp3': [1]
        })),
        throwsA(predicate((e) =>
            e is FormatException &&
            e.message.startsWith('content-media-missing'))),
      );
    });

    test('title vắng → fallback tên file', () {
      final plan = PackContent.parse(_contents(PackType.audio, data: {
        'tracks.json': jsonEncode([
          {'file': 'a.mp3'}
        ])
      }, media: {
        'a.mp3': [1]
      }));
      expect((plan as AudioPackPlan).tracks.single.title, 'a.mp3');
    });
  });

  group('ImagePack', () {
    test('parse items.json', () {
      final plan = PackContent.parse(_contents(PackType.image, data: {
        'items.json': jsonEncode([
          {'image': 'cat.jpg', 'caption': 'con mèo', 'word': 'cat'},
        ])
      }, media: {
        'cat.jpg': [7]
      }));
      final image = plan as ImagePackPlan;
      expect(image.items.single.caption, 'con mèo');
      expect(image.items.single.word, 'cat');
    });
  });

  test('manifest thiếu type → content-type-unknown', () {
    expect(
      () => PackContent.parse(_contents(null)),
      throwsA(predicate((e) =>
          e is FormatException && e.message.startsWith('content-type-unknown'))),
    );
  });
}
