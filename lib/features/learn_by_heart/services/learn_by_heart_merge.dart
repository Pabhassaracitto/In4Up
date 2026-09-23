// lib/features/learn_by_heart/services/learn_by_heart_merge.dart
//
// Hòa giải dữ liệu Thuộc Lòng giữa máy (SharedPreferences) và cloud
// (Firestore) — THUẦN LOGIC, không I/O, không Firebase ⇒ test được offline.
//
// Quy tắc (LHB-006):
//   1. "Cloud thắng" — TRỪ khi bản cục bộ có thay đổi CHƯA ĐẨY (pending)
//      với mốc thời gian MỚI HƠN bản cloud. Lúc đó giữ cục bộ và đẩy lên.
//   2. Xoá là bia mộ (tombstone): doc cloud `{deleted: true, deletedAt}` xoá
//      bài ở mọi thiết bị; bia mộ cũ không hồi sinh bài local.
//   3. Bài seed mặc định KHÔNG bao giờ pending ⇒ cloud luôn thắng, tránh
//      việc máy mới "hồi sinh" bài người dùng đã xoá/sửa ở máy khác.

import '../models/learn_by_heart_item.dart';

/// Một document `users/{uid}/learn_by_heart/{id}` đã decode.
class LearnByHeartRemoteRecord {
  final String id;

  /// Mốc thay đổi của bản cloud (ISO string hoặc Timestamp → DateTime).
  final DateTime updatedAt;

  /// true = bia mộ (bài đã bị xoá ở một thiết bị khác).
  final bool deleted;
  final DateTime? deletedAt;

  /// Nội dung bài (null khi [deleted] = true hoặc doc hỏng).
  final LearnByHeartItem? item;

  const LearnByHeartRemoteRecord({
    required this.id,
    required this.updatedAt,
    this.deleted = false,
    this.deletedAt,
    this.item,
  });

  /// Decode doc Firestore (plugin hoặc REST đều trả Map<String, dynamic>).
  /// Trả null nếu doc thiếu mốc thời gian hoặc JSON bài hỏng.
  static LearnByHeartRemoteRecord? fromFirestoreDoc(
      String id, Map<String, dynamic> data) {
    if (id.trim().isEmpty) return null;

    final deleted = data['deleted'] == true;
    final deletedAt = LearnByHeartItem.parseStamp(data['deletedAt']);
    final updatedAt = LearnByHeartItem.parseStamp(data['updatedAt']) ??
        deletedAt ??
        LearnByHeartItem.parseStamp(data['lastReviewedAt']) ??
        LearnByHeartItem.parseStamp(data['createdAt']);
    if (updatedAt == null) return null;

    if (deleted) {
      return LearnByHeartRemoteRecord(
        id: id,
        updatedAt: updatedAt,
        deleted: true,
        deletedAt: deletedAt ?? updatedAt,
      );
    }

    try {
      final payload = Map<String, dynamic>.from(data)
        ..remove('_syncedAt')
        ..remove('deleted');
      // Doc id là chân lý (JSON cũ có thể thiếu hoặc lệch id).
      payload['id'] = id;
      final item = LearnByHeartItem.fromJson(payload);
      return LearnByHeartRemoteRecord(
        id: id,
        updatedAt: updatedAt,
        item: item,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Kết quả hòa giải: danh sách bài + trạng thái đồng bộ đã cập nhật.
class LearnByHeartMergeResult {
  final List<LearnByHeartItem> items;
  final Map<String, DateTime> tombstones;
  final Set<String> pendingIds;

  /// Số bài cục bộ thực sự bị cloud thay đổi (thêm mới/sửa/xoá).
  final int appliedCount;

  const LearnByHeartMergeResult({
    required this.items,
    required this.tombstones,
    required this.pendingIds,
    required this.appliedCount,
  });
}

class LearnByHeartMerge {
  /// Bia mộ quá cũ thì dọn (cloud vẫn giữ doc — vô hại).
  static const Duration tombstoneRetention = Duration(days: 365);

  /// Quyết định "có áp bản cloud lên local không?".
  static bool shouldApplyRemote({
    required DateTime? localStamp,
    required bool localPending,
    required DateTime remoteStamp,
  }) {
    // Chưa có thay đổi cục bộ nào chờ đẩy → cloud thắng (kể cả bài seed mới
    // sinh với createdAt = hôm nay).
    if (!localPending) return true;
    // Không có mốc cục bộ để so → cloud thắng.
    if (localStamp == null) return true;
    // Cục bộ mới hơn bản cloud đang chờ đẩy → giữ cục bộ (đẩy lên sau).
    return !localStamp.isAfter(remoteStamp);
  }

  /// Hòa giải danh sách bài cục bộ với các doc cloud.
  static LearnByHeartMergeResult merge({
    required List<LearnByHeartItem> localItems,
    required List<LearnByHeartRemoteRecord> remoteRecords,
    Set<String> pendingIds = const <String>{},
    Map<String, DateTime> tombstones = const <String, DateTime>{},
    DateTime? now,
  }) {
    final byId = <String, LearnByHeartItem>{};
    final localOrder = <String>[];
    for (final item in localItems) {
      if (item.id.trim().isEmpty || byId.containsKey(item.id)) continue;
      byId[item.id] = item;
      localOrder.add(item.id);
    }

    final nextTombstones = pruneTombstones(tombstones, now: now);
    final nextPending = Set<String>.from(pendingIds);
    final freshIds = <String>[];
    var applied = 0;

    for (final record in remoteRecords) {
      final local = byId[record.id];
      final localPending = nextPending.contains(record.id);

      if (record.deleted) {
        final remoteStamp = record.deletedAt ?? record.updatedAt;
        if (!shouldApplyRemote(
          localStamp: local?.syncStamp,
          localPending: localPending,
          remoteStamp: remoteStamp,
        )) {
          continue; // local mới hơn → giữ bài, đẩy lại (đã pending)
        }
        final existing = nextTombstones[record.id];
        if (existing == null || existing.isBefore(remoteStamp)) {
          nextTombstones[record.id] = remoteStamp;
        }
        nextPending.remove(record.id);
        if (local != null) {
          byId.remove(record.id);
          localOrder.remove(record.id);
          applied++;
        }
        continue;
      }

      final item = record.item;
      if (item == null) continue;

      if (!shouldApplyRemote(
        localStamp: local?.syncStamp,
        localPending: localPending,
        remoteStamp: record.updatedAt,
      )) {
        continue;
      }

      // Đã từng đồng bộ đúng mốc này rồi → không ghi lại (tránh nhiễu/báo sai).
      final alreadyInSync = local != null &&
          !localPending &&
          local.updatedAt != null &&
          !local.updatedAt!.isBefore(record.updatedAt);
      nextTombstones.remove(item.id);
      if (alreadyInSync) continue;

      final isNew = local == null;
      byId[item.id] = item;
      if (isNew) {
        // Bài mới từ cloud lên đầu danh sách (giống saveItem chèn index 0).
        freshIds.insert(0, item.id);
      }
      nextPending.remove(item.id);
      applied++;
    }

    // Lắp danh sách cuối: bài mới từ cloud lên đầu, phần còn lại giữ thứ tự
    // cục bộ; chống trùng id (doc trùng trong 1 lần kéo) bằng [seen].
    final merged = <LearnByHeartItem>[];
    final seen = <String>{};
    for (final id in freshIds) {
      final item = byId[id];
      if (item == null || !seen.add(id)) continue;
      merged.add(item);
    }
    for (final id in localOrder) {
      final item = byId[id];
      if (item == null || !seen.add(id)) continue;
      merged.add(item);
    }

    return LearnByHeartMergeResult(
      items: merged,
      tombstones: nextTombstones,
      pendingIds: nextPending,
      appliedCount: applied,
    );
  }

  /// Dọn bia mộ cũ hơn [maxAge] (mặc định 1 năm).
  static Map<String, DateTime> pruneTombstones(
    Map<String, DateTime> tombstones, {
    DateTime? now,
    Duration maxAge = tombstoneRetention,
  }) {
    if (tombstones.isEmpty) return <String, DateTime>{};
    final reference = now ?? DateTime.now();
    final kept = <String, DateTime>{};
    tombstones.forEach((id, at) {
      if (reference.difference(at).abs() <= maxAge) kept[id] = at;
    });
    return kept;
  }
}
