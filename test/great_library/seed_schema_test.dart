// test/great_library/seed_schema_test.dart
//
// GLIB-008 — seed pack build in-memory theo đúng schema
// tool/great_library_seed/ (vocab entries / audio tracks / image items) phải
// pass PackFile.extract + PackContent.parse (oracle Dart thật trong CI).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_content.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';

Map<String, Object?> _seedManifest(PackType type, int itemCount) => {
      'schemaVersion': 1,
      'id': 'seed_schema_${type.name}',
      'type': type.wire,
      'title': 'Seed ${type.name}',
      'description': 'd',
      'srcLang': 'en',
      'dstLang': 'vi',
      'tags': const ['seed'],
      'level': 'B1',
      'author': const {
        'uid': 'seed-in4up',
        'displayName': 'In4Up Seed',
        'verified': true,
      },
      'license': 'cc0',
      'version': 1,
      'sizeBytes': 100,
      'entryCount': itemCount,
      'stats': const {'downloads': 0, 'rating': 0, 'ratings': 0},
      'status': 'published',
      'storage': const {'backend': 'firebase', 'path': 'in4up-seed/x'},
      'createdAt': '2026-11-23T00:00:00Z',
      'updatedAt': '2026-11-23T00:00:00Z',
    };

void main() {
  test('vocab seed schema parse pass', () async {
    final files = {
      'data/entries.json': utf8.encode(jsonEncode({
        'schema': 'vocab-v1',
        'entries': [
          {
            'word': 'be',
            'meaning': 'thì; là; ở',
            'audio': 'be.mp3',
            'phonetic': '/biː/',
            'example': 'I want to be a teacher.',
          },
        ],
      })),
    };
    final bytes = await PackFile.build(
      manifestJson: jsonEncode(_seedManifest(PackType.vocab, 1)),
      files: files,
    );
    final extracted = await PackFile.extract(bytes);
    final content = PackContent.parse(extracted.manifest, extracted.files);
    expect(content, isA<VocabPackContent>());
    final vocab = content as VocabPackContent;
    expect(vocab.entries.single.word, 'be');
    expect(vocab.entries.single.audioName, 'be.mp3');
  });

  test('audio seed schema parse pass (track + lrc)', () async {
    final files = {
      'data/tracks.json': utf8.encode(jsonEncode({
        'schema': 'audio-v1',
        'tracks': [
          {
            'file': 'story.wav',
            'title': 'Story',
            'lrc': 'story.lrc',
            'durationSec': 30,
          },
        ],
      })),
      'media/story.wav': Uint8List.fromList(const [82, 73, 70, 70]),
      'data/story.lrc': utf8.encode('[00:00.00]Hello world\n'),
    };
    final bytes = await PackFile.build(
      manifestJson: jsonEncode(_seedManifest(PackType.audio, 1)),
      files: files,
    );
    final extracted = await PackFile.extract(bytes);
    final content = PackContent.parse(extracted.manifest, extracted.files);
    expect(content, isA<AudioPackContent>());
    final audio = content as AudioPackContent;
    expect(audio.tracks.single.fileName, 'story.wav');
    expect(audio.tracks.single.lrcName, 'story.lrc');
  });

  test('image seed schema parse pass', () async {
    final files = {
      'data/items.json': utf8.encode(jsonEncode({
        'schema': 'image-v1',
        'items': [
          {'image': 'dog.png', 'caption': 'dog — con chó', 'word': 'dog'},
        ],
      })),
      'media/dog.png': Uint8List.fromList(const [137, 80, 78, 71]),
    };
    final bytes = await PackFile.build(
      manifestJson: jsonEncode(_seedManifest(PackType.image, 1)),
      files: files,
    );
    final extracted = await PackFile.extract(bytes);
    final content = PackContent.parse(extracted.manifest, extracted.files);
    expect(content, isA<ImagePackContent>());
    final img = content as ImagePackContent;
    expect(img.items.single.imageName, 'dog.png');
    expect(img.items.single.caption, 'dog — con chó');
  });
}
