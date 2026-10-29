/// ═══════════════════════════════════════════════════════════════
/// REVIEW EVENT STORE — lưu trữ append-only (mục 2.4 + mục 3 bàn giao)
///
///  * Append-only: KHÔNG có API sửa/xóa event thường — chỉ
///    `append` và `retire` (nén vào baseline bởi compaction).
///  * Lazy theo unit: truy vấn THEO UNIT, không bao giờ load cả box —
///    "Cấm load toàn bộ ReviewEvent box vào RAM lúc khởi động" (mục 3).
///  * Impl vật lý (Hive LazyBox chia tháng / SQLite) gắn sau qua interface
///    này; InMemory impl phục vụ test + chứng minh RAM-bounded per-unit.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/review_event.dart';

abstract class ReviewEventStore {
  /// Thêm event MỚI. Trùng `eventId` ⇒ StateError (append-only nghiêm ngặt).
  Future<void> append(ReviewEvent event);

  /// Event ĐANG HOẠT ĐỘNG của 1 unit (chưa bị nén), lazy theo dòng,
  /// sắp theo timestamp. KHÔNG dùng để load nhiều unit cùng lúc.
  Stream<ReviewEvent> activeEventsOfUnit(String unitId);

  /// Số event active của unit (bounded bởi ngưỡng compaction + ε).
  Future<int> activeCountOfUnit(String unitId);

  /// Compaction "nghỉ hưu" các event đã nằm trong baseline — thông tin
  /// của chúng BẢO TOÀN trong CompactionRecord.baseline; ID được ghi lại
  /// trong record để truy vết (không mất dấu vết một cách âm thầm).
  Future<void> retire(Set<String> eventIds);
}

/// Impl in-memory cho test + mô phỏng hành vi RAM-bounded:
/// active per-unit nhỏ (bị chặn bởi compaction), tổng lịch sử append
/// được đếm vĩnh viễn.
class InMemoryReviewEventStore implements ReviewEventStore {
  final Map<String, List<ReviewEvent>> _active = <String, List<ReviewEvent>>{};
  final Set<String> _everAppendedIds = <String>{};
  final Set<String> _retiredIds = <String>{};

  InMemoryReviewEventStore();

  @override
  Future<void> append(ReviewEvent event) async {
    if (!_everAppendedIds.add(event.eventId)) {
      throw StateError(
          'ReviewEvent append-only: eventId trùng (${event.eventId})');
    }
    _active.putIfAbsent(event.unitId, () => <ReviewEvent>[]).add(event);
  }

  @override
  Stream<ReviewEvent> activeEventsOfUnit(String unitId) async* {
    final list = _active[unitId] ?? const <ReviewEvent>[];
    final active =
        list.where((e) => !_retiredIds.contains(e.eventId)).toList()
          ..sort((a, b) {
            final byTime = a.timestamp.compareTo(b.timestamp);
            if (byTime != 0) return byTime;
            return a.eventId.compareTo(b.eventId);
          });
    yield* Stream.fromIterable(active);
  }

  @override
  Future<int> activeCountOfUnit(String unitId) async {
    final list = _active[unitId] ?? const <ReviewEvent>[];
    return list.where((e) => !_retiredIds.contains(e.eventId)).length;
  }

  @override
  Future<void> retire(Set<String> eventIds) async {
    _retiredIds.addAll(eventIds);
  }

  /// Tổng số event từng được append (kể cả đã nén) — cho kiểm kê/audit.
  int get totalAppended => _everAppendedIds.length;

  /// Số event đã được nén vào baseline.
  int get totalRetired => _retiredIds.length;
}
