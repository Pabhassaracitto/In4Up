// lib/core/platform/system_tts/system_tts_worker.dart
//
// PSRC-221 — worker Dart của "in4up làm giọng đọc hệ thống Android".
//
// Chạy trong engine Flutter NỀN do `In4UpTtsService` (Kotlin) khởi, KHÔNG phụ
// thuộc UI của app: Android bind service ⇒ service dựng engine ⇒ worker này
// trả danh sách giọng và tổng hợp âm thanh bằng CHÍNH các engine offline của
// app (Piper qua sherpa-onnx, VieNeu qua audio.cpp). App không cần đang mở.
//
// Vì sao logic nằm ở Dart chứ không ở Kotlin: repo chưa có hạ tầng test
// Kotlin, còn Dart thì `flutter test` chạy được trên CI. Kotlin chỉ làm phần
// bắt buộc phải native (vòng đời service, ghi PCM cho Android); chia đoạn,
// chọn giọng, giải mã WAV, huỷ giữa chừng đều ở đây và có test.
//
// Luồng một yêu cầu đọc:
//   native ──synthesize{requestId,text,voice,locale,rate,pitch}──▶ Dart
//   Dart chia văn bản thành đoạn ngắn, với MỖI đoạn:
//     tổng hợp ▶ giải mã WAV ▶ ──audio{requestId,sampleRate,pcm}──▶ native
//   Dart trả {status: ok | cancelled | noVoice | failed}.
//
// Đoạn i+1 được tổng hợp TRONG LÚC đoạn i đang phát; Dart chỉ chờ native
// xác nhận đoạn i trước khi GỬI đoạn i+1 ⇒ không dồn cả bài vào RAM mà cũng
// không có khoảng lặng dài bằng thời gian tổng hợp giữa hai đoạn.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../features/tts/tts_text_chunker.dart';
import 'system_tts_pcm.dart';
import 'system_tts_protocol.dart';

/// Số ký tự tối đa mỗi đoạn. Ngắn hơn mức của tab Đọc (280) để tiếng đầu
/// tiên ra sớm — trình đọc màn hình / app đọc sách chờ lâu là thấy "treo".
const int kSystemTtsChunkChars = 200;

/// Thời gian chờ native xác nhận một khối âm thanh. Android chặn lời ghi tới
/// khi bộ đệm phát còn chỗ, nên một khối ~15 giây có thể được xác nhận sau
/// ~15 giây; mốc này chỉ để worker không treo vĩnh viễn nếu native chết.
const Duration kSystemTtsAudioAckTimeout = Duration(minutes: 5);

/// Một giọng mà một backend cung cấp.
@immutable
class SystemTtsBackendVoice {
  const SystemTtsBackendVoice({required this.voiceId, required this.locale});

  /// Mã giọng theo cách gọi của engine (tên model Piper, id giọng VieNeu…).
  final String voiceId;

  /// BCP-47, ví dụ `vi-VN`, `en-US`. Android cần locale cho MỌI giọng.
  final String locale;
}

/// Một engine TTS OFFLINE của app, nhìn từ phía worker.
abstract class SystemTtsBackend {
  /// Tiền tố của tên giọng lộ ra cho Android (`<id>/<voiceId>`).
  String get id;

  /// Giọng dùng được NGAY BÂY GIỜ (đã có model trên máy). Chỉ đọc đĩa,
  /// không nạp model. Thứ tự có nghĩa: giọng đứng trước là giọng mặc định
  /// của locale đó.
  Future<List<SystemTtsBackendVoice>> voices();

  /// Tổng hợp [text] thành WAV. Trả `null` hoặc ném lỗi khi thất bại.
  Future<Uint8List?> synthesizeWav({
    required String voiceId,
    required String locale,
    required String text,
    required double rate,
    required double pitch,
  });
}

/// Một giọng trong danh mục gửi cho Android.
@immutable
class SystemTtsVoice {
  const SystemTtsVoice({
    required this.name,
    required this.locale,
    required this.voiceId,
    required this.backend,
  });

  /// Tên duy nhất, là thứ Android lưu khi người dùng chọn giọng.
  final String name;
  final String locale;
  final String voiceId;
  final SystemTtsBackend backend;

  Map<String, Object?> toMap() => <String, Object?>{
        SystemTtsProtocol.keyName: name,
        SystemTtsProtocol.keyLocale: locale,
      };
}

final RegExp _speakable = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Đoạn có ít nhất một chữ/số — đoạn chỉ gồm dấu câu thì không đưa cho
/// engine (Piper trả rỗng ⇒ cả câu bị tính là lỗi).
bool isSpeakableForSystemTts(String text) => _speakable.hasMatch(text);

/// Chuẩn hoá `vi_VN` / `VI-vn` → `vi-VN`; chuỗi rỗng nếu không hợp lệ.
String normalizeSystemTtsLocale(String raw) {
  final parts = raw
      .trim()
      .replaceAll('_', '-')
      .split('-')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final language = parts.first.toLowerCase();
  if (!RegExp(r'^[a-z]{2,3}$').hasMatch(language)) return '';
  if (parts.length < 2) return language;
  final region = parts[1].toUpperCase();
  if (!RegExp(r'^([A-Z]{2}|[0-9]{3})$').hasMatch(region)) return language;
  return '$language-$region';
}

class SystemTtsWorker {
  SystemTtsWorker({
    required List<SystemTtsBackend> backends,
    MethodChannel? channel,
    this.chunkChars = kSystemTtsChunkChars,
    this.audioAckTimeout = kSystemTtsAudioAckTimeout,
  })  : _backends = List<SystemTtsBackend>.unmodifiable(backends),
        _channel = channel ?? const MethodChannel(SystemTtsProtocol.channel);

  final List<SystemTtsBackend> _backends;
  final MethodChannel _channel;
  final int chunkChars;
  final Duration audioAckTimeout;

  List<SystemTtsVoice> _voices = const <SystemTtsVoice>[];
  final Set<int> _cancelled = <int>{};
  Future<void> _tail = Future<void>.value();

  /// Danh mục giọng của lần quét gần nhất.
  List<SystemTtsVoice> get voices => _voices;

  /// Gắn handler rồi báo native "sẵn sàng" kèm danh mục giọng.
  Future<void> attach() async {
    _channel.setMethodCallHandler(handleCall);
    final found = await refreshVoices();
    try {
      await _channel.invokeMethod<void>(
        SystemTtsProtocol.methodReady,
        <String, Object?>{
          SystemTtsProtocol.keyVoices: _encode(found),
        },
      );
    } catch (e) {
      debugPrint('⚠️ system tts worker: không báo được ready: $e');
    }
  }

  static List<Map<String, Object?>> _encode(List<SystemTtsVoice> voices) =>
      voices.map((voice) => voice.toMap()).toList();

  /// Điểm vào của mọi lời gọi native → Dart (lộ ra để test gọi thẳng).
  Future<Object?> handleCall(MethodCall call) async {
    switch (call.method) {
      case SystemTtsProtocol.methodListVoices:
        return _encode(await refreshVoices());
      case SystemTtsProtocol.methodSynthesize:
        final raw = call.arguments;
        final args = raw is Map ? raw : const <Object?, Object?>{};
        return synthesize(args);
      case SystemTtsProtocol.methodCancel:
        final raw = call.arguments;
        final id = raw is Map ? raw[SystemTtsProtocol.keyRequestId] : raw;
        if (id is int) cancel(id);
        return null;
      default:
        throw MissingPluginException('system tts: ${call.method}');
    }
  }

  /// Quét lại giọng của mọi backend. Một backend hỏng không làm mất giọng
  /// của backend khác.
  Future<List<SystemTtsVoice>> refreshVoices() async {
    final found = <SystemTtsVoice>[];
    final seen = <String>{};
    for (final backend in _backends) {
      List<SystemTtsBackendVoice> list;
      try {
        list = await backend.voices();
      } catch (e) {
        debugPrint('⚠️ system tts worker: backend ${backend.id} lỗi: $e');
        continue;
      }
      for (final voice in list) {
        final locale = normalizeSystemTtsLocale(voice.locale);
        if (locale.isEmpty || voice.voiceId.isEmpty) continue;
        final name = '${backend.id}/${voice.voiceId}';
        if (!seen.add(name)) continue;
        found.add(SystemTtsVoice(
          name: name,
          locale: locale,
          voiceId: voice.voiceId,
          backend: backend,
        ));
      }
    }
    _voices = List<SystemTtsVoice>.unmodifiable(found);
    return _voices;
  }

  /// Chọn giọng: đúng tên → đúng locale → cùng ngôn ngữ. `null` nếu không có.
  SystemTtsVoice? resolveVoice({String? name, String? locale}) {
    if (name != null && name.isNotEmpty) {
      for (final voice in _voices) {
        if (voice.name == name) return voice;
      }
    }
    final want = normalizeSystemTtsLocale(locale ?? '');
    if (want.isEmpty) return null;
    for (final voice in _voices) {
      if (voice.locale == want) return voice;
    }
    final language = want.split('-').first;
    for (final voice in _voices) {
      if (voice.locale.split('-').first == language) return voice;
    }
    return null;
  }

  /// Dừng yêu cầu [requestId]: vòng đọc thoát trước đoạn kế tiếp.
  void cancel(int requestId) => _cancelled.add(requestId);

  /// Đọc một yêu cầu. Các yêu cầu chạy NỐI TIẾP: engine native chỉ có một
  /// model đang nạp, hai lượt tổng hợp chồng nhau là tranh nhau worker.
  Future<Map<String, Object?>> synthesize(Map<Object?, Object?> args) {
    final done = Completer<Map<String, Object?>>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await _run(args));
      } catch (e) {
        done.complete(_status(SystemTtsProtocol.statusFailed, '$e'));
      }
    });
    return done.future;
  }

  static Map<String, Object?> _status(String status, [String? message]) =>
      <String, Object?>{
        SystemTtsProtocol.keyStatus: status,
        if (message != null) SystemTtsProtocol.keyMessage: message,
      };

  Future<Map<String, Object?>> _run(Map<Object?, Object?> args) async {
    final rawId = args[SystemTtsProtocol.keyRequestId];
    final requestId = rawId is int ? rawId : 0;
    final text = (args[SystemTtsProtocol.keyText] as String?) ?? '';
    final name = args[SystemTtsProtocol.keyVoice] as String?;
    final locale = args[SystemTtsProtocol.keyLocale] as String?;
    final rate = _factor(args[SystemTtsProtocol.keyRate]);
    final pitch = _factor(args[SystemTtsProtocol.keyPitch]);

    try {
      if (_cancelled.contains(requestId)) {
        return _status(SystemTtsProtocol.statusCancelled);
      }

      var voice = resolveVoice(name: name, locale: locale);
      if (voice == null) {
        // Người dùng có thể vừa import giọng sau lần quét trước.
        await refreshVoices();
        voice = resolveVoice(name: name, locale: locale);
      }
      if (voice == null) {
        return _status(
          SystemTtsProtocol.statusNoVoice,
          'no offline voice for ${locale ?? name ?? '?'}',
        );
      }

      final chunks = chunkTextForTts(text, chunkChars)
          .where(isSpeakableForSystemTts)
          .toList();

      Future<bool>? pendingAck;
      for (final chunk in chunks) {
        if (_cancelled.contains(requestId)) {
          return _status(SystemTtsProtocol.statusCancelled);
        }

        String? problem;
        SystemTtsPcm? pcm;
        try {
          final wav = await voice.backend.synthesizeWav(
            voiceId: voice.voiceId,
            locale: voice.locale,
            text: chunk,
            rate: rate,
            pitch: pitch,
          );
          if (wav == null) {
            problem = 'engine returned no audio';
          } else {
            pcm = decodeWavToPcm16Mono(wav);
            if (pcm == null) problem = 'unsupported audio format';
          }
        } catch (e) {
          problem = '$e';
        }

        // Chờ khối TRƯỚC được native nhận xong rồi mới gửi khối này.
        if (pendingAck != null && !await pendingAck) {
          return _status(SystemTtsProtocol.statusCancelled);
        }
        pendingAck = null;

        if (pcm == null || pcm.bytes.isEmpty) {
          return _status(
            SystemTtsProtocol.statusFailed,
            '${voice.name}: ${problem ?? 'empty audio'}',
          );
        }
        if (_cancelled.contains(requestId)) {
          return _status(SystemTtsProtocol.statusCancelled);
        }
        pendingAck = _sendAudio(requestId, pcm);
      }

      if (pendingAck != null && !await pendingAck) {
        return _status(SystemTtsProtocol.statusCancelled);
      }
      return _status(SystemTtsProtocol.statusOk);
    } finally {
      _cancelled.remove(requestId);
    }
  }

  /// Android gửi tốc độ/cao độ theo phần trăm (100 = bình thường); native đã
  /// chia 100. Kẹp về khoảng engine chịu được.
  static double _factor(Object? raw) {
    final value = raw is num ? raw.toDouble() : 1.0;
    if (value.isNaN || value <= 0) return 1.0;
    return value.clamp(0.3, 3.0).toDouble();
  }

  Future<bool> _sendAudio(int requestId, SystemTtsPcm pcm) {
    return _channel
        .invokeMethod<bool>(
          SystemTtsProtocol.methodAudio,
          <String, Object?>{
            SystemTtsProtocol.keyRequestId: requestId,
            SystemTtsProtocol.keySampleRate: pcm.sampleRate,
            SystemTtsProtocol.keyPcm: pcm.bytes,
          },
        )
        .then((accepted) => accepted ?? false)
        .timeout(audioAckTimeout, onTimeout: () => false)
        .catchError((Object e) {
          debugPrint('⚠️ system tts worker: gửi audio lỗi: $e');
          return false;
        });
  }
}
