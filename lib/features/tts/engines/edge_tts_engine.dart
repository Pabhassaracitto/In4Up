// lib/features/tts/engines/edge_tts_engine.dart
//
// TTS-EDGE-001 / PSRC-18 — Microsoft Edge "Read Aloud" TTS (giao thức edge-tts).
//
// Nguồn giọng ONLINE miễn phí, KHÔNG cần API key: gọi thẳng WebSocket
// endpoint "Read Aloud" của Microsoft Edge — cùng giao thức với thư viện
// tham chiếu `edge-tts` bản Python (đã nâng cấp theo v7.3.1, 2026-10):
//
//   • Kết nối: wss://speech.platform.bing.com/consumer/speech/synthesize/
//     readaloud/edge/v1?TrustedClientToken=…&ConnectionId=<uuid32>
//     &Sec-MS-GEC=<cs64-sha256>&Sec-MS-GEC-Version=2-<chromium-version>
//   • Sec-MS-GEC v2 (2026-10, edge-tts 7.3.0+): kết hợp `<16 hex CS64>-<64 hex
//     custom salted SHA-256>` trên chuỗi ascii("$fileTimeTicks$token"), với
//     ticks = unix+11644473600 (epoch 1601), làm tròn xuống bội số 300s, ×10^7.
//   • Tự hiệu chỉnh lệch đồng hồ máy (`clockSkewSeconds`) từ HTTP header `Date`
//     (RFC 2616 UTC) khi máy chủ trả 403, rồi thử lại 1 lần.
//   • Dùng `HttpClient()..userAgent = null` khi bắt tay WebSocket để `dart:io`
//     không tự ghép thêm `Dart/3.x (dart:io)` vào `User-Agent` giả danh Edge.
//   • Khung message: `speech.config` (JSON outputFormat
//     audio-24khz-48kbitrate-mono-mp3) rồi `Path:ssml` kèm SSML. Server
//     trả frame binary (header 2-byte BE length, `Path:audio`,
//     `Content-Type: audio/mpeg`) + frame text `Path:turn.end` khi xong.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'tts_engine.dart';

class EdgeTtsEngine extends TtsEngine {
  /// Client inject khi test; production = null (tự tạo + đóng theo call).
  final http.Client? _httpClientOverride;

  /// Ghi đè URL WebSocket khi chạy unit test loopback cục bộ (`ws://127.0.0.1:…`).
  @visibleForTesting
  final String Function()? wssUrlBuilderOverride;

  EdgeTtsEngine({
    http.Client? httpClient,
    @visibleForTesting this.wssUrlBuilderOverride,
  }) : _httpClientOverride = httpClient;

  @override
  String get name => 'Microsoft Edge TTS';

  @override
  String get id => 'edge_tts';

  /// Trần tham chiếu cho tầng ngoài — engine tự chia mọi text dài thành
  /// các turn ~tham số `_wsMaxChunkChars`/`wsTurnMaxEscapedBytes`.
  @override
  int get maxCharsPerRequest => 10000;

  /// Danh sách ngôn ngữ tiêu biểu hiển thị mặc định trong Cài đặt Text Studio
  /// (PSRC-18): Tiếng Việt, Tiếng Anh, Anh Anh, Trung Quốc, Hindi, Myanmar,
  /// Sri Lanka, Thái.
  static const List<String> featuredLanguages = [
    'vi-VN',
    'en-US',
    'en-GB',
    'zh-CN',
    'hi-IN',
    'my-MM',
    'si-LK',
    'th-TH',
  ];

  @override
  List<String> get supportedLanguages => const [
        'vi-VN',
        'en-US',
        'en-GB',
        'zh-CN',
        'hi-IN',
        'my-MM',
        'si-LK',
        'th-TH',
        'zh-TW',
        'ja-JP',
        'ko-KR',
        'fr-FR',
        'de-DE',
        'es-ES',
        'ru-RU',
        'pt-BR',
        'id-ID',
      ];

  // ═══════════════════════════════════════
  // HẰNG SỐ GIAO THỨC (đối chiếu edge-tts 7.3.1 `constants.py` & `drm.py`)
  // ═══════════════════════════════════════

  @visibleForTesting
  static const String trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';

  /// Version Chromium/Edge mà client giả danh — phải nâng theo upstream
  /// khi Microsoft bắt đầu reject bản cũ (xem edge-tts `constants.py`).
  @visibleForTesting
  static const String chromiumFullVersion = '143.0.3650.75';

  static const String _chromiumMajorVersion = '143';

  @visibleForTesting
  static const String secMsGecVersion = '2-$chromiumFullVersion';

  static const String _basePath =
      'speech.platform.bing.com/consumer/speech/synthesize/readaloud';

  static const String _wssBase =
      'wss://$_basePath/edge/v1?TrustedClientToken=$trustedClientToken';

  static const String _voiceListBase =
      'https://$_basePath/voices/list?trustedclienttoken=$trustedClientToken';

  /// Giây giữa epoch Unix (1970) và Windows file-time epoch (1601).
  static const int _winEpochSeconds = 11644473600;

  /// Trần byte PAYLOAD SSML đã escape cho 1 turn WebSocket (upstream: 4096).
  @visibleForTesting
  static const int wsTurnMaxEscapedBytes = 4096;

  /// Cắt sơ bộ theo CÂU (đơn vị ký tự) trước khi escape + cắt byte.
  static const int _wsMaxChunkChars = 2000;

  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _receiveIdleTimeout = Duration(seconds: 25);

  /// Độ lệch đồng hồ máy so với máy chủ Microsoft (giây) — tự động bù khi
  /// gặp HTTP 403 kèm header `Date` (`DRM.clock_skew_seconds` upstream).
  static double _clockSkewSeconds = 0.0;

  @visibleForTesting
  static double get clockSkewSeconds => _clockSkewSeconds;

  @visibleForTesting
  static void resetClockSkewForTesting() {
    _clockSkewSeconds = 0.0;
  }

  /// Cache phiên cho danh sách giọng LIVE để UI mở rộng ngôn ngữ không phải
  /// gọi mạng lặp lại mỗi lần mở sheet cài đặt.
  static List<TtsVoice>? _cachedLiveVoices;

  // ═══════════════════════════════════════
  // HẰNG SỐ MẬT MÃ Sec-MS-GEC v2 (`drm.py` edge-tts 7.3.1)
  // ═══════════════════════════════════════

  static const int _u32Mask = 0xFFFFFFFF;

  static const List<int> _sha256Initial = [
    0x6A09E667,
    0xBB67AE85,
    0x3C6EF372,
    0xA54FF53A,
    0x510E527F,
    0x9B05688C,
    0x1F83D9AB,
    0x5BE0CD19,
  ];

  static const List<int> _sha256State = [
    0xFD9FBEA2,
    0x91243CE7,
    0xBE499094,
    0xCD2E1E0A,
    0x6C006F49,
    0x04BD35AB,
    0xFEB0A7E4,
    0x03EFFBD2,
  ];

  static const List<int> _sha256Schedule = [
    0xEB24BF9E,
    0x1558691F,
    0xA0C09EE2,
    0x0CFA32BA,
    0xA622EE8C,
    0xD1DD9491,
    0xC0DD25A0,
    0xF9E70AB6,
    0xF0C31573,
    0x7058CE4E,
    0x7188E606,
    0x00E5AB33,
    0xD258B060,
    0x72766564,
  ];

  static const List<int> _sha256RoundConstants = [
    0x428A2F98,
    0x71374491,
    0xB5C0FBCF,
    0xE9B5DBA5,
    0x3956C25B,
    0x59F111F1,
    0x923F82A4,
    0xAB1C5ED5,
    0xD807AA98,
    0x12835B01,
    0x243185BE,
    0x550C7DC3,
    0x72BE5D74,
    0x80DEB1FE,
    0x9BDC06A7,
    0xC19BF174,
    0xE49B69C1,
    0xEFBE4786,
    0x0FC19DC6,
    0x240CA1CC,
    0x2DE92C6F,
    0x4A7484AA,
    0x5CB0A9DC,
    0x76F988DA,
    0x983E5152,
    0xA831C66D,
    0xB00327C8,
    0xBF597FC7,
    0xC6E00BF3,
    0xD5A79147,
    0x06CA6351,
    0x14292967,
    0x27B70A85,
    0x2E1B2138,
    0x4D2C6DFC,
    0x53380D13,
    0x650A7354,
    0x766A0ABB,
    0x81C2C92E,
    0x92722C85,
    0xA2BFE8A1,
    0xA81A664B,
    0xC24B8B70,
    0xC76C51A3,
    0xD192E819,
    0xD6990624,
    0xF40E3585,
    0x106AA070,
    0x19A4C116,
    0x1E376C08,
    0x2748774C,
    0x34B0BCB5,
    0x391C0CB3,
    0x4ED8AA4A,
    0x5B9CCA4F,
    0x682E6FF3,
    0x748F82EE,
    0x78A5636F,
    0x84C87814,
    0x8CC70208,
    0x90BEFFFA,
    0xA4506CEB,
    0xBEF9A3F7,
    0xC67178F2,
  ];

  static const int _sha256Adjustment = 0xC9DC06A7;
  static const int _sha256Sigma0Adjustment = 0x059C0B80;
  static const int _sha256Sigma1Adjustment = 0x000B92C0;

  static const List<(int, int)> _cs64Coefficients = [
    (0xE82E91B1, 0xB32700D0),
    (0x44DE24C6, 0x88DFF51D),
    (0x3BEB65BC, 0x29514038),
    (0xC89C5933, 0xB328CBDF),
    (0x8D1EC211, 0xD405B4D5),
    (0x314EF5D5, 0x26E55F3C),
    (0xE92491B1, 0x607801C6),
    (0xF0A5B9D5, 0x82B2C1FB),
    (0x06064CF3, 0xFA51A3DA),
    (0xDA79FA60, 0x207CC464),
    (0xBED20560, 0x3C3C74F3),
    (0x89F9C9F8, 0xD2D14B61),
    (0x35FA38C6, 0xBB04A2C1),
    (0xCB49E3C6, 0xC5626167),
  ];

  static const int _cs64Factor = 0x82893933;
  static const int _cs64Adjustment0 = 0xF2F90B1A;
  static const int _cs64Adjustment1 = 0x0B1A0000;

  // ═══════════════════════════════════════
  // DANH MỤC GIỌNG TRƯNG (ưu tiên 8 ngôn ngữ tiêu biểu PSRC-18, đủ nữ + nam)
  // ═══════════════════════════════════════

  static const List<TtsVoice> _voices = [
    // 1. Tiếng Việt (vi-VN)
    TtsVoice(
      id: 'vi-VN-HoaiMyNeural',
      name: 'Hoài My (Nữ, truyền cảm)',
      language: 'vi-VN',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'vi-VN-NamMinhNeural',
      name: 'Nam Minh (Nam, tự nhiên)',
      language: 'vi-VN',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 2. Tiếng Anh Mỹ (en-US)
    TtsVoice(
      id: 'en-US-AriaNeural',
      name: 'Aria (Nữ, Mỹ)',
      language: 'en-US',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'en-US-GuyNeural',
      name: 'Guy (Nam, Mỹ)',
      language: 'en-US',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'en-US-EmmaMultilingualNeural',
      name: 'Emma (Nữ, đa ngôn ngữ)',
      language: 'en-US',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 3. Tiếng Anh Anh (en-GB)
    TtsVoice(
      id: 'en-GB-SoniaNeural',
      name: 'Sonia (Nữ, Anh)',
      language: 'en-GB',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'en-GB-RyanNeural',
      name: 'Ryan (Nam, Anh)',
      language: 'en-GB',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 4. Tiếng Trung Quốc (zh-CN)
    TtsVoice(
      id: 'zh-CN-XiaoxiaoNeural',
      name: 'Xiaoxiao (Nữ, Trung)',
      language: 'zh-CN',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'zh-CN-YunjianNeural',
      name: 'Yunjian (Nam, Trung)',
      language: 'zh-CN',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 5. Tiếng Hindi (hi-IN)
    TtsVoice(
      id: 'hi-IN-SwaraNeural',
      name: 'Swara (Nữ, Ấn)',
      language: 'hi-IN',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'hi-IN-MadhurNeural',
      name: 'Madhur (Nam, Ấn)',
      language: 'hi-IN',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 6. Tiếng Myanmar (my-MM)
    TtsVoice(
      id: 'my-MM-NilarNeural',
      name: 'Nilar (Nữ, Myanmar)',
      language: 'my-MM',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'my-MM-ThihaNeural',
      name: 'Thiha (Nam, Myanmar)',
      language: 'my-MM',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 7. Tiếng Sri Lanka / Sinhala (si-LK)
    TtsVoice(
      id: 'si-LK-ThiliniNeural',
      name: 'Thilini (Nữ, Sri Lanka)',
      language: 'si-LK',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'si-LK-SameeraNeural',
      name: 'Sameera (Nam, Sri Lanka)',
      language: 'si-LK',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // 8. Tiếng Thái (th-TH)
    TtsVoice(
      id: 'th-TH-PremwadeeNeural',
      name: 'Premwadee (Nữ, Thái)',
      language: 'th-TH',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'th-TH-NiwatNeural',
      name: 'Niwat (Nam, Thái)',
      language: 'th-TH',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    // ── Các ngôn ngữ mở rộng (hiển thị khi bấm Xem thêm ngôn ngữ khác) ──
    TtsVoice(
      id: 'zh-TW-HsiaoChenNeural',
      name: 'HsiaoChen (Nữ, Đài Loan)',
      language: 'zh-TW',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'zh-TW-YunJheNeural',
      name: 'YunJhe (Nam, Đài Loan)',
      language: 'zh-TW',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'ja-JP-NanamiNeural',
      name: 'Nanami (Nữ, Nhật)',
      language: 'ja-JP',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'ja-JP-KeitaNeural',
      name: 'Keita (Nam, Nhật)',
      language: 'ja-JP',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'ko-KR-SunHiNeural',
      name: 'Sun Hi (Nữ, Hàn)',
      language: 'ko-KR',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'ko-KR-InJoonNeural',
      name: 'InJoon (Nam, Hàn)',
      language: 'ko-KR',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'fr-FR-DeniseNeural',
      name: 'Denise (Nữ, Pháp)',
      language: 'fr-FR',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'fr-FR-HenriNeural',
      name: 'Henri (Nam, Pháp)',
      language: 'fr-FR',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'de-DE-KatjaNeural',
      name: 'Katja (Nữ, Đức)',
      language: 'de-DE',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'de-DE-ConradNeural',
      name: 'Conrad (Nam, Đức)',
      language: 'de-DE',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'es-ES-ElviraNeural',
      name: 'Elvira (Nữ, TBN)',
      language: 'es-ES',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'es-ES-AlvaroNeural',
      name: 'Alvaro (Nam, TBN)',
      language: 'es-ES',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'ru-RU-SvetlanaNeural',
      name: 'Svetlana (Nữ, Nga)',
      language: 'ru-RU',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'ru-RU-DmitryNeural',
      name: 'Dmitry (Nam, Nga)',
      language: 'ru-RU',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'pt-BR-FranciscaNeural',
      name: 'Francisca (Nữ, Bồ-BR)',
      language: 'pt-BR',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'pt-BR-AntonioNeural',
      name: 'Antonio (Nam, Bồ-BR)',
      language: 'pt-BR',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'id-ID-GadisNeural',
      name: 'Gadis (Nữ, Indo)',
      language: 'id-ID',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
    TtsVoice(
      id: 'id-ID-ArdiNeural',
      name: 'Ardi (Nam, Indo)',
      language: 'id-ID',
      gender: 'male',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
  ];

  /// Giọng mặc định theo locale (mã đầy đủ `xx-YY` trước, prefix sau).
  static const Map<String, String> _defaultVoiceByLanguage = {
    'vi-vn': 'vi-VN-HoaiMyNeural',
    'vi': 'vi-VN-HoaiMyNeural',
    'en-us': 'en-US-AriaNeural',
    'en-gb': 'en-GB-SoniaNeural',
    'en': 'en-US-AriaNeural',
    'zh-tw': 'zh-TW-HsiaoChenNeural',
    'zh-hk': 'zh-TW-HsiaoChenNeural',
    'zh-cn': 'zh-CN-XiaoxiaoNeural',
    'zh': 'zh-CN-XiaoxiaoNeural',
    'hi-in': 'hi-IN-SwaraNeural',
    'hi': 'hi-IN-SwaraNeural',
    'my-mm': 'my-MM-NilarNeural',
    'my': 'my-MM-NilarNeural',
    'si-lk': 'si-LK-ThiliniNeural',
    'si': 'si-LK-ThiliniNeural',
    'th-th': 'th-TH-PremwadeeNeural',
    'th': 'th-TH-PremwadeeNeural',
    'ja-jp': 'ja-JP-NanamiNeural',
    'ja': 'ja-JP-NanamiNeural',
    'ko-kr': 'ko-KR-SunHiNeural',
    'ko': 'ko-KR-SunHiNeural',
    'fr-fr': 'fr-FR-DeniseNeural',
    'fr': 'fr-FR-DeniseNeural',
    'de-de': 'de-DE-KatjaNeural',
    'de': 'de-DE-KatjaNeural',
    'es-es': 'es-ES-ElviraNeural',
    'es': 'es-ES-ElviraNeural',
    'ru-ru': 'ru-RU-SvetlanaNeural',
    'ru': 'ru-RU-SvetlanaNeural',
    'pt-br': 'pt-BR-FranciscaNeural',
    'pt': 'pt-BR-FranciscaNeural',
    'id-id': 'id-ID-GadisNeural',
    'id': 'id-ID-GadisNeural',
  };

  /// Id giọng kiểu Edge Neural: `vi-VN-HoaiMyNeural`,
  /// `en-US-EmmaMultilingualNeural`, `zh-CN-liaoning-XiaobeiNeural`…
  /// Chỉ nhận id đúng dạng này — tránh nuốt nhầm `_selectedVoiceId` chung
  /// của TtsService (tên model Piper `vi_VN-vivos-x_low`, speaker Zalo `1`,
  /// giọng FPT `banmai`, OpenAI `alloy`…).
  static final RegExp _edgeVoicePattern = RegExp(
    r'^[a-z]{2,3}-[A-Z]{2}(?:-[A-Za-z0-9]+)*-\w+Neural(?:-V\d+)?$',
  );

  // ═══════════════════════════════════════
  // DRM Sec-MS-GEC v2 / CLOCK SKEW / KHUNG MESSAGE
  // ═══════════════════════════════════════

  /// Nhân 32-bit không dấu an toàn trên cả Dart VM 64-bit lẫn Dart Web (53-bit).
  static int _mul32(int a, int b) {
    final x = a & _u32Mask;
    final y = b & _u32Mask;
    final xLo = x & 0xFFFF;
    final xHi = (x >>> 16) & 0xFFFF;
    final yLo = y & 0xFFFF;
    final yHi = (y >>> 16) & 0xFFFF;
    return (xLo * yLo + (((xHi * yLo + xLo * yHi) & 0xFFFF) << 16)) & _u32Mask;
  }

  static int _rotr32(int value, int shift) {
    final v = value & _u32Mask;
    return ((v >>> shift) | ((v << (32 - shift)) & _u32Mask)) & _u32Mask;
  }

  static int _rol16(int value) {
    final v = value & _u32Mask;
    return (((v << 16) & _u32Mask) | (v >>> 16)) & _u32Mask;
  }

  static int _sigma0(int value) {
    final v = value & _u32Mask;
    return (_rotr32(v, 7) ^ _rotr32(v, 18) ^ (v >>> 3)) & _u32Mask;
  }

  static int _sigma1(int value) {
    final v = value & _u32Mask;
    return (_rotr32(v, 17) ^ _rotr32(v, 19) ^ (v >>> 10)) & _u32Mask;
  }

  static int _bigSigma0(int value) =>
      (_rotr32(value, 2) ^ _rotr32(value, 13) ^ _rotr32(value, 22)) & _u32Mask;

  static int _bigSigma1(int value) =>
      (_rotr32(value, 6) ^ _rotr32(value, 11) ^ _rotr32(value, 25)) & _u32Mask;

  static void _expandSha256Schedule(List<int> words, [int firstWord = 16]) {
    for (var index = firstWord; index < 64; index++) {
      final s1 = _sigma1(words[index - 2]);
      final s0 = _sigma0(words[index - 15]);
      words.add(
        (s1 + words[index - 7] + s0 + words[index - 16]) & _u32Mask,
      );
    }
  }

  static List<int> _sha256Rounds(
    List<int> state,
    List<int> words, [
    int firstRound = 0,
  ]) {
    var a = state[0];
    var b = state[1];
    var c = state[2];
    var d = state[3];
    var e = state[4];
    var f = state[5];
    var g = state[6];
    var h = state[7];

    for (var index = firstRound; index < 64; index++) {
      final k = (firstRound == 14 && index == 14)
          ? _sha256Adjustment
          : _sha256RoundConstants[index];
      final ch = (g ^ (e & (f ^ g))) & _u32Mask;
      final maj = ((a & b) | (c & (a | b))) & _u32Mask;
      final t1 = (h + _bigSigma1(e) + ch + k + words[index]) & _u32Mask;
      final t2 = (_bigSigma0(a) + maj) & _u32Mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _u32Mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _u32Mask;
    }
    return [a, b, c, d, e, f, g, h];
  }

  static List<int> _sha256Init(Uint8List data7) {
    final w14 = ((data7[0] << 16) | (data7[1] << 8) | data7[2]) & _u32Mask;
    final w15 = ((data7[3] << 24) |
            (data7[4] << 16) |
            (data7[5] << 8) |
            data7[6]) &
        _u32Mask;
    final words = <int>[
      for (var i = 0; i < 14; i++) 0,
      w14,
      w15,
    ];
    for (var index = 16; index < 30; index++) {
      var value = _sha256Schedule[index - 16];
      if (index - 2 >= 14) {
        final part = index == 16
            ? (_sigma1(words[index - 2]) ^ _sha256Sigma1Adjustment)
            : _sigma1(words[index - 2]);
        value = (value + part) & _u32Mask;
      }
      if (index - 7 >= 14) {
        value = (value + words[index - 7]) & _u32Mask;
      }
      if (index - 15 >= 14) {
        final part = index == 29
            ? (_sigma0(words[index - 15]) ^ _sha256Sigma0Adjustment)
            : _sigma0(words[index - 15]);
        value = (value + part) & _u32Mask;
      }
      words.add(value & _u32Mask);
    }
    words.add(
      (_sigma1(words[28]) +
              words[23] +
              _sigma0(words[15]) +
              words[14] +
              _sha256Adjustment -
              _sha256RoundConstants[14]) &
          _u32Mask,
    );
    _expandSha256Schedule(words, 31);
    final working = _sha256Rounds(_sha256State, words, 14);
    return [
      for (var i = 0; i < 8; i++) (_sha256Initial[i] + working[i]) & _u32Mask,
    ];
  }

  static Uint8List _sha256DigestV2(Uint8List data) {
    if (data.length < 7) {
      throw ArgumentError('Token salt must contain at least seven bytes');
    }
    final length = 57 + data.length;
    final padZeros = ((55 - (length % 64)) + 64) % 64;
    final bitLength = length * 8;
    final hi = (bitLength ~/ 0x100000000) & _u32Mask;
    final lo = bitLength & _u32Mask;

    final padded = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(data, 7))
      ..addByte(0x80)
      ..add(Uint8List(padZeros))
      ..add([
        (hi >>> 24) & 0xFF,
        (hi >>> 16) & 0xFF,
        (hi >>> 8) & 0xFF,
        hi & 0xFF,
        (lo >>> 24) & 0xFF,
        (lo >>> 16) & 0xFF,
        (lo >>> 8) & 0xFF,
        lo & 0xFF,
      ]);
    final buf = padded.takeBytes();

    var state = _sha256Init(Uint8List.sublistView(data, 0, 7));
    for (var offset = 0; offset < buf.length; offset += 64) {
      final words = <int>[
        for (var i = 0; i < 64; i += 4)
          ((buf[offset + i] << 24) |
                  (buf[offset + i + 1] << 16) |
                  (buf[offset + i + 2] << 8) |
                  buf[offset + i + 3]) &
              _u32Mask,
      ];
      _expandSha256Schedule(words, 16);
      final working = _sha256Rounds(state, words, 0);
      state = [
        for (var i = 0; i < 8; i++) (state[i] + working[i]) & _u32Mask,
      ];
    }

    final out = Uint8List(32);
    for (var i = 0; i < 8; i++) {
      final w = state[i];
      out[i * 4] = (w >>> 24) & 0xFF;
      out[i * 4 + 1] = (w >>> 16) & 0xFF;
      out[i * 4 + 2] = (w >>> 8) & 0xFF;
      out[i * 4 + 3] = w & 0xFF;
    }
    return out;
  }

  static List<int> _wordsLe4Even(Uint8List data) {
    if (data.isEmpty) return const [];
    final pad = (4 - (data.length % 4)) % 4;
    final buf = Uint8List(data.length + pad)..setRange(0, data.length, data);
    final words = <int>[
      for (var i = 0; i < buf.length; i += 4)
        (buf[i] |
                (buf[i + 1] << 8) |
                (buf[i + 2] << 16) |
                (buf[i + 3] << 24)) &
            _u32Mask,
    ];
    if (words.length.isOdd) words.add(0);
    return words;
  }

  static (int, int) _cs64Digest(Uint8List data, Uint8List digest) {
    final keyA = (digest[0] |
            (digest[1] << 8) |
            (digest[2] << 16) |
            (digest[3] << 24) |
            1) &
        _u32Mask;
    final keyB = (digest[4] |
            (digest[5] << 8) |
            (digest[6] << 16) |
            (digest[7] << 24) |
            1) &
        _u32Mask;
    final factor0 = _mul32(keyA, _cs64Factor);
    final factor1 = _mul32(keyB, _cs64Factor);

    final terms = <int>[
      for (var i = 0; i < _cs64Coefficients.length; i++)
        _mul32(_cs64Coefficients[i].$1, i.isEven ? factor0 : factor1),
    ];
    final offsets = <int>[
      for (final c in _cs64Coefficients) c.$2,
    ];

    final prefixed = Uint8List(1 + data.length)
      ..setRange(1, 1 + data.length, data);
    final dataWords = _wordsLe4Even(prefixed);
    for (var index = 0; index < dataWords.length; index++) {
      final word = dataWords[index];
      var term = _mul32(word, index.isEven ? keyA : keyB);
      var offset = _mul32(
        _rol16(word),
        index.isEven ? 0xEF0569FB : 0xC31713DB,
      );
      if (index == 0) {
        term = (term + _mul32(_cs64Adjustment0, factor0)) & _u32Mask;
        offset = (offset + _cs64Adjustment1) & _u32Mask;
      }
      terms.add(term & _u32Mask);
      offsets.add(offset & _u32Mask);
    }

    var swapAcc = 0;
    var swapLast = 0;
    var state = 0;
    var acc = 0;
    for (var index = 0; index < terms.length; index += 2) {
      final x = terms[index];
      final y = terms[index + 1];

      var t = _rol16((offsets[index] + x) & _u32Mask);
      var q = _mul32(t, 0x76F50F34);
      swapAcc =
          (swapAcc + ((_mul32(_rol16(q), 0xC3EFEA97) + q) & _u32Mask)) &
              _u32Mask;

      t = _rol16((offsets[index + 1] + y) & _u32Mask);
      q = _mul32(t, 0x1881CE3C);
      swapLast = (_mul32(_rol16(q), 0x35BD1EC9) + q) & _u32Mask;
      swapAcc = (swapAcc + swapLast) & _u32Mask;

      state = (_mul32(state, keyA) + x) & _u32Mask;
      state = _mul32(_rol16(state), 0xCF98B111);
      state = _mul32(_rol16(state), 0x87085B9F);
      state = _mul32(_rol16(state), 0x12CEB96D);
      state = _mul32(_rol16(state), 0x257E1D83);
      acc = (acc + state) & _u32Mask;

      t = (_mul32(state, keyB) + y) & _u32Mask;
      t = _mul32(_rol16(t), 0xA27416F5);
      t = _mul32(_rol16(t), 0xD38396FF);
      state = _mul32(_rol16(_mul32(_rol16(t), 0x7C932B89)), 0xBFA49F69);
      acc = (acc + state) & _u32Mask;
    }

    return ((swapLast ^ state) & _u32Mask, (swapAcc ^ acc) & _u32Mask);
  }

  static String _bytesToUpperHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString();
  }

  static double _currentAdjustedUnixSeconds() =>
      (DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0) +
      _clockSkewSeconds;

  /// Sec-MS-GEC v2 — đối chiếu `edge-tts` 7.3.1 `drm.py generate_sec_ms_gec_v2()`:
  /// trả chuỗi 81 ký tự `<16 hex CS64>-<64 hex custom SHA256>`.
  @visibleForTesting
  static String generateSecMsGec([num? unixTimestampSeconds]) {
    final effectiveSeconds =
        (unixTimestampSeconds?.toDouble() ?? _currentAdjustedUnixSeconds())
            .floor();
    var ticks = effectiveSeconds + _winEpochSeconds;
    ticks -= ticks % 300;
    final data = Uint8List.fromList(
      ascii.encode('${ticks}0000000$trustedClientToken'),
    );
    final digest = _sha256DigestV2(data);
    final (csLo, csHi) = _cs64Digest(data, digest);
    final csBytes = Uint8List.fromList([
      csLo & 0xFF,
      (csLo >>> 8) & 0xFF,
      (csLo >>> 16) & 0xFF,
      (csLo >>> 24) & 0xFF,
      csHi & 0xFF,
      (csHi >>> 8) & 0xFF,
      (csHi >>> 16) & 0xFF,
      (csHi >>> 24) & 0xFF,
    ]);
    return '${_bytesToUpperHex(csBytes)}-${_bytesToUpperHex(digest)}';
  }

  /// Parse chuỗi ngày giờ RFC 2616 / RFC 1123 (ví dụ:
  /// `Sun, 08 Nov 2026 19:45:00 GMT`) độc lập locale hệ thống (theo `b2ffbdd`
  /// của `edge-tts` 7.3.1). Trả về Unix timestamp (giây UTC) hoặc null.
  @visibleForTesting
  static double? parseRfc2616Date(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final m = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
      r'(\d{2}):(\d{2}):(\d{2})\s*(?:GMT|UTC|\+0000|-0000)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = months[m.group(2)!.toLowerCase()];
    final year = int.tryParse(m.group(3)!);
    final hour = int.tryParse(m.group(4)!);
    final minute = int.tryParse(m.group(5)!);
    final second = int.tryParse(m.group(6)!);
    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }
    final dt = DateTime.utc(year, month, day, hour, minute, second);
    return dt.millisecondsSinceEpoch / 1000.0;
  }

  /// Cập nhật `clockSkewSeconds` dựa trên HTTP header `Date` trả về từ máy chủ
  /// Microsoft (`DRM.handle_client_response_error` upstream). Trả true nếu đã
  /// parse thành công và điều chỉnh.
  @visibleForTesting
  static bool adjustClockSkewFromDateHeader(
    String? dateHeader, {
    double? clientUnixSeconds,
  }) {
    final serverTs = parseRfc2616Date(dateHeader);
    if (serverTs == null) return false;
    final clientTs = clientUnixSeconds != null
        ? clientUnixSeconds + _clockSkewSeconds
        : _currentAdjustedUnixSeconds();
    _clockSkewSeconds += serverTs - clientTs;
    return true;
  }

  /// Id ngẫu nhiên 32 hex thường (uuid4 bỏ gạch — như `connect_id()`).
  @visibleForTesting
  static String connectId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// MUID cookie — 32 hex HOA (`DRM.generate_muid`).
  @visibleForTesting
  static String generateMuid() => connectId().toUpperCase();

  /// URL WebSocket đầy đủ tham số DRM cho 1 phiên tổng hợp.
  @visibleForTesting
  static String buildWssUrl({String? connectionId, num? unixTimestampSeconds}) {
    return '$_wssBase'
        '&ConnectionId=${connectionId ?? connectId()}'
        '&Sec-MS-GEC=${generateSecMsGec(unixTimestampSeconds)}'
        '&Sec-MS-GEC-Version=$secMsGecVersion';
  }

  /// URL liệt kê giọng (endpoint HTTPS, cũng yêu cầu Sec-MS-GEC).
  @visibleForTesting
  static String buildVoiceListUrl({num? unixTimestampSeconds}) {
    return '$_voiceListBase'
        '&Sec-MS-GEC=${generateSecMsGec(unixTimestampSeconds)}'
        '&Sec-MS-GEC-Version=$secMsGecVersion';
  }

  static const String _edgeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      ' (KHTML, like Gecko) Chrome/$_chromiumMajorVersion.0.0.0 Safari/537.36'
      ' Edg/$_chromiumMajorVersion.0.0.0';

  /// Header bắt chước tiện ích Read Aloud của Edge (`WSS_HEADERS` +
  /// `DRM.headers_with_muid`). `Sec-WebSocket-Version: 13` do dart:io tự
  /// điền khi handshake.
  @visibleForTesting
  static Map<String, String> buildRequestHeaders({String? muid}) {
    return {
      'User-Agent': _edgeUserAgent,
      'Accept-Language': 'en-US,en;q=0.9',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      'Cookie': 'muid=${muid ?? generateMuid()};',
    };
  }

  /// Header dành riêng cho HTTPS `voices/list` (`VOICE_HEADERS` +
  /// `DRM.headers_with_muid` trong `edge-tts` 7.3.1).
  @visibleForTesting
  static Map<String, String> buildVoiceListHeaders({String? muid}) {
    return {
      'User-Agent': _edgeUserAgent,
      'Accept-Language': 'en-US,en;q=0.9',
      'Authority': 'speech.platform.bing.com',
      'Sec-CH-UA':
          '" Not;A Brand";v="99", "Microsoft Edge";v="$_chromiumMajorVersion",'
              ' "Chromium";v="$_chromiumMajorVersion"',
      'Sec-CH-UA-Mobile': '?0',
      'Accept': '*/*',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Dest': 'empty',
      'Cookie': 'muid=${muid ?? generateMuid()};',
    };
  }

  /// Chuỗi thời gian kiểu JS (`date_to_string()` upstream):
  /// `Fri Oct 02 2026 09:30:15 GMT+0000 (Coordinated Universal Time)`.
  @visibleForTesting
  static String edgeTimestamp([DateTime? now]) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final t = (now ?? DateTime.now()).toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${weekdays[t.weekday - 1]} ${months[t.month - 1]} ${two(t.day)} '
        '${t.year} ${two(t.hour)}:${two(t.minute)}:${two(t.second)} '
        'GMT+0000 (Coordinated Universal Time)';
  }

  /// Frame `speech.config` — chọn output MP3 24kHz/48kbps mono, bật
  /// wordBoundary `false`/`true` giống upstream (boundary WordBoundary).
  @visibleForTesting
  static String buildSpeechConfigMessage([DateTime? now]) {
    return 'X-Timestamp:${edgeTimestamp(now)}\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{'
        '"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"'
        '},'
        '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"'
        '}}}}\r\n';
  }

  /// Frame `Path:ssml` (lưu ý `X-Timestamp:…Z` — quirk phía Microsoft,
  /// upstream giữ nguyên chữ Z).
  @visibleForTesting
  static String buildSsmlMessage({
    required String requestId,
    required String ssml,
    DateTime? now,
  }) {
    return 'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${edgeTimestamp(now)}Z\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml';
  }

  /// SSML đầy đủ (`mkssml()` upstream) — [escapedText] PHẢI đã qua
  /// [escapeSsmlText].
  @visibleForTesting
  static String buildSsml({
    required String voice,
    required String rate,
    required String pitch,
    required String escapedText,
    String volume = '+0%',
  }) {
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' "
        "xml:lang='en-US'>"
        "<voice name='$voice'>"
        "<prosody pitch='$pitch' rate='$rate' volume='$volume'>"
        '$escapedText'
        '</prosody>'
        '</voice>'
        '</speak>';
  }

  /// Escape 5 ký tự XML (thứ tự `&` trước — như saxutils.escape).
  @visibleForTesting
  static String escapeSsmlText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('>', '&gt;')
        .replaceAll('<', '&lt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Thay ký tự điều khiển server không chịu (tab/\n/\r GIỮ LẠI — đúng
  /// dải của `remove_incompatible_characters()` upstream: 0-8, 11-12, 14-31).
  @visibleForTesting
  static String removeIncompatibleCharacters(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune <= 8 || (rune >= 11 && rune <= 12) || (rune >= 14 && rune <= 31)) {
        out.write(' ');
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// speed 0.25–2.0 → rate Edge `+50%`/`-25%` (đã clamp ±100% chuẩn SSML).
  @visibleForTesting
  static String formatRate(double speed) {
    final pct = ((speed - 1.0) * 100).round().clamp(-100, 100);
    final sign = pct >= 0 ? '+' : '';
    return '$sign$pct%';
  }

  /// pitch 0.5–2.0 → pitch Edge `+0Hz`…`±100Hz` (clamp cho an toàn).
  @visibleForTesting
  static String formatPitch(double pitch) {
    final hz = ((pitch - 1.0) * 100).round().clamp(-100, 100);
    final sign = hz >= 0 ? '+' : '';
    return '$sign${hz}Hz';
  }

  // ═══════════════════════════════════════
  // CHIA TEXT → TURN SSML (đã escape, ≤4096 byte)
  // ═══════════════════════════════════════

  /// Pipeline đầy đủ: làm sạch ký tự điều khiển → chia theo câu
  /// (≤[maxChars] ký tự/chunk) → escape XML → đảm bảo mỗi chunk ≤[maxBytes]
  /// byte UTF-8 (cắt ở khoảng trắng, không tách nửa entity/UTF-8).
  /// Trả về danh sách payload ĐÃ ESCAPE sẵn sàng nhét vào [buildSsml].
  @visibleForTesting
  static List<String> splitForSynthesis(
    String text, {
    int maxChars = _wsMaxChunkChars,
    int maxBytes = wsTurnMaxEscapedBytes,
  }) {
    final cleaned = removeIncompatibleCharacters(text);
    final rawChunks = splitText(cleaned, maxChars);
    final out = <String>[];
    for (final raw in rawChunks) {
      final escaped = escapeSsmlText(raw.trim());
      if (escaped.isEmpty) continue;
      if (utf8.encode(escaped).length <= maxBytes) {
        out.add(escaped);
      } else {
        out.addAll(splitEscapedByByteLength(escaped, maxBytes));
      }
    }
    return out;
  }

  /// Chia text theo câu → dấu phẩy → cắt cứng (y mẫu Zalo/OpenAI trong repo).
  @visibleForTesting
  static List<String> splitText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s*'));
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.length + sentence.length + 1 > maxLen) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        if (sentence.length > maxLen) {
          final subParts = sentence.split(RegExp(r'(?<=[,;:])\s*'));
          final subBuffer = StringBuffer();
          for (final part in subParts) {
            if (subBuffer.length + part.length + 1 > maxLen) {
              if (subBuffer.isNotEmpty) {
                chunks.add(subBuffer.toString().trim());
                subBuffer.clear();
              }
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

  /// Cắt text ĐÃ ESCAPE thành các phần ≤[maxBytes] byte UTF-8 — ưu tiên
  /// khoảng trắng xuống dòng/dấu cách, không cắt giữa ký tự nhiều byte,
  /// không cắt giữa XML entity (`&amp;`…).
  @visibleForTesting
  static List<String> splitEscapedByByteLength(String escaped, int maxBytes) {
    final chunks = <String>[];
    var rest = escaped.trimLeft();
    while (rest.isNotEmpty) {
      if (utf8.encode(rest).length <= maxBytes) {
        final tail = rest.trimRight();
        if (tail.isNotEmpty) chunks.add(tail);
        break;
      }
      var cut = _findCutIndexByBytes(rest, maxBytes);
      cut = _adjustCutForXmlEntity(rest, cut);
      if (cut <= 0) cut = 1; // tối thiểu tiến 1 ký tự — chặn vòng lặp vô hạn
      final head = rest.substring(0, cut).trim();
      if (head.isNotEmpty) chunks.add(head);
      rest = rest.substring(cut).trimLeft();
    }
    return chunks;
  }

  static int _findCutIndexByBytes(String s, int maxBytes) {
    var byteCount = 0;
    var lastSafe = 0;
    var lastSpace = -1;
    var index = 0;
    for (final rune in s.runes) {
      final runeBytes = rune < 0x80
          ? 1
          : rune < 0x800
              ? 2
              : rune < 0x10000
                  ? 3
                  : 4;
      if (byteCount + runeBytes > maxBytes) break;
      byteCount += runeBytes;
      index += rune > 0xFFFF ? 2 : 1;
      lastSafe = index;
      if (rune == 0x20 || rune == 0x0A) lastSpace = index;
    }
    return lastSpace > 0 ? lastSpace : lastSafe;
  }

  static int _adjustCutForXmlEntity(String s, int cut) {
    if (cut <= 0) return cut;
    final amp = s.lastIndexOf('&', cut - 1);
    if (amp < 0) return cut;
    final semi = s.indexOf(';', amp);
    if (semi >= 0 && semi < cut) return cut; // entity đã đóng trước cut
    return amp;
  }

  // ═══════════════════════════════════════
  // PARSE FRAME TRẢ VỀ
  // ═══════════════════════════════════════

  @visibleForTesting
  static Map<String, String> parseHeaderBlock(String block) {
    final headers = <String, String>{};
    for (final line in block.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      if (key.isEmpty) continue;
      headers[key] = line.substring(idx + 1).trim();
    }
    return headers;
  }

  @visibleForTesting
  static ({Map<String, String> headers, String body}) parseTextFrame(
      String frame) {
    final sep = frame.indexOf('\r\n\r\n');
    if (sep < 0) return (headers: parseHeaderBlock(frame), body: '');
    return (
      headers: parseHeaderBlock(frame.substring(0, sep)),
      body: frame.substring(sep + 4),
    );
  }

  @visibleForTesting
  static Uint8List? parseAudioFrame(Uint8List frame) {
    if (frame.length < 2) return null;
    final headerLen = (frame[0] << 8) | frame[1];
    if (headerLen < 2 || headerLen + 2 > frame.length) return null;

    final headers = parseHeaderBlock(
      utf8.decode(frame.sublist(2, headerLen), allowMalformed: true),
    );
    if (headers['Path'] != 'audio') return null;

    final body = frame.sublist(headerLen + 2);
    final contentType = headers['Content-Type'];
    if (contentType == null) return null;
    if (contentType.toLowerCase() != 'audio/mpeg') return null;
    if (body.isEmpty) return null;
    return body;
  }

  // ═══════════════════════════════════════
  // CHỌN GIỌNG
  // ═══════════════════════════════════════

  static bool isEdgeVoiceId(String voiceId) =>
      _edgeVoicePattern.hasMatch(voiceId.trim());

  /// Giọng mặc định cho ngôn ngữ (`vi-VN` – HoaiMy, `en-US` – Aria…).
  static String defaultVoiceForLanguage(String language) {
    final norm = language.trim().replaceAll('_', '-').toLowerCase();
    final direct = _defaultVoiceByLanguage[norm];
    if (direct != null) return direct;
    final prefix = norm.split('-').first;
    return _defaultVoiceByLanguage[prefix] ?? 'en-US-AriaNeural';
  }

  /// Ưu tiên [voiceId] nếu đúng giọng Edge; sai/thiếu → mặc định theo ngôn
  /// ngữ. Đây là chốt an toàn cho việc TtsService dùng 1 voiceId chung.
  static String resolveVoice({String? voiceId, required String language}) {
    final candidate = voiceId?.trim();
    if (candidate != null && candidate.isNotEmpty && isEdgeVoiceId(candidate)) {
      return candidate;
    }
    return defaultVoiceForLanguage(language);
  }

  // ═══════════════════════════════════════
  // CATALOG OFFLINE + MERGED CATALOG CHO UI BỘ CHỌN GIỌNG
  // ═══════════════════════════════════════

  /// Toàn bộ danh mục giọng trưng offline (trật tự ưu tiên: vi-VN đầu tiên).
  static List<TtsVoice> get catalogVoices => _voices;

  /// Danh mục hợp nhất giữa giọng trưng offline (có nhãn dễ hiểu) và các
  /// ngôn ngữ/giọng LIVE đã tải được trong phiên (nếu có).
  static List<TtsVoice> get mergedCatalogVoices {
    final live = _cachedLiveVoices;
    if (live == null || live.isEmpty) return _voices;
    final seen = <String>{for (final v in _voices) v.id};
    return [
      ..._voices,
      for (final v in live)
        if (seen.add(v.id)) v,
    ];
  }

  /// Danh mục offline lọc theo [language] (đồng bộ, không mạng).
  static List<TtsVoice> catalogVoicesFor(String language) =>
      filterVoicesByLanguage(_voices, language);

  // ═══════════════════════════════════════
  // TtsEngine API
  // ═══════════════════════════════════════

  Future<http.Response> _getVoiceListResponse(
    http.Client client, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    var res = await client
        .get(
          Uri.parse(buildVoiceListUrl()),
          headers: buildVoiceListHeaders(),
        )
        .timeout(timeout);
    if (res.statusCode == 403 &&
        adjustClockSkewFromDateHeader(res.headers['date'])) {
      res = await client
          .get(
            Uri.parse(buildVoiceListUrl()),
            headers: buildVoiceListHeaders(),
          )
          .timeout(timeout);
    }
    return res;
  }

  /// Khi WebSocket bị từ chối (ví dụ HTTP 403 do đồng hồ máy người dùng lệch
  /// >5 phút so với UTC), gọi nhanh endpoint `voices/list` để đọc header
  /// `Date` của máy chủ Microsoft và đồng bộ lại `_clockSkewSeconds`.
  Future<void> _syncClockSkewFromServer() async {
    final client = _httpClientOverride ?? http.Client();
    try {
      final res = await client
          .get(
            Uri.parse(buildVoiceListUrl()),
            headers: buildVoiceListHeaders(),
          )
          .timeout(const Duration(seconds: 4));
      adjustClockSkewFromDateHeader(res.headers['date']);
    } catch (_) {
      // Best-effort: không được chặn luồng retry nếu probe cũng lỗi mạng.
    } finally {
      if (_httpClientOverride == null) client.close();
    }
  }

  @override
  Future<bool> isAvailable() async {
    final client = _httpClientOverride ?? http.Client();
    try {
      final res = await _getVoiceListResponse(client);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (_httpClientOverride == null) client.close();
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    if (text.trim().isEmpty) {
      return TtsResult.failure(error: 'Text trống', engine: name);
    }

    final stopwatch = Stopwatch()..start();

    try {
      final chunks = splitForSynthesis(text);
      if (chunks.isEmpty) {
        return TtsResult.failure(
          error: 'Không có nội dung hợp lệ sau khi làm sạch',
          engine: name,
        );
      }

      final voice = resolveVoice(voiceId: voiceId, language: language);
      final rate = formatRate(speed);
      final pitchStr = formatPitch(pitch);

      final allBytes = BytesBuilder(copy: false);
      for (var i = 0; i < chunks.length; i++) {
        Uint8List? audio;
        Object? lastError;

        // 1 retry nhẹ cho cả turn: vừa làm mới token sát mốc đổi ca 5 phút,
        // vừa đồng bộ lệch đồng hồ máy nếu lần đầu gặp HTTP 403.
        for (var attempt = 0; attempt < 2 && audio == null; attempt++) {
          try {
            audio = await _synthesizeTurn(
              chunks[i],
              voice: voice,
              rate: rate,
              pitch: pitchStr,
            );
          } catch (e) {
            lastError = e;
            debugPrint(
              '⚠️ Edge TTS turn ${i + 1}/${chunks.length} lỗi (lần ${attempt + 1}): $e',
            );
            if (attempt == 0) {
              if (e is WebSocketException) {
                await _syncClockSkewFromServer();
              }
              await Future<void>.delayed(const Duration(milliseconds: 350));
            }
          }
        }

        if (audio == null || audio.isEmpty) {
          stopwatch.stop();
          return TtsResult.failure(
            error: _friendlyError(lastError),
            engine: '$name ($voice)',
          );
        }

        allBytes.add(audio);

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
        engine: '$name ($voice)',
        responseTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TtsResult.failure(error: e.toString(), engine: name);
    }
  }

  /// Một turn WebSocket hoàn chỉnh cho 1 payload SSML đã escape.
  Future<Uint8List> _synthesizeTurn(
    String escapedChunk, {
    required String voice,
    required String rate,
    required String pitch,
  }) async {
    // QUAN TRỌNG: `WebSocket.connect` mặc định dùng `HttpClient()` nội bộ có
    // sẵn `userAgent = 'Dart/3.x (dart:io)'` rồi gọi `request.headers.add`,
    // làm rò rỉ 2 dòng User-Agent lên máy chủ Edge. Truyền `customClient` với
    // `userAgent = null` để chỉ gửi duy nhất User-Agent của Edge Chromium.
    final customClient = HttpClient()..userAgent = null;
    WebSocket? ws;
    try {
      final targetWssUrl = wssUrlBuilderOverride != null
          ? wssUrlBuilderOverride!()
          : buildWssUrl();
      ws = await WebSocket.connect(
        targetWssUrl,
        headers: buildRequestHeaders(),
        customClient: customClient,
      ).timeout(_connectTimeout);

      ws.pingInterval = const Duration(seconds: 5);

      ws.add(buildSpeechConfigMessage());
      ws.add(
        buildSsmlMessage(
          requestId: connectId(),
          ssml: buildSsml(
            voice: voice,
            rate: rate,
            pitch: pitch,
            escapedText: escapedChunk,
          ),
        ),
      );

      final audio = BytesBuilder(copy: false);
      var turnEnded = false;

      await for (final event in ws.timeout(_receiveIdleTimeout)) {
        if (event is String) {
          final parsed = parseTextFrame(event);
          if (parsed.headers['Path'] == 'turn.end') {
            turnEnded = true;
            break;
          }
        } else if (event is List<int>) {
          final payload = parseAudioFrame(
            event is Uint8List ? event : Uint8List.fromList(event),
          );
          if (payload != null) audio.add(payload);
        }
      }

      final data = audio.takeBytes();
      if (data.isEmpty) {
        throw StateError(
          turnEnded
              ? 'Edge TTS kết thúc turn nhưng không có audio'
              : 'Kết nối Edge TTS đóng trước khi gửi audio',
        );
      }
      return data;
    } finally {
      try {
        await ws?.close();
      } catch (_) {}
      customClient.close(force: false);
    }
  }

  String _friendlyError(Object? error) {
    if (error == null) return 'Không nhận được audio từ Edge TTS';
    if (error is TimeoutException) {
      return 'Edge TTS phản hồi quá chậm (timeout)';
    }
    if (error is SocketException) {
      return 'Không kết nối được máy chủ Edge TTS (mất mạng / bị chặn)';
    }
    if (error is WebSocketException) {
      return 'Edge TTS từ chối kết nối WebSocket: ${error.message}';
    }
    return 'Edge TTS lỗi: $error';
  }

  /// Nạp toàn bộ danh mục giọng LIVE (nếu có mạng) và hợp nhất với danh mục
  /// offline. Dùng khi người dùng bấm mở rộng danh sách ngôn ngữ khác.
  Future<List<TtsVoice>> loadMergedCatalogVoices() async {
    try {
      final live = await _fetchLiveVoices().timeout(
        const Duration(seconds: 8),
        onTimeout: () => const <TtsVoice>[],
      );
      if (live.isNotEmpty && _httpClientOverride == null) {
        _cachedLiveVoices = live;
      }
      if (live.isNotEmpty) {
        final seen = <String>{for (final v in _voices) v.id};
        return [
          ..._voices,
          for (final v in live)
            if (seen.add(v.id)) v,
        ];
      }
    } catch (_) {}
    return mergedCatalogVoices;
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    try {
      final live = await _fetchLiveVoices().timeout(
        const Duration(seconds: 8),
        onTimeout: () => const <TtsVoice>[],
      );
      if (live.isNotEmpty) {
        if (_httpClientOverride == null) {
          _cachedLiveVoices = live;
        }
        final filtered = _filterByLanguage(live, language);
        if (filtered.isNotEmpty) return filtered;
      }
    } catch (_) {}
    return _filterByLanguage(_voices, language);
  }

  Future<List<TtsVoice>> _fetchLiveVoices() async {
    final client = _httpClientOverride ?? http.Client();
    try {
      final res = await _getVoiceListResponse(
        client,
        timeout: const Duration(seconds: 8),
      );
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! List) return const [];

      final voices = <TtsVoice>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final shortName = item['ShortName']?.toString() ?? '';
        if (shortName.isEmpty) continue;
        final locale = item['Locale']?.toString() ??
            shortName.split('-').take(2).join('-');
        final friendly = item['FriendlyName']?.toString();
        final gender = (item['Gender']?.toString() ?? 'unknown').toLowerCase();
        voices.add(
          TtsVoice(
            id: shortName,
            name: (friendly != null && friendly.trim().isNotEmpty)
                ? friendly
                    .replaceFirst('Microsoft ', '')
                    .replaceFirst(' Online (Natural)', '')
                : shortName,
            language: locale,
            gender: gender,
            engine: name,
            isNeural: shortName.contains('Neural'),
          ),
        );
      }
      return voices;
    } finally {
      if (_httpClientOverride == null) client.close();
    }
  }

  /// Lọc theo ngôn ngữ: khớp đúng locale trước (`vi-VN`), không có thì theo
  /// prefix (`vi` → mọi `vi-*`). Trùng lặp theo id giữ 1 bản đầu.
  @visibleForTesting
  static List<TtsVoice> filterVoicesByLanguage(
    List<TtsVoice> voices,
    String language,
  ) {
    final norm = language.trim().toLowerCase();
    final prefix = norm.split('-').first;
    final seen = <String>{};
    final exact = <TtsVoice>[];
    final byPrefix = <TtsVoice>[];
    for (final v in voices) {
      if (!seen.add(v.id)) continue;
      final vl = v.language.toLowerCase();
      if (vl == norm) {
        exact.add(v);
      } else if (vl == prefix || vl.startsWith('$prefix-')) {
        byPrefix.add(v);
      }
    }
    return exact.isNotEmpty ? exact : byPrefix;
  }

  List<TtsVoice> _filterByLanguage(List<TtsVoice> voices, String language) =>
      filterVoicesByLanguage(voices, language);
}
