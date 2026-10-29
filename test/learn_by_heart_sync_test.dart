// test/learn_by_heart_sync_test.dart
//
// LHB-006 — Đồng bộ lưu trữ Thuộc Lòng đa thiết bị.
//
// Test THUẦN LOGIC (không cần mạng/Firebase):
//   1. Mốc thay đổi của item (`updatedAt` / `syncStamp`) + round-trip JSON.
//   2. Hòa giải cloud ↔ máy: LWW + bia mộ (tombstone) + hàng đợi pending.
//   3. Nhịp học (streak) hòa giải theo ngày.
//   4. Kho cục bộ: pending/tombstone ghi bền; seed KHÔNG hồi sinh bài đã xoá.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/learn_by_heart/data/dhammapada_seed_data.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_stats.dart';
import 'package:in4up/features/learn_by_heart/services/learn_by_heart_merge.dart';
import 'package:in4up/features/learn_by_heart/services/learn_by_heart_storage.dart';

/// Item giả có id cố định, mốc thời gian cho trước.
LearnByHeartItem _item(
  String id, {
  required DateTime stamp,
  String title = 'Bài',
  bool favorite = false,
}) {
  return LearnByHeartItem(
    id: id,
    title: title,
    paliText: 'pali $id',
    vietnameseText: 'vi $id',
    createdAt: stamp,
    updatedAt: stamp,
    isFavorite: favorite,
  );
}

/// Doc cloud dạng Map (giống dữ liệu Firestore đã decode).
Map<String, dynamic> _remoteItemJson(LearnByHeartItem item) {
  final data = item.toJson();
  data['updatedAt'] = item.syncStamp.toUtc().toIso8601String();
  data['deleted'] = false;
  return data;
}

Map<String, dynamic> _remoteTombstone(String id, DateTime at) {
  final iso = at.toUtc().toIso8601String();
  return <String, dynamic>{
    'id': id,
    'deleted': true,
    'deletedAt': iso,
    'updatedAt': iso,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day0 = DateTime.utc(2026, 1, 1, 8);
  final day1 = DateTime.utc(2026, 1, 2, 8);
  final day2 = DateTime.utc(2026, 1, 3, 8);

  group('LHB-006 — mốc thay đổi của item', () {
    test('updatedAt round-trip qua JSON', () {
      final item = _item('a', stamp: day1);
      final restored = LearnByHeartItem.fromJson(item.toJson());
      expect(restored.updatedAt, day1);
      expect(restored.syncStamp, day1);
    });

    test('item cũ không có updatedAt → syncStamp suy từ createdAt', () {
      final legacy = LearnByHeartItem(
        id: 'legacy',
        title: 'Cũ',
        paliText: 'p',
        vietnameseText: 'v',
        createdAt: day0,
      );
      final json = legacy.toJson();
      expect(json['updatedAt'], isNull);
      final restored = LearnByHeartItem.fromJson(json);
      expect(restored.updatedAt, isNull);
      expect(restored.syncStamp, day0);
    });

    test('parseStamp chịu lỗi: chuỗi ISO ok, giá trị rác → null', () {
      expect(LearnByHeartItem.parseStamp(day1.toIso8601String()), day1);
      expect(LearnByHeartItem.parseStamp('không phải ngày'), isNull);
      expect(LearnByHeartItem.parseStamp(null), isNull);
      expect(LearnByHeartItem.parseStamp(day1), day1);
    });

    test('seed mặc định không có updatedAt (không tự nhận là bản mới)', () {
      for (final seed in DhammapadaSeedData.getInitialItems()) {
        expect(seed.updatedAt, isNull);
      }
    });
  });

  group('LHB-006 — hòa giải cloud ↔ máy', () {
    test('máy chưa sửa gì (không pending) → cloud thắng', () {
      // Bài seed mới sinh có createdAt = hôm nay nhưng KHÔNG pending.
      final local = _item('dhp_001', stamp: day2, title: 'Seed mới');
      final remote = LearnByHeartRemoteRecord.fromFirestoreDoc(
        'dhp_001',
        _remoteItemJson(_item('dhp_001', stamp: day1, title: 'Bản cloud')),
      )!;

      final result = LearnByHeartMerge.merge(
        localItems: [local],
        remoteRecords: [remote],
      );
      expect(result.appliedCount, 1);
      expect(result.items.single.title, 'Bản cloud');
    });

    test('máy có sửa CHƯA đẩy & mới hơn → giữ máy, chờ đẩy', () {
      final local = _item('dhp_001', stamp: day2, title: 'Sửa ở máy');
      final remote = LearnByHeartRemoteRecord.fromFirestoreDoc(
        'dhp_001',
        _remoteItemJson(_item('dhp_001', stamp: day1, title: 'Bản cloud cũ')),
      )!;

      final result = LearnByHeartMerge.merge(
        localItems: [local],
        remoteRecords: [remote],
        pendingIds: {'dhp_001'},
      );
      expect(result.appliedCount, 0);
      expect(result.items.single.title, 'Sửa ở máy');
      expect(result.pendingIds, contains('dhp_001'));
    });

    test('máy có sửa chờ đẩy nhưng cloud MỚI hơn → cloud thắng, bỏ pending', () {
      final local = _item('dhp_001', stamp: day1, title: 'Sửa ở máy');
      final remote = LearnByHeartRemoteRecord.fromFirestoreDoc(
        'dhp_001',
        _remoteItemJson(_item('dhp_001', stamp: day2, title: 'Cloud mới')),
      )!;

      final result = LearnByHeartMerge.merge(
        localItems: [local],
        remoteRecords: [remote],
        pendingIds: {'dhp_001'},
      );
      expect(result.items.single.title, 'Cloud mới');
      expect(result.pendingIds, isEmpty);
      expect(result.appliedCount, 1);
    });

    test('bài mới từ cloud: lên đầu danh sách, giữ thứ tự còn lại', () {
      final local = [_item('b', stamp: day0), _item('c', stamp: day0)];
      final records = [
        LearnByHeartRemoteRecord.fromFirestoreDoc(
          'x',
          _remoteItemJson(_item('x', stamp: day1)),
        )!,
        LearnByHeartRemoteRecord.fromFirestoreDoc(
          'y',
          _remoteItemJson(_item('y', stamp: day1)),
        )!,
      ];

      final result = LearnByHeartMerge.merge(
        localItems: local,
        remoteRecords: records,
      );
      expect(result.items.map((i) => i.id).toList(), ['x', 'y', 'b', 'c']);
    });

    test('đã đồng bộ đúng mốc rồi → không tính là thay đổi (không nhiễu)', () {
      final item = _item('a', stamp: day1);
      final record = LearnByHeartRemoteRecord.fromFirestoreDoc(
        'a',
        _remoteItemJson(item),
      )!;
      final result = LearnByHeartMerge.merge(
        localItems: [_item('a', stamp: day1)],
        remoteRecords: [record],
      );
      expect(result.appliedCount, 0);
      expect(result.items.single.id, 'a');
    });

    test('bia mộ cloud xoá bài ở máy (không pending)', () {
      final result = LearnByHeartMerge.merge(
        localItems: [_item('a', stamp: day0), _item('b', stamp: day0)],
        remoteRecords: [
          LearnByHeartRemoteRecord.fromFirestoreDoc(
            'a',
            _remoteTombstone('a', day1),
          )!,
        ],
      );
      expect(result.items.map((i) => i.id).toList(), ['b']);
      expect(result.tombstones.containsKey('a'), isTrue);
      expect(result.tombstones['a'], day1);
      expect(result.appliedCount, 1);
    });

    test('máy sửa SAU khi bị xoá ở nơi khác → giữ bài, đẩy lại (không pending loss)',
        () {
      final result = LearnByHeartMerge.merge(
        localItems: [_item('a', stamp: day2, title: 'Sửa lại ở máy')],
        remoteRecords: [
          LearnByHeartRemoteRecord.fromFirestoreDoc(
            'a',
            _remoteTombstone('a', day1),
          )!,
        ],
        pendingIds: {'a'},
      );
      expect(result.items.single.title, 'Sửa lại ở máy');
      expect(result.tombstones.containsKey('a'), isFalse);
      expect(result.pendingIds, contains('a'));
    });

    test('bài sống lại từ cloud → xoá bia mộ cục bộ', () {
      final result = LearnByHeartMerge.merge(
        localItems: const [],
        remoteRecords: [
          LearnByHeartRemoteRecord.fromFirestoreDoc(
            'a',
            _remoteItemJson(_item('a', stamp: day2)),
          )!,
        ],
        tombstones: {'a': day1},
      );
      expect(result.items.single.id, 'a');
      expect(result.tombstones, isEmpty);
    });

    test('doc hỏng (thiếu mốc / JSON lỗi) bị bỏ qua, không crash', () {
      expect(
        LearnByHeartRemoteRecord.fromFirestoreDoc('a', {'title': 'x'}),
        isNull,
      );
      final broken = LearnByHeartRemoteRecord.fromFirestoreDoc('a', {
        'updatedAt': day1.toIso8601String(),
        'createdAt': 'không-phải-ngày',
        'keywords': 'phải-là-list',
      });
      expect(broken, isNull);

      final result = LearnByHeartMerge.merge(
        localItems: [_item('a', stamp: day0)],
        remoteRecords: const [],
      );
      expect(result.items.single.id, 'a');
      expect(result.appliedCount, 0);
    });

    test('dọn bia mộ cũ hơn 1 năm', () {
      final pruned = LearnByHeartMerge.pruneTombstones(
        {'cũ': DateTime.utc(2024, 1, 1), 'mới': day2},
        now: day2,
      );
      expect(pruned.containsKey('cũ'), isFalse);
      expect(pruned.containsKey('mới'), isTrue);
    });

    test('shouldApplyRemote: chỉ local-pending-mới-hơn mới thắng cloud', () {
      expect(
        LearnByHeartMerge.shouldApplyRemote(
          localStamp: day2,
          localPending: false,
          remoteStamp: day1,
        ),
        isTrue,
      );
      expect(
        LearnByHeartMerge.shouldApplyRemote(
          localStamp: day2,
          localPending: true,
          remoteStamp: day1,
        ),
        isFalse,
      );
      expect(
        LearnByHeartMerge.shouldApplyRemote(
          localStamp: day1,
          localPending: true,
          remoteStamp: day2,
        ),
        isTrue,
      );
      expect(
        LearnByHeartMerge.shouldApplyRemote(
          localStamp: null,
          localPending: true,
          remoteStamp: day2,
        ),
        isTrue,
      );
    });
  });

  group('LHB-006 — nhịp học (streak)', () {
    test('ngày mới hơn thắng', () {
      const local = LearnByHeartStats(streak: 3, lastActiveDate: '2026-1-1');
      const remote = LearnByHeartStats(streak: 1, lastActiveDate: '2026-1-2');
      expect(LearnByHeartStats.reconcile(local, remote).streak, 1);
      expect(
        LearnByHeartStats.reconcile(remote, local).lastActiveDate,
        '2026-1-2',
      );
    });

    test('cùng ngày → lấy streak lớn hơn', () {
      const local = LearnByHeartStats(streak: 3, lastActiveDate: '2026-1-2');
      const remote = LearnByHeartStats(streak: 7, lastActiveDate: '2026-1-2');
      expect(LearnByHeartStats.reconcile(local, remote).streak, 7);
    });

    test('khoá ngày không zero-pad vẫn so sánh đúng thứ tự', () {
      expect(
        LearnByHeartStats.dayOrdinal('2026-9-30') <
            LearnByHeartStats.dayOrdinal('2026-10-1'),
        isTrue,
      );
      expect(LearnByHeartStats.dayOrdinal(''), 0);
    });

    test('fromJson chịu được giá trị lạ', () {
      final stats = LearnByHeartStats.fromJson({
        'streak': '5',
        'lastActiveDate': 42,
      });
      expect(stats.streak, 5);
      expect(stats.lastActiveDate, '42');
    });
  });

  group('LHB-006 — kho cục bộ (pending + bia mộ)', () {
    final storage = LearnByHeartStorage.instance;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage.debugResetPrefsCache();
    });

    test('pending: đánh dấu / đọc / xoá', () async {
      await storage.markPending('a');
      await storage.markPending('b');
      await storage.markPending('a'); // trùng → không nhân đôi
      expect(await storage.loadPendingIds(), {'a', 'b'});

      await storage.clearPending(['a']);
      expect(await storage.loadPendingIds(), {'b'});

      await storage.savePendingIds({'x'});
      expect(await storage.loadPendingIds(), {'x'});

      await storage.savePendingIds(<String>{});
      expect(await storage.loadPendingIds(), isEmpty);
    });

    test('bia mộ: ghi / đọc lại (ISO, UTC) / không tụt mốc cũ', () async {
      await storage.addTombstone('a', at: day1);
      await storage.addTombstone('a', at: day0); // cũ hơn → giữ mốc mới
      final tombstones = await storage.loadTombstones();
      expect(tombstones.length, 1);
      expect(tombstones['a']!.toUtc(), day1);

      // Đọc lại từ prefs thô (mô phỏng mở app lần sau).
      storage.debugResetPrefsCache();
      expect((await storage.loadTombstones())['a']!.toUtc(), day1);
    });

    test('readItems không seed; loadItems seed nhưng BỎ bài đã xoá', () async {
      expect(await storage.readItems(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('learn_by_heart_items_v1'), isNull);

      final seeded = await storage.loadItems();
      expect(seeded, isNotEmpty);

      // Xoá 1 bài seed → tombstone → lần nạp sau KHÔNG hồi sinh bài đó.
      final removedId = seeded.first.id;
      await storage.addTombstone(removedId, at: day1);
      await storage.saveItems(<LearnByHeartItem>[]);
      storage.debugResetPrefsCache();

      final reloaded = await storage.loadItems();
      expect(reloaded.any((i) => i.id == removedId), isFalse);
      expect(reloaded.length, seeded.length - 1);
    });

    test('items đọc/ghi round-trip kèm updatedAt', () async {
      final item = _item('a', stamp: day1, favorite: true);
      await storage.saveItems([item]);
      storage.debugResetPrefsCache();

      final restored = await storage.readItems();
      expect(restored.single.id, 'a');
      expect(restored.single.updatedAt!.toUtc(), day1);
      expect(restored.single.isFavorite, isTrue);
    });

    test('stats đọc/ghi', () async {
      expect((await storage.readStats()).isEmpty, isTrue);
      await storage.writeStats(
        const LearnByHeartStats(streak: 4, lastActiveDate: '2026-1-2'),
      );
      storage.debugResetPrefsCache();
      final stats = await storage.readStats();
      expect(stats.streak, 4);
      expect(stats.lastActiveDate, '2026-1-2');
    });

    test('payload JSON của doc cloud = item JSON + updatedAt + deleted:false',
        () {
      final item = _item('a', stamp: day1);
      final payload = _remoteItemJson(item);
      final decoded = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      final record =
          LearnByHeartRemoteRecord.fromFirestoreDoc('a', decoded)!;
      expect(record.deleted, isFalse);
      expect(record.updatedAt.toUtc(), day1);
      expect(record.item!.id, 'a');
      expect(record.item!.updatedAt!.toUtc(), day1);
    });
  });
}
