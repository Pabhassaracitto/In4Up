// test/audio_playlist_test.dart
// I4U18-LISTEN-LIB-001 — model playlist thủ công: add/remove/reorder + JSON.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_playlist.dart';

void main() {
  group('AudioPlaylist', () {
    test('create + add không trùng', () {
      final pl = AudioPlaylist.create('My list');
      expect(pl.name, 'My list');
      expect(pl.add('a'), isTrue);
      expect(pl.add('a'), isFalse); // trùng
      expect(pl.add('b'), isTrue);
      expect(pl.trackIds, ['a', 'b']);
    });

    test('remove', () {
      final pl = AudioPlaylist.create('x')..add('a')..add('b');
      expect(pl.remove('a'), isTrue);
      expect(pl.remove('zzz'), isFalse);
      expect(pl.trackIds, ['b']);
    });

    test('reorder', () {
      final pl = AudioPlaylist.create('x')
        ..add('a')
        ..add('b')
        ..add('c');
      pl.reorder(0, 3); // đưa 'a' xuống cuối
      expect(pl.trackIds, ['b', 'c', 'a']);
    });

    test('reorder biên an toàn', () {
      final pl = AudioPlaylist.create('x')..add('a')..add('b');
      pl.reorder(5, 0); // index ngoài biên → no-op
      expect(pl.trackIds, ['a', 'b']);
    });

    test('JSON round-trip', () {
      final pl = AudioPlaylist.create('Round')..add('x')..add('y');
      final back = AudioPlaylist.fromJson(pl.toJson());
      expect(back.id, pl.id);
      expect(back.name, 'Round');
      expect(back.trackIds, ['x', 'y']);
    });

    test('create với tên rỗng → mặc định', () {
      expect(AudioPlaylist.create('   ').name, 'Playlist');
    });
  });
}
