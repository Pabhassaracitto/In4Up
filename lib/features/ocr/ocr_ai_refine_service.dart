// lib/features/ocr/ocr_ai_refine_service.dart
//
// PSRC-209 — "tinh chỉnh bằng AI" sau OCR trong PDF reader báo SAI cấu hình.
//
// Ba lỗi gốc của bản cũ:
//  1. Gửi TOÀN BỘ văn bản trong MỘT request với `maxTokens: 8192` ⇒ model
//     context 8k (free tier OpenRouter/Groq) trả 400/lỗi ⇒ rơi vào snackbar
//     chung "kiểm tra cấu hình AI" dù cấu hình đúng.
//  2. `resolveProvider()` đọc trạng thái mạng ĐÃ CACHE của
//     `AiConnectivityRouter` mà không đo lại ⇒ máy vừa bật Wi-Fi vẫn bị
//     `auto` resolve thành `offlineOnly` ⇒ "không có provider".
//  3. Mọi nguyên nhân (chưa có provider / provider tắt / chưa chọn model /
//     thiếu API key / mất mạng / routing "Chỉ offline") đều đổ về CÙNG một
//     câu ⇒ người dùng không biết thiếu gì để sửa.
//
// Hợp đồng mới:
//  - [OcrAiRefinePolicy.missingPrerequisite] là hàm THUẦN: nhận ảnh chụp cấu
//    hình ([OcrAiRefineSetup]) → trả ĐÚNG mã thiếu (test được, không cần
//    SharedPreferences/mạng).
//  - Chia văn bản thành LÔ theo DÒNG, mỗi lô ≤ [OcrAiRefineBlocks.maxChunkChars]
//    ký tự, `max_tokens` tính theo độ dài lô (trần 4096) ⇒ chạy được cả model
//    8k context.
//  - GIỮ NGUYÊN số khối (map 1-1): dòng trống giữ nguyên, mỗi dòng nguồn có
//    đúng một dòng kết quả; model trả lệch số dòng ⇒ nhắc lại định dạng, vẫn
//    lệch ⇒ sửa từng dòng, cuối cùng giữ nguyên dòng gốc. KHÔNG BAO GIỜ gộp
//    hoặc tách khối.
//  - 429/5xx: backoff + retry tối đa 1 lần mỗi lô (luật tầng API 2.7).
//  - Bóc `<think>`/code fence — model reasoning hay bọc output.
//  - Lỗi trả về mã cấu trúc ([OcrAiRefineError]); dialog tự dịch thành câu
//    hướng dẫn đúng việc cần làm. KHÔNG log apiKey.

import 'dart:async';

import 'package:in4up_ai/in4up_ai.dart';

/// Pure UI policy: the optional refinement action is available only when
/// there is text worth sending to the configured AI provider.
class OcrAiRefinePolicy {
  const OcrAiRefinePolicy._();

  static bool shouldOffer(String text) => text.trim().isNotEmpty;

  /// Điều kiện tiên quyết còn THIẾU (null = đủ điều kiện gọi API).
  ///
  /// Thứ tự xét là thứ tự người dùng sửa được: chưa có provider → provider
  /// tắt → chưa chọn model → routing "Chỉ offline" → mất mạng → thiếu key.
  /// Nhờ vậy thông báo nêu ĐÚNG một việc cần làm, không phải câu chung chung.
  static OcrAiRefineError? missingPrerequisite(OcrAiRefineSetup setup) {
    if (setup.providers.isEmpty) return OcrAiRefineError.noProvider;
    if (!setup.providers.any((p) => p.enabled)) {
      return OcrAiRefineError.noProvider;
    }
    final provider = setup.provider;
    final model = setup.model;
    if (provider == null || model == null || model.trim().isEmpty) {
      return OcrAiRefineError.noModel;
    }
    if (setup.configuredMode == AiRouteMode.offlineOnly) {
      return OcrAiRefineError.offlineOnly;
    }
    if (!setup.hasNetwork) return OcrAiRefineError.noNetwork;
    if (requiresApiKey(provider) && (provider.apiKey ?? '').trim().isEmpty) {
      return OcrAiRefineError.missingApiKey;
    }
    return null;
  }

  /// Provider cloud (https, host công cộng) BẮT BUỘC có API key; server LAN
  /// (`localhost`, IP riêng, tên máy `.local`…) thì không.
  ///
  /// Dùng cùng quy ước với guard cleartext của `OpenAiCompatClient` để app
  /// không báo "thiếu API key" cho llama-server trong nhà.
  static bool requiresApiKey(AiProviderConfig provider) {
    final raw = provider.baseUrl.trim();
    if (raw.isEmpty) return false; // lỗi baseUrl có mã riêng khi gửi request
    final uri = Uri.tryParse(OpenAiCompatClient.normalizeBaseUrl(raw));
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') return false;
    if (!host.contains('.')) return false; // tên máy ngắn trong LAN
    final parts = host.split('.');
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      if (octets.every((o) => o != null && o >= 0 && o <= 255)) {
        final a = octets[0]!;
        final b = octets[1]!;
        if (a == 10 || a == 127) return false;
        if (a == 192 && b == 168) return false;
        if (a == 172 && b >= 16 && b <= 31) return false;
        if (a == 169 && b == 254) return false;
      }
    }
    final tld = host.substring(host.lastIndexOf('.') + 1);
    if (tld == 'local' || tld == 'lan' || tld == 'internal' || tld == 'home') {
      return false;
    }
    return true;
  }
}

/// Mã lỗi cấu trúc — dialog phân nhánh theo MÃ, không match chuỗi.
enum OcrAiRefineError {
  /// Văn bản rỗng.
  emptyInput,

  /// Chưa thêm provider nào, hoặc mọi provider đang tắt.
  noProvider,

  /// Có provider bật nhưng chưa chọn model (chat hoặc dịch).
  noModel,

  /// Người dùng đặt routing "Chỉ offline" cho AI Chat.
  offlineOnly,

  /// Mất mạng (router resolve `auto` → offlineOnly vì không có kết nối).
  noNetwork,

  /// Provider cloud nhưng chưa nhập API key.
  missingApiKey,

  /// 401/403 — key sai/hết hạn.
  unauthorized,

  /// 429 — đã backoff + retry 1 lần vẫn bị.
  rateLimited,

  /// Quá thời gian chờ.
  timeout,

  /// Văn bản quá dài (quá số lô tối đa).
  tooLong,

  /// Model trả rỗng/không dùng được cho mọi lô.
  emptyOutput,

  /// Lỗi HTTP/parse khác.
  requestFailed,
}

class OcrAiRefineException implements Exception {
  final OcrAiRefineError code;

  /// Nhãn provider / thông điệp kỹ thuật — hiển thị phụ, KHÔNG phải apiKey.
  final String? detail;

  const OcrAiRefineException(this.code, [this.detail]);

  @override
  String toString() =>
      'OcrAiRefineException(${code.name}${detail == null ? '' : ': $detail'})';
}

/// Ảnh chụp cấu hình AI tại thời điểm bấm "Tinh chỉnh" — dữ liệu THUẦN để
/// [OcrAiRefinePolicy.missingPrerequisite] test được không cần plugin.
class OcrAiRefineSetup {
  /// Toàn bộ provider đã lưu (kể cả đang tắt).
  final List<AiProviderConfig> providers;

  /// Năng lực sẽ dùng: `chat`, hoặc `translation` khi provider chỉ có model
  /// dịch (vẫn là LLM cùng khả năng sửa lỗi OCR).
  final AiRouteCapability capability;

  /// Mode NGƯỜI DÙNG chọn cho [capability] (chưa resolve theo mạng).
  final AiRouteMode configuredMode;

  final bool hasNetwork;

  /// Provider được chọn (null = không có provider nào phục vụ được).
  final AiProviderConfig? provider;

  /// Model thật sẽ gửi lên (null = provider chưa chọn model).
  final String? model;

  const OcrAiRefineSetup({
    required this.providers,
    required this.capability,
    required this.configuredMode,
    required this.hasNetwork,
    required this.provider,
    required this.model,
  });
}

/// Nguồn cấu hình — tách interface để test không cần SharedPreferences /
/// connectivity_plus.
abstract class OcrAiRefineEnv {
  Future<OcrAiRefineSetup> load();
}

/// Env thật: `AiProviderStore` + `AiConnectivityRouter`.
class _StoreEnv implements OcrAiRefineEnv {
  const _StoreEnv();

  @override
  Future<OcrAiRefineSetup> load() async {
    final store = AiProviderStore.instance;
    await store.ensureLoaded();

    // PSRC-209: ĐO LẠI mạng (TTL 10s) trước khi resolve. Trước đây đọc giá
    // trị cache ⇒ vừa có Wi-Fi vẫn bị coi là offline ⇒ báo "chưa cấu hình".
    var kind = AiConnectivityRouter.instance.kind;
    try {
      kind = await AiConnectivityRouter.instance.refresh();
    } catch (_) {
      // Desktop/plugin lỗi — giữ giá trị lạc quan của router.
    }

    final enabled = store.enabledProviders;
    final supportsChat =
        enabled.any((p) => p.supports(AiRouteCapability.chat));
    final supportsTranslation =
        enabled.any((p) => p.supports(AiRouteCapability.translation));
    final capability = supportsChat
        ? AiRouteCapability.chat
        : supportsTranslation
            ? AiRouteCapability.translation
            : AiRouteCapability.chat;

    final provider = _pickCandidate(store, capability);

    return OcrAiRefineSetup(
      providers: store.providers,
      capability: capability,
      configuredMode: store.routing.modeOf(capability),
      hasNetwork: kind != AiNetworkKind.none,
      provider: provider,
      model: provider?.modelFor(capability),
    );
  }

  /// Chọn provider ỨNG VIÊN, KHÔNG xét routing/mạng (chẩn đoán tự xét sau —
  /// nếu xét ở đây thì mất mạng sẽ bị báo nhầm thành "chưa cấu hình").
  AiProviderConfig? _pickCandidate(
    AiProviderStore store,
    AiRouteCapability capability,
  ) {
    final candidates = store.enabledProviders
        .where((p) => p.supports(capability))
        .toList();
    if (candidates.isEmpty) return null;
    final preferred = <String?>[
      store.routing.preferredProviderOf(capability),
      store.routing.preferredProviderOf(AiRouteCapability.chat),
      store.routing.preferredProviderOf(AiRouteCapability.translation),
    ];
    for (final id in preferred) {
      if (id == null) continue;
      for (final p in candidates) {
        if (p.id == id) return p;
      }
    }
    return candidates.first;
  }
}

/// Lớp "gửi prompt → nhận output thô" (test inject backend giả).
abstract class OcrAiRefineBackend {
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    String? reminder,
    required int maxTokens,
    required Duration timeout,
  });
}

/// Backend thật: dùng ĐÚNG client OpenAI-compat của tầng API (ADR-0008).
class OpenAiCompatRefineBackend implements OcrAiRefineBackend {
  const OpenAiCompatRefineBackend();

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    String? reminder,
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
        if (reminder != null) OpenAiChatMessage('user', reminder),
      ],
      temperature: 0.1,
      maxTokens: maxTokens,
      timeout: timeout,
    );
  }
}

/// Một mẩu văn bản trong lô: dòng nào (`line`), phần thứ mấy (`part`).
///
/// Dòng OCR dài hơn [OcrAiRefineBlocks.maxLineChars] bị cắt thành nhiều phần
/// để gửi, rồi ghép lại bằng [glue] (khoảng trắng đã bị cắt) ⇒ khối vẫn 1-1.
class OcrRefineSegment {
  final int line;
  final int part;
  final String text;

  /// Chuỗi chèn SAU phần này khi ghép lại ('' = phần cuối của dòng).
  final String glue;

  const OcrRefineSegment({
    required this.line,
    required this.part,
    required this.text,
    required this.glue,
  });
}

class OcrRefineChunk {
  final List<OcrRefineSegment> segments;

  const OcrRefineChunk(this.segments);

  int get chars =>
      segments.fold(0, (sum, segment) => sum + segment.text.length);

  String get prompt => segments.map((s) => s.text).join('\n');
}

class OcrAiRefinePlan {
  /// Các dòng GỐC của văn bản (kể cả dòng trống — giữ nguyên khi ghép).
  final List<String> lines;
  final List<OcrRefineChunk> chunks;

  /// Số phần của từng dòng có chữ (dòng không có chữ không xuất hiện).
  final Map<int, int> partsPerLine;

  /// Chuỗi nối giữa phần p và p+1 của từng dòng.
  final Map<int, List<String>> gluesPerLine;

  const OcrAiRefinePlan({
    required this.lines,
    required this.chunks,
    required this.partsPerLine,
    required this.gluesPerLine,
  });
}

/// Tiện ích THUẦN cho văn bản OCR — chia lô + ghép lại, giữ đúng số khối.
class OcrAiRefineBlocks {
  const OcrAiRefineBlocks._();

  /// Ký tự tối đa mỗi lô (~400 token) — vừa context 8k của model free.
  static const int maxChunkChars = 1200;

  /// Dòng dài hơn mức này bị cắt thành nhiều phần rồi ghép lại.
  static const int maxLineChars = 1600;

  /// Trần số lô một lượt tinh chỉnh (chặn tài liệu khổng lồ).
  static const int maxChunks = 40;

  /// `max_tokens` theo độ dài lô: CJK ~1 token/ký tự, Latin ~0.5. Sàn 512,
  /// trần 4096 — KHÔNG BAO GIỜ xin 8192 như bản cũ.
  static int maxTokensFor(int chars) {
    final estimate = chars + 256;
    if (estimate < 512) return 512;
    if (estimate > 4096) return 4096;
    return estimate;
  }

  /// Số khối = số dòng CÓ CHỮ (bất biến phải giữ sau khi tinh chỉnh).
  static int countBlocks(String text) => text
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .length;

  static OcrAiRefinePlan plan(
    String text, {
    int chunkChars = OcrAiRefineBlocks.maxChunkChars,
    int lineChars = OcrAiRefineBlocks.maxLineChars,
  }) {
    final lines = text.split('\n');
    final partsPerLine = <int, int>{};
    final gluesPerLine = <int, List<String>>{};
    final segments = <OcrRefineSegment>[];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue; // dòng trống: giữ nguyên, không gửi
      final pieces = _splitLine(trimmed, lineChars);
      partsPerLine[i] = pieces.length;
      gluesPerLine[i] = [
        for (var p = 0; p < pieces.length - 1; p++) pieces[p].glue,
      ];
      for (var p = 0; p < pieces.length; p++) {
        segments.add(
          OcrRefineSegment(
            line: i,
            part: p,
            text: pieces[p].text,
            glue: pieces[p].glue,
          ),
        );
      }
    }

    final chunks = <OcrRefineChunk>[];
    var current = <OcrRefineSegment>[];
    var currentChars = 0;
    for (final segment in segments) {
      final next = currentChars + segment.text.length + 1;
      if (current.isNotEmpty && next > chunkChars) {
        chunks.add(OcrRefineChunk(current));
        current = <OcrRefineSegment>[];
        currentChars = 0;
      }
      current.add(segment);
      currentChars += segment.text.length + 1;
    }
    if (current.isNotEmpty) chunks.add(OcrRefineChunk(current));

    return OcrAiRefinePlan(
      lines: lines,
      chunks: chunks,
      partsPerLine: partsPerLine,
      gluesPerLine: gluesPerLine,
    );
  }

  /// Ghép kết quả đã sửa về văn bản: dòng trống giữ nguyên, dòng thiếu kết
  /// quả (model trả rác) giữ nguyên bản gốc ⇒ số khối KHÔNG đổi.
  static String assemble(
    OcrAiRefinePlan plan,
    Map<int, Map<int, String>> refined,
  ) {
    final out = <String>[];
    for (var i = 0; i < plan.lines.length; i++) {
      final total = plan.partsPerLine[i];
      final parts = refined[i];
      if (total == null || parts == null || parts.length != total) {
        out.add(plan.lines[i]);
        continue;
      }
      final glues = plan.gluesPerLine[i] ?? const <String>[];
      final buffer = StringBuffer();
      for (var p = 0; p < total; p++) {
        buffer.write(parts[p]!.trim());
        if (p < total - 1) {
          buffer.write(p < glues.length ? glues[p] : ' ');
        }
      }
      out.add(buffer.toString());
    }
    return out.join('\n');
  }

  /// Output thô của model → danh sách dòng sạch.
  ///
  /// Bóc `<think>…</think>` (cả thẻ chưa đóng), code fence, và số thứ tự
  /// "1. " khi MỌI dòng đều bị đánh số (model tự thêm).
  static List<String> outputLines(String raw) {
    var text = raw;
    text = text.replaceAll(
      RegExp(r'<think(?:ing)?>[\s\S]*?</think(?:ing)?>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<think(?:ing)?>[\s\S]*$', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'^\s*```[^\n]*$', multiLine: true), '');
    text = text.replaceAll('```', '');

    final marker = RegExp(r'^\s*(?:\d+[.)]|[-*•])\s+');
    var lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length > 1 && lines.every(marker.hasMatch)) {
      lines = lines.map((line) => line.replaceFirst(marker, '').trim()).toList();
    }
    return lines;
  }

  static List<_LinePiece> _splitLine(String line, int maxChars) {
    if (line.length <= maxChars) {
      return [_LinePiece(text: line, glue: '')];
    }
    final pieces = <_LinePiece>[];
    var start = 0;
    while (start < line.length) {
      final end = start + maxChars;
      if (end >= line.length) {
        pieces.add(_LinePiece(text: line.substring(start), glue: ''));
        break;
      }
      // Cắt ở khoảng trắng gần cuối nhất để không bẻ đôi từ; ký tự khoảng
      // trắng đó trở thành `glue` để ghép lại ĐÚNG như ban đầu.
      final cut = line.lastIndexOf(RegExp(r'\s'), end);
      if (cut <= start) {
        // Không có khoảng trắng (CJK) → cắt cứng, ghép lại không chèn gì.
        pieces.add(_LinePiece(text: line.substring(start, end), glue: ''));
        start = end;
        continue;
      }
      pieces.add(
        _LinePiece(text: line.substring(start, cut), glue: line[cut]),
      );
      start = cut + 1;
    }
    return pieces.isEmpty ? [_LinePiece(text: line, glue: '')] : pieces;
  }
}

class _LinePiece {
  final String text;
  final String glue;

  const _LinePiece({required this.text, required this.glue});
}

/// Optional OCR post-processing through the already-configured chat provider.
/// No provider/model is downloaded or enabled implicitly.
class OcrAiRefineService {
  OcrAiRefineService._({
    OcrAiRefineEnv? env,
    OcrAiRefineBackend? backend,
    Duration? timeout,
    Duration? retryBackoff,
    Duration? chunkDelay,
    int? maxChunks,
    int? maxChunkChars,
  })  : _env = env ?? const _StoreEnv(),
        _backend = backend ?? const OpenAiCompatRefineBackend(),
        _timeout = timeout ?? const Duration(seconds: 90),
        _retryBackoff = retryBackoff ?? const Duration(milliseconds: 800),
        _chunkDelay = chunkDelay ?? const Duration(milliseconds: 250),
        _maxChunks = maxChunks ?? OcrAiRefineBlocks.maxChunks,
        _maxChunkChars = maxChunkChars ?? OcrAiRefineBlocks.maxChunkChars;

  static final OcrAiRefineService instance = OcrAiRefineService._();

  /// Constructor DUY NHẤT cho test — inject env (cấu hình/mạng) + backend
  /// giả; không chạm SharedPreferences / connectivity / network.
  factory OcrAiRefineService.forTest({
    required OcrAiRefineEnv env,
    OcrAiRefineBackend? backend,
    Duration timeout = const Duration(seconds: 90),
    Duration retryBackoff = Duration.zero,
    Duration chunkDelay = Duration.zero,
    int maxChunks = OcrAiRefineBlocks.maxChunks,
    int maxChunkChars = OcrAiRefineBlocks.maxChunkChars,
  }) {
    return OcrAiRefineService._(
      env: env,
      backend: backend,
      timeout: timeout,
      retryBackoff: retryBackoff,
      chunkDelay: chunkDelay,
      maxChunks: maxChunks,
      maxChunkChars: maxChunkChars,
    );
  }

  static const String _systemPrompt =
      'You are a careful OCR proofreading assistant. Correct likely OCR '
      'recognition errors, spelling, punctuation, and obvious grammar while '
      'preserving the original language, meaning, names, numbers, paragraph '
      'structure, headings, and line breaks. Do not summarize, translate, add '
      'facts, or rewrite stylistically. If uncertain, preserve the source '
      'text. Return only the corrected text, without commentary or quotation '
      'marks. Keep the exact same number of lines as the input: never merge '
      'or split lines, and return one corrected line for each input line, in '
      'the same order.';

  final OcrAiRefineEnv _env;
  final OcrAiRefineBackend _backend;
  final Duration _timeout;
  final Duration _retryBackoff;
  final Duration _chunkDelay;
  final int _maxChunks;
  final int _maxChunkChars;

  /// Chẩn đoán KHÔNG gọi mạng — dialog dùng trước khi hiện lỗi để nêu đúng
  /// cấu hình còn thiếu.
  Future<OcrAiRefineSetup> inspectSetup() => _env.load();

  /// The caller supplies the exact current draft; the OCR result is never sent
  /// unless the user taps the refinement action.
  Future<String> refine(String text) async {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      throw const OcrAiRefineException(OcrAiRefineError.emptyInput);
    }

    final setup = await _env.load();
    final missing = OcrAiRefinePolicy.missingPrerequisite(setup);
    if (missing != null) {
      throw OcrAiRefineException(missing, setup.provider?.label);
    }
    final provider = setup.provider!;
    final model = setup.model!;

    final plan = OcrAiRefineBlocks.plan(
      normalized,
      chunkChars: _maxChunkChars,
    );
    if (plan.chunks.isEmpty) {
      throw const OcrAiRefineException(OcrAiRefineError.emptyInput);
    }
    if (plan.chunks.length > _maxChunks) {
      throw OcrAiRefineException(
        OcrAiRefineError.tooLong,
        '${plan.chunks.length} chunks',
      );
    }

    final refined = <int, Map<int, String>>{};
    var refinedAny = false;
    for (var i = 0; i < plan.chunks.length; i++) {
      final chunk = plan.chunks[i];
      final result = await _refineChunk(
        provider: provider,
        model: model,
        chunk: chunk,
      );
      if (result != null && result.isNotEmpty) {
        refinedAny = true;
        for (final entry in result.entries) {
          (refined[entry.key] ??= <int, String>{}).addAll(entry.value);
        }
      }
      if (i < plan.chunks.length - 1) {
        await Future<void>.delayed(_chunkDelay);
      }
    }

    if (!refinedAny) {
      throw const OcrAiRefineException(OcrAiRefineError.emptyOutput);
    }
    return OcrAiRefineBlocks.assemble(plan, refined);
  }

  /// Sửa 1 lô. Trả null = model trả rác cho lô này (giữ nguyên văn bản gốc).
  /// Ném [OcrAiRefineException] = lỗi API thật (không thể tiếp tục).
  Future<Map<int, Map<int, String>>?> _refineChunk({
    required AiProviderConfig provider,
    required String model,
    required OcrRefineChunk chunk,
  }) async {
    final expected = chunk.segments.length;
    final prompt = chunk.prompt;
    final maxTokens = OcrAiRefineBlocks.maxTokensFor(prompt.length);

    final raw = await _request(
      provider: provider,
      model: model,
      userPrompt: prompt,
      maxTokens: maxTokens,
    );
    final lines = OcrAiRefineBlocks.outputLines(raw);
    if (lines.length == expected) return _zip(chunk, lines);

    if (expected > 1) {
      // Nhắc lại định dạng MỘT lần — model free hay thêm/bớt dòng.
      final retry = await _request(
        provider: provider,
        model: model,
        userPrompt: prompt,
        maxTokens: maxTokens,
        reminder: 'Your previous reply had ${lines.length} lines but the '
            'input has $expected lines. Reply with exactly $expected lines — '
            'one corrected line per input line, in the same order, no '
            'numbering, no commentary.',
      );
      final retryLines = OcrAiRefineBlocks.outputLines(retry);
      if (retryLines.length == expected) return _zip(chunk, retryLines);

      // Lưới an toàn cuối: sửa TỪNG dòng (giữ đúng số khối), chỉ khi lô nhỏ.
      if (expected <= 8) {
        final out = <int, Map<int, String>>{};
        for (final segment in chunk.segments) {
          final single = await _request(
            provider: provider,
            model: model,
            userPrompt: segment.text,
            maxTokens: OcrAiRefineBlocks.maxTokensFor(segment.text.length),
          );
          final singleLines = OcrAiRefineBlocks.outputLines(single);
          if (singleLines.length == 1 && singleLines.single.isNotEmpty) {
            (out[segment.line] ??= <int, String>{})[segment.part] =
                singleLines.single;
          }
          await Future<void>.delayed(_chunkDelay);
        }
        return out.isEmpty ? null : out;
      }
    }
    return null;
  }

  Map<int, Map<int, String>> _zip(
    OcrRefineChunk chunk,
    List<String> lines,
  ) {
    final out = <int, Map<int, String>>{};
    for (var i = 0; i < chunk.segments.length; i++) {
      final segment = chunk.segments[i];
      (out[segment.line] ??= <int, String>{})[segment.part] = lines[i];
    }
    return out;
  }

  /// Gửi 1 request; 429/5xx backoff + retry TỐI ĐA 1 lần (luật tầng API 2.7).
  Future<String> _request({
    required AiProviderConfig provider,
    required String model,
    required String userPrompt,
    required int maxTokens,
    String? reminder,
  }) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _backend
            .chat(
              provider: provider,
              model: model,
              systemPrompt: _systemPrompt,
              userPrompt: userPrompt,
              reminder: reminder,
              maxTokens: maxTokens,
              timeout: _timeout,
            )
            .timeout(_timeout + const Duration(seconds: 5));
      } on AiApiException catch (error) {
        final retryable = error.code == AiApiErrorCode.rateLimited ||
            (error.code == AiApiErrorCode.httpError &&
                (error.statusCode ?? 0) >= 500);
        if (!retryable || attempt == 2) {
          throw _mapApiError(error);
        }
      } on TimeoutException {
        throw const OcrAiRefineException(OcrAiRefineError.timeout);
      } on OcrAiRefineException {
        rethrow;
      } catch (error) {
        throw OcrAiRefineException(
          OcrAiRefineError.requestFailed,
          error.toString(),
        );
      }
      await Future<void>.delayed(_retryBackoff);
    }
    throw const OcrAiRefineException(OcrAiRefineError.requestFailed);
  }

  static OcrAiRefineException _mapApiError(AiApiException error) {
    switch (error.code) {
      case AiApiErrorCode.noNetwork:
        return OcrAiRefineException(
          OcrAiRefineError.noNetwork,
          error.message,
        );
      case AiApiErrorCode.timeout:
        return OcrAiRefineException(OcrAiRefineError.timeout, error.message);
      case AiApiErrorCode.unauthorized:
        return OcrAiRefineException(
          OcrAiRefineError.unauthorized,
          error.message,
        );
      case AiApiErrorCode.rateLimited:
        return OcrAiRefineException(
          OcrAiRefineError.rateLimited,
          error.message,
        );
      case AiApiErrorCode.httpError:
      case AiApiErrorCode.invalidResponse:
      case AiApiErrorCode.cleartextBlocked:
      case AiApiErrorCode.invalidBaseUrl:
        return OcrAiRefineException(
          OcrAiRefineError.requestFailed,
          '${error.code.name}: ${error.message}',
        );
    }
  }
}
