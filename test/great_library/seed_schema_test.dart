// test/great_library/seed_schema_test.dart
//
// GLIB-008 — seed pack build in-memory theo đúng schema
// tool/great_library_seed/ (vocab entries / audio tracks / image items) phải
// pass PackFile.build + extract + PackContent.parse (oracle Dart thật trong
// CI). Manifest field khớp builder Python (build_manifest).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_content.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';

/// Manifest khớp build_seed_packs.build_manifest: seed-in4up / en→vi / level
/// hợp lệ / license cc0 / storage firebase / status published.
PackManifest _seedManifest(String id, PackType type, int itemCount,
        {int payloadBytes = 100}) =>
    PackManifest(
      id: id,
      type: type,
      title: 'Seed ${type.name}',
      description: 'Seed schema test',
      srcLang: 'en',
      dstLang: 'vi',
      tags: const ['seed'],
      level: 'B1',
      author: const PackAuthor(
          uid: 'seed-in4up', displayName: 'In4Up Seed', verified: true),
      license: PackLicense.cc0,
      sizeBytes: payloadBytes,
      entryCount: itemCount,
      status: PackStatus.published,
      storage: const PackStorageRef(backend: 'firebase', path: 'in4up-seed/x'),
      createdAt: DateTime.utc(2026, 11, 23),
      updatedAt: DateTime.utc(2026, 11, 23),
    );

void main() {
  test('vocab seed schema parse pass', () {
    final result = PackFile.build(
      manifest: _seedManifest('seed_schema_vocab', PackType.vocab, 1),
      dataFiles: {
        'entries.json': utf8.encode(jsonEncode([
          {
            'word': 'be',
            'meaning': 'thì; là; ở',
            'audio': 'be.mp3',
            'phonetic': '/biː/',
            'example': 'I want to be a teacher.',
          },
        ])),
      },
      // vocab.audio trỏ media/be.mp3 (TTS bulk lúc soạn) — parser bắt buộc
      // media tồn tại → test gắn placeholder để khớp contract GLIB-005.
      mediaFiles: {'be.mp3': Uint8List.fromList(const [0xFF, 0xFB])},
    );
    final extracted = PackFile.extract(result.bytes);
    final plan = PackContent.parse(extracted);
    expect(plan, isA<VocabPackPlan>());
    final vocab = plan as VocabPackPlan;
    expect(vocab.items.single.word, 'be');
    expect(vocab.items.single.meaning, 'thì; là; ở');
    expect(vocab.items.single.audioName, 'be.mp3');
    expect(vocab.items.single.phonetic, '/biː/');
  });

  test('audio seed schema parse pass (track + lrc)', () {
    final result = PackFile.build(
      manifest: _seedManifest('seed_schema_audio', PackType.audio, 1),
      dataFiles: {
        'tracks.json': utf8.encode(jsonEncode([
          {
            'file': 'story.wav',
            'title': 'Story',
            'lrc': 'story.lrc',
            'durationSec': 30,
          },
        ])),
        'story.lrc': utf8.encode('[00:00.00]Hello world\n'),
      },
      mediaFiles: {'story.wav': Uint8List.fromList(const [82, 73, 70, 70])},
    );
    final extracted = PackFile.extract(result.bytes);
    final plan = PackContent.parse(extracted);
    expect(plan, isA<AudioPackPlan>());
    final audio = plan as AudioPackPlan;
    expect(audio.tracks.single.fileName, 'story.wav');
    expect(audio.tracks.single.lrcName, 'story.lrc');
    expect(audio.tracks.single.durationSec, 30);
  });

  test('image seed schema parse pass', () {
    final result = PackFile.build(
      manifest: _seedManifest('seed_schema_image', PackType.image, 1),
      dataFiles: {
        'items.json': utf8.encode(jsonEncode([
          {'image': 'dog.png', 'caption': 'dog — con chó', 'word': 'dog'},
        ])),
      },
      mediaFiles: {'dog.png': Uint8List.fromList(const [137, 80, 78, 71])},
    );
    final extracted = PackFile.extract(result.bytes);
    final plan = PackContent.parse(extracted);
    expect(plan, isA<ImagePackPlan>());
    final img = plan as ImagePackPlan;
    expect(img.items.single.imageName, 'dog.png');
    expect(img.items.single.caption, 'dog — con chó');
    expect(img.items.single.word, 'dog');
  });
}
