// lib/features/tts/engines/openai_compat_tts_engine.dart
//
// WP4 (API-005) — TTS qua server OpenAI-compatible (POST /v1/audio/speech):
//   • Cloud: OpenAI tts-1 / tts-1-hd…
//   • Local/LAN: Kokoro (-FastAPI), Speaches, LM Studio…
//
// Khác Zalo/FPT (key cục bộ riêng trong TtsService), engine này KHÔNG lưu
// key: baseUrl + apiKey + ttsModel nằm trong store chung WP0
// (`AiProviderStore` — màn "Server & API"). `TtsService` resolve provider
// theo routing prefs rồi inject vào constructor ⇒ engine thuần HTTP, test
// được không cần SharedPreferences/thiết bị.
//
// Mẫu trực tiếp: zalo_tts_engine.dart (chunk text → tổng hợp mp3 bytes;
// TtsService ghi bytes vào file cache temp → phát qua AudioPlayer như mọi
// engine khác, KHÔNG đổi đường phát).

import 'dart:typed_data';

import 'package:in4up_ai/in4up_ai.dart';

import 'tts_engine.dart';

class OpenAiCompatTtsEngine extends TtsEngine {
  /// Provider đã resolve từ store chung WP0 (đã lọc enabled + có ttsModel).
  final AiProviderConfig provider;

  /// Client inject khi test; production = null (tạo từ provider).
  final OpenAiCompatClient? _clientOverride;

  OpenAiCompatTtsEngine({
    required this.provider,
    OpenAiCompatClient? client,
  }) : _clientOverride = client;

  @override
  String get name => provider.label.isNotEmpty
      ? 'Server TTS · ${provider.label}'
      : 'Server TTS (API)';

  @override
  String get id => 'openai_compat_tts';

  /// Giới hạn thực tế OpenAI là 4096 ký tự/request; giữ 2000 theo nhịp
  /// chuỗi engine hiện có (chuỗi fallback của TtsService có trần thời gian
  /// tổng 15s — chunk nhỏ an toàn hơn cho server LAN yếu).
  @override
  int get maxCharsPerRequest => 2000;

  /// AT WP4: đọc được VI/EN. Model per provider (tts-1/kokoro/…) — server
  /// quyết ngôn ngữ hỗ trợ thật; synthesize KHÔNG chặn ngôn ngữ khác
  /// (chain của TtsService luôn có engine khác fallback nếu server từ chối).
  @override
  List<String> get supportedLanguages => const [
        'vi-VN',
        'vi',
        'en-US',
        'en',
      ];

  /// Giọng mặc định khi user chưa chọn — 'alloy' tồn tại trên HẦU NHƯ mọi
  /// server OpenAI-compatible (OpenAI cloud, Kokoro, Speaches).
  static const String defaultVoice = 'alloy';

  /// 6 giọng chuẩn OpenAI (chuẩn hoá đều ở hầu hết server compat).
  static const List<TtsVoice> _defaultVoices = [
    TtsVoice(
      id: 'alloy',
      name: 'Alloy',
      language: 'en-US',
      gender: 'neutral',
      engine: 'OpenAI',
      isNeural: true,
    ),
    TtsVoice(
      id: 'nova',
      name: 'Nova',
      language: 'en-US',
      gender: 'female',
      engine: 'OpenAI',
      isNeural: true,
    ),
    TtsVoice(
      id: 'shimmer',
      name: 'Shimmer',
      language: 'en-US',
      gender: 'female',
      engine: 'OpenAI',
      isNeural: true,
    ),
    TtsVoice(
      id: 'echo',
      name: 'Echo',
      language: 'en-US',
      gender: 'male',
      engine: 'OpenAI',
      isNeural: true,
    ),
    TtsVoice(
      id: 'onyx',
      name: 'Onyx',
      language: 'en-US',
      gender: 'male',
      engine: 'OpenAI',
      isNeural: true,
    ),
    TtsVoice(
      id: 'fable',
      name: 'Fable',
      language: 'en-US',
      gender: 'neutral',
      engine: 'OpenAI',
      isNeural: true,
    ),
  ];

  OpenAiCompatClient _client() =>
      _clientOverride ??
      OpenAiCompatClient(baseUrl: provider.baseUrl, apiKey: provider.apiKey);

  @override
  Future<bool> isAvailable() async {
    if ((provider.ttsModel ?? '').trim().isEmpty) return false;
    if (provider.baseUrl.trim().isEmpty) return false;
    final health = await _client().healthCheck();
    return health.ok;
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    final model = (provider.ttsModel ?? '').trim();
    if (model.isEmpty) {
      return TtsResult.failure(
        error:
            'Provider "${provider.label}" chưa chọn model TTS — cấu hình ở Server & API',
        engine: name,
      );
    }
    if (provider.baseUrl.trim().isEmpty) {
      return TtsResult.failure(
        error: 'Provider "${provider.label}" thiếu baseUrl',
        engine: name,
      );
    }
    if (text.trim().isEmpty) {
      return TtsResult.failure(error: 'Text trống', engine: name);
    }

    final voice = (voiceId != null && voiceId.trim().isNotEmpty)
        ? voiceId.trim()
        : defaultVoice;
    final clampedSpeed = speed.clamp(0.25, 4.0).toDouble();
    final stopwatch = Stopwatch()..start();

    try {
      final client = _client();
      final chunks = _splitText(text, maxCharsPerRequest);
      final allBytes = BytesBuilder(copy: false);

      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        if (chunk.trim().isEmpty) continue;

        try {
          final bytes = await _synthesizeWithRetry(
            client,
            model: model,
            input: chunk,
            voice: voice,
            speed: clampedSpeed,
          );
          allBytes.add(bytes);
        } on AiApiException catch (e) {
          stopwatch.stop();
          return TtsResult.failure(
            error: '${_friendlyError(e)} (đoạn ${i + 1}/${chunks.length})',
            engine: name,
          );
        }

        // Nhịp nhỏ giữa chunks — tránh binge rate-limit (tiền lệ Zalo).
        if (i < chunks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }

      stopwatch.stop();
      final data = allBytes.takeBytes();
      if (data.isEmpty) {
        return TtsResult.failure(
          error: 'Không nhận được audio data',
          engine: name,
        );
      }
      return TtsResult.successBytes(
        data: data,
        engine: '$name ($model · $voice)',
        responseTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TtsResult.failure(error: e.toString(), engine: name);
    }
  }

  /// 1 request + retry TỐI ĐA 1 lần (luật tầng API: 429/5xx → backoff).
  Future<Uint8List> _synthesizeWithRetry(
    OpenAiCompatClient client, {
    required String model,
    required String input,
    required String voice,
    required double speed,
  }) async {
    try {
      return await client.synthesizeSpeech(
        model: model,
        input: input,
        voice: voice,
        speed: speed,
      );
    } on AiApiException catch (e) {
      final retryable = e.code == AiApiErrorCode.rateLimited ||
          (e.code == AiApiErrorCode.httpError &&
              (e.statusCode ?? 0) >= 500);
      if (!retryable) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return client.synthesizeSpeech(
        model: model,
        input: input,
        voice: voice,
        speed: speed,
      );
    }
  }

  /// Thông điệp lỗi dễ hành động — KHÔNG lộ key/baseUrl trong text hiển thị
  /// (label là tên gợi nhớ user tự đặt, AN TOÀN cho UI status).
  String _friendlyError(AiApiException e) {
    switch (e.code) {
      case AiApiErrorCode.noNetwork:
        return 'Không kết nối được "${provider.label}" (mất mạng/sai địa chỉ server)';
      case AiApiErrorCode.timeout:
        return '"${provider.label}" phản hồi quá chậm (timeout)';
      case AiApiErrorCode.unauthorized:
        return 'API key sai/thiếu quyền tại "${provider.label}"';
      case AiApiErrorCode.rateLimited:
        return '"${provider.label}" đang rate-limit (429) — thử giảm tốc độ gọi';
      case AiApiErrorCode.httpError:
        return '"${provider.label}" lỗi: ${e.message}';
      case AiApiErrorCode.invalidResponse:
        return 'Dữ liệu trả về không phải audio hợp lệ: ${e.message}';
      case AiApiErrorCode.cleartextBlocked:
        return 'HTTP công cộng bị chặn (chỉ cho phép LAN/localhost)';
      case AiApiErrorCode.invalidBaseUrl:
        return 'Base URL không hợp lệ';
    }
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    final lang = language.toLowerCase();
    if (!lang.startsWith('vi') && !lang.startsWith('en')) return const [];
    try {
      final serverVoices = await _client().listVoices();
      if (serverVoices.isEmpty) return _defaultVoicesFor(language);
      return [
        for (final voiceId in serverVoices)
          TtsVoice(
            id: voiceId,
            name: voiceId,
            language: _languageOfVoiceId(voiceId, fallback: language),
            gender: _genderOfVoiceId(voiceId),
            engine: name,
            isNeural: true,
          ),
      ];
    } on AiApiException {
      // Server không có /audio/voices (endpoint không bắt buộc) — dùng list
      // giọng OpenAI mặc định.
      return _defaultVoicesFor(language);
    }
  }

  List<TtsVoice> _defaultVoicesFor(String language) => [
        for (final voice in _defaultVoices)
          TtsVoice(
            id: voice.id,
            name: voice.name,
            language: language,
            gender: voice.gender,
            engine: name,
            isNeural: true,
          ),
      ];

  /// Suy luận ngôn ngữ/giới tính từ quy ước ĐẶT TÊN voice của Kokoro:
  /// `<vùng><giới tính>_tên` — af_heart (American Female), bm_lewis
  /// (British Male), jf_gongitsune (Japanese Female)… Chỉ để hiển thị
  /// khái quát — chuẩn OpenAI KHÔNG quy định format voice id.
  static String _languageOfVoiceId(String voiceId, {required String fallback}) {
    const regionOfPrefix = {
      'a': 'en-US', // American
      'b': 'en-GB', // British
      'e': 'es-ES',
      'f': 'fr-FR',
      'h': 'hi-IN',
      'i': 'it-IT',
      'j': 'ja-JP',
      'k': 'ko-KR',
      'p': 'pt-BR',
      'z': 'zh-CN',
    };
    final match =
        RegExp(r'^([a-z])[fm]_').firstMatch(voiceId.toLowerCase());
    if (match != null) {
      final region = regionOfPrefix[match.group(1)];
      if (region != null) return region;
    }
    return fallback;
  }

  static String _genderOfVoiceId(String voiceId) {
    final match = RegExp(r'^[a-z]([fm])_').firstMatch(voiceId.toLowerCase());
    if (match != null) return match.group(1) == 'f' ? 'female' : 'male';
    switch (voiceId.toLowerCase()) {
      case 'nova':
      case 'shimmer':
        return 'female';
      case 'echo':
      case 'onyx':
        return 'male';
      default:
        return 'neutral';
    }
  }

  /// Chia text thành chunks nhỏ (y pattern Zalo: câu → dấu phẩy → cắt cứng).
  List<String> _splitText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];

    // Chia theo câu (dấu chấm, chấm hỏi, chấm than, xuống dòng)
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s*'));
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.length + sentence.length + 1 > maxLen) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }

        // Câu đơn dài hơn maxLen → cắt theo dấu phẩy
        if (sentence.length > maxLen) {
          final subParts = sentence.split(RegExp(r'(?<=[,;:])\s*'));
          final subBuffer = StringBuffer();

          for (final part in subParts) {
            if (subBuffer.length + part.length + 1 > maxLen) {
              if (subBuffer.isNotEmpty) {
                chunks.add(subBuffer.toString().trim());
                subBuffer.clear();
              }
              // Vẫn quá dài → cắt cứng
              if (part.length > maxLen) {
                for (int i = 0; i < part.length; i += maxLen) {
                  final end = (i + maxLen).clamp(0, part.length);
                  chunks.add(part.substring(i, end));
                }
              } else {
                subBuffer.write(part);
              }
            } else {
              if (subBuffer.isNotEmpty) subBuffer.write(' ');
              subBuffer.write(part);
            }
          }
          if (subBuffer.isNotEmpty) {
            buffer.write(subBuffer.toString());
          }
        } else {
          buffer.write(sentence);
        }
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(sentence);
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }
}
