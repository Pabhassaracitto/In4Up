// PSRC-221 — worker Dart của "in4up làm giọng đọc hệ thống Android".
//
// Máy bắt cho phần logic KHÔNG cần thiết bị: giải mã WAV → PCM, danh mục
// giọng, chọn giọng, chia đoạn + thứ tự gửi âm thanh, huỷ giữa chừng, và các
// nhánh lỗi (không có giọng / engine không ra tiếng). Backend là giả, channel
// là channel giả của flutter_test.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/platform/system_tts/system_tts_pcm.dart';
import 'package:in4up/core/platform/system_tts/system_tts_protocol.dart';
import 'package:in4up/core/platform/system_tts/system_tts_worker.dart';

/// WAV PCM 16-bit với [samples] xen kẽ theo kênh.
Uint8List wav16(List<int> samples, {int rate = 22050, int channels = 1}) {
  final dataSize = samples.length * 2;
  final out = ByteData(44 + dataSize);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + dataSize, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little);
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, rate, Endian.little);
  out.setUint32(28, rate * channels * 2, Endian.little);
  out.setUint16(32, channels * 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  out.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    out.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return out.buffer.asUint8List();
}

List<int> pcmSamples(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return <int>[
    for (var i = 0; i + 1 < bytes.length; i += 2)
      data.getInt16(i, Endian.little),
  ];
}

class FakeBackend implements SystemTtsBackend {
  FakeBackend(this.id, this.list);

  @override
  final String id;
  List<SystemTtsBackendVoice> list;
  bool throwOnVoices = false;

  /// Văn bản của từng lượt tổng hợp, theo thứ tự.
  final List<String> spoken = <String>[];
  final List<String> voiceIds = <String>[];
  final List<double> rates = <double>[];

  /// Trả về cho mỗi lượt; mặc định là WAV 1 mẫu mang SỐ THỨ TỰ lượt.
  Uint8List? Function(int index, String text)? onSynthesize;

  /// Nếu đặt, mỗi lượt tổng hợp chờ future này trước khi trả.
  Future<void> Function(int index)? gate;

  @override
  Future<List<SystemTtsBackendVoice>> voices() async {
    if (throwOnVoices) throw StateError('disk error');
    return list;
  }

  @override
  Future<Uint8List?> synthesizeWav({
    required String voiceId,
    required String locale,
    required String text,
    required double rate,
    required double pitch,
  }) async {
    final index = spoken.length;
    spoken.add(text);
    voiceIds.add(voiceId);
    rates.add(rate);
    await gate?.call(index);
    final custom = onSynthesize;
    if (custom != null) return custom(index, text);
    return wav16(<int>[index + 1]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SystemTtsProtocol.channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Mọi lời gọi Dart → native.
  late List<MethodCall> nativeCalls;

  /// Trả lời của "native" cho `audio`; mặc định nhận hết.
  late FutureOr<bool> Function(MethodCall call) onAudio;

  setUp(() {
    nativeCalls = <MethodCall>[];
    onAudio = (_) => true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      if (call.method == SystemTtsProtocol.methodAudio) {
        return onAudio(call);
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  List<MethodCall> audioCalls() => nativeCalls
      .where((c) => c.method == SystemTtsProtocol.methodAudio)
      .toList();

  Map<Object?, Object?> request({
    int id = 1,
    String text = 'Xin chào.',
    String? voice,
    String? locale = 'vi-VN',
    Object? rate = 1.0,
  }) =>
      <Object?, Object?>{
        SystemTtsProtocol.keyRequestId: id,
        SystemTtsProtocol.keyText: text,
        SystemTtsProtocol.keyVoice: voice,
        SystemTtsProtocol.keyLocale: locale,
        SystemTtsProtocol.keyRate: rate,
        SystemTtsProtocol.keyPitch: 1.0,
      };

  group('decodeWavToPcm16Mono', () {
    test('PCM 16-bit mono giữ nguyên mẫu và tần số', () {
      final pcm = decodeWavToPcm16Mono(wav16(<int>[0, 1000, -1000, 32767]));
      expect(pcm, isNotNull);
      expect(pcm!.sampleRate, 22050);
      expect(pcmSamples(pcm.bytes), <int>[0, 1000, -1000, 32767]);
      expect(pcm.sampleCount, 4);
    });

    test('stereo được trộn trung bình về mono', () {
      final pcm = decodeWavToPcm16Mono(
        wav16(<int>[100, 300, -200, -400], rate: 48000, channels: 2),
      );
      expect(pcm!.sampleRate, 48000);
      expect(pcmSamples(pcm.bytes), <int>[200, -300]);
    });

    test('float 32-bit được đổi sang 16-bit và kẹp biên', () {
      final floats = Float32List.fromList(<double>[0.0, 0.5, -1.0, 2.0]);
      final body = floats.buffer.asUint8List();
      final out = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(<int>[0, 0, 0, 0])
        ..add('WAVE'.codeUnits)
        ..add('fmt '.codeUnits)
        ..add(<int>[16, 0, 0, 0])
        ..add(<int>[3, 0]) // IEEE float
        ..add(<int>[1, 0])
        ..add(<int>[0x80, 0x3E, 0, 0]) // 16000
        ..add(<int>[0, 0xFA, 0, 0])
        ..add(<int>[4, 0])
        ..add(<int>[32, 0])
        ..add('data'.codeUnits)
        ..add(<int>[body.length, 0, 0, 0])
        ..add(body);
      final pcm = decodeWavToPcm16Mono(out.toBytes());
      expect(pcm!.sampleRate, 16000);
      expect(pcmSamples(pcm.bytes), <int>[0, 16384, -32767, 32767]);
    });

    test('bỏ qua chunk lạ đứng trước data (kể cả chunk độ dài lẻ)', () {
      final plain = wav16(<int>[7, 8]);
      final out = BytesBuilder()
        ..add(plain.sublist(0, 36))
        ..add('LIST'.codeUnits)
        ..add(<int>[3, 0, 0, 0])
        ..add(<int>[1, 2, 3, 0]) // 3 byte + 1 byte đệm
        ..add(plain.sublist(36));
      final pcm = decodeWavToPcm16Mono(out.toBytes());
      expect(pcmSamples(pcm!.bytes), <int>[7, 8]);
    });

    test('data khai kích thước 0 (ghi theo luồng) ⇒ lấy tới hết file', () {
      final bytes = wav16(<int>[5, 6, 7]);
      ByteData.sublistView(bytes).setUint32(40, 0, Endian.little);
      expect(pcmSamples(decodeWavToPcm16Mono(bytes)!.bytes), <int>[5, 6, 7]);
    });

    test('không phải WAV / định dạng không hỗ trợ ⇒ null, không ném', () {
      expect(decodeWavToPcm16Mono(Uint8List(0)), isNull);
      expect(
        decodeWavToPcm16Mono(Uint8List.fromList(List<int>.filled(64, 1))),
        isNull,
      );
      // MP3 (Edge/Google trả về) không được coi là PCM.
      expect(
        decodeWavToPcm16Mono(
          Uint8List.fromList(<int>[0x49, 0x44, 0x33, ...List<int>.filled(40, 0)]),
        ),
        isNull,
      );
      final eightBit = wav16(<int>[1, 2]);
      ByteData.sublistView(eightBit).setUint16(34, 8, Endian.little);
      expect(decodeWavToPcm16Mono(eightBit), isNull);
    });
  });

  group('normalizeSystemTtsLocale / isSpeakableForSystemTts', () {
    test('chuẩn hoá về BCP-47', () {
      expect(normalizeSystemTtsLocale('vi_VN'), 'vi-VN');
      expect(normalizeSystemTtsLocale('EN-us'), 'en-US');
      expect(normalizeSystemTtsLocale('vi'), 'vi');
      expect(normalizeSystemTtsLocale('es-419'), 'es-419');
      expect(normalizeSystemTtsLocale(''), '');
      expect(normalizeSystemTtsLocale('auto?'), '');
      // Phần sau không phải mã vùng ⇒ chỉ giữ ngôn ngữ.
      expect(normalizeSystemTtsLocale('vi-vais1000'), 'vi');
    });

    test('đoạn chỉ có dấu câu không đưa cho engine', () {
      expect(isSpeakableForSystemTts('…'), isFalse);
      expect(isSpeakableForSystemTts(' — !? '), isFalse);
      expect(isSpeakableForSystemTts('a'), isTrue);
      expect(isSpeakableForSystemTts('Đ'), isTrue);
      expect(isSpeakableForSystemTts('你'), isTrue);
      expect(isSpeakableForSystemTts('7'), isTrue);
    });
  });

  group('danh mục giọng', () {
    test('tên giọng = <backend>/<voiceId>, giữ thứ tự backend', () async {
      final piper = FakeBackend('piper', const <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'vi_VN-a', locale: 'vi_VN'),
        SystemTtsBackendVoice(voiceId: 'en_US-b', locale: 'en-US'),
      ]);
      final vieneu = FakeBackend('vieneu', const <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'default', locale: 'vi-VN'),
      ]);
      final worker = SystemTtsWorker(
        backends: <SystemTtsBackend>[piper, vieneu],
        channel: channel,
      );
      final voices = await worker.refreshVoices();
      expect(
        voices.map((v) => '${v.name}|${v.locale}').toList(),
        <String>['piper/vi_VN-a|vi-VN', 'piper/en_US-b|en-US', 'vieneu/default|vi-VN'],
      );
    });

    test('bỏ giọng không có locale, giọng trùng tên; backend hỏng không lan',
        () async {
      final broken = FakeBackend('piper', const <SystemTtsBackendVoice>[])
        ..throwOnVoices = true;
      final ok = FakeBackend('vieneu', const <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'x', locale: ''),
        SystemTtsBackendVoice(voiceId: 'y', locale: 'vi-VN'),
        SystemTtsBackendVoice(voiceId: 'y', locale: 'vi-VN'),
        SystemTtsBackendVoice(voiceId: '', locale: 'vi-VN'),
      ]);
      final worker = SystemTtsWorker(
        backends: <SystemTtsBackend>[broken, ok],
        channel: channel,
      );
      final voices = await worker.refreshVoices();
      expect(voices.map((v) => v.name).toList(), <String>['vieneu/y']);
    });

    test('attach báo ready kèm danh sách giọng đúng tên khoá', () async {
      final worker = SystemTtsWorker(
        backends: <SystemTtsBackend>[
          FakeBackend('piper', const <SystemTtsBackendVoice>[
            SystemTtsBackendVoice(voiceId: 'vi_VN-a', locale: 'vi-VN'),
          ]),
        ],
        channel: channel,
      );
      await worker.attach();
      final ready = nativeCalls.single;
      expect(ready.method, 'ready');
      expect((ready.arguments as Map)['voices'], <Object?>[
        <Object?, Object?>{'name': 'piper/vi_VN-a', 'locale': 'vi-VN'},
      ]);
    });

    test('listVoices quét lại đĩa (giọng vừa import xuất hiện)', () async {
      final backend = FakeBackend('piper', const <SystemTtsBackendVoice>[]);
      final worker = SystemTtsWorker(
        backends: <SystemTtsBackend>[backend],
        channel: channel,
      );
      expect(
        await worker.handleCall(const MethodCall('listVoices')),
        isEmpty,
      );
      backend.list = const <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'en_US-b', locale: 'en-US'),
      ];
      expect(
        await worker.handleCall(const MethodCall('listVoices')),
        <Object?>[
          <String, Object?>{'name': 'piper/en_US-b', 'locale': 'en-US'},
        ],
      );
    });

    test('resolveVoice: tên → đúng locale → cùng ngôn ngữ → null', () async {
      final worker = SystemTtsWorker(
        backends: <SystemTtsBackend>[
          FakeBackend('piper', const <SystemTtsBackendVoice>[
            SystemTtsBackendVoice(voiceId: 'en_GB-a', locale: 'en-GB'),
            SystemTtsBackendVoice(voiceId: 'en_US-b', locale: 'en-US'),
            SystemTtsBackendVoice(voiceId: 'vi_VN-c', locale: 'vi-VN'),
          ]),
        ],
        channel: channel,
      );
      await worker.refreshVoices();
      expect(
        worker.resolveVoice(name: 'piper/vi_VN-c', locale: 'en-US')!.voiceId,
        'vi_VN-c',
      );
      expect(worker.resolveVoice(locale: 'en-US')!.voiceId, 'en_US-b');
      expect(worker.resolveVoice(locale: 'en_AU')!.voiceId, 'en_GB-a');
      expect(worker.resolveVoice(name: 'piper/gone', locale: 'vi')!.voiceId,
          'vi_VN-c');
      expect(worker.resolveVoice(locale: 'fr-FR'), isNull);
      expect(worker.resolveVoice(name: 'piper/gone'), isNull);
    });
  });

  group('synthesize', () {
    late FakeBackend backend;
    late SystemTtsWorker worker;

    setUp(() async {
      backend = FakeBackend('piper', const <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'vi_VN-a', locale: 'vi-VN'),
        SystemTtsBackendVoice(voiceId: 'en_US-b', locale: 'en-US'),
      ]);
      worker = SystemTtsWorker(
        backends: <SystemTtsBackend>[backend],
        channel: channel,
        chunkChars: 20,
      );
      await worker.refreshVoices();
    });

    test('câu ngắn: một khối PCM đúng khoá, trạng thái ok', () async {
      final result = await worker.handleCall(
        MethodCall('synthesize', request(id: 7, voice: 'piper/vi_VN-a')),
      );
      expect(result, <String, Object?>{'status': 'ok'});
      expect(backend.spoken, <String>['Xin chào.']);
      expect(backend.voiceIds, <String>['vi_VN-a']);
      final audio = audioCalls().single.arguments as Map;
      expect(audio.keys.toSet(), <String>{'requestId', 'sampleRate', 'pcm'});
      expect(audio['requestId'], 7);
      expect(audio['sampleRate'], 22050);
      expect(pcmSamples(audio['pcm'] as Uint8List), <int>[1]);
    });

    test('văn bản dài được chia đoạn, gửi ĐÚNG THỨ TỰ', () async {
      const text = 'Câu thứ nhất ở đây. Câu thứ hai ở đây. Câu thứ ba ở đây.';
      final result = await worker.synthesize(request(text: text));
      expect(result['status'], 'ok');
      expect(backend.spoken.length, greaterThan(1));
      expect(backend.spoken.every((chunk) => chunk.length <= 20), isTrue);
      expect(backend.spoken.join(' '), text);
      expect(
        audioCalls()
            .map((c) => pcmSamples((c.arguments as Map)['pcm'] as Uint8List))
            .toList(),
        <List<int>>[
          for (var i = 0; i < backend.spoken.length; i++) <int>[i + 1],
        ],
      );
    });

    test('đoạn kế được tổng hợp TRONG LÚC native còn giữ đoạn trước',
        () async {
      // Native chưa xác nhận khối 1 ⇒ worker vẫn phải tổng hợp sẵn đoạn 2,
      // nhưng KHÔNG được gửi khối 2 trước khi khối 1 được xác nhận.
      final firstAck = Completer<bool>();
      var audioSeen = 0;
      onAudio = (_) async {
        audioSeen++;
        if (audioSeen == 1) return firstAck.future;
        return true;
      };
      final secondSynthesized = Completer<void>();
      backend.gate = (index) async {
        if (index == 1) secondSynthesized.complete();
      };

      final pending = worker.synthesize(
        request(text: 'Câu thứ nhất ở đây. Câu thứ hai ở đây.'),
      );
      await secondSynthesized.future;
      await pumpEventQueue();
      expect(audioSeen, 1, reason: 'khối 2 chưa được gửi khi khối 1 chưa xong');
      firstAck.complete(true);
      expect((await pending)['status'], 'ok');
      expect(audioSeen, 2);
    });

    test('chọn giọng theo locale khi không có tên; tốc độ được kẹp',
        () async {
      await worker.synthesize(
        request(text: 'Hello.', locale: 'en-AU', rate: 9.0),
      );
      await worker.synthesize(
        request(id: 2, text: 'Hello.', locale: 'en-US', rate: 'x'),
      );
      expect(backend.voiceIds, <String>['en_US-b', 'en_US-b']);
      expect(backend.rates, <double>[3.0, 1.0]);
    });

    test('không có giọng cho ngôn ngữ ⇒ noVoice, không gọi engine', () async {
      final result = await worker.synthesize(
        request(text: 'Bonjour.', locale: 'fr-FR'),
      );
      expect(result['status'], 'noVoice');
      expect(result['message'], contains('fr-FR'));
      expect(backend.spoken, isEmpty);
      expect(audioCalls(), isEmpty);
    });

    test('giọng vừa import sau lần quét trước vẫn đọc được', () async {
      backend.list = const <SystemTtsBackendVoice>[
        SystemTtsBackendVoice(voiceId: 'fr_FR-n', locale: 'fr-FR'),
      ];
      final result = await worker.synthesize(
        request(text: 'Bonjour.', locale: 'fr-FR'),
      );
      expect(result['status'], 'ok');
      expect(backend.voiceIds, <String>['fr_FR-n']);
    });

    test('văn bản rỗng / chỉ dấu câu ⇒ ok, không có âm thanh', () async {
      expect((await worker.synthesize(request(text: '   ')))['status'], 'ok');
      expect((await worker.synthesize(request(text: '… !?')))['status'], 'ok');
      expect(backend.spoken, isEmpty);
      expect(audioCalls(), isEmpty);
    });

    test('engine không ra tiếng ⇒ failed kèm lý do', () async {
      backend.onSynthesize = (_, __) => null;
      final none = await worker.synthesize(request());
      expect(none['status'], 'failed');
      expect(none['message'], contains('piper/vi_VN-a'));

      backend.onSynthesize = (_, __) => Uint8List.fromList(<int>[1, 2, 3]);
      final garbage = await worker.synthesize(request(id: 2));
      expect(garbage['status'], 'failed');
      expect(garbage['message'], contains('unsupported audio format'));

      backend.onSynthesize = (_, __) => throw StateError('model missing');
      final thrown = await worker.synthesize(request(id: 3));
      expect(thrown['status'], 'failed');
      expect(thrown['message'], contains('model missing'));
      expect(audioCalls(), isEmpty);
    });

    test('cancel giữa chừng: dừng trước đoạn kế, trả cancelled', () async {
      backend.gate = (index) async {
        if (index == 0) {
          await worker.handleCall(
            const MethodCall('cancel', <String, Object?>{'requestId': 5}),
          );
        }
      };
      final result = await worker.synthesize(
        request(id: 5, text: 'Câu thứ nhất ở đây. Câu thứ hai ở đây.'),
      );
      expect(result['status'], 'cancelled');
      expect(backend.spoken.length, 1);
      expect(audioCalls(), isEmpty);
    });

    test('native từ chối khối âm thanh (đã onStop) ⇒ cancelled', () async {
      onAudio = (_) => false;
      final result = await worker.synthesize(
        request(text: 'Câu thứ nhất ở đây. Câu thứ hai ở đây. Câu thứ ba.'),
      );
      expect(result['status'], 'cancelled');
      // Khối 1 bị từ chối: đoạn 2 đã tổng hợp sẵn nhưng KHÔNG được gửi, và
      // đoạn 3 không được tổng hợp.
      expect(audioCalls().length, 1);
      expect(backend.spoken.length, 2);
    });

    test('native không trả lời ⇒ hết hạn chờ, không treo', () async {
      final slow = SystemTtsWorker(
        backends: <SystemTtsBackend>[backend],
        channel: channel,
        audioAckTimeout: const Duration(milliseconds: 20),
      );
      await slow.refreshVoices();
      onAudio = (_) => Completer<bool>().future;
      final result = await slow.synthesize(request());
      expect(result['status'], 'cancelled');
    });

    test('yêu cầu chạy NỐI TIẾP, huỷ yêu cầu cũ không ảnh hưởng yêu cầu mới',
        () async {
      final release = Completer<void>();
      backend.gate = (index) async {
        if (index == 0) await release.future;
      };
      final first = worker.synthesize(request(id: 1, text: 'Một.'));
      final second = worker.synthesize(request(id: 2, text: 'Hai.'));
      await pumpEventQueue();
      expect(backend.spoken, <String>['Một.'],
          reason: 'yêu cầu 2 chưa được chạy khi yêu cầu 1 chưa xong');
      worker.cancel(1);
      release.complete();
      expect((await first)['status'], 'cancelled');
      expect((await second)['status'], 'ok');
      expect(backend.spoken, <String>['Một.', 'Hai.']);
      expect(audioCalls().single.arguments['requestId'], 2);
    });

    test('method lạ ⇒ MissingPluginException (native thấy notImplemented)',
        () async {
      expect(
        () => worker.handleCall(const MethodCall('nope')),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}
