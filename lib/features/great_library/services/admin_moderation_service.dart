// lib/features/great_library/services/admin_moderation_service.dart
//
// GLIB-007 — hàng chờ kiểm duyệt + state machine pending → published/rejected
// (PLAN-049 §GLIB-007). Transport pluggable (Firestore thật / fake test).

/// Một đóng góp trong hàng chờ (đọc từ `gl_contributions`).
class PendingContribution {
  const PendingContribution({
    required this.contributionId,
    required this.packId,
    required this.title,
    required this.authorUid,
    required this.manifest,
    required this.storagePath,
    required this.submittedAtMs,
    this.status = 'pending',
    this.reviewerNote,
  });

  final String contributionId;
  final String packId;
  final String title;
  final String authorUid;
  final Map<String, dynamic> manifest;
  final String storagePath;
  final int submittedAtMs;
  final String status;
  final String? reviewerNote;

  PendingContribution copyWith({String? status, String? reviewerNote}) =>
      PendingContribution(
        contributionId: contributionId,
        packId: packId,
        title: title,
        authorUid: authorUid,
        manifest: manifest,
        storagePath: storagePath,
        submittedAtMs: submittedAtMs,
        status: status ?? this.status,
        reviewerNote: reviewerNote ?? this.reviewerNote,
      );

  factory PendingContribution.fromDoc(
      String docId, Map<String, dynamic> fields) {
    final submitted = fields['submittedAt'];
    return PendingContribution(
      contributionId: docId,
      packId: (fields['packId'] as String?) ?? '',
      title: (fields['manifest'] is Map)
          ? ((fields['manifest'] as Map)['title'] as String? ?? '')
          : '',
      authorUid: (fields['authorUid'] as String?) ?? '',
      manifest: (fields['manifest'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      storagePath: (fields['storage'] is Map)
          ? ((fields['storage'] as Map)['path'] as String? ?? '')
          : '',
      submittedAtMs: submitted is DateTime
          ? submitted.millisecondsSinceEpoch
          : (submitted is num ? submitted.toInt() : 0),
      status: (fields['status'] as String?) ?? 'pending',
      reviewerNote: fields['reviewerNote'] as String?,
    );
  }
}

/// Kết quả 1 hành động moderation.
class ModerationResult {
  const ModerationResult({required this.ok, this.errorCode});

  final bool ok;
  final String? errorCode;
}

/// Cổng server (Firestore transport hoặc fake test).
abstract class ModerationTransport {
  /// Danh sách đóng góp pending (mới nhất trước).
  Future<List<PendingContribution>> fetchPending();

  /// Cập nhật status + reviewerNote trên doc gl_contributions/<id>.
  /// [newStatus]: 'published' | 'rejected' | 'hidden'.
  Future<void> updateStatus(
    String contributionId, {
    required String newStatus,
    String? reviewerNote,
  });

  /// Duyệt: ghi doc `gl_packs/<packId>` (status published) từ manifest của
  /// contribution. Rules: chỉ admin ghi gl_packs.
  Future<void> publishPack(PendingContribution contribution);
}

/// Service state machine moderation (thuần — test được).
class AdminModerationService {
  AdminModerationService({required ModerationTransport transport})
      : _transport = transport;

  final ModerationTransport _transport;

  Future<List<PendingContribution>> loadQueue() => _transport.fetchPending();

  /// pending → published: ghi gl_packs + đổi status contribution.
  Future<ModerationResult> approve(PendingContribution c) async {
    if (c.status != 'pending') {
      return const ModerationResult(ok: false, errorCode: 'not-pending');
    }
    try {
      await _transport.publishPack(c);
      await _transport.updateStatus(c.contributionId, newStatus: 'published');
      return const ModerationResult(ok: true);
    } on Object catch (e) {
      return ModerationResult(ok: false, errorCode: '$e');
    }
  }

  /// pending → rejected: BẮT BUỘC lý do (reviewerNote) để user hiểu.
  Future<ModerationResult> reject(PendingContribution c,
      {required String reason}) async {
    if (c.status != 'pending') {
      return const ModerationResult(ok: false, errorCode: 'not-pending');
    }
    if (reason.trim().isEmpty) {
      return const ModerationResult(ok: false, errorCode: 'reason-required');
    }
    try {
      await _transport.updateStatus(c.contributionId,
          newStatus: 'rejected', reviewerNote: reason.trim());
      return const ModerationResult(ok: true);
    } on Object catch (e) {
      return ModerationResult(ok: false, errorCode: '$e');
    }
  }

  /// published/pending → hidden (gỡ nội dung vi phạm).
  Future<ModerationResult> hide(PendingContribution c,
      {required String reason}) async {
    if (reason.trim().isEmpty) {
      return const ModerationResult(ok: false, errorCode: 'reason-required');
    }
    try {
      await _transport.updateStatus(c.contributionId,
          newStatus: 'hidden', reviewerNote: reason.trim());
      return const ModerationResult(ok: true);
    } on Object catch (e) {
      return ModerationResult(ok: false, errorCode: '$e');
    }
  }
}
