// test/great_library/contribution_service_test.dart
//
// GLIB-006 — PackContributionService thuần: build pack từ vocab giả, quota
// counter (10/tháng), upload + submit end-to-end với fake backend/transport,
// và ContributionAiSuggest: AI tắt → KHÔNG gọi network (pin bằng fake).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/contribution_ai_suggest.dart';
import 'package:in4up/features/great_library/services/contribution_store.dart';
import 'package:in4up/features/great_library/services/pack_contribution_service.dart';
import 'package:in4up/features/great_library/services/pack_content.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';
import 'package:in4up/features/great_library/services/pack_storage_backend.dart';
import 'package:in4up/features/translation/engines/llm_mt_engine.dart';

class _FakeStorageBackend implements PackStorageBackend {
  int uploads = 0;
  bool failUpload = false;

  @override
  String get backendId => 'firebase';

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) =>
      throw UnimplementedError();

  @override
  Future<int> contentLength(PackStorageRef ref) => throw UnimplementedError();

  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
      {void Function(int, int)? onProgress}) async {
    if (failUpload) throw StateError('no-permission');
    uploads++;
  }

  @override
  Uri publicUrl(PackStorageRef ref) => Uri.parse('https://x/${ref.path}');
}

class _FakeTransport implements ContributionTransport {
  int submissions = 0;
  bool failSubmit = false;

  @override
  Future<String> submitContribution({
    required String packId,
    required Map<String, dynamic> manifestJson,
    required String storageBackend,
    required String storagePath,
    required int zipBytes,
    required String sha256,
  }) async {
    if (failSubmit) throw StateError('rules-denied');
    submissions++;
    return 'contrib_$packId';
  }
}

ContributionMetadata _meta({String title = 'Pack của tôi'}) =>
    ContributionMetadata(
      title: title,
      description: 'Mô tả thử',
      tags: const ['verbs'],
      level: 'A2',
      license: PackLicense.selfMade,
    );

const _items = [
  ContributionVocabInput(word: 'apple', meaning: 'quả táo'),
  ContributionVocabInput(word: 'run', meaning: 'chạy'),
  ContributionVocabInput(word: '', meaning: 'bỏ qua vì word rỗng'),
];

PackContributionService _service({
  ContributionStore? store,
  _FakeStorageBackend? storage,
  _FakeTransport? transport,
  DateTime? now,
}) =>
    PackContributionService(
      store: store ?? MemoryContributionStore(),
      storage: storage ?? _FakeStorageBackend(),
      transport: transport ?? _FakeTransport(),
      authorUid: 'u-test',
      authorName: 'Tester',
      clock: now != null ? () => now : null,
    );

void main() {
  group('buildVocabPack', () {
    test('build pack từ vocab giả → manifest đúng + parse lại được', () {
      final svc = _service(now: DateTime(2026, 11, 23, 10));
      final pack = svc.buildVocabPack(
        packId: PackContributionService.newPackId(
            'Pack của tôi', DateTime(2026, 11, 23, 10)),
        meta: _meta(),
        items: _items,
      );
      expect(pack.manifest.type, PackType.vocab);
      expect(pack.manifest.status, PackStatus.pending); // D4 pending-first
      expect(pack.manifest.entryCount, 2); // item rỗng bị lọc
      expect(pack.manifest.author.uid, 'u-test');
      expect(pack.manifest.storage!.path,
          contains('contributions/glu_'));

      // Round-trip: giải nén + parse khớp GLIB-005.
      final plan = PackContent.parse(PackFile.extract(pack.bytes));
      expect(plan, isA<VocabPackPlan>());
      expect((plan as VocabPackPlan).items.length, 2);
    });

    test('id pack: glu_<slug>_<rand> — slug hoá tiếng Việt', () {
      final id =
          PackContributionService.newPackId('Động từ hay gặp', DateTime(2026));
      expect(id, startsWith('glu_'));
      expect(id.length, lessThanOrEqualTo(4 + 32 + 1 + 6));
    });

    test('không còn item hợp lệ → ContributionException(no-valid-items)', () {
      final svc = _service();
      expect(
        () => svc.buildVocabPack(
          packId: 'glu_x_000000',
          meta: _meta(),
          items: const [ContributionVocabInput(word: '', meaning: 'x')],
        ),
        throwsA(isA<ContributionException>()
            .having((e) => e.code, 'code', 'no-valid-items')),
      );
    });

    test('quota 10/tháng: vượt → quota-exceeded, chưa vượt → OK', () {
      final now = DateTime(2026, 11, 23);
      final store = MemoryContributionStore([
        for (var i = 0; i < 10; i++)
          ContributionRecord(
            contributionId: 'c$i',
            packId: 'p$i',
            title: 't$i',
            submittedAtMs: DateTime(2026, 11, 1 + (i % 20))
                .millisecondsSinceEpoch,
          ),
      ]);
      final svc = _service(store: store, now: now);
      expect(svc.quotaUsedThisMonth(), 10);
      expect(svc.quotaExceeded, isTrue);
      expect(
        () => svc.buildVocabPack(
            packId: 'glu_x_000000', meta: _meta(), items: _items),
        throwsA(isA<ContributionException>()
            .having((e) => e.code, 'code', 'quota-exceeded')),
      );

      // Tháng khác → quota reset.
      final svc2 = _service(store: store, now: DateTime(2026, 12, 1));
      expect(svc2.quotaExceeded, isFalse);
    });
  });

  group('submit', () {
    test('upload + ghi gl_contributions + lưu record local', () async {
      final store = MemoryContributionStore();
      final storage = _FakeStorageBackend();
      final transport = _FakeTransport();
      final svc = _service(
          store: store, storage: storage, transport: transport,
          now: DateTime(2026, 11, 23));
      final result = await svc.buildAndSubmitVocab(meta: _meta(), items: _items);
      expect(result.status, ContributionStatus.submitted);
      expect(result.contributionId, startsWith('contrib_glu_'));
      expect(storage.uploads, 1);
      expect(transport.submissions, 1);
      expect(store.all().single.status, 'pending');
    });

    test('upload lỗi → failed, KHÔNG ghi transport/store', () async {
      final store = MemoryContributionStore();
      final storage = _FakeStorageBackend()..failUpload = true;
      final transport = _FakeTransport();
      final svc = _service(
          store: store, storage: storage, transport: transport);
      final result =
          await svc.buildAndSubmitVocab(meta: _meta(), items: _items);
      expect(result.status, ContributionStatus.failed);
      expect(result.errorCode, contains('upload-failed'));
      expect(transport.submissions, 0);
      expect(store.all(), isEmpty);
    });

    test('submit lỗi (rules chặn) → failed, record không lưu', () async {
      final store = MemoryContributionStore();
      final transport = _FakeTransport()..failSubmit = true;
      final svc = _service(transport: transport, store: store);
      final result =
          await svc.buildAndSubmitVocab(meta: _meta(), items: _items);
      expect(result.status, ContributionStatus.failed);
      expect(result.errorCode, contains('submit-failed'));
      expect(store.all(), isEmpty);
    });
  });

  group('ContributionAiSuggest (BYOK opt-in)', () {
    test('providerResolver null (AI tắt) → null, KHÔNG gọi backend', () async {
      var backendCalls = 0;
      final ai = ContributionAiSuggest(
        providerResolver: null, // chưa cấu hình BYOK
        backend: _RecordingBackend(onChat: () => backendCalls++),
      );
      final suggestion =
          await ai.suggest(type: PackType.vocab, sampleWords: const ['apple']);
      expect(suggestion, isNull);
      expect(backendCalls, 0); // pin: AI tắt → 0 network
    });

    test('resolver trả null → null, không gọi backend', () async {
      var backendCalls = 0;
      final ai = ContributionAiSuggest(
        providerResolver: () async => null,
        backend: _RecordingBackend(onChat: () => backendCalls++),
      );
      expect(await ai.suggest(type: PackType.vocab, sampleWords: const []),
          isNull);
      expect(backendCalls, 0);
    });

    test('provider OK → gọi backend 1 lần, parse JSON gợi ý', () async {
      var backendCalls = 0;
      final ai = ContributionAiSuggest(
        providerResolver: () async => const AiProviderConfig(
          id: 'p1',
          label: 'Test',
          baseUrl: 'https://api.example.com',
          apiKey: 'k',
          chatModel: 'm',
        ),
        backend: _RecordingBackend(onChat: () => backendCalls++),
      );
      final s = await ai.suggest(
          type: PackType.vocab, sampleWords: const ['apple', 'run']);
      expect(backendCalls, 1);
      expect(s, isNotNull);
      expect(s!.title, 'Pack từ vựng của tôi');
      expect(s.level, 'A2');
      expect(s.tags, contains('verbs'));
    });

    test('backend ném lỗi → null (UI giữ form)', () async {
      final ai = ContributionAiSuggest(
        providerResolver: () async => const AiProviderConfig(
          id: 'p1',
          label: 'Test',
          baseUrl: 'https://api.example.com',
          apiKey: 'k',
          chatModel: 'm',
        ),
        backend: _ThrowingBackend(),
      );
      expect(await ai.suggest(type: PackType.vocab, sampleWords: const ['x']),
          isNull);
    });
  });
}

class _RecordingBackend implements LlmMtBackend {
  _RecordingBackend({required this.onChat});

  final void Function() onChat;

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required Duration timeout,
  }) async {
    onChat();
    return jsonEncode({
      'title': 'Pack từ vựng của tôi',
      'description': 'Bộ từ vựng tự soạn',
      'tags': ['verbs', 'custom'],
      'level': 'A2',
    });
  }
}

class _ThrowingBackend implements LlmMtBackend {
  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required Duration timeout,
  }) =>
      throw StateError('network down');
}
