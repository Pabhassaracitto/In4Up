// test/edge_tts_engine_test.dart — TTS-EDGE-001
//
// Test logic thuần của EdgeTtsEngine (KHÔNG chạm network thật):
//  - Sec-MS-GEC (DRM mềm): known-vector sinh bằng thư viện tham chiếu
//    edge-tts (Python) 7.2.8 cho timestamp cố định.
//  - Khung message speech.config / SSML, escape XML, timestamp kiểu JS.
//  - Chia text → turn SSML: ranh câu, ≤4096 byte, không tách UTF-8/entity.
//  - Parse frame trả về (audio binary + text turn.end).
//  - Chọn giọng: chống nuốt nhầm voiceId của engine khác (Piper/Zalo/FPT).
//  - isAvailable / getAvailableVoices qua http.Client GIẢ.
//  - Source-scan: pin đăng ký trong TtsService (không sửa behaviour cũ).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:in4up/features/tts/engines/edge_tts_engine.dart';
import 'package:in4up/features/tts/engines/tts_engine.dart';

/// HTTP client giả — phản hồi theo hành vi test dựng, không chạm network.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.onRequest);

  final Future<http.StreamedResponse> Function(http.BaseRequest) onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      onRequest(request);
}

http.StreamedResponse _resp(int status, [String body = '']) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), status);
}

EdgeTtsEngine _engineReturning(int status, [String body = '']) =>
    EdgeTtsEngine(httpClient: _FakeHttpClient((_) async => _resp(status, body)));

EdgeTtsEngine _engineThrowing() => EdgeTtsEngine(
      httpClient: _FakeHttpClient(
        (_) async => throw const SocketException('no network'),
      ),
    );

/// Dựng frame binary `Path:audio` đúng layout server:
/// 2 byte đầu = headerLength (TÍNH CẢ 2 byte đó) big-endian,
/// header text, `\r\n`, rồi payload.
Uint8List _frame({
  required String header,
  List<int> body = const [0xFF, 0xFB, 1, 2, 3],
}) {
  final headerBytes = utf8.encode(header);
  final headerLen = 2 + headerBytes.length;
  return Uint8List.fromList([
    headerLen >> 8,
    headerLen & 0xFF,
    ...headerBytes,
    0x0D,
    0x0A,
    ...body,
  ]);
}

void main() {
  group('EdgeTtsEngine — metadata', () {
    test('id/name/limit theo spec task', () {
      final engine = EdgeTtsEngine();
      expect(engine.id, 'edge_tts');
      expect(engine.name, 'Microsoft Edge TTS');
      expect(engine.maxCharsPerRequest, 10000);
      expect(
        engine.supportedLanguages,
        containsAll(['vi-VN', 'en-US', 'ja-JP', 'zh-CN', 'th-TH']),
      );
    });
  });

  group('Sec-MS-GEC (DRM mềm)', () {
    // Known-vector sinh từ edge-tts 7.2.8 DRM.generate_sec_ms_gec():
    //   ticks = ts + 11644473600; ticks -= ticks % 300; ticks *= 10^7
    //   sha256(ascii(f"{ticks}{TRUSTED_CLIENT_TOKEN}")).hexdigest().upper()
    test('known-vector ts=1730000000', () {
      expect(
        EdgeTtsEngine.generateSecMsGec(1730000000),
        '68EBC40536E04FEDEC126E928E3BD86045309ED62EA865F537896B0A96858D3B',
      );
    });

    test('known-vector ts=1759641037', () {
      expect(
        EdgeTtsEngine.generateSecMsGec(1759641037),
        '4DEED9068EE61E7C3E9314BD22F7713246DC5A6B7C304A7CE3B00B5A480B047F',
      );
    });

    test('ổn định trong cùng cửa sổ 5 phút, khác nhau giữa 2 cửa sổ', () {
      final a = EdgeTtsEngine.generateSecMsGec(1759641037);
      final b = EdgeTtsEngine.generateSecMsGec(1759641099); // cùng mốc 300s
      final c = EdgeTtsEngine.generateSecMsGec(1759641300); // mốc kế
      expect(a, b);
      expect(a, isNot(c));
    });

    test('không tham số → 64 hex HOA', () {
      final gec = EdgeTtsEngine.generateSecMsGec();
      expect(gec.length, 64);
      expect(gec, RegExp(r'^[0-9A-F]{64}$'));
    });
  });

  group('URL & headers bắt chước Edge', () {
    test('WSS URL đủ TrustedClientToken + DRM + ConnectionId', () {
      final url = EdgeTtsEngine.buildWssUrl(
        connectionId: 'a' * 32,
        unixTimestampSeconds: 1730000000,
      );
      expect(url, startsWith('wss://speech.platform.bing.com/'));
      expect(url, contains('TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4'));
      expect(url, contains('ConnectionId=${'a' * 32}'));
      expect(
        url,
        contains(
          'Sec-MS-GEC=68EBC40536E04FEDEC126E928E3BD86045309'
          'ED62EA865F537896B0A96858D3B',
        ),
      );
      expect(url, contains('Sec-MS-GEC-Version=1-143.0.3650.75'));
    });

    test('voice-list URL cũng mang Sec-MS-GEC', () {
      final url = EdgeTtsEngine.buildVoiceListUrl(unixTimestampSeconds: 1730000000);
      expect(url, startsWith('https://speech.platform.bing.com/'));
      expect(url, contains('voices/list'));
      expect(url, contains('Sec-MS-GEC='));
    });

    test('headers: Origin extension + Cookie muid + UA Edg/143', () {
      final headers = EdgeTtsEngine.buildRequestHeaders(muid: 'ABC123');
      expect(
        headers['Origin'],
        'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      );
      expect(headers['Cookie'], 'muid=ABC123;');
      expect(headers['User-Agent'], contains('Edg/143.0.0.0'));
    });

    test('muid/connectId đúng format', () {
      expect(EdgeTtsEngine.generateMuid(), RegExp(r'^[0-9A-F]{32}$'));
      expect(EdgeTtsEngine.connectId(), RegExp(r'^[0-9a-f]{32}$'));
    });
  });

  group('Khung message & SSML', () {
    test('edgeTimestamp đúng format JS', () {
      expect(
        EdgeTtsEngine.edgeTimestamp(DateTime.utc(2026, 10, 2, 9, 30, 15)),
        'Fri Oct 02 2026 09:30:15 GMT+0000 (Coordinated Universal Time)',
      );
    });

    test('speech.config chọn MP3 + boundary flags + CRLF cuối', () {
      final msg = EdgeTtsEngine.buildSpeechConfigMessage(
        DateTime.utc(2026, 10, 2, 9, 30, 15),
      );
      expect(msg, startsWith('X-Timestamp:Fri Oct 02 2026 09:30:15'));
      expect(msg, contains('Path:speech.config\r\n\r\n'));
      expect(msg, contains('"outputFormat":"audio-24khz-48kbitrate-mono-mp3"'));
      expect(msg, contains('"wordBoundaryEnabled":"true"'));
      expect(msg, endsWith('\r\n'));
    });

    test('SSML message: header + X-Timestamp đuôi Z (quirk) + body', () {
      final msg = EdgeTtsEngine.buildSsmlMessage(
        requestId: 'r1',
        ssml: '<speak/>',
        now: DateTime.utc(2026, 10, 2, 9, 30, 15),
      );
      expect(msg, startsWith('X-RequestId:r1\r\n'));
      expect(msg, contains('Content-Type:application/ssml+xml\r\n'));
      expect(msg, contains('(Coordinated Universal Time)Z\r\n'));
      expect(msg, endsWith('Path:ssml\r\n\r\n<speak/>'));
    });

    test('buildSsml đủ voice/prosody', () {
      final ssml = EdgeTtsEngine.buildSsml(
        voice: 'vi-VN-HoaiMyNeural',
        rate: '+10%',
        pitch: '-5Hz',
        escapedText: 'Xin chào',
      );
      expect(ssml, '<speak version=\'1.0\' '
          'xmlns=\'http://www.w3.org/2001/10/synthesis\' xml:lang=\'en-US\'>'
          '<voice name=\'vi-VN-HoaiMyNeural\'>'
          '<prosody pitch=\'-5Hz\' rate=\'+10%\' volume=\'+0%\'>'
          'Xin chào</prosody></voice></speak>');
    });

    test('escapeSsmlText: & trước, đủ 5 ký tự, không double-escape có thứ tự', () {
      expect(
        EdgeTtsEngine.escapeSsmlText('a & b < > " \''),
        'a &amp; b &lt; &gt; &quot; &apos;',
      );
      expect(EdgeTtsEngine.escapeSsmlText('&amp;'), '&amp;amp;');
      expect(EdgeTtsEngine.escapeSsmlText('tiếng Việt'), 'tiếng Việt');
    });

    test('formatRate/formatPitch mapping + clamp', () {
      expect(EdgeTtsEngine.formatRate(1.0), '+0%');
      expect(EdgeTtsEngine.formatRate(1.5), '+50%');
      expect(EdgeTtsEngine.formatRate(0.5), '-50%');
      expect(EdgeTtsEngine.formatRate(0.25), '-75%');
      expect(EdgeTtsEngine.formatRate(2.0), '+100%');
      expect(EdgeTtsEngine.formatRate(3.0), '+100%'); // clamp trên
      expect(EdgeTtsEngine.formatRate(0.0), '-100%'); // clamp dưới

      expect(EdgeTtsEngine.formatPitch(1.0), '+0Hz');
      expect(EdgeTtsEngine.formatPitch(1.3), '+30Hz');
      expect(EdgeTtsEngine.formatPitch(0.7), '-30Hz');
      expect(EdgeTtsEngine.formatPitch(0.5), '-50Hz');
      expect(EdgeTtsEngine.formatPitch(2.0), '+100Hz');
      expect(EdgeTtsEngine.formatPitch(3.0), '+100Hz'); // clamp
    });
  });

  group('Chia text → turn SSML', () {
    test('removeIncompatibleCharacters giữ tab/LF/CR/DEL', () {
      expect(
        EdgeTtsEngine.removeIncompatibleCharacters('\x00\x01ab\x0B\x0C\t\ncd\x7F'),
        '  ab  \t\ncd\x7F',
      );
    });

    test('splitText ngắn → 1 chunk; câu → gom theo maxLen; cắt cứng câu dài', () {
      expect(EdgeTtsEngine.splitText('abc', 10), ['abc']);

      expect(
        EdgeTtsEngine.splitText('Một hai. Ba bốn. Năm sáu.', 14),
        ['Một hai.', 'Ba bốn.', 'Năm sáu.'],
      );

      final hard = EdgeTtsEngine.splitText('x' * 30, 10);
      expect(hard.length, 3);
      expect(hard.every((c) => c.length == 10), isTrue);
    });

    test('splitForSynthesis: ký tự điều khiển → space', () {
      expect(EdgeTtsEngine.splitForSynthesis('A\x0Bb'), ['A b']);
    });

    test('splitForSynthesis: CJK không khoảng trắng — cắt cứng an toàn byte', () {
      final chunks = EdgeTtsEngine.splitForSynthesis('漢' * 100, maxBytes: 120);
      expect(chunks.join(), '漢' * 100);
      expect(chunks.length, 3); // 300 byte → 40+40+20 ký tự (3 byte/em)
      for (final c in chunks) {
        expect(utf8.encode(c).length, lessThanOrEqualTo(120));
        expect(() => utf8.encode(c), returnsNormally); // không nửa ký tự
      }
    });

    test('splitForSynthesis: emoji (surrogate pair) không bị tách nửa', () {
      final chunks = EdgeTtsEngine.splitForSynthesis('😀' * 50, maxBytes: 15);
      expect(chunks.join(), '😀' * 50);
      for (final c in chunks) {
        expect(utf8.encode(c).length, lessThanOrEqualTo(15));
        // Utf8Encoder ném FormatException nếu gặp surrogate lẻ.
        expect(() => utf8.encode(c), returnsNormally);
      }
    });

    test('splitForSynthesis: không cắt giữa XML entity (vector parity)', () {
      final chunks = EdgeTtsEngine.splitForSynthesis(
        'a & b < c d > e f & g h \' i " j k l m n o p q r s t u v w x y z',
        maxChars: 200,
        maxBytes: 40,
      );
      expect(chunks, [
        'a &amp; b &lt; c d &gt; e f &amp; g h',
        '&apos; i &quot; j k l m n o p q r s t u',
        'v w x y z',
      ]);
      for (final c in chunks) {
        expect(utf8.encode(c).length, lessThanOrEqualTo(40));
      }
    });

    test('splitEscapedByByteLength: entity đứng đầu giới hạn không bị xẻ', () {
      expect(
        EdgeTtsEngine.splitEscapedByByteLength('ab &amp; cd &lt; ef', 10),
        ['ab &amp;', 'cd &lt; ef'],
      );
      expect(
        EdgeTtsEngine.splitEscapedByByteLength('ab &amp; cd &lt; ef', 6),
        ['ab', '&amp;', 'cd', '&lt;', 'ef'],
      );
    });
  });

  group('Parse frame trả về', () {
    test('audio frame hợp lệ → payload MP3', () {
      final frame = _frame(
        header: 'X-RequestId:ab12\r\nContent-Type:audio/mpeg\r\nPath:audio',
      );
      expect(
        EdgeTtsEngine.parseAudioFrame(frame),
        [0xFF, 0xFB, 1, 2, 3],
      );
    });

    test('frame kết thúc (không Content-Type, không data) → null', () {
      final frame = _frame(
        header: 'X-RequestId:ab12\r\nPath:audio',
        body: const [],
      );
      expect(EdgeTtsEngine.parseAudioFrame(frame), isNull);
    });

    test('Path khác audio / sai content-type / frame lỗi → null', () {
      expect(
        EdgeTtsEngine.parseAudioFrame(
          _frame(header: 'X-RequestId:ab12\r\nPath:turn.end'),
        ),
        isNull,
      );
      expect(
        EdgeTtsEngine.parseAudioFrame(
          _frame(header: 'Path:audio\r\nContent-Type:text/plain'),
        ),
        isNull,
      );
      expect(EdgeTtsEngine.parseAudioFrame(Uint8List.fromList([0])), isNull);
      expect(
        EdgeTtsEngine.parseAudioFrame(Uint8List.fromList([0xFF, 0xFF, 1, 2])),
        isNull,
      );
    });

    test('parseTextFrame tách header/body tại CRLF-CRLF', () {
      final end = EdgeTtsEngine.parseTextFrame(
        'X-RequestId:abc\r\nContent-Type:application/json\r\n'
        'Path:turn.end\r\n\r\n',
      );
      expect(end.headers['Path'], 'turn.end');
      expect(end.headers['X-RequestId'], 'abc');
      expect(end.body, '');

      final meta = EdgeTtsEngine.parseTextFrame(
        'Path:audio.metadata\r\nContent-Type:application/json\r\n\r\n{"x":1}',
      );
      expect(meta.headers['Path'], 'audio.metadata');
      expect(meta.body, '{"x":1}');
    });

    test('parseHeaderBlock trim khoảng trắng thừa', () {
      expect(
        EdgeTtsEngine.parseHeaderBlock('Content-Type: audio/mpeg')['Content-Type'],
        'audio/mpeg',
      );
    });
  });

  group('Chọn giọng (chống nhầm voiceId engine khác)', () {
    test('isEdgeVoiceId nhận giọng Edge Neural', () {
      expect(EdgeTtsEngine.isEdgeVoiceId('vi-VN-HoaiMyNeural'), isTrue);
      expect(EdgeTtsEngine.isEdgeVoiceId('en-US-EmmaMultilingualNeural'), isTrue);
      expect(EdgeTtsEngine.isEdgeVoiceId('zh-TW-HsiaoChenNeural'), isTrue);
    });

    test('isEdgeVoiceId gạt id Piper/Zalo/FPT/OpenAI', () {
      expect(EdgeTtsEngine.isEdgeVoiceId('vi_VN-vivos-x_low'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('banmai'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('alloy'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('1'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('vi-VN-'), isFalse);
    });

    test('defaultVoiceForLanguage — vi/en/zh/th + fallback Aria', () {
      expect(EdgeTtsEngine.defaultVoiceForLanguage('vi-VN'), 'vi-VN-HoaiMyNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('vi'), 'vi-VN-HoaiMyNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('en'), 'en-US-AriaNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('en-GB'), 'en-GB-SoniaNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('zh-CN'), 'zh-CN-XiaoxiaoNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('zh-TW'), 'zh-TW-HsiaoChenNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('zh'), 'zh-CN-XiaoxiaoNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('th'), 'th-TH-PremwadeeNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('xx'), 'en-US-AriaNeural');
    });

    test('resolveVoice: id Edge hợp lệ thắng, id lạ → default ngôn ngữ', () {
      expect(
        EdgeTtsEngine.resolveVoice(
          voiceId: 'vi-VN-NamMinhNeural',
          language: 'vi-VN',
        ),
        'vi-VN-NamMinhNeural',
      );
      expect(
        EdgeTtsEngine.resolveVoice(voiceId: 'banmai', language: 'vi-VN'),
        'vi-VN-HoaiMyNeural',
      );
      expect(
        EdgeTtsEngine.resolveVoice(language: 'en-US'),
        'en-US-AriaNeural',
      );
    });
  });

  group('isAvailable / getAvailableVoices (http giả)', () {
    test('isAvailable: 200 → true; lỗi HTTP → false; ném → false', () async {
      expect(await _engineReturning(200, '[]').isAvailable(), isTrue);
      expect(await _engineReturning(403).isAvailable(), isFalse);
      expect(await _engineThrowing().isAvailable(), isFalse);
    });

    test('getAvailableVoices: live list được map + lọc theo ngôn ngữ', () async {
      final engine = _engineReturning(
        200,
        jsonEncode([
          {'ShortName': 'vi-VN-HoaiMyNeural', 'Gender': 'Female', 'Locale': 'vi-VN'},
          {'ShortName': 'vi-VN-NamMinhNeural', 'Gender': 'Male', 'Locale': 'vi-VN'},
          {'ShortName': 'vi-VN-HoaiMyNeural', 'Gender': 'Female', 'Locale': 'vi-VN'},
          {'ShortName': 'en-US-AriaNeural', 'Gender': 'Female', 'Locale': 'en-US'},
        ]),
      );
      final voices = await engine.getAvailableVoices('vi-VN');
      // Dedup: 3 bản ghi vi-VN nhưng 2 id khác nhau.
      expect(voices.map((v) => v.id), ['vi-VN-HoaiMyNeural', 'vi-VN-NamMinhNeural']);
      expect(voices.first.gender, 'female');
      expect(voices.first.isNeural, isTrue);
    });

    test('getAvailableVoices: server hỏng/rỗng → danh mục trưng offline', () async {
      final down = await _engineReturning(500).getAvailableVoices('vi-VN');
      expect(
        down.map((v) => v.id),
        ['vi-VN-HoaiMyNeural', 'vi-VN-NamMinhNeural'],
      );

      final empty = await _engineReturning(200, '[]').getAvailableVoices('vi');
      expect(empty.any((v) => v.id == 'vi-VN-HoaiMyNeural'), isTrue);

      final th = await _engineReturning(500).getAvailableVoices('th-TH');
      expect(
        th.map((v) => v.id),
        ['th-TH-PremwadeeNeural', 'th-TH-NiwatNeural'],
      );

      final throwing = await _engineThrowing().getAvailableVoices('vi-VN');
      expect(throwing, isNotEmpty);
    });
  });

  group('Source-scan: pin đăng ký TtsService', () {
    test('TtsService import + dispatch + online engines đủ 3 điểm cắm', () {
      final source = File('lib/features/tts/tts_service.dart').readAsStringSync();
      expect(source, contains("import 'engines/edge_tts_engine.dart';"));
      expect(source, contains("id: 'edge_tts'"));
      // `case 'edge_tts':` phải có ở cả switch speak() lẫn _getOnlineEngines.
      final caseCount = RegExp("case 'edge_tts':").allMatches(source).length;
      expect(caseCount, 2);
    });

    test('edge_tts là ONLINE đầu tiên (trước google) cho cài đặt mới', () {
      final source = File('lib/features/tts/tts_service.dart').readAsStringSync();
      final start = source.indexOf('void _buildDefaultEngineOrder()');
      expect(start, greaterThan(0));
      final end = source.indexOf('];', start);
      final segment = source.substring(start, end);
      final edge = segment.indexOf("id: 'edge_tts'");
      final google = segment.indexOf("id: 'google_tts'");
      final openai = segment.indexOf("id: 'openai_compat_tts'");
      expect(edge, greaterThan(0));
      expect(edge, lessThan(google));
      expect(openai, greaterThan(google)); // WP4 vẫn cuối chuỗi
    });

    test('engine không lưu key (không SharedPreferences)', () {
      final engineSource =
          File('lib/features/tts/engines/edge_tts_engine.dart')
              .readAsStringSync();
      expect(engineSource, isNot(contains('SharedPreferences')));
      expect(engineSource, contains('vi-VN-HoaiMyNeural'));
      expect(engineSource, contains('vi-VN-NamMinhNeural'));
    });

    test('maxCharsPerRequest ≥ 10000 theo spec', () {
      expect(EdgeTtsEngine().maxCharsPerRequest, greaterThanOrEqualTo(10000));
    });
  });

  group('TtsVoice/TtsResult wiring cơ bản', () {
    test('synthesize với text trống → failure không chạm network', () async {
      final result = await _engineThrowing().synthesize(
        text: '   ',
        language: 'vi-VN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('voice catalog là TtsVoice neural của Microsoft Edge', () {
      final vi = EdgeTtsEngine.filterVoicesByLanguage(
        const [
          TtsVoice(
            id: 'vi-VN-HoaiMyNeural',
            name: 'Hoài My',
            language: 'vi-VN',
            gender: 'female',
            engine: 'Microsoft Edge',
            isNeural: true,
          ),
          TtsVoice(
            id: 'en-US-AriaNeural',
            name: 'Aria',
            language: 'en-US',
            gender: 'female',
            engine: 'Microsoft Edge',
            isNeural: true,
          ),
        ],
        'vi',
      );
      expect(vi.single.id, 'vi-VN-HoaiMyNeural');
    });
  });
}
