// test/great_library/admin_moderation_test.dart
//
// GLIB-007 — test thuần: gate logic theo uid + state machine
// pending→published/rejected (reject bắt buộc lý do; hidden cần lý do).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/services/admin_gate.dart';
import 'package:in4up/features/great_library/services/admin_moderation_service.dart';

class _FakeGateFetcher implements AdminGateFetcher {
  _FakeGateFetcher(this.uids);

  final Set<String>? uids;
  int calls = 0;

  @override
  Future<Set<String>?> fetchAdminUids() async {
    calls++;
    return uids;
  }
}

class _FakeModerationTransport implements ModerationTransport {
  List<PendingContribution> queue = [];
  final List<String> publishedPacks = [];
  final Map<String, String> statusUpdates = {};
  final Map<String, String> notes = {};

  @override
  Future<List<PendingContribution>> fetchPending() async => queue;

  @override
  Future<void> updateStatus(String contributionId,
      {required String newStatus, String? reviewerNote}) async {
    statusUpdates[contributionId] = newStatus;
    if (reviewerNote != null) notes[contributionId] = reviewerNote;
  }

  @override
  Future<void> publishPack(PendingContribution contribution) async {
    publishedPacks.add(contribution.packId);
  }
}

PendingContribution _contrib(
        {String id = 'c1', String status = 'pending'}) =>
    PendingContribution(
      contributionId: id,
      packId: 'glu_pack_$id',
      title: 'Pack $id',
      authorUid: 'u-author',
      manifest: const {'type': 'vocab', 'entryCount': 5},
      storagePath: 'contributions/glu_pack_$id.i4upack',
      submittedAtMs: 1700000000000,
      status: status,
    );

void main() {
  group('AdminGate (gate theo uid)', () {
    test('uid nằm trong gl_config/admins → admin', () async {
      final gate = AdminGate(
          fetcher: _FakeGateFetcher({'owner-uid'}), currentUid: 'owner-uid');
      expect(await gate.isAdmin(), isTrue);
    });

    test('uid thường → KHÔNG admin (AT3: UI chặn)', () async {
      final gate = AdminGate(
          fetcher: _FakeGateFetcher({'owner-uid'}), currentUid: 'user-thuong');
      expect(await gate.isAdmin(), isFalse);
    });

    test('chưa đăng nhập (uid rỗng) → false, không gọi fetcher', () async {
      final fetcher = _FakeGateFetcher({'owner-uid'});
      final gate = AdminGate(fetcher: fetcher, currentUid: '');
      expect(await gate.isAdmin(), isFalse);
      expect(fetcher.calls, 0);
    });

    test('fetcher lỗi (null) → false an toàn (ẩn entry)', () async {
      final gate = AdminGate(
          fetcher: _FakeGateFetcher(null), currentUid: 'owner-uid');
      expect(await gate.isAdmin(), isFalse);
    });

    test('cache trong phiên: gọi 2 lần chỉ fetch 1 lần', () async {
      final fetcher = _FakeGateFetcher({'owner-uid'});
      final gate = AdminGate(fetcher: fetcher, currentUid: 'owner-uid');
      expect(await gate.isAdmin(), isTrue);
      expect(await gate.isAdmin(), isTrue);
      expect(fetcher.calls, 1);
    });
  });

  group('AdminModerationService (state machine)', () {
    test('approve: pending → published (ghi gl_packs + đổi status)', () async {
      final transport = _FakeModerationTransport();
      final svc = AdminModerationService(transport: transport);
      final c = _contrib();
      final result = await svc.approve(c);
      expect(result.ok, isTrue);
      expect(transport.publishedPacks, ['glu_pack_c1']);
      expect(transport.statusUpdates['c1'], 'published');
    });

    test('reject: pending → rejected, BẮT BUỘC lý do', () async {
      final transport = _FakeModerationTransport();
      final svc = AdminModerationService(transport: transport);
      final noReason = await svc.reject(_contrib(), reason: '  ');
      expect(noReason.ok, isFalse);
      expect(noReason.errorCode, 'reason-required');
      expect(transport.statusUpdates, isEmpty);

      final ok = await svc.reject(_contrib(), reason: 'Nội dung trùng lặp');
      expect(ok.ok, isTrue);
      expect(transport.statusUpdates['c1'], 'rejected');
      expect(transport.notes['c1'], 'Nội dung trùng lặp');
    });

    test('đã duyệt rồi → approve lại bị chặn (not-pending)', () async {
      final transport = _FakeModerationTransport();
      final svc = AdminModerationService(transport: transport);
      final result = await svc.approve(_contrib(status: 'published'));
      expect(result.ok, isFalse);
      expect(result.errorCode, 'not-pending');
      expect(transport.publishedPacks, isEmpty);
    });

    test('hide: cần lý do, status → hidden', () async {
      final transport = _FakeModerationTransport();
      final svc = AdminModerationService(transport: transport);
      final noReason = await svc.hide(_contrib(), reason: '');
      expect(noReason.ok, isFalse);

      final ok = await svc.hide(_contrib(status: 'published'),
          reason: 'Vi phạm bản quyền');
      expect(ok.ok, isTrue);
      expect(transport.statusUpdates['c1'], 'hidden');
    });

    test('loadQueue trả hàng chờ từ transport', () async {
      final transport = _FakeModerationTransport()
        ..queue = [_contrib(id: 'c1'), _contrib(id: 'c2')];
      final svc = AdminModerationService(transport: transport);
      expect((await svc.loadQueue()).length, 2);
    });
  });
}
