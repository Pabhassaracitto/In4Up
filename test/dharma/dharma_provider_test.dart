// test/dharma/dharma_provider_test.dart
//
// AT-2/AT-3/AT-6 ở tầng provider — phần KHÔNG thể chứng minh bằng hàm thuần:
//   * tiến độ ghi theo `episodeKey` (danh tính nội dung), không theo path ⇒
//     quét lại/đổi nguồn không mất vị trí (AT-6);
//   * "Đã nghe xong" bấm tay THẮNG suy luận tự động, và không bị lần ghi tiến
//     độ sau đó xoá mất (bẫy thật: `_captureProgressFromPlayer` dựng lại
//     `DharmaProgress` từ đầu nên dễ làm rơi cờ `completedManually`);
//   * sửa tay tên vị Thầy gộp series vào đúng nhóm, và sống qua lần `load()`
//     kế tiếp (lưu ở box overrides), trong khi `episodeKey` KHÔNG đổi.
//
// Dùng `DharmaProvider(store: …)` với store giả trong RAM nên không cần Hive,
// không cần SharedPreferences, không cần plugin.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in4up/features/dharma/models/dharma_talk.dart';
import 'package:in4up/features/dharma/services/dharma_provider.dart';
import 'package:in4up/features/dharma/services/dharma_scanner.dart';
import 'package:in4up/features/dharma/services/dharma_store.dart';

/// Store trong RAM — `extends DharmaStore` (không `implements`) để nếu sau này
/// thêm method vào store thì test này KHÔNG vỡ vì thiếu override, mà chỉ đơn
/// giản là chạy bản Hive (và nếu chạm Hive thì test sẽ báo lỗi rõ ràng).
class _FakeStore extends DharmaStore {
  _FakeStore() : super.forTest();

  List<DharmaSeries> series = <DharmaSeries>[];
  final Map<String, DharmaProgress> progress = <String, DharmaProgress>{};
  final Map<String, String> overrides = <String, String>{};

  @override
  Future<List<DharmaSeries>> loadSeries() async => List.of(series);

  @override
  Future<void> saveSeries(List<DharmaSeries> value) async {
    // Hành vi THẬT: thay catalog, KHÔNG chạm progress (ADR-0022).
    series = List.of(value);
  }

  @override
  Future<Map<String, DharmaProgress>> loadProgress() async =>
      Map.of(progress);

  @override
  Future<void> putProgress(DharmaProgress value) async {
    progress[value.episodeKey] = value;
  }

  @override
  Future<void> clearProgress(String episodeKey) async {
    progress.remove(episodeKey);
  }

  @override
  Future<Map<String, String>> loadOverrides() async => Map.of(overrides);

  @override
  Future<void> putOverride(String key, String value) async {
    overrides[key] = value;
  }
}

DharmaSeries _series({
  String seriesKey = 'local:s1',
  String speaker = 'Sayadaw U Kovida',
  List<DharmaEpisode> episodes = const <DharmaEpisode>[],
}) {
  return DharmaSeries(
    seriesKey: seriesKey,
    title: 'Khoá thiền PS',
    rawName: '34. Sayadaw U Kovida Khoá thiền PS 2024',
    speakerKey: speaker.isEmpty ? null : speaker.toLowerCase().replaceAll(' ', '_'),
    speakerDisplay: speaker.isEmpty ? null : speaker,
    collection: DharmaCollection.talkArchive,
    episodes: episodes,
    lastScannedAt: DateTime(2026, 11, 3),
  );
}

DharmaEpisode _episode(int n, {String seriesKey = 'local:s1'}) {
  return DharmaEpisode(
    episodeKey: '$seriesKey:ep$n',
    source: '/root/series/B$n.mp3',
    title: 'Buổi $n',
    rawName: 'B$n Buổi $n.mp3',
    episodeStart: n,
  );
}

void main() {
  // `DharmaProvider.load()` đọc nguồn đã chọn từ SharedPreferences ⇒ phải có
  // mock, nếu không test ném MissingPluginException (không có plugin trên CI).
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('tiến độ theo danh tính nội dung', () {
    test('quét lại (catalog mới) KHÔNG xoá vị trí đã nghe (AT-6)', () async {
      final store = _FakeStore();
      final ep = _episode(1);
      store.series = [_series(episodes: [ep])];
      store.progress[ep.episodeKey] = const DharmaProgress(
        episodeKey: 'local:s1:ep1',
        lastPosition: Duration(minutes: 12),
        duration: Duration(minutes: 60),
      );

      final provider = DharmaProvider(store: store);
      await provider.load();

      expect(provider.progressFor(ep.episodeKey)?.lastPosition,
          const Duration(minutes: 12));

      // Quét lại: cùng nội dung nhưng đường dẫn phát đã đổi (nguồn khác).
      store.series = [
        _series(episodes: [
          DharmaEpisode(
            episodeKey: ep.episodeKey,
            source: '/other/place/B1.mp3',
            title: 'Buổi 1',
            rawName: 'B1 Buổi 1.mp3',
            episodeStart: 1,
          ),
        ]),
      ];
      // Ghi catalog mới đúng như `rescan()` làm, nhưng không quét (không I/O).
      await store.saveSeries(store.series);

      expect(provider.progressFor(ep.episodeKey)?.lastPosition,
          const Duration(minutes: 12),
          reason: 'catalog và tiến độ là hai box riêng (ADR-0022)');
      expect(store.progress, contains(ep.episodeKey),
          reason: 'saveSeries không được xoá progress');
    });

    test('"Đã nghe xong" bấm tay thắng suy luận và sống qua load()',
        () async {
      final store = _FakeStore();
      final ep = _episode(1);
      store.series = [_series(episodes: [ep])];
      store.progress[ep.episodeKey] = const DharmaProgress(
        episodeKey: 'local:s1:ep1',
        lastPosition: Duration(minutes: 1),
        duration: Duration(minutes: 60),
      );

      final provider = DharmaProvider(store: store);
      await provider.load();

      // 1 phút / 60 phút ⇒ chưa xong.
      expect(provider.progressFor(ep.episodeKey)?.isCompleted, isFalse);

      await provider.markCompleted(ep);
      expect(provider.progressFor(ep.episodeKey)?.isCompleted, isTrue,
          reason: 'đánh dấu tay phải thắng ngưỡng %');

      // Provider mới đọc lại từ store ⇒ cờ phải còn.
      final again = DharmaProvider(store: store);
      await again.load();
      expect(again.progressFor(ep.episodeKey)?.isCompleted, isTrue);

      // Bỏ đánh dấu ⇒ quay về suy luận (1 phút vẫn chưa xong).
      await again.markCompleted(ep, completed: false);
      expect(again.progressFor(ep.episodeKey)?.isCompleted, isFalse);
    });

    test('xoá tiến độ chỉ xoá tiến độ, không đụng catalog (AT-6)',
        () async {
      final store = _FakeStore();
      final ep = _episode(2);
      store.series = [_series(episodes: [ep])];
      store.progress[ep.episodeKey] = const DharmaProgress(
        episodeKey: 'local:s1:ep2',
        lastPosition: Duration(minutes: 30),
        duration: Duration(minutes: 60),
      );

      final provider = DharmaProvider(store: store);
      await provider.load();
      await provider.resetProgress(ep);

      expect(provider.progressFor(ep.episodeKey), isNull);
      expect(provider.series, hasLength(1));
      expect(store.series, hasLength(1), reason: 'catalog còn nguyên');
    });
  });

  group('sửa tay tên vị Thầy', () {
    test('đổi nhóm hiển thị nhưng KHÔNG đổi seriesKey/episodeKey', () async {
      final store = _FakeStore();
      final ep = _episode(1);
      final s = _series(episodes: [ep]);
      store.series = [s];

      final provider = DharmaProvider(store: store);
      await provider.load();
      final beforeKeys =
          provider.series.map((x) => x.seriesKey).toList(growable: false);

      await provider.overrideSpeaker(s, 'Sư Bà Dipankara');

      expect(provider.series.first.speakerDisplay, 'Sư Bà Dipankara');
      expect(provider.series.first.speakerKey, 'su_ba_dipankara');
      expect(provider.series.map((x) => x.seriesKey).toList(), beforeKeys,
          reason: 'danh tính nội dung không được đổi theo tên hiển thị');
      expect(store.overrides['speaker:local:s1'], 'Sư Bà Dipankara');
    });

    test('nhóm "chưa rõ vị Thầy" dùng khoá __unknown__', () async {
      final store = _FakeStore();
      store.series = [_series(speaker: '', episodes: [_episode(1)])];

      final provider = DharmaProvider(store: store);
      await provider.load();

      final groups = provider.speakerGroups();
      expect(groups.any((g) => g.isUnknown), isTrue);
      expect(groups.firstWhere((g) => g.isUnknown).key, '__unknown__');
    });
  });

  group('đường dẫn tới buổi', () {
    test('nextEpisodeOf chọn buổi dở trước, rồi buổi chưa nghe đầu tiên',
        () async {
      final store = _FakeStore();
      final e1 = _episode(1);
      final e2 = _episode(2);
      final e3 = _episode(3);
      store.series = [_series(episodes: [e1, e2, e3])];
      // Buổi 1 ĐÃ XONG (59:45/60:00 ⇒ còn 15 s ≤ 30 s), nên phải bỏ qua dù vị
      // trí > 0; buổi 2 chưa nghe; buổi 3 đang nghe dở ⇒ đề xuất buổi 3 (đang
      // dở thắng "chưa nghe"). Thứ tự duyệt là từ đầu series, nên nếu buổi 1
      // không được coi là xong thì test này bắt đúng lỗi "đề xuất bài đã xong".
      store.progress[e1.episodeKey] = const DharmaProgress(
        episodeKey: 'local:s1:ep1',
        lastPosition: Duration(minutes: 59, seconds: 45),
        duration: Duration(minutes: 60),
      );
      expect(store.progress[e1.episodeKey]!.isCompleted, isTrue,
          reason: 'còn ≤30 s cuối ⇒ xong (bài dài)');
      expect(store.progress[e1.episodeKey]!.isInProgress, isFalse);
      store.progress[e3.episodeKey] = const DharmaProgress(
        episodeKey: 'local:s1:ep3',
        lastPosition: Duration(minutes: 10),
        duration: Duration(minutes: 60),
      );

      final provider = DharmaProvider(store: store);
      await provider.load();

      expect(provider.nextEpisodeOf(provider.series.first)?.episodeKey,
          e3.episodeKey);
    });
  });

  group('danh tính do scanner sinh', () {
    test('localEpisodeKey ổn định và khác nhau theo đường dẫn', () {
      const a = '/root/series/B1.mp3';
      const b = '/root/series/B1.mp3';
      const c = '/root/series/B2.mp3';
      expect(localEpisodeKey(a), localEpisodeKey(b));
      expect(localEpisodeKey(a), isNot(localEpisodeKey(c)));
      expect(localEpisodeKey(a), startsWith('local:'));
    });

    test('dấu \\ (Windows) được chuẩn hoá về / trước khi băm', () {
      expect(localEpisodeKey(r'C:\root\B1.mp3'), localEpisodeKey('C:/root/B1.mp3'));
    });

    test('seriesKeyFor ổn định theo thư mục tương đối', () {
      expect(seriesKeyFor('C/34. Kovida'), seriesKeyFor('C/34. Kovida'));
      expect(seriesKeyFor('C/34. Kovida'), isNot(seriesKeyFor('C/35. Khác')));
    });
  });
}
