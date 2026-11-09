// test/edge_tts_engine_test.dart — TTS-EDGE-001 / PSRC-18
//
// Test logic thuần + loopback WebSocket của EdgeTtsEngine (KHÔNG chạm mạng ngoài):
//  - Sec-MS-GEC v2 (`2-143.0.3650.75`): known-vector sinh bằng thư viện tham
//    chiếu `edge-tts` (Python) 7.3.1 (`drm.py generate_sec_ms_gec_v2`).
//  - Đồng bộ lệch đồng hồ máy (`clockSkewSeconds`) từ HTTP header `Date`
//    (RFC 2616 UTC) khi gặp 403 trên cả `voices/list` lẫn WebSocket.
//  - Loopback WebSocket thực tế: xác nhận không rò rỉ `Dart/3.x (dart:io)`
//    trong User-Agent, tổng hợp thành công cả giọng nam (NamMinh) lẫn nữ
//    (HoaiMy), và retry thành công sau lỗi 403 lệch giờ.
//  - Danh mục 8 ngôn ngữ tiêu biểu PSRC-18 (`vi-VN`, `en-US`, `en-GB`, `zh-CN`,
//    `hi-IN`, `my-MM`, `si-LK`, `th-TH`) có đủ giọng nữ + nam.

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

http.StreamedResponse _resp(
  int status, [
  String body = '',
  Map<String, String> headers = const {},
]) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    status,
    headers: headers,
  );
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
  setUp(EdgeTtsEngine.resetClockSkewForTesting);
  tearDown(EdgeTtsEngine.resetClockSkewForTesting);

  group('EdgeTtsEngine — metadata & featuredLanguages', () {
    test('id/name/limit và 8 ngôn ngữ tiêu biểu PSRC-18', () {
      final engine = EdgeTtsEngine();
      expect(engine.id, 'edge_tts');
      expect(engine.name, 'Microsoft Edge TTS');
      expect(engine.maxCharsPerRequest, 10000);
      expect(
        EdgeTtsEngine.featuredLanguages,
        equals([
          'vi-VN',
          'en-US',
          'en-GB',
          'zh-CN',
          'hi-IN',
          'my-MM',
          'si-LK',
          'th-TH',
        ]),
      );
      expect(
        engine.supportedLanguages,
        containsAll(EdgeTtsEngine.featuredLanguages),
      );
    });
  });

  group('Sec-MS-GEC v2 (edge-tts 7.3.1 parity)', () {
    // Known-vectors sinh trực tiếp từ `rany2/edge-tts` v7.3.1 `drm.py`:
    //   generate_sec_ms_gec_v2(unix_timestamp)
    test('known-vector ts=0', () {
      expect(
        EdgeTtsEngine.generateSecMsGec(0),
        '52BC7A17B50DFEC9-'
        '28C4394775C8751CD2F6859C030C06DB1489ACAB3B3A7651831FC26895177ED6',
      );
    });

    test('known-vector ts=1730000000 & ts=1730000300', () {
      expect(
        EdgeTtsEngine.generateSecMsGec(1730000000),
        '50065ABF67B90F95-'
        '49BDAF24D28ECEB38DAEEC84DEAA71E91F92945EA8A47921C58FB4F8F79A4F5E',
      );
      expect(
        EdgeTtsEngine.generateSecMsGec(1730000300),
        '0DFD97ECED65E1DD-'
        '8609EC61F608B8A41449868EACE186270CA60926165F7AB04A7B769009B61BC0',
      );
    });

    test('known-vector ts=1759641037 & ts=1794182400', () {
      expect(
        EdgeTtsEngine.generateSecMsGec(1759641037),
        'DC8706DD09249BDD-'
        '9DE322EEA9C0A1511A4E9F5D4155962B75D21E9AE05217E3F5C99BADC50778AC',
      );
      expect(
        EdgeTtsEngine.generateSecMsGec(1794182400),
        '55AA5EC408362C6F-'
        '3C9D01112D5BD9C8BF0EC1E8779A68ACC7190DB1B4CAB0A68F075C1D61D5C10C',
      );
    });

    test('ổn định trong cùng cửa sổ 5 phút, khác nhau giữa 2 cửa sổ', () {
      final a = EdgeTtsEngine.generateSecMsGec(1759641037);
      final b = EdgeTtsEngine.generateSecMsGec(1759641099);
      final c = EdgeTtsEngine.generateSecMsGec(1759641300);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('không tham số → định dạng v2 <16 hex>-<64 hex> (81 ký tự)', () {
      final gec = EdgeTtsEngine.generateSecMsGec();
      expect(gec.length, 81);
      expect(RegExp(r'^[0-9A-F]{16}-[0-9A-F]{64}$').hasMatch(gec), isTrue);
    });

    test('parseRfc2616Date + adjustClockSkewFromDateHeader bù lệch giờ', () {
      final parsed = EdgeTtsEngine.parseRfc2616Date(
        'Sun, 08 Nov 2026 00:00:00 GMT',
      );
      expect(parsed, DateTime.utc(2026, 11, 8).millisecondsSinceEpoch / 1000.0);
      expect(EdgeTtsEngine.parseRfc2616Date('invalid date'), isNull);

      final adjusted = EdgeTtsEngine.adjustClockSkewFromDateHeader(
        'Sun, 08 Nov 2026 00:10:00 GMT',
        clientUnixSeconds:
            DateTime.utc(2026, 11, 8).millisecondsSinceEpoch / 1000.0,
      );
      expect(adjusted, isTrue);
      expect(EdgeTtsEngine.clockSkewSeconds, closeTo(600.0, 0.001));
    });
  });

  group('URL & headers bắt chước Edge', () {
    test('WSS URL đủ TrustedClientToken + DRM v2 + ConnectionId', () {
      final url = EdgeTtsEngine.buildWssUrl(
        connectionId: 'a' * 32,
        unixTimestampSeconds: 1730000000,
      );
      expect(url, startsWith('wss://speech.platform.bing.com/'));
      expect(
        url,
        contains('TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4'),
      );
      expect(url, contains('ConnectionId=${'a' * 32}'));
      expect(
        url,
        contains(
          'Sec-MS-GEC=50065ABF67B90F95-'
          '49BDAF24D28ECEB38DAEEC84DEAA71E91F92945EA8A47921C58FB4F8F79A4F5E',
        ),
      );
      expect(url, contains('Sec-MS-GEC-Version=2-143.0.3650.75'));
    });

    test('voice-list URL & VOICE_HEADERS đúng chuẩn edge-tts 7.3.1', () {
      final url =
          EdgeTtsEngine.buildVoiceListUrl(unixTimestampSeconds: 1730000000);
      expect(url, startsWith('https://speech.platform.bing.com/'));
      expect(url, contains('voices/list'));
      expect(url, contains('Sec-MS-GEC='));
      expect(url, contains('Sec-MS-GEC-Version=2-143.0.3650.75'));

      final voiceHeaders = EdgeTtsEngine.buildVoiceListHeaders(muid: 'ABC123');
      expect(voiceHeaders['Authority'], 'speech.platform.bing.com');
      expect(voiceHeaders['Sec-Fetch-Mode'], 'cors');
      expect(voiceHeaders['Cookie'], 'muid=ABC123;');
    });

    test('headers WSS: Origin extension + Cookie muid + UA Edg/143', () {
      final headers = EdgeTtsEngine.buildRequestHeaders(muid: 'ABC123');
      expect(
        headers['Origin'],
        'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      );
      expect(headers['Cookie'], 'muid=ABC123;');
      expect(headers['User-Agent'], contains('Edg/143.0.0.0'));
    });

    test('muid/connectId đúng format', () {
      expect(
        RegExp(r'^[0-9A-F]{32}$').hasMatch(EdgeTtsEngine.generateMuid()),
        isTrue,
      );
      expect(
        RegExp(r'^[0-9a-f]{32}$').hasMatch(EdgeTtsEngine.connectId()),
        isTrue,
      );
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
      expect(
        ssml,
        '<speak version=\'1.0\' '
        'xmlns=\'http://www.w3.org/2001/10/synthesis\' xml:lang=\'en-US\'>'
        '<voice name=\'vi-VN-HoaiMyNeural\'>'
        '<prosody pitch=\'-5Hz\' rate=\'+10%\' volume=\'+0%\'>'
        'Xin chào</prosody></voice></speak>',
      );
    });

    test('escapeSsmlText: & trước, đủ 5 ký tự', () {
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
      expect(EdgeTtsEngine.formatRate(3.0), '+100%');
      expect(EdgeTtsEngine.formatRate(0.0), '-100%');

      expect(EdgeTtsEngine.formatPitch(1.0), '+0Hz');
      expect(EdgeTtsEngine.formatPitch(1.3), '+30Hz');
      expect(EdgeTtsEngine.formatPitch(0.7), '-30Hz');
      expect(EdgeTtsEngine.formatPitch(0.5), '-50Hz');
      expect(EdgeTtsEngine.formatPitch(2.0), '+100Hz');
      expect(EdgeTtsEngine.formatPitch(3.0), '+100Hz');
    });
  });

  group('Chia text → turn SSML', () {
    test('removeIncompatibleCharacters giữ tab/LF/CR/DEL', () {
      expect(
        EdgeTtsEngine.removeIncompatibleCharacters(
          '\x00\x01ab\x0B\x0C\t\ncd\x7F',
        ),
        '  ab  \t\ncd\x7F',
      );
    });

    test('splitText ngắn → 1 chunk; câu → gom theo maxLen; cắt cứng câu dài',
        () {
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

    test('splitForSynthesis: CJK không khoảng trắng — cắt cứng an toàn byte',
        () {
      final chunks = EdgeTtsEngine.splitForSynthesis('漢' * 100, maxBytes: 120);
      expect(chunks.join(), '漢' * 100);
      expect(chunks.length, 3);
      for (final c in chunks) {
        expect(utf8.encode(c).length, lessThanOrEqualTo(120));
        expect(() => utf8.encode(c), returnsNormally);
      }
    });

    test('splitForSynthesis: emoji (surrogate pair) không bị tách nửa', () {
      final chunks = EdgeTtsEngine.splitForSynthesis('😀' * 50, maxBytes: 15);
      expect(chunks.join(), '😀' * 50);
      for (final c in chunks) {
        expect(utf8.encode(c).length, lessThanOrEqualTo(15));
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
        EdgeTtsEngine.parseHeaderBlock(
          'Content-Type: audio/mpeg',
        )['Content-Type'],
        'audio/mpeg',
      );
    });
  });

  group('Chọn giọng & danh mục 8 ngôn ngữ tiêu biểu (PSRC-18)', () {
    test('isEdgeVoiceId nhận giọng Edge Neural (kể cả giọng vùng phụ)', () {
      expect(EdgeTtsEngine.isEdgeVoiceId('vi-VN-HoaiMyNeural'), isTrue);
      expect(EdgeTtsEngine.isEdgeVoiceId('vi-VN-NamMinhNeural'), isTrue);
      expect(
        EdgeTtsEngine.isEdgeVoiceId('en-US-EmmaMultilingualNeural'),
        isTrue,
      );
      expect(EdgeTtsEngine.isEdgeVoiceId('my-MM-NilarNeural'), isTrue);
      expect(EdgeTtsEngine.isEdgeVoiceId('si-LK-SameeraNeural'), isTrue);
      expect(
        EdgeTtsEngine.isEdgeVoiceId('zh-CN-liaoning-XiaobeiNeural'),
        isTrue,
      );
    });

    test('isEdgeVoiceId gạt id Piper/Zalo/FPT/OpenAI', () {
      expect(EdgeTtsEngine.isEdgeVoiceId('vi_VN-vivos-x_low'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('banmai'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('alloy'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('1'), isFalse);
      expect(EdgeTtsEngine.isEdgeVoiceId('vi-VN-'), isFalse);
    });

    test('defaultVoiceForLanguage — đủ 8 ngôn ngữ tiêu biểu + fallback Aria',
        () {
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('vi-VN'),
        'vi-VN-HoaiMyNeural',
      );
      expect(EdgeTtsEngine.defaultVoiceForLanguage('vi'), 'vi-VN-HoaiMyNeural');
      expect(EdgeTtsEngine.defaultVoiceForLanguage('en'), 'en-US-AriaNeural');
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('en-GB'),
        'en-GB-SoniaNeural',
      );
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('zh-CN'),
        'zh-CN-XiaoxiaoNeural',
      );
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('zh-TW'),
        'zh-TW-HsiaoChenNeural',
      );
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('hi-IN'),
        'hi-IN-SwaraNeural',
      );
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('my-MM'),
        'my-MM-NilarNeural',
      );
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('si-LK'),
        'si-LK-ThiliniNeural',
      );
      expect(
        EdgeTtsEngine.defaultVoiceForLanguage('th-TH'),
        'th-TH-PremwadeeNeural',
      );
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

    test('mọi ngôn ngữ trong featuredLanguages đều có cả giọng nữ và nam', () {
      final cat = EdgeTtsEngine.catalogVoices;
      expect(cat.first.language, 'vi-VN');
      final ids = cat.map((v) => v.id).toSet();
      expect(ids.length, cat.length);
      for (final v in cat) {
        expect(EdgeTtsEngine.isEdgeVoiceId(v.id), isTrue, reason: v.id);
      }

      for (final locale in EdgeTtsEngine.featuredLanguages) {
        final voices = EdgeTtsEngine.catalogVoicesFor(locale);
        expect(
          voices.any((v) => v.gender == 'female'),
          isTrue,
          reason: '$locale thiếu giọng nữ',
        );
        expect(
          voices.any((v) => v.gender == 'male'),
          isTrue,
          reason: '$locale thiếu giọng nam',
        );
      }
    });
  });

  group('isAvailable / getAvailableVoices + tự động bù lệch giờ 403', () {
    test('isAvailable: 200 → true; 403 không Date → false; ném → false',
        () async {
      expect(await _engineReturning(200, '[]').isAvailable(), isTrue);
      expect(await _engineReturning(403).isAvailable(), isFalse);
      expect(await _engineThrowing().isAvailable(), isFalse);
    });

    test('isAvailable: gặp 403 kèm Date header → tự chỉnh skew rồi retry 200',
        () async {
      var calls = 0;
      final serverDate = HttpDate.format(
        DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );
      final engine = EdgeTtsEngine(
        httpClient: _FakeHttpClient((_) async {
          calls++;
          if (calls == 1) {
            return _resp(403, 'Forbidden', {'date': serverDate});
          }
          return _resp(200, '[]');
        }),
      );

      expect(await engine.isAvailable(), isTrue);
      expect(calls, 2);
      expect(EdgeTtsEngine.clockSkewSeconds.abs(), greaterThan(500));
    });

    test('getAvailableVoices: live list được map + lọc theo ngôn ngữ',
        () async {
      final engine = _engineReturning(
        200,
        jsonEncode([
          {
            'ShortName': 'vi-VN-HoaiMyNeural',
            'Gender': 'Female',
            'Locale': 'vi-VN',
          },
          {
            'ShortName': 'vi-VN-NamMinhNeural',
            'Gender': 'Male',
            'Locale': 'vi-VN',
          },
          {
            'ShortName': 'vi-VN-HoaiMyNeural',
            'Gender': 'Female',
            'Locale': 'vi-VN',
          },
          {
            'ShortName': 'en-US-AriaNeural',
            'Gender': 'Female',
            'Locale': 'en-US',
          },
        ]),
      );
      final voices = await engine.getAvailableVoices('vi-VN');
      expect(
        voices.map((v) => v.id),
        ['vi-VN-HoaiMyNeural', 'vi-VN-NamMinhNeural'],
      );
      expect(voices.first.gender, 'female');
      expect(voices.first.isNeural, isTrue);
    });

    test('getAvailableVoices: server hỏng/rỗng → danh mục trưng offline',
        () async {
      final down = await _engineReturning(500).getAvailableVoices('vi-VN');
      expect(
        down.map((v) => v.id),
        ['vi-VN-HoaiMyNeural', 'vi-VN-NamMinhNeural'],
      );

      final th = await _engineReturning(500).getAvailableVoices('th-TH');
      expect(
        th.map((v) => v.id),
        ['th-TH-PremwadeeNeural', 'th-TH-NiwatNeural'],
      );
    });
  });

  group('Loopback WebSocket synthesize (nam & nữ + User-Agent + 403 retry)',
      () {
    test('tổng hợp thành công cả giọng NamMinh và HoaiMy, không lộ Dart UA',
        () async {
      final receivedUserAgents = <List<String>>[];
      final receivedSsmlFrames = <String>[];

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest req) async {
        receivedUserAgents.add(
          List<String>.from(
            req.headers[HttpHeaders.userAgentHeader] ?? const [],
          ),
        );
        final ws = await WebSocketTransformer.upgrade(req);
        await for (final msg in ws) {
          if (msg is String && msg.contains('Path:ssml')) {
            receivedSsmlFrames.add(msg);
            final isMale = msg.contains('vi-VN-NamMinhNeural');
            ws.add(
              _frame(
                header:
                    'X-RequestId:req1\r\nContent-Type:audio/mpeg\r\nPath:audio',
                body: isMale
                    ? const [0xFF, 0xFB, 0x90, 0x01]
                    : const [0xFF, 0xFB, 0x90, 0x02],
              ),
            );
            ws.add('X-RequestId:req1\r\nPath:turn.end\r\n\r\n');
          }
        }
      });

      final engine = EdgeTtsEngine(
        wssUrlBuilderOverride: () =>
            'ws://${server.address.address}:${server.port}/edge/v1',
      );

      final maleRes = await engine.synthesize(
        text: 'Xin chào từ giọng nam',
        language: 'vi-VN',
        voiceId: 'vi-VN-NamMinhNeural',
      );
      final femaleRes = await engine.synthesize(
        text: 'Xin chào từ giọng nữ',
        language: 'vi-VN',
        voiceId: 'vi-VN-HoaiMyNeural',
      );

      expect(maleRes.isSuccess, isTrue, reason: maleRes.error);
      expect(femaleRes.isSuccess, isTrue, reason: femaleRes.error);
      expect(maleRes.audioData, [0xFF, 0xFB, 0x90, 0x01]);
      expect(femaleRes.audioData, [0xFF, 0xFB, 0x90, 0x02]);
      expect(maleRes.audioData, isNot(equals(femaleRes.audioData)));

      expect(receivedSsmlFrames, hasLength(2));
      expect(receivedSsmlFrames[0], contains("voice name='vi-VN-NamMinhNeural'"));
      expect(receivedSsmlFrames[1], contains("voice name='vi-VN-HoaiMyNeural'"));

      // Phải gửi đúng 1 dòng User-Agent của Edge Chromium, tuyệt đối không rò
      // rỉ `Dart/3.x (dart:io)`.
      for (final uaList in receivedUserAgents) {
        expect(uaList, hasLength(1));
        expect(uaList.single, contains('Edg/143.0.0.0'));
        expect(uaList.single, isNot(contains('Dart/')));
      }
    });

    test('WebSocket 403 lần 1 → tự đồng bộ Date header rồi thành công lần 2',
        () async {
      var wsAttempts = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((HttpRequest req) async {
        wsAttempts++;
        if (wsAttempts == 1) {
          req.response.statusCode = HttpStatus.forbidden;
          await req.response.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(req);
        await for (final msg in ws) {
          if (msg is String && msg.contains('Path:ssml')) {
            ws.add(
              _frame(
                header:
                    'X-RequestId:r2\r\nContent-Type:audio/mpeg\r\nPath:audio',
                body: const [0xFF, 0xFB, 0xAA, 0xBB],
              ),
            );
            ws.add('X-RequestId:r2\r\nPath:turn.end\r\n\r\n');
          }
        }
      });

      final futureServerDate = HttpDate.format(
        DateTime.now().toUtc().add(const Duration(minutes: 8)),
      );
      final engine = EdgeTtsEngine(
        httpClient: _FakeHttpClient(
          (_) async => _resp(403, '', {'date': futureServerDate}),
        ),
        wssUrlBuilderOverride: () =>
            'ws://${server.address.address}:${server.port}/edge/v1',
      );

      final res = await engine.synthesize(
        text: 'Thử lại sau khi bù lệch giờ',
        language: 'vi-VN',
        voiceId: 'vi-VN-NamMinhNeural',
      );

      expect(res.isSuccess, isTrue, reason: res.error);
      expect(wsAttempts, 2);
      expect(EdgeTtsEngine.clockSkewSeconds.abs(), greaterThan(400));
    });
  });

  group('Source-scan: pin đăng ký TtsService & chống nuốt giọng', () {
    String ttsSource() =>
        File('lib/features/tts/tts_service.dart').readAsStringSync();

    test('TtsService import + dispatch + online engines đủ 3 điểm cắm', () {
      final source = ttsSource();
      expect(source, contains("import 'engines/edge_tts_engine.dart';"));
      expect(source, contains("id: 'edge_tts'"));
      final caseCount = RegExp("case 'edge_tts':").allMatches(source).length;
      expect(caseCount, 2);
    });

    test('edge_tts là ONLINE đầu tiên (trước google) cho cài đặt mới', () {
      final source = ttsSource();
      final start = source.indexOf('void _buildDefaultEngineOrder()');
      expect(start, greaterThan(0));
      final end = source.indexOf('];', start);
      final segment = source.substring(start, end);
      final edge = segment.indexOf("id: 'edge_tts'");
      final google = segment.indexOf("id: 'google_tts'");
      final openai = segment.indexOf("id: 'openai_compat_tts'");
      expect(edge, greaterThan(0));
      expect(edge, lessThan(google));
      expect(openai, greaterThan(google));
    });

    test('engine không lưu key (không SharedPreferences)', () {
      final engineSource =
          File('lib/features/tts/engines/edge_tts_engine.dart')
              .readAsStringSync();
      expect(engineSource, isNot(contains('SharedPreferences')));
      expect(engineSource, contains('vi-VN-HoaiMyNeural'));
      expect(engineSource, contains('vi-VN-NamMinhNeural'));
    });

    test('không còn dò cache bằng engineId: any (get/put bất đối xứng)', () {
      final code = ttsSource().replaceAll(RegExp(r'//[^\n]*'), '');
      expect(code, isNot(contains("engineId: 'any'")));
    });

    test('cache get/put dùng đúng danh tính engine + giọng cụ thể', () {
      final source = ttsSource();
      final identityUses =
          RegExp(r'engineId: engine\.id').allMatches(source).length;
      expect(identityUses, greaterThanOrEqualTo(4));
      expect(source, contains('resolveOnlineVoice('));
      expect(source, contains('voiceId: voiceId,'));
      expect(source, contains('_shortVoiceLabel(voiceId)'));
      expect(source, contains('🌐 \${result.engineName}'));
    });

    test('speak() và _prefetchOnline đều hỏi _resolveEdgeVoice(lang)', () {
      final source = ttsSource();
      final resolves =
          RegExp(r'_resolveEdgeVoice\(lang(?:,|\))').allMatches(source).length;
      expect(resolves, greaterThanOrEqualTo(2));
      expect(source, contains("engine.id == 'edge_tts'"));
    });

    test('FlutterTtsServiceImpl không ghi đè autoDetect=false toàn cục', () {
      final implSource = File(
        'lib/screens/read_mode/services/tts_service_impl.dart',
      ).readAsStringSync();
      final code = implSource.replaceAll(RegExp(r'//[^\n]*'), '');
      expect(code, isNot(contains('autoDetect: false')));
      expect(code, contains('language: _activeLocale'));
    });

    test('EdgeVoicePrefs ghim giọng: giọng riêng thắng, ghim cho ngôn ngữ trống',
        () {
      final prefs = File('lib/features/tts/edge_voice_prefs.dart')
          .readAsStringSync();
      expect(prefs, contains('resolveVoiceForLanguage'));
      expect(prefs, contains('pinAllLanguages'));
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
