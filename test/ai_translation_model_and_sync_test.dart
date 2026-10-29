// test/ai_translation_model_and_sync_test.dart — API-TRANS-MODEL-001,
// MODEL-PICKER-001, API-SYNC-001, API-DIAG-001 (owner 2026-10-26).
//
// Chủ yếu là LOGIC THUẦN (không mạng, không plugin):
//   1. Model dịch RIÊNG: `translationModel` + `effectiveTranslationModel` +
//      `modelFor(translation)` và store có resolve được provider theo nó.
//   2. Đồng bộ Firebase: `AiSettingsSnapshot` round-trip, `mergeAiSettings`
//      newest-wins theo từng provider + bia mộ (không "sống lại" provider đã
//      xoá) + routing lấy từ bên mới hơn.
//   3. "AI đang chạy": `buildAiRoutingReport` theo từng loại mạng (wifi/4g/
//      không mạng) — API hay trên máy, provider + model nào.
//   4. "Chạy thử THẬT": `probeAiCapability` với transport giả — phân biệt
//      ok / lỗi có mã / bỏ qua; STT chỉ xác nhận model có trong /v1/models và
//      KHÔNG được báo là đã bóc băng file thật.
//
// Test 3/4 dùng `AiProviderStore.instance` + SharedPreferences mock (cùng
// pattern test/ai_wp1_remote_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

AiProviderConfig _provider({
  String id = 'p1',
  String? chatModel = 'chat-model',
  String? translationModel,
  String? sttModel,
  String? ttsModel,
  bool enabled = true,
}) =>
    AiProviderConfig(
      id: id,
      label: 'Test $id',
      baseUrl: 'https://api.example.com/v1',
      chatModel: chatModel,
      translationModel: translationModel,
      sttModel: sttModel,
      ttsModel: ttsModel,
      enabled: enabled,
    );

/// Transport giả: ghi lại request, trả kết quả định trước.
class _FakeTransport implements AiProbeTransport {
  _FakeTransport({
    this.chatReply = 'OK',
    this.chatError,
    this.models = const ['whisper-1', 'tts-1'],
    this.modelsError,
    this.speechBytes = 1234,
  });

  final String chatReply;
  final Object? chatError;
  final List<String> models;
  final Object? modelsError;
  final int speechBytes;

  final List<String> chatModelsUsed = [];
  int chatCalls = 0;
  int speechCalls = 0;
  int modelListCalls = 0;

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String prompt,
    required Duration timeout,
  }) async {
    chatCalls++;
    chatModelsUsed.add(model);
    if (chatError != null) throw chatError!;
    return chatReply;
  }

  @override
  Future<List<String>> listModels({
    required AiProviderConfig provider,
    required Duration timeout,
  }) async {
    modelListCalls++;
    if (modelsError != null) throw modelsError!;
    return models;
  }

  @override
  Future<int> speech({
    required AiProviderConfig provider,
    required String model,
    required String input,
    required Duration timeout,
  }) async {
    speechCalls++;
    return speechBytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('API-TRANS-MODEL-001 — model dịch riêng', () {
    test('chưa chọn translationModel ⇒ dịch dùng chatModel (tương thích cũ)',
        () {
      final p = _provider(chatModel: 'qwen-7b');
      expect(p.translationModel, isNull);
      expect(p.effectiveTranslationModel, 'qwen-7b');
      expect(p.modelFor(AiRouteCapability.translation), 'qwen-7b');
    });

    test('chọn translationModel ⇒ dịch dùng model RIÊNG, chat không đổi', () {
      final p = _provider(chatModel: 'qwen-7b', translationModel: 'hymt-1.8b');
      expect(p.effectiveTranslationModel, 'hymt-1.8b');
      expect(p.modelFor(AiRouteCapability.translation), 'hymt-1.8b');
      expect(p.modelFor(AiRouteCapability.chat), 'qwen-7b');
    });

    test('provider CHỈ có model dịch ⇒ phục vụ dịch, không phục vụ chat', () {
      final p = _provider(chatModel: null, translationModel: 'hymt-1.8b');
      expect(p.supports(AiRouteCapability.translation), isTrue);
      expect(p.supports(AiRouteCapability.chat), isFalse);
      expect(p.modelFor(AiRouteCapability.chat), isNull);
    });

    test('chuỗi rỗng coi như chưa chọn (không gửi model "" lên API)', () {
      final p = _provider(chatModel: '', translationModel: '');
      expect(p.effectiveTranslationModel, isNull);
      expect(p.supports(AiRouteCapability.translation), isFalse);
    });

    test('JSON round-trip giữ translationModel (và bản cũ không có key)', () {
      final p = _provider(chatModel: 'a', translationModel: 'b');
      final back = AiProviderConfig.fromJson(p.toJson());
      expect(back.translationModel, 'b');

      final legacy = Map<String, dynamic>.from(p.toJson())
        ..remove('translationModel');
      final old = AiProviderConfig.fromJson(legacy);
      expect(old.translationModel, isNull);
      expect(old.effectiveTranslationModel, 'a');
    });

    test('copyWith(clearTranslationModel) xoá về fallback chat', () {
      final p = _provider(chatModel: 'a', translationModel: 'b');
      final cleared = p.copyWith(clearTranslationModel: true);
      expect(cleared.translationModel, isNull);
      expect(cleared.effectiveTranslationModel, 'a');
    });
  });

  group('API-SYNC-001 — hòa giải cấu hình cloud', () {
    test('snapshot JSON round-trip giữ provider + routing + bia mộ', () {
      final snap = AiSettingsSnapshot(
        providers: [_provider(translationModel: 'hymt')],
        routing: const AiRoutingPrefs(
          modes: {AiRouteCapability.translation: AiRouteMode.onlineFirst},
          preferredProviderIds: {AiRouteCapability.translation: 'p1'},
        ),
        tombstones: {'gone': 111},
        updatedAtMs: 500,
      );
      final back = AiSettingsSnapshot.fromJson(snap.toJson());
      expect(back.providers.single.translationModel, 'hymt');
      expect(back.routing.modeOf(AiRouteCapability.translation),
          AiRouteMode.onlineFirst);
      expect(back.routing.preferredProviderOf(AiRouteCapability.translation),
          'p1');
      expect(back.tombstones['gone'], 111);
      expect(back.updatedAtMs, 500);
    });

    test('provider hỏng trong payload KHÔNG kéo cả bản sync xuống', () {
      final json = <String, dynamic>{
        'providers': [
          {'id': 'ok', 'label': 'OK', 'baseUrl': 'https://a/v1'},
          {'label': 'thiếu id'},
        ],
        'routing': 'không phải map',
        'tombstones': {'x': 'not-int'},
        'updatedAtMs': 'oops',
      };
      final snap = AiSettingsSnapshot.fromJson(json);
      expect(snap.providers.map((p) => p.id), ['ok']);
      expect(snap.tombstones, isEmpty);
      expect(snap.updatedAtMs, 0);
    });

    test('2 máy thêm provider KHÁC nhau ⇒ giữ cả hai (không cả gói thắng)', () {
      // Local là bên MỚI hơn (vừa thêm "laptop"), remote cũ hơn có "phone".
      // Remote không có "laptop" chỉ vì nó chụp ảnh TRƯỚC khi laptop được
      // thêm ⇒ KHÔNG được coi là đã xoá ⇒ phải giữ cả hai.
      final local = AiSettingsSnapshot(
        providers: [_provider(id: 'laptop', chatModel: 'm1')],
        updatedAtMs: 2000,
      );
      final remote = AiSettingsSnapshot(
        providers: [_provider(id: 'phone', chatModel: 'm2')],
        updatedAtMs: 1000,
      );
      final merged = mergeAiSettings(
        local: local,
        remote: remote,
      );
      final ids = merged.merged.providers.map((p) => p.id).toSet();
      expect(ids, {'laptop', 'phone'});
      expect(merged.changedLocally,
          isTrue,
          reason: 'provider của máy kia phải vào được máy này');
    });

    test('cùng id, remote mới hơn ⇒ remote thắng (model dịch mới)', () {
      final local = AiSettingsSnapshot(
        providers: [_provider(id: 'p1', translationModel: 'old')],
        updatedAtMs: 100,
      );
      final remote = AiSettingsSnapshot(
        providers: [_provider(id: 'p1', translationModel: 'new')],
        updatedAtMs: 900,
      );
      final merged = mergeAiSettings(
        local: local,
        remote: remote,
      );
      expect(merged.merged.providers.single.translationModel, 'new');
    });

    test('bia mộ chặn provider đã xoá "sống lại" từ máy khác', () {
      // Máy A xoá p1 (bia mộ). Máy B vẫn còn p1 và push sau đó.
      final local = AiSettingsSnapshot(
        providers: const [],
        tombstones: {'p1': 500},
        updatedAtMs: 500,
      );
      final remote = AiSettingsSnapshot(
        providers: [_provider(id: 'p1', chatModel: 'm')],
        updatedAtMs: 400,
      );
      final merged = mergeAiSettings(
        local: local,
        remote: remote,
      );
      expect(merged.merged.providers, isEmpty,
          reason: 'provider đã xoá không được hồi sinh');
    });

    test('bia mộ cũ hơn provider mới thêm ⇒ provider được nhận', () {
      final local = AiSettingsSnapshot(
        providers: const [],
        tombstones: {'p1': 100},
        updatedAtMs: 100,
      );
      final remote = AiSettingsSnapshot(
        providers: [_provider(id: 'p1')],
        updatedAtMs: 900,
      );
      final merged = mergeAiSettings(
        local: local,
        remote: remote,
      );
      expect(merged.merged.providers.single.id, 'p1');
    });

    test('routing lấy từ bên MỚI hơn (đổi mode dịch ở máy kia)', () {
      final local = AiSettingsSnapshot(
        routing: const AiRoutingPrefs(
          modes: {AiRouteCapability.translation: AiRouteMode.offlineOnly},
        ),
        updatedAtMs: 10,
      );
      final remote = AiSettingsSnapshot(
        routing: const AiRoutingPrefs(
          modes: {AiRouteCapability.translation: AiRouteMode.onlineFirst},
        ),
        updatedAtMs: 20,
      );
      final merged = mergeAiSettings(
        local: local,
        remote: remote,
      );
      expect(merged.merged.routing.modeOf(AiRouteCapability.translation),
          AiRouteMode.onlineFirst);
      expect(merged.changedLocally, isTrue);
    });

    test('máy MỚI cài (mốc 0, provider seed chưa key) KHÔNG ghi đè key trên cloud',
        () {
      // Đây là kịch bản owner mô tả: cài app mới → đăng nhập → phải có sẵn key.
      // Provider seed có sẵn (cùng id) nhưng CHƯA có key, mốc document = 0.
      final fresh = AiSettingsSnapshot(
        providers: [
          const AiProviderConfig(
            id: kBuiltinOpenRouterId,
            label: 'OpenRouter',
            baseUrl: 'https://openrouter.ai/api/v1',
          ),
        ],
        updatedAtMs: 0,
      );
      final cloud = AiSettingsSnapshot(
        providers: [
          const AiProviderConfig(
            id: kBuiltinOpenRouterId,
            label: 'OpenRouter',
            baseUrl: 'https://openrouter.ai/api/v1',
            apiKey: 'sk-or-v1-that-key',
            chatModel: 'meta/llama-3.1-8b',
          ),
        ],
        updatedAtMs: 900,
      );
      final merged = mergeAiSettings(local: fresh, remote: cloud);
      expect(merged.merged.providers.single.apiKey, 'sk-or-v1-that-key',
          reason: 'key trên cloud phải thắng bản seed rỗng');
      expect(merged.merged.providers.single.chatModel, 'meta/llama-3.1-8b');
      expect(merged.changedLocally, isTrue,
          reason: 'máy mới phải ghi lại cấu hình vừa nhận');
    });

    test('provider CHỈ có ở máy mới (seed) vẫn được giữ, không bị "đã xoá"',
        () {
      final local = AiSettingsSnapshot(
        providers: [
          const AiProviderConfig(
            id: 'seed-only',
            label: 'Seed only',
            baseUrl: 'https://seed/v1',
          ),
        ],
        updatedAtMs: 0,
      );
      final remote = AiSettingsSnapshot(
        providers: [_provider(id: 'user-made', chatModel: 'm')],
        updatedAtMs: 5000,
      );
      final merged = mergeAiSettings(local: local, remote: remote);
      final ids = merged.merged.providers.map((p) => p.id).toSet();
      expect(ids, {'seed-only', 'user-made'});
    });

    test('bia mộ được dọn khi cả 2 phía đều mới hơn mốc xoá', () {
      final local = AiSettingsSnapshot(
        providers: const [],
        tombstones: {'dead': 100},
        updatedAtMs: 500,
      );
      final remote = AiSettingsSnapshot(
        providers: const [],
        tombstones: {'dead': 100},
        updatedAtMs: 600,
      );
      final merged = mergeAiSettings(local: local, remote: remote);
      expect(merged.merged.tombstones, isEmpty,
          reason: 'bia mộ cũ không được phình vô hạn');
    });

    test('2 bên giống hệt ⇒ không báo thay đổi (không push vô ích)', () {
      final a = AiSettingsSnapshot(
        providers: [_provider()],
        updatedAtMs: 7,
      );
      final merged = mergeAiSettings(
        local: a,
        remote: AiSettingsSnapshot.fromJson(a.toJson()),
      );
      expect(merged.changedLocally, isFalse);
      expect(merged.changedRemotely, isFalse);
    });
  });

  group('API-DIAG-001 — "AI đang chạy hiện tại" theo loại mạng', () {
    // Store là singleton trong cả file: reset BẰNG applySnapshot (không phụ
    // thuộc việc `ensureLoaded` có nạp lại SharedPreferences hay không) để
    // mỗi test bắt đầu từ đúng 1 provider p1.
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        // Chặn seed provider có sẵn (OpenRouter) để test tất định.
        'ai_builtin_providers_seeded_v1': true,
      });
      final store = AiProviderStore.instance;
      await store.ensureLoaded();
      await store.applySnapshot(
        AiSettingsSnapshot(
          providers: [
            _provider(
              id: 'p1',
              chatModel: 'chat-1',
              translationModel: 'trans-1',
              sttModel: 'stt-1',
              ttsModel: 'tts-1',
            ),
          ],
          updatedAtMs: 1,
        ),
        touch: true,
      );
      await store.updateRouting(const AiRoutingPrefs());
    });

    test('auto + wifi ⇒ cả 4 năng lực đi API, model đúng từng năng lực', () {
      final reports = buildAiRoutingReport(
        store: AiProviderStore.instance,
        network: AiNetworkKind.wifi,
      );
      expect(reports, hasLength(4));
      for (final r in reports) {
        expect(r.usesApi, isTrue, reason: '${r.capability} phải đi API');
        expect(r.provider!.id, 'p1');
        expect(r.warning, AiRouteWarning.none);
      }
      final byCap = {for (final r in reports) r.capability: r};
      expect(byCap[AiRouteCapability.chat]!.model, 'chat-1');
      expect(byCap[AiRouteCapability.translation]!.model, 'trans-1');
      expect(byCap[AiRouteCapability.sttFile]!.model, 'stt-1');
      expect(byCap[AiRouteCapability.tts]!.model, 'tts-1');
      expect(byCap[AiRouteCapability.translation]!.translationFallsBackToChatModel,
          isFalse);
    });

    test('auto + KHÔNG mạng ⇒ không năng lực nào đi API', () {
      final reports = buildAiRoutingReport(
        store: AiProviderStore.instance,
        network: AiNetworkKind.none,
      );
      for (final r in reports) {
        expect(r.usesApi, isFalse);
        expect(r.effectiveMode, AiRouteMode.offlineOnly);
      }
    });

    test('auto + 4G ⇒ ưu tiên trên máy nhưng vẫn có provider dự phòng', () {
      final reports = buildAiRoutingReport(
        store: AiProviderStore.instance,
        network: AiNetworkKind.mobile,
      );
      for (final r in reports) {
        expect(r.effectiveMode, AiRouteMode.offlineFirst);
        expect(r.usesApi, isTrue, reason: 'offlineFirst vẫn có API dự phòng');
      }
    });

    test('offlineOnly ⇒ provider null + cảnh báo không (chủ ý của user)', () async {
      await AiProviderStore.instance.updateRouting(const AiRoutingPrefs(
        modes: {AiRouteCapability.translation: AiRouteMode.offlineOnly},
      ));
      final r = buildAiRoutingReport(
        store: AiProviderStore.instance,
        network: AiNetworkKind.wifi,
        only: [AiRouteCapability.translation],
      ).single;
      expect(r.usesApi, isFalse);
      expect(r.provider, isNull);
      expect(r.warning, AiRouteWarning.none);
    });

    test('provider chưa có model cho năng lực ⇒ cảnh báo noProvider', () async {
      // Chỉ còn provider "chat-only": có chatModel nhưng KHÔNG có ttsModel.
      await AiProviderStore.instance.applySnapshot(
        AiSettingsSnapshot(
          providers: [_provider(id: 'chat-only', chatModel: 'c')],
          updatedAtMs: 2,
        ),
        touch: true,
      );
      // Model dịch fallback chatModel ⇒ vẫn phục vụ dịch được; TTS thì không.
      final tts = buildAiRoutingReport(
        store: AiProviderStore.instance,
        network: AiNetworkKind.wifi,
        only: [AiRouteCapability.tts],
      ).single;
      expect(tts.usesApi, isFalse);
      expect(tts.provider, isNull);
      expect(tts.warning, AiRouteWarning.noProviderForCapability);
    });
  });

  group('API-DIAG-001 — chạy thử THẬT (transport giả)', () {
    test('chat OK ⇒ ok + trả sample + có độ trễ', () async {
      final t = _FakeTransport(chatReply: 'Xin chào');
      final r = await probeAiCapability(
        capability: AiRouteCapability.chat,
        provider: _provider(chatModel: 'chat-1'),
        transport: t,
      );
      expect(r.status, AiProbeStatus.ok);
      expect(r.model, 'chat-1');
      expect(r.sample, 'Xin chào');
      expect(t.chatModelsUsed, ['chat-1']);
    });

    test('dịch gọi ĐÚNG model dịch (không dùng chat model)', () async {
      final t = _FakeTransport(chatReply: 'Chào buổi sáng');
      final r = await probeAiCapability(
        capability: AiRouteCapability.translation,
        provider: _provider(chatModel: 'chat-1', translationModel: 'trans-1'),
        transport: t,
      );
      expect(r.status, AiProbeStatus.ok);
      expect(r.model, 'trans-1');
      expect(t.chatModelsUsed, ['trans-1'],
          reason: 'API-DIAG-001: phải thử đúng model dịch');
    });

    test('lỗi API ⇒ failed + GIỮ mã lỗi cấu trúc (không match chuỗi)', () async {
      final t = _FakeTransport(
        chatError: const AiApiException(
            AiApiErrorCode.unauthorized, 'bad key', statusCode: 401),
      );
      final r = await probeAiCapability(
        capability: AiRouteCapability.chat,
        provider: _provider(chatModel: 'chat-1'),
        transport: t,
      );
      expect(r.status, AiProbeStatus.failed);
      expect(r.errorCode, AiApiErrorCode.unauthorized);
      expect(r.ok, isFalse);
    });

    test('provider null ⇒ skipped (không tự đi tìm provider)', () async {
      final t = _FakeTransport();
      final r = await probeAiCapability(
        capability: AiRouteCapability.chat,
        provider: null,
        transport: t,
      );
      expect(r.status, AiProbeStatus.skipped);
      expect(r.skipReason, AiProbeSkipReason.noProvider);
      expect(t.chatCalls, 0);
    });

    test('provider thiếu model ⇒ skipped noModel, KHÔNG gửi request', () async {
      final t = _FakeTransport();
      final r = await probeAiCapability(
        capability: AiRouteCapability.tts,
        provider: _provider(chatModel: 'c', ttsModel: null),
        transport: t,
      );
      expect(r.skipReason, AiProbeSkipReason.noModel);
      expect(t.speechCalls, 0);
    });

    test('TTS trả 0 byte ⇒ failed (không fake success)', () async {
      final t = _FakeTransport(speechBytes: 0);
      final r = await probeAiCapability(
        capability: AiRouteCapability.tts,
        provider: _provider(ttsModel: 'tts-1'),
        transport: t,
      );
      expect(r.status, AiProbeStatus.failed);
      expect(r.errorCode, AiApiErrorCode.invalidResponse);
    });

    test('STT: model có trong /v1/models ⇒ ok nhưng KHÔNG nhận đã bóc băng',
        () async {
      final t = _FakeTransport(models: ['whisper-1', 'gpt-4o-mini']);
      final r = await probeAiCapability(
        capability: AiRouteCapability.sttFile,
        provider: _provider(sttModel: 'whisper-1'),
        transport: t,
      );
      expect(r.status, AiProbeStatus.ok);
      expect(r.modelPresentInModelList, isTrue);
      expect(r.modelCount, 2);
      expect(r.transcribedRealAudio, isFalse,
          reason: 'không có file audio ⇒ không được báo đã bóc băng');
    });

    test('STT: model KHÔNG có trong danh sách ⇒ failed (bóc băng sẽ lỗi)',
        () async {
      final t = _FakeTransport(models: ['whisper-1']);
      final r = await probeAiCapability(
        capability: AiRouteCapability.sttFile,
        provider: _provider(sttModel: 'parakeet-x'),
        transport: t,
      );
      expect(r.status, AiProbeStatus.failed);
      expect(r.modelPresentInModelList, isFalse);
    });

    test('probeAiCapabilities chạy lần lượt + báo từng kết quả', () async {
      final t = _FakeTransport();
      final seen = <AiRouteCapability>[];
      final all = await probeAiCapabilities(
        targets: [
          AiCapabilityProbeTarget(AiRouteCapability.chat, _provider(chatModel: 'c')),
          AiCapabilityProbeTarget(AiRouteCapability.tts, _provider(ttsModel: 't')),
        ],
        transport: t,
        onResult: (r) => seen.add(r.capability),
      );
      expect(all, hasLength(2));
      expect(seen, [AiRouteCapability.chat, AiRouteCapability.tts]);
    });
  });
}
