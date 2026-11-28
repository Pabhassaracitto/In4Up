// lib/features/great_library/services/contribution_store.dart
//
// GLIB-006 — đếm quota đóng góp client-side (10 pack/tháng — ideation §6.2)
// + danh sách "Đóng góp của tôi" (lưu local; trạng thái duyệt tra cứu trên
// Firestore `gl_contributions` khi có mạng).
//
// Pure logic + pluggable persistence → test thuần, không plugin.

/// Bản ghi 1 lần đóng góp (đã gửi lên `gl_contributions`).
class ContributionRecord {
  const ContributionRecord({
    required this.contributionId,
    required this.packId,
    required this.title,
    required this.submittedAtMs,
    this.status = 'pending',
    this.reviewerNote,
  });

  final String contributionId;
  final String packId;
  final String title;
  final int submittedAtMs;

  /// 'pending' | 'published' | 'rejected' — cập nhật khi tra cứu server.
  final String status;
  final String? reviewerNote;

  ContributionRecord copyWith({String? status, String? reviewerNote}) =>
      ContributionRecord(
        contributionId: contributionId,
        packId: packId,
        title: title,
        submittedAtMs: submittedAtMs,
        status: status ?? this.status,
        reviewerNote: reviewerNote ?? this.reviewerNote,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'contributionId': contributionId,
        'packId': packId,
        'title': title,
        'submittedAtMs': submittedAtMs,
        'status': status,
        if (reviewerNote != null) 'reviewerNote': reviewerNote,
      };

  factory ContributionRecord.fromJson(Map<String, dynamic> json) =>
      ContributionRecord(
        contributionId: (json['contributionId'] as String?) ?? '',
        packId: (json['packId'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        submittedAtMs: (json['submittedAtMs'] as num?)?.toInt() ?? 0,
        status: (json['status'] as String?) ?? 'pending',
        reviewerNote: json['reviewerNote'] as String?,
      );
}

abstract class ContributionStore {
  /// Số đóng góp đã gửi trong tháng dương lịch chứa [nowMs] (quota 10/tháng).
  int countInMonth(int nowMs);

  void add(ContributionRecord record);

  List<ContributionRecord> all();
}

/// In-memory (test / web stub).
class MemoryContributionStore implements ContributionStore {
  MemoryContributionStore([List<ContributionRecord>? seed])
      : _records = seed ?? <ContributionRecord>[];

  final List<ContributionRecord> _records;

  static const int maxPerMonth = 10;

  @override
  int countInMonth(int nowMs) {
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    var n = 0;
    for (final r in _records) {
      final t = DateTime.fromMillisecondsSinceEpoch(r.submittedAtMs);
      if (t.year == now.year && t.month == now.month) n++;
    }
    return n;
  }

  bool quotaExceeded(int nowMs) => countInMonth(nowMs) >= maxPerMonth;

  @override
  void add(ContributionRecord record) => _records.add(record);

  @override
  List<ContributionRecord> all() => List.unmodifiable(_records);
}
