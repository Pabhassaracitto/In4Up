// test/audio_library_filters_test.dart
// I4U18-LISTEN-LIB-001 — bộ lọc (album/tác giả/thư mục/yêu thích) + smart
// playlist (recent/favorite/unplayed) + facet lists + search album.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_library_entry.dart';
import 'package:in4up/services/audio_library_service.dart';

AudioLibraryEntry _e({
  required String id,
  String title = 'T',
  String? artist,
  String? album,
  String folder = '',
  bool favorite = false,
  DateTime? lastPlayed,
}) {
  return AudioLibraryEntry(
    libraryId: id,
    uri: 'u:$id',
    title: title,
    artist: artist,
    album: album,
    folder: folder,
    favorite: favorite,
    lastPlayed: lastPlayed,
    addedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final now = DateTime(2026, 9, 30);
  final entries = [
    _e(id: '1', title: 'A', artist: 'Thầy Minh', album: 'Pháp thoại', folder: 'Dhamma', favorite: true, lastPlayed: now.subtract(const Duration(days: 2))),
    _e(id: '2', title: 'B', artist: 'BBC', album: 'News', folder: 'English'),
    _e(id: '3', title: 'C', artist: 'Thầy Minh', album: 'Pháp thoại', folder: 'Dhamma', lastPlayed: now.subtract(const Duration(days: 90))),
  ];

  group('facet lists', () {
    test('albums / artists / folders duy nhất + sắp xếp', () {
      expect(AudioLibraryService.albums(entries), ['News', 'Pháp thoại']);
      expect(AudioLibraryService.artists(entries), ['BBC', 'Thầy Minh']);
      expect(AudioLibraryService.folders(entries), ['Dhamma', 'English']);
    });
  });

  group('lọc facet', () {
    test('byAlbum', () {
      final r = AudioLibraryService.byAlbum(entries, 'Pháp thoại');
      expect(r.map((e) => e.libraryId), ['1', '3']);
    });
    test('byArtist', () {
      final r = AudioLibraryService.byArtist(entries, 'bbc'); // hoa/thường
      expect(r.single.libraryId, '2');
    });
    test('byFolder', () {
      expect(AudioLibraryService.byFolder(entries, 'English').single.libraryId,
          '2');
    });
  });

  group('smart playlist', () {
    test('favorites', () {
      expect(AudioLibraryService.favorites(entries).single.libraryId, '1');
    });
    test('recent (30 ngày)', () {
      final r = AudioLibraryService.recent(entries, days: 30, now: now);
      expect(r.map((e) => e.libraryId), ['1']); // '3' đã 90 ngày
    });
    test('unplayed', () {
      expect(AudioLibraryService.unplayed(entries).single.libraryId, '2');
    });
    test('applySmart', () {
      expect(
          AudioLibraryService.applySmart(entries, SmartPlaylist.all, now: now)
              .length,
          3);
      expect(
          AudioLibraryService.applySmart(entries, SmartPlaylist.favorite)
              .single
              .libraryId,
          '1');
    });
  });

  group('search bao gồm album', () {
    test('tìm theo album', () {
      expect(AudioLibraryService.search(entries, 'news').single.libraryId, '2');
    });
  });

  group('fromMediaMap đọc album + folder', () {
    test('album + relativePath → folder', () {
      final e = AudioLibraryEntry.fromMediaMap({
        'id': '9',
        'uri': 'content://media/external/audio/media/9',
        'title': 'X',
        'artist': 'Y',
        'album': 'Z',
        'durationMs': 1000,
        'sizeBytes': 5,
        'dateAddedSec': 0,
        'relativePath': 'Music/Dhamma/',
      });
      expect(e.album, 'Z');
      expect(e.folder, 'Dhamma');
    });
  });
}
