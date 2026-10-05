// lib/features/tts/engines/edge_tts_engine.dart
//
// TTS-EDGE-001 — Microsoft Edge "Read Aloud" TTS (giao thức edge-tts).
//
// Nguồn giọng ONLINE miễn phí, KHÔNG cần API key: gọi thẳng WebSocket
// endpoint "Read Aloud" của Microsoft Edge — cùng giao thức với thư viện
// tham chiếu `edge-tts` bản Python (đã đối chiếu theo v7.2.8, mới nhất
// 2026-10):
//
//   • Kết nối: wss://speech.platform.bing.com/consumer/speech/synthesize/
//     readaloud/edge/v1?TrustedClientToken=…&ConnectionId=<uuid32>
//     &Sec-MS-GEC=<sha256>&Sec-MS-GEC-Version=1-<chromium-version>
//   • Sec-MS-GEC (DRM mềm, thêm 2024-11): sha256(ascii(ticks + token))
//     UPPER-HEX, ticks = unix+11644473600 (đổi epoch → 1601), làm tròn
//     XUỐNG bội số 300 giây, rồi ×10^7 (đơn vị 100ns → đúng "file time").
//   • Header WS bắt chước Edge extension: Origin chrome-extension://…,
//     Cookie muid=<hex32 hoa>, UA Chrome/143.
//   • Khung message: `speech.config` (JSON outputFormat
//     audio-24khz-48kbitrate-mono-mp3) rồi `Path:ssml` kèm SSML. Server
//     trả frame binary (header 2-byte BE length, `Path:audio`,
//     `Content-Type: audio/mpeg`) + frame text `Path:turn.end` khi xong.
//
// Mỗi "turn" WebSocket chịu ~4096 byte payload (theo upstream) — engine tự
// chia text dài: câu → dấu phẩy → cắt cứng (mẫu Zalo/OpenAI của repo),
// rồi cắt byte-an-toàn (không tách nửa ký tự UTF-8, không tách giữa XML
// entity). MP3 bytes các turn nối tiếp phát được như 1 file (tiền lệ
// Google/Zalo: TtsService ghi bytes → file cache temp → just_audio).
//
// Không lưu key, không đụng kho cấu hình của app — tương tự GoogleTtsEngine;
// chuỗi fallback ngoài TtsService lo: `_trySpeakOnline` check mạng trước,
// timeout 15s → engine kế → cuối cùng emergency Offline (Máy) như hiện tại.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'tts_engine.dart';

class EdgeTtsEngine extends TtsEngine {
  /// Client inject khi test; production = null (tự tạo + đóng theo call).
  final http.Client? _httpClientOverride;

  EdgeTtsEngine({http.Client? httpClient}) : _httpClientOverride = httpClient;

  @override
  String get name => 'Microsoft Edge TTS';

  @override
  String get id => 'edge_tts';

  /// Trần tham chiếu cho tầng ngoài — engine tự chia mọi text dài thành
  /// các turn ~tham số `_wsMaxChunkChars`/`_wsTurnMaxEscapedBytes`.
  @override
  int get maxCharsPerRequest => 10000;

  @override
  List<String> get supportedLanguages => const [
        'vi-VN',
        'en-US',
        'en-GB',
        'ja-JP',
        'ko-KR',
        'zh-CN',
        'zh-TW',
        'th-TH',
        'fr-FR',
        'de-DE',
        'es-ES',
        'ru-RU',
        'pt-BR',
        'id-ID',
        'hi-IN',
      ];

  // ═══════════════════════════════════════
  // HẰNG SỐ GIAO THỨC (đối chiếu edge-tts 7.2.8 `constants.py`)
  // ═══════════════════════════════════════

  @visibleForTesting
  static const String trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';

  /// Version Chromium/Edge mà client giả danh — phải nâng theo upstream
  /// khi Microsoft bắt đầu reject bản cũ (xem edge-tts `constants.py`).
  @visibleForTesting
  static const String chromiumFullVersion = '143.0.3650.75';

  @visibleForTesting
  static const String secMsGecVersion = '1-$chromiumFullVersion';

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

  // ═══════════════════════════════════════
  // DANH MỤC GIỌNG TRƯNG (ưu tiên vi-VN theo yêu cầu)
  // ═══════════════════════════════════════

  static const List<TtsVoice> _voices = [
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
    TtsVoice(
      id: 'en-GB-SoniaNeural',
      name: 'Sonia (Nữ, Anh)',
      language: 'en-GB',
      gender: 'female',
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
    TtsVoice(
      id: 'zh-TW-HsiaoChenNeural',
      name: 'HsiaoChen (Nữ, Đài Loan)',
      language: 'zh-TW',
      gender: 'female',
      engine: 'Microsoft Edge',
      isNeural: true,
    ),
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
    TtsVoice(
      id: 'fr-FR-DeniseNeural',
      name: 'Denise (Nữ, Pháp)',
      language: 'fr-FR',
      gender: 'female',
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
      id: 'es-ES-ElviraNeural',
      name: 'Elvira (Nữ, TBN)',
      language: 'es-ES',
      gender: 'female',
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
      id: 'pt-BR-FranciscaNeural',
      name: 'Francisca (Nữ, Bồ-BR)',
      language: 'pt-BR',
      gender: 'female',
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
      id: 'hi-IN-SwaraNeural',
      name: 'Swara (Nữ, Ấn)',
      language: 'hi-IN',
      gender: 'female',
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
    'ja-jp': 'ja-JP-NanamiNeural',
    'ja': 'ja-JP-NanamiNeural',
    'ko-kr': 'ko-KR-SunHiNeural',
    'ko': 'ko-KR-SunHiNeural',
    'zh-tw': 'zh-TW-HsiaoChenNeural',
    'zh-hk': 'zh-TW-HsiaoChenNeural',
    'zh-cn': 'zh-CN-XiaoxiaoNeural',
    'zh': 'zh-CN-XiaoxiaoNeural',
    'th-th': 'th-TH-PremwadeeNeural',
    'th': 'th-TH-PremwadeeNeural',
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
    'hi-in': 'hi-IN-SwaraNeural',
    'hi': 'hi-IN-SwaraNeural',
  };

  /// Id giọng kiểu Edge Neural: `vi-VN-HoaiMyNeural`,
  /// `en-US-EmmaMultilingualNeural`… Chỉ nhận id đúng dạng này — tránh
  /// nuốt nhầm `_selectedVoiceId` chung của TtsService (tên model Piper
  /// `vi_VN-vivos-x_low`, speaker Zalo `1`, giọng FPT `banmai`…).
  static final RegExp _edgeVoicePattern =
      RegExp(r'^[a-z]{2,3}-[A-Z]{2}-\w+Neural$');

  // ═══════════════════════════════════════
  // DRM / KHUNG MESSAGE — hàm thuần, test được không mạng
  // ═══════════════════════════════════════

  /// Sec-MS-GEC — đối chiếu edge-tts `drm.py generate_sec_ms_gec()`:
  /// ticks = (unix + 11644473600); làm tròn xuống bội số 300; ×10^7
  /// (đơn vị 100ns); sha256-UPPER(ascii("$ticks$token")).
  @visibleForTesting
  static String generateSecMsGec([int? unixTimestampSeconds]) {
    var ticks =
        (unixTimestampSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000) +
            _winEpochSeconds;
    ticks -= ticks % 300;
    final fileTimeTicks = ticks * 10000000;
    final digest =
        sha256.convert(ascii.encode('$fileTimeTicks$trustedClientToken'));
    return digest.toString().toUpperCase();
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
  static String buildWssUrl({String? connectionId, int? unixTimestampSeconds}) {
    return '$_wssBase'
        '&ConnectionId=${connectionId ?? connectId()}'
        '&Sec-MS-GEC=${generateSecMsGec(unixTimestampSeconds)}'
        '&Sec-MS-GEC-Version=$secMsGecVersion';
  }

  /// URL liệt kê giọng (endpoint HTTPS, cũng yêu cầu Sec-MS-GEC).
  @visibleForTesting
  static String buildVoiceListUrl({int? unixTimestampSeconds}) {
    return '$_voiceListBase'
        '&Sec-MS-GEC=${generateSecMsGec(unixTimestampSeconds)}'
        '&Sec-MS-GEC-Version=$secMsGecVersion';
  }

  /// Header bắt chước tiện ích Read Aloud của Edge (`WSS_HEADERS` +
  /// `DRM.headers_with_muid`). `Sec-WebSocket-Version: 13` do dart:io tự
  /// điền khi handshake.
  @visibleForTesting
  static Map<String, String> buildRequestHeaders({String? muid}) {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
              ' (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36'
              ' Edg/143.0.0.0',
      'Accept-Language': 'en-US,en;q=0.9',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
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

  /// Thay ký tự điều khiển server không chịu (tab/\\n/\\r GIỮ LẠI — đúng
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

  /// Chỉ số code-unit cắt lớn nhất sao cho prefix ≤ [maxBytes] byte UTF-8,
  /// ưu tiên LÀN CUỐI ngay sau khoảng trắng (`\n`/dấu cách).
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

  /// Lùi điểm cắt nếu nó rơi GIỮA một XML entity (`&…;`) — đưa về trước `&`.
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

  /// Parse block header dạng `Key:value\r\nKey:value` (không phân biệt
  /// khoảng trắng thừa quanh value — trim khi so khớp).
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

  /// Parse frame TEXT của service: `(headers, body)` tách tại `\r\n\r\n`.
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

  /// Trích payload MP3 từ frame BINARY `Path:audio` (2 byte đầu = độ dài
  /// header big-endian, sau header là `\r\n` rồi mới đến audio bytes —
  /// `get_headers_and_data()` upstream).
  ///
  /// Trả null cho frame kết thúc (không `Content-Type`, không data) hoặc
  /// frame không phải audio — caller bỏ qua mà không coi là lỗi.
  /// Lưu ý layout (đúng `get_headers_and_data()` upstream): 2 byte đầu =
  /// `headerLength` TÍNH CẢ 2 byte đó; text header = bytes[2..headerLength];
  /// 2 byte kế = `\r\n`; audio = bytes[headerLength+2..].
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
    if (contentType == null) return null; // frame kết thúc hợp lệ, không data
    if (contentType.toLowerCase() != 'audio/mpeg') return null;
    if (body.isEmpty) return null;
    return body;
  }

  // ═══════════════════════════════════════
  // CHỌN GIỌNG
  // ═══════════════════════════════════════

  /// true nếu [voiceId] đúng dạng giọng Edge Neural (chống nhầm id của
  /// engine khác: Piper/Zalo/FPT/OpenAI dùng chung `_selectedVoiceId`).
  @visibleForTesting
  static bool isEdgeVoiceId(String voiceId) =>
      _edgeVoicePattern.hasMatch(voiceId.trim());

  /// Giọng mặc định cho ngôn ngữ (`vi-VN`– HoaiMy, `en-US` – Aria…).
  @visibleForTesting
  static String defaultVoiceForLanguage(String language) {
    final norm = language.trim().toLowerCase();
    final direct = _defaultVoiceByLanguage[norm];
    if (direct != null) return direct;
    final prefix = norm.split('-').first;
    return _defaultVoiceByLanguage[prefix] ?? 'en-US-AriaNeural';
  }

  /// Ưu tiên [voiceId] nếu đúng giọng Edge; sai/thiếu → mặc định theo ngôn
  /// ngữ. Đây là chốt an toàn cho việc TtsService dùng 1 voiceId chung.
  @visibleForTesting
  static String resolveVoice({String? voiceId, required String language}) {
    final candidate = voiceId?.trim();
    if (candidate != null && candidate.isNotEmpty && isEdgeVoiceId(candidate)) {
      return candidate;
    }
    return defaultVoiceForLanguage(language);
  }

  // ═══════════════════════════════════════
  // CATALOG OFFLINE (đồng bộ, KHÔNG mạng) — cho UI bộ chọn giọng
  // ═══════════════════════════════════════
  //
  // TTS-EDGE-VOICE-001: `getAvailableVoices` (async) ưu tiên fetch LIVE từ
  // endpoint rồi mới fallback offline — UI bộ chọn KHÔNG thể chờ mạng mỗi lần
  // mở settings. Hai getter DƯỚI là bản đồng bộ của danh mục trưng offline,
  // để UI render tức thì; mạng vẫn chỉ dùng khi THỰC TẾ tổng hợp.

  /// Toàn bộ danh mục giọng trưng offline (trật tự ưu tiên: vi-VN đầu tiên).
  static List<TtsVoice> get catalogVoices => _voices;

  /// Danh mục offline lọc theo [language] (đồng bộ, không mạng).
  /// Dùng `filterVoicesByLanguage` chung với `getAvailableVoices`.
  static List<TtsVoice> catalogVoicesFor(String language) =>
      filterVoicesByLanguage(_voices, language);

  // ═══════════════════════════════════════
  // TtsEngine API
  // ═══════════════════════════════════════

  @override
  Future<bool> isAvailable() async {
    final client = _httpClientOverride ?? http.Client();
    try {
      final res = await client
          .get(
            Uri.parse(buildVoiceListUrl()),
            headers: buildRequestHeaders(),
          )
          .timeout(const Duration(seconds: 6));
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

        // 1 retry nhẹ cho cả turn: Sec-MS-GEC sống theo mốc 5 phút —
        // regenerate nguyên URL tự nhiên "làm mới" token sát mốc đổi ca.
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
              await Future<void>.delayed(const Duration(milliseconds: 400));
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

        // Nhịp nhỏ giữa các turn (tiền lệ Zalo/OpenAI: chống binge).
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
    final ws = await WebSocket.connect(
      buildWssUrl(),
      headers: buildRequestHeaders(),
    ).timeout(_connectTimeout);

    try {
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

      // `.timeout` theo khoảng YÊN: stream của Edge đẩy audio liên tục;
      // im lặng quá ngưỡng ⇒ coi như treo, cắt để chuỗi fallback chạy.
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
        await ws.close();
      } catch (_) {}
    }
  }

  /// Thông điệp lỗi dễ hành động; KHÔNG lộ query params; URL đầy đủ khá ồn
  /// phải bí mật nhưng URL query khá ồn — chỉ giữ phần lõi.
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

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    // 1) Thử danh sách TRỰC TIẾP từ endpoint (luôn mới nhất, cập nhật khi
    // Microsoft thêm/bớt giọng). 2) Hỏng/rỗng → danh mục trưng offline.
    try {
      final live = await _fetchLiveVoices()
          .timeout(const Duration(seconds: 8), onTimeout: () => const <TtsVoice>[]);
      if (live.isNotEmpty) {
        final filtered = _filterByLanguage(live, language);
        if (filtered.isNotEmpty) return filtered;
      }
    } catch (_) {}
    return _filterByLanguage(_voices, language);
  }

  Future<List<TtsVoice>> _fetchLiveVoices() async {
    final client = _httpClientOverride ?? http.Client();
    try {
      final res = await client.get(
        Uri.parse(buildVoiceListUrl()),
        headers: buildRequestHeaders(),
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
        final gender = (item['Gender']?.toString() ?? 'unknown').toLowerCase();
        voices.add(
          TtsVoice(
            id: shortName,
            name: shortName,
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
