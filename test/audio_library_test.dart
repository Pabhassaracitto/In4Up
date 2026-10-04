// test/audio_library_test.dart
// Test logic thuần của Thư viện âm thanh (P1) — mergeScanned + search.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_library_entry.dart';
import 'package:in4up/services/audio_library_service.dart';

AudioLibraryEntry _entry({
  required String id,
  required String uri,
  String title = 'Title',
  String? artist,
  AudioSource source = AudioSource.media,
  DateTime? lastPlayed,
}) {
  return AudioLibraryEntry(
    libraryId: id,
    uri: uri,
    title: title,
    artist: artist,
    source: source,
    addedAt: DateTime(2026, 1, 1),
    lastPlayed: lastPlayed,
  );
}

void main() {
  group('AudioLibraryService.mergeScanned', () {
    test('entry mới được giữ nguyên, entry trùng uri giữ lastPlayed + fingerprint', () {
      final existing = [
        _entry(
          id: 'media_1',
          uri: 'content://media/external/audio/media/1',
          title: 'Pháp thoại 1',
          lastPlayed: DateTime(2026, 8, 1),
        ),
      ];
      final scanned = [
        _entry(id: 'media_1', uri: 'content://media/external/audio/media/1', title: 'Pháp thoại 1'),
        _entry(id: 'media_2', uri: 'content://media/external/audio/media/2', title: 'Bài nghe 2'),
      ];

      final merged = AudioLibraryService.mergeScanned(scanned, existing);

      expect(merged, hasLength(2));
      final kept = merged.firstWhere((e) => e.libraryId == 'media_1');
      expect(kept.lastPlayed, DateTime(2026, 8, 1)); // giữ từ bản cũ
      final added = merged.firstWhere((e) => e.libraryId == 'media_2');
      expect(added.lastPlayed, isNull);
    });

    test('entry media biến mất khỏi lần quét mới → bị bỏ', () {
      final existing = [
        _entry(id: 'media_9', uri: 'content://.../9', title: 'Cũ'),
      ];
      final merged = AudioLibraryService.mergeScanned(
        [_entry(id: 'media_1', uri: 'content://.../1', title: 'Mới')],
        existing,
      );
      expect(merged.any((e) => e.libraryId == 'media_9'), isFalse);
    });

    test('entry nguồn picked/recent luôn được giữ dù không còn trên máy', () {
      final existing = [
        _entry(
          id: 'picked_x',
          uri: '/storage/emulated/0/Download/audio.mp3',
          title: 'Imported',
          source: AudioSource.picked,
        ),
      ];
      final merged = AudioLibraryService.mergeScanned(
        [_entry(id: 'media_1', uri: 'content://.../1', title: 'Mới')],
        existing,
      );
      expect(merged.any((e) => e.libraryId == 'picked_x'), isTrue);
    });
  });

  group('AudioLibraryService.search', () {
    test('tìm theo title và artist (không phân biệt hoa thường)', () {
      final entries = [
        _entry(id: 'a', uri: 'u:a', title: 'Pháp Thoại Ngày Nay', artist: 'Thầy Minh'),
        _entry(id: 'b', uri: 'u:b', title: 'English Lesson 1', artist: 'BBC'),
      ];

      expect(AudioLibraryService.search(entries, 'pháp').single.libraryId, 'a');
      expect(AudioLibraryService.search(entries, 'thầy').single.libraryId, 'a');
      expect(AudioLibraryService.search(entries, 'bbc').single.libraryId, 'b');
    });

    test('query rỗng → trả toàn bộ', () {
      final entries = [_entry(id: 'a', uri: 'u:a'), _entry(id: 'b', uri: 'u:b')];
      expect(AudioLibraryService.search(entries, ''), hasLength(2));
      expect(AudioLibraryService.search(entries, '   '), hasLength(2));
    });
  });
}
