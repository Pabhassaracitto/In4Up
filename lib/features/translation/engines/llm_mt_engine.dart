// lib/features/translation/engines/llm_mt_engine.dart
//
// WP3 (API-004) — Dịch bằng LLM qua tầng Server API (ADR-0007).
// Mục tiêu: chất lượng dịch (nhất là Pali/chuyên ngữ Phật học) tốt hơn
// Hy-MT; giảm nhu cầu giữ model 600MB trên máy.
//
// Hợp đồng với TranslationService (KHÔNG đổi):
// - Glossary chuyên ngữ chạy TRƯỚC engine → engine nhận text ĐÃ thay slot
//   `__G{n}__`; output PHẢI giữ nguyên slot. Mất slot = lỗi cấu trúc
//   `slotLost` (engine tự báo, chuỗi rơi tiếp engine khác — không fake
//   success làm mất nghĩa khóa glossary).
// - Khi tầng tắt (chưa cấu hình provider / routing offlineOnly / mất mạng)
//   engine tự fail nhanh với mã cấu trúc → chuỗi fallback hiện có
//   (DeepLX → Google → … → Hy-MT → ML Kit → Offline) NGUYÊN VẸN.
//
// Vị trí chèn theo routing (ADR-0007, AiRouteCapability.translation) —
// service đọc [runsBeforeFreeOnlineEngines]:
// - onlineFirst  → TRƯỚC các engine online miễn phí (DeepLX/Google/…).
// - offlineFirst (mặc định) → SAU Hy-MT + ML Kit, TRƯỚC từ điển offline
//   ("thử offline trước; lỗi/thiếu model → thử API").
//
// Kỷ luật (tái dùng pattern Hy-MT HYMT-002 + luật tầng API mục 2.7):
// - Single-flight 1 request/1 slot (HyMtSlot), chờ hữu hạn → mã `busy`.
// - Chunk ≤ ~2000 ký tự theo ranh giới câu (HyMtChunking — phân hoạch
//   chính xác, không lặp/mất đoạn); MỖI chunk timeout hữu hạn riêng.
// - 429/5xx → backoff rồi retry TỐI ĐA 1 lần mỗi chunk.
// - Mã lỗi cấu trúc [LlmMtErrorCode] — phần API trùng TÊN AiApiErrorCode
//   (mã chung tầng API).
// - KHÔNG log apiKey (chỉ log label + model của provider).

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:in4up_ai/in4up_ai.dart';

import 'hymt_chunking.dart';
import 'hymt_slot.dart';
import 'llm_mt_prompts.dart';
import 'translation_engine.dart';

/// Mã lỗi cấu trúc — UI/service phân nhánh theo mã
/// (`TranslationResult.errorCode` = `code.name`), không match chuỗi.
///
/// 8 mã giữa (noNetwork…invalidBaseUrl) trùng TÊN [AiApiErrorCode] —
/// mã chung của tầng API; các mã còn lại là điều kiện engine
/// (provider/slot/chunk) theo khuôn HyMtErrorCode.
enum LlmMtErrorCode {
  /// Chưa cấu hình provider / provider tắt / chưa chọn chatModel /
  /// routing translation = offlineOnly.
  noProvider,

  /// Không có kết nối mạng (= AiApiErrorCode.noNetwork).
  noNetwork,

  /// Có request khác đang chạy (hết hạn chờ slot single-flight).
  busy,

  /// Hết thời gian chờ chunk (= AiApiErrorCode.timeout).
  timeout,

  /// 429 — đã backoff + retry 1 lần vẫn bị (= AiApiErrorCode.rateLimited).
  rateLimited,

  /// 401/403 — sai/thiếu API key (= AiApiErrorCode.unauthorized).
  unauthorized,

  /// Lỗi HTTP khác — 5xx, 4xx khác (= AiApiErrorCode.httpError).
  httpError,

  /// Response không parse được JSON chuẩn OpenAI
  /// (= AiApiErrorCode.invalidResponse).
  invalidResponse,

  /// baseUrl http:// công cộng bị guard chặn
  /// (= AiApiErrorCode.cleartextBlocked).
  cleartextBlocked,

  /// baseUrl rỗng/sai format (= AiApiErrorCode.invalidBaseUrl).
  invalidBaseUrl,

  /// Model trả output rỗng (sau khi làm sạch).
  emptyOutput,

  /// Glossary slot `__G{n}__` bị model làm mất trong output.
  slotLost,

  /// Văn bản quá dài (vượt số chunk tối đa).
  tooLong,
}

/// Nguồn cấu hình + mạng + routing — tách interface để test thuần
/// (không SharedPreferences, không connectivity plugin, không network).
abstract class LlmMtEnv {
  /// Provider đang bật hỗ trợ dịch, hoặc null (chưa cấu hình /
  /// routing offlineOnly — resolveProvider của store đã xử cả hai).
  Future<AiProviderConfig?> resolveProvider();

  /// Routing mode hiện tại của năng lực translation.
  Future<AiRouteMode> routeMode();

  /// Có kết nối mạng không.
  Future<bool> hasNetwork();
}

/// Env thật: AiProviderStore (WP0) + connectivity_plus.
class _StoreEnv implements LlmMtEnv {
  Future<AiProviderStore> _loadStore() async {
    final store = AiProviderStore.instance;
    // Idempotent — load 1 lần từ SharedPreferences, các lần sau trả ngay.
    await store.ensureLoaded();
    return store;
  }

  @override
  Future<AiProviderConfig?> resolveProvider() async {
    final store = await _loadStore();
    return store.resolveProvider(AiRouteCapability.translation);
  }

  @override
  Future<AiRouteMode> routeMode() async {
    final store = await _loadStore();
    return store.routing.modeOf(AiRouteCapability.translation);
  }

  @override
  Future<bool> hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((entry) =>
          entry == ConnectivityResult.wifi ||
          entry == ConnectivityResult.mobile ||
          entry == ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }
}

/// Lớp "gửi prompt → nhận output thô" qua OpenAI-compat. Test inject
/// backend giả để kiểm tra chunk/slot/retry/mã lỗi MÀ KHÔNG cần network.
abstract class LlmMtBackend {
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required Duration timeout,
  });
}

/// Backend thật: dùng ĐÚNG client OpenAI-compat duy nhất của tầng API
/// (ADR-0007 — WP thêm method vào client, không tạo client thứ 2).
/// Client không giữ connection dài hạn → tạo theo request là đủ.
class OpenAiCompatChatBackend implements LlmMtBackend {
  const OpenAiCompatChatBackend();

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required Duration timeout,
  }) {
    final client = OpenAiCompatClient(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
    );
    return client.chatCompletion(
      model: model,
      messages: [
        OpenAiChatMessage('system', systemPrompt),
        OpenAiChatMessage('user', userPrompt),
      ],
      temperature: LlmMtPrompts.temperature,
      maxTokens: maxTokens,
      timeout: timeout,
    );
  }
}

/// Engine dịch bằng LLM qua /v1/chat/completions (API-004).
///
/// [LlmMtEngine.forTest] inject env + backend giả; singleton
/// [LlmMtEngine.instance] dùng store thật (BYOK — không cấu hình thì
/// engine fail nhanh `no_provider`, app hành xử như chưa có tầng API).
class LlmMtEngine extends TranslationEngine {
  LlmMtEngine._({
    LlmMtEnv? env,
    LlmMtBackend? backend,
    Duration? chunkTimeout,
    Duration? retryBackoff,
    Duration? queueWait,
    int? maxChunks,
  })  : _env = env ?? _StoreEnv(),
        _backend = backend ?? const OpenAiCompatChatBackend(),
        _chunkTimeout = chunkTimeout ?? const Duration(seconds: 60),
        _retryBackoff = retryBackoff ?? const Duration(milliseconds: 800),
        _queueWait = queueWait ?? const Duration(seconds: 10),
        _maxChunks = maxChunks ?? 32;

  static final LlmMtEngine instance = LlmMtEngine._();
  factory LlmMtEngine() => instance;

  /// Constructor DUY NHẤT cho test — inject env (provider/mạng/routing)
  /// + backend giả; không chạm SharedPreferences/connectivity/network.
  factory LlmMtEngine.forTest({
    required LlmMtEnv env,
    LlmMtBackend? backend,
    Duration chunkTimeout = const Duration(seconds: 60),
    Duration retryBackoff = const Duration(milliseconds: 800),
    Duration queueWait = const Duration(seconds: 10),
    int maxChunks = 32,
  }) {
    return LlmMtEngine._(
      env: env,
      backend: backend,
      chunkTimeout: chunkTimeout,
      retryBackoff: retryBackoff,
      queueWait: queueWait,
      maxChunks: maxChunks,
    );
  }

  /// Mục tiêu ký tự mỗi chunk (~maxCharsPerRequest — prompt WP3 mục 2).
  static const int maxChunkChars = 2000;

  @override
  String get name => 'LLM API';

  @override
  String get id => 'llm_mt';

  @override
  int get maxCharsPerRequest => maxChunkChars;

  @override
  Duration get requestDelay => const Duration(milliseconds: 300);

  final LlmMtEnv _env;
  final LlmMtBackend _backend;
  final Duration _chunkTimeout;
  final Duration _retryBackoff;
  final Duration _queueWait;
  final int _maxChunks;

  HyMtSlot? _slot;
  String? _lastChunkError;
  LlmMtErrorCode? _lastChunkCode;

  /// Slot single-flight (lazy) — 1 request tại một thời điểm (mẫu HyMtSlot).
  HyMtSlot get slot => _slot ??= HyMtSlot(maxWait: _queueWait);

  /// Provider hiện tại — cho UI hiện trạng thái (null = chưa cấu hình).
  Future<AiProviderConfig?> currentProvider() => _env.resolveProvider();

  /// Routing translation hiện tại (service dùng chọn vị trí chèn).
  Future<AiRouteMode> routeMode() => _env.routeMode();

  /// onlineFirst → service chèn engine TRƯỚC các engine online miễn phí;
  /// offlineFirst (mặc định) → sau Hy-MT/ML Kit, trước từ điển.
  ///
  /// Không bao giờ throw (đọc cấu hình lỗi → coi như offlineFirst — mặc
  /// định an toàn, chuỗi dịch không bị đứt vì tầng API).
  Future<bool> runsBeforeFreeOnlineEngines() async {
    try {
      return await _env.routeMode() == AiRouteMode.onlineFirst;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (await _env.resolveProvider() == null) return false;
    return _env.hasNetwork();
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: name,
      );
    }

    final provider = await _env.resolveProvider();
    if (provider == null) {
      return _fail(
        text,
        'Chưa cấu hình provider cho dịch LLM (màn Server & API) hoặc '
        'routing "Dịch" đang "Chỉ offline".',
        LlmMtErrorCode.noProvider,
        sourceLang,
        targetLang,
      );
    }
    final model = provider.chatModel;
    if (model == null || model.isEmpty) {
      return _fail(
        text,
        'Provider "${provider.label}" chưa chọn chat model — mở màn '
        'Server & API để chọn từ danh sách model.',
        LlmMtErrorCode.noProvider,
        sourceLang,
        targetLang,
      );
    }
    if (!await _env.hasNetwork()) {
      return _fail(
        text,
        'Không có mạng — LLM API cần kết nối (chuỗi tự fallback về engine '
        'offline).',
        LlmMtErrorCode.noNetwork,
        sourceLang,
        targetLang,
      );
    }

    // Single-flight: 1 request/1 slot; request kế tiếp chờ hữu hạn rồi
    // báo `busy` có cấu trúc (mẫu HYMT-002 mục 1).
    final slotGuard = slot;
    if (!await slotGuard.acquire()) {
      return _fail(
        text,
        'LLM API đang bận: request trước vẫn đang chạy '
            '(đã chờ ${_fmtDuration(_queueWait)}).',
        LlmMtErrorCode.busy,
        sourceLang,
        targetLang,
      );
    }
    try {
      final chunks = HyMtChunking.chunk(text, maxChars: maxChunkChars);
      if (chunks.isEmpty) {
        return TranslationResult.success(
          original: text,
          translated: '',
          engine: name,
          detectedLang: sourceLang,
          targetLang: targetLang,
        );
      }
      if (chunks.length > _maxChunks) {
        return _fail(
          text,
          'Văn bản quá dài cho LLM API (${text.length} ký tự, tối đa ~'
              '${_maxChunks * maxChunkChars}). Tách văn bản ra rồi dịch '
              'từng phần.',
          LlmMtErrorCode.tooLong,
          sourceLang,
          targetLang,
        );
      }

      final systemPrompt = LlmMtPrompts.buildSystemPrompt(
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      final outputs = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        final piece = chunks[i].text;
        final out = await _translateChunk(
          provider: provider,
          model: model,
          systemPrompt: systemPrompt,
          piece: piece,
          chunkIndex: i,
          chunkCount: chunks.length,
        );
        if (out == null) {
          return _fail(
            text,
            'LLM API lỗi ở segment ${i + 1}/${chunks.length}: '
                '${_lastChunkError ?? 'lỗi không xác định'}',
            _lastChunkCode ?? LlmMtErrorCode.httpError,
            sourceLang,
            targetLang,
          );
        }
        outputs.add(out);
        if (i < chunks.length - 1) {
          // Tránh rate limit giữa các chunk (requestDelay của interface).
          await Future<void>.delayed(requestDelay);
        }
      }

      final translated = HyMtChunking.assemble(outputs, chunks);
      if (translated.trim().isEmpty) {
        return _fail(
          text,
          'LLM API trả về rỗng.',
          LlmMtErrorCode.emptyOutput,
          sourceLang,
          targetLang,
        );
      }
      return TranslationResult.success(
        original: text,
        translated: translated,
        engine: name,
        detectedLang: sourceLang,
        targetLang: targetLang,
      );
    } finally {
      slotGuard.release();
    }
  }

  /// Dịch 1 chunk: gọi backend → làm sạch → KIỂM TRA SLOT.
  ///
  /// Retry TỐI ĐA 1 lần/lần chunk cho: 429/5xx (backoff — luật tầng API
  /// 2.7) và các lỗi "phi xác định" (rỗng/mất slot). Timeout và lỗi 4xx
  /// khác KHÔNG retry (request có thể vẫn đang chạy server-side / sai key
  /// thì lặp lại cũng vậy). Trả null = fail hẳn — lỗi cuối nằm ở
  /// [_lastChunkError]/[_lastChunkCode].
  Future<String?> _translateChunk({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String piece,
    required int chunkIndex,
    required int chunkCount,
  }) async {
    final maxTokens = _maxTokensFor(piece);
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final raw = await _backend
            .chat(
              provider: provider,
              model: model,
              systemPrompt: systemPrompt,
              userPrompt: piece,
              maxTokens: maxTokens,
              timeout: _chunkTimeout,
            )
            .timeout(_chunkTimeout + const Duration(seconds: 5));
        final cleaned = LlmMtPrompts.cleanOutput(raw, sourceText: piece);
        if (cleaned.isEmpty) {
          _setChunkError(
            LlmMtErrorCode.emptyOutput,
            'model trả rỗng cho segment ${chunkIndex + 1}/$chunkCount',
          );
        } else {
          final lost = LlmMtPrompts.lostSlot(piece, cleaned);
          if (lost == null) return cleaned;
          _setChunkError(
            LlmMtErrorCode.slotLost,
            'mất slot glossary $lost ở segment ${chunkIndex + 1}/$chunkCount',
          );
        }
      } on AiApiException catch (e) {
        _setChunkError(_mapApiError(e.code), e.message);
        final retryable = e.code == AiApiErrorCode.rateLimited ||
            (e.code == AiApiErrorCode.httpError && (e.statusCode ?? 0) >= 500);
        if (!retryable) return null;
      } on TimeoutException {
        _setChunkError(
          LlmMtErrorCode.timeout,
          'segment ${chunkIndex + 1}/$chunkCount quá '
              '${_fmtDuration(_chunkTimeout)}',
        );
        return null;
      } catch (e) {
        _setChunkError(LlmMtErrorCode.invalidResponse, '$e');
        return null;
      }
      if (attempt == 1) {
        await Future<void>.delayed(_retryBackoff);
      }
    }
    return null;
  }

  void _setChunkError(LlmMtErrorCode code, String message) {
    _lastChunkCode = code;
    _lastChunkError = message;
  }

  /// max_tokens đủ cho bản dịch của chunk: ~1 token/2 ký tự với tiếng
  /// Latin, dư biên độ cho CJK (1 token/ký tự) — sàn 1024, trần 4096
  /// (một số server từ chối max_tokens vượt context model).
  static int _maxTokensFor(String piece) {
    final estimate = piece.length + 512;
    if (estimate < 1024) return 1024;
    if (estimate > 4096) return 4096;
    return estimate;
  }

  static LlmMtErrorCode _mapApiError(AiApiErrorCode code) {
    switch (code) {
      case AiApiErrorCode.noNetwork:
        return LlmMtErrorCode.noNetwork;
      case AiApiErrorCode.timeout:
        return LlmMtErrorCode.timeout;
      case AiApiErrorCode.unauthorized:
        return LlmMtErrorCode.unauthorized;
      case AiApiErrorCode.rateLimited:
        return LlmMtErrorCode.rateLimited;
      case AiApiErrorCode.httpError:
        return LlmMtErrorCode.httpError;
      case AiApiErrorCode.invalidResponse:
        return LlmMtErrorCode.invalidResponse;
      case AiApiErrorCode.cleartextBlocked:
        return LlmMtErrorCode.cleartextBlocked;
      case AiApiErrorCode.invalidBaseUrl:
        return LlmMtErrorCode.invalidBaseUrl;
    }
  }

  TranslationResult _fail(
    String text,
    String error,
    LlmMtErrorCode code,
    String sourceLang,
    String targetLang,
  ) {
    return TranslationResult.failure(
      original: text,
      error: error,
      engine: name,
      errorCode: code.name,
      detectedLang: sourceLang,
      targetLang: targetLang,
    );
  }

  static String _fmtDuration(Duration d) => d.inSeconds >= 60
      ? '${d.inMinutes} phút'
      : d.inMilliseconds >= 1000
          ? '${d.inSeconds}s'
          : '${d.inMilliseconds}ms';
}
