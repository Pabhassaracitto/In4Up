// test/video_library_logic_test.dart
// I4U18-VIDEO-LIB-001 — logic thuần thư viện video: folder key, ghép phụ đề,
// merge (không trùng, giữ favorite/vị trí/phụ đề), lọc/sắp xếp.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/models/video_info.dart';
import 'package:in4up/features/video/services/video_library_logic.dart';

VideoScanItem _item(String uri, {int size = 100, int mtime = 0}) {
  final name = uri.contains('/document/')
      ? Uri.decodeComponent(uri.split('/document/').last).split('/').last
      : uri.split('/').last;
  return VideoScanItem(
    uri: uri,
    name: name,
    sizeBytes: size,
    dateModifiedMs: mtime,
    ext: VideoLibraryLogic.extensionOf(name),
  );
}

void main() {
  group('extension + folder helpers', () {
    test('extensionOf / stripExtension', () {
      expect(VideoLibraryLogic.extensionOf('movie.MP4'), 'mp4');
      expect(VideoLibraryLogic.extensionOf('no_ext'), '');
      expect(VideoLibraryLogic.stripExtension('movie.en.srt'), 'movie.en');
      expect(VideoLibraryLogic.stripExtension('movie'), 'movie');
    });

    test('folderKey/folderLabel cho file path', () {
      expect(VideoLibraryLogic.folderKey('/storage/emulated/0/Movies/a.mp4'),
          '/storage/emulated/0/Movies');
      expect(VideoLibraryLogic.folderLabel('/storage/emulated/0/Movies/a.mp4'),
          'Movies');
    });

    test('folderKey/folderLabel cho content:// SAF URI', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3AMovies/document/primary%3AMovies%2Fsub%2Fa.mp4';
      expect(VideoLibraryLogic.folderKey(uri), 'primary:Movies/sub');
      expect(VideoLibraryLogic.folderLabel(uri), 'sub');
    });

    test('stableId ổn định (không phụ thuộc mtime) + không phân biệt hoa/thường',
        () {
      final a = VideoLibraryLogic.stableId('/x/Movie.MP4');
      final b = VideoLibraryLogic.stableId('/x/movie.mp4');
      expect(a, b);
    });
  });

  group('matchSubtitle', () {
    test('ưu tiên cùng thư mục + cùng tên', () {
      final v = _item('/m/a.mp4');
      final subs = [
        _item('/other/a.srt'),
        _item('/m/a.srt'),
        _item('/m/b.srt'),
      ];
      expect(VideoLibraryLogic.matchSubtitle(v, subs), '/m/a.srt');
    });

    test('phụ đề đa ngữ movie.en.srt khớp movie.mp4', () {
      final v = _item('/m/movie.mp4');
      final subs = [_item('/m/movie.en.srt')];
      expect(VideoLibraryLogic.matchSubtitle(v, subs), '/m/movie.en.srt');
    });

    test('cùng tên nhưng khác thư mục vẫn khớp khi không có lựa chọn tốt hơn',
        () {
      final v = _item('/m/a.mp4');
      final subs = [_item('/other/a.srt')];
      expect(VideoLibraryLogic.matchSubtitle(v, subs), '/other/a.srt');
    });

    test('thư mục có đúng 1 phụ đề → dùng dù tên khác', () {
      final v = _item('/m/a.mp4');
      final subs = [_item('/m/whatever.srt')];
      expect(VideoLibraryLogic.matchSubtitle(v, subs), '/m/whatever.srt');
    });

    test('không có phụ đề → null', () {
      final v = _item('/m/a.mp4');
      expect(VideoLibraryLogic.matchSubtitle(v, const []), isNull);
    });
  });

  group('buildFromScan', () {
    test('tách video/phụ đề + ghép phụ đề', () {
      final items = [
        _item('/m/a.mp4'),
        _item('/m/a.srt'),
        _item('/m/b.mkv'),
      ];
      final videos = VideoLibraryLogic.buildFromScan(items);
      expect(videos, hasLength(2));
      final a = videos.firstWhere((v) => v.title == 'a');
      expect(a.hasSubtitle, isTrue);
      final b = videos.firstWhere((v) => v.title == 'b');
      expect(b.hasSubtitle, isFalse);
    });
  });

  group('mergeScanned', () {
    VideoInfo folder(String uri, {bool fav = false, int pos = 0, String? sub}) =>
        VideoInfo(
          id: VideoLibraryLogic.stableId(uri),
          title: VideoLibraryLogic.stripExtension(uri.split('/').last),
          filePath: uri,
          duration: Duration.zero,
          addedAt: DateTime(2026, 1, 1),
          source: VideoSource.folder,
          favorite: fav,
          lastPositionMs: pos,
          subtitlePath: sub,
        );

    test('quét lại KHÔNG tạo bản trùng + giữ favorite/vị trí/phụ đề', () {
      final existing = [
        folder('/m/a.mp4', fav: true, pos: 42000, sub: '/m/a.srt'),
      ];
      final scanned = [folder('/m/a.mp4'), folder('/m/b.mp4')];
      final merged = VideoLibraryLogic.mergeScanned(scanned, existing);
      expect(merged, hasLength(2));
      final a = merged.firstWhere((v) => v.title == 'a');
      expect(a.favorite, isTrue);
      expect(a.lastPositionMs, 42000);
      expect(a.subtitlePath, '/m/a.srt');
    });

    test('file folder biến mất khỏi lần quét mới → bị bỏ', () {
      final existing = [folder('/m/gone.mp4')];
      final merged =
          VideoLibraryLogic.mergeScanned([folder('/m/a.mp4')], existing);
      expect(merged.any((v) => v.title == 'gone'), isFalse);
    });

    test('video import thủ công (picked) luôn được giữ', () {
      final picked = VideoInfo(
        id: 'p1',
        title: 'imported',
        filePath: '/dl/imported.mp4',
        duration: Duration.zero,
        addedAt: DateTime(2026, 1, 1),
        source: VideoSource.picked,
      );
      final merged =
          VideoLibraryLogic.mergeScanned([folder('/m/a.mp4')], [picked]);
      expect(merged.any((v) => v.title == 'imported'), isTrue);
    });
  });

  group('query (lọc + sắp xếp + tìm)', () {
    final list = [
      VideoInfo(
        id: '1',
        title: 'Alpha',
        filePath: '/m/Alpha.mp4',
        duration: const Duration(minutes: 10),
        addedAt: DateTime(2026, 1, 1),
        folder: 'M',
        favorite: true,
        subtitlePath: '/m/Alpha.srt',
        lastPlayed: DateTime.now(),
      ),
      VideoInfo(
        id: '2',
        title: 'Beta',
        filePath: '/m/Beta.mp4',
        duration: const Duration(minutes: 30),
        addedAt: DateTime(2026, 2, 1),
        folder: 'N',
      ),
    ];

    test('filter favorites', () {
      final r = list.query(filter: VideoFilter.favorites);
      expect(r, hasLength(1));
      expect(r.first.title, 'Alpha');
    });

    test('filter hasSubtitle', () {
      final r = list.query(filter: VideoFilter.hasSubtitle);
      expect(r.single.title, 'Alpha');
    });

    test('sort durationLongest', () {
      final r = list.query(sort: VideoSort.durationLongest);
      expect(r.first.title, 'Beta');
    });

    test('sort titleAsc', () {
      final r = list.query(sort: VideoSort.titleAsc);
      expect(r.first.title, 'Alpha');
    });

    test('search theo tên', () {
      expect(list.query(search: 'beta').single.title, 'Beta');
    });

    test('folders liệt kê duy nhất, sắp xếp', () {
      expect(list.folders, ['M', 'N']);
    });
  });
}
