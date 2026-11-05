// packages/in4up_stt/lib/tts/vieneu_tts_core.dart
//
// VieNeu-TTS v3 Turbo (audio.cpp C API) — on-device, offline Vietnamese TTS
// cho module TTS của in4up (ticket TTS-VIENEU-001).
//
// Quy trình model (không bundle cứng vào APK, giống cơ chế import .gguf thủ
// công đang có ở Hy-MT):
//   1. Người dùng tải về `vieneu-v3-turbo-q8_0.gguf` (~170 MB, Apache-2.0) từ
//      https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo-GGUF
//   2. Import vào app → lưu vào documents/vieneu_tts/
//   3. (Tùy chọn, khuyên dùng) voices/<id>/ (ref_codes.txt +
//      speaker.emb.txt) và sea_g2p.bin + libsea_g2p_rs.so để engine nhận
//      văn bản tiếng Việt thuần thay vì chuỗi phoneme.
//
// Native: `native/tts_vieneu/` (C wrapper trên audio.cpp C ABI), build qua
// android/app/src/main/cpp/ai/CMakeLists.txt (chỉ Android arm64-v8a, CPU
// backend — GPU out of scope theo ticket). Desktop: lib chưa bundle ⇒ engine
// báo chưa sẵn sàng → fallback.
//
// Tất cả lệnh native (nạp model, synthesize) chạy trong **worker isolate**
// riêng (`_vieneuTtsWorkerEntry`) để native synthesize (có thể mất vài giây
// cho đoạn dài) KHÔNG block UI thread — câu hỏi architecture của ticket:
// ✅ cần isolate riêng, tương tự Gemma-IT generate (PR #23).

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Một giọng đọc preset được đóng gói kèm model GGUF.
class VieneuTtsVoice {
  /// Mã giọng (tên thư mục `voices/<id>/` trong gói GGUF).
  final String id;
  /// Tên hiển thị.
  final String name;
  /// Vùng miền (dùng làm nhãn UI; audio.cpp không trả metadata này).
  final String region;
  final String refCodesPath;
  final String? speakerEmbeddingPath;

  const VieneuTtsVoice({
    required this.id,
    required this.name,
    required this.region,
    required this.refCodesPath,
    this.speakerEmbeddingPath,
  });

  @override
  String toString() => '$name ($region)';
}

/// Kết quả synthesize: WAV 16-bit PCM mono, sẵn sàng phát bằng just_audio.
class VieneuTtsResult {
  final Uint8List wavBytes;
  final int sampleRate;

  const VieneuTtsResult({required this.wavBytes, required this.sampleRate});
}

/// Bridge FFI + worker isolate dành cho audio.cpp VieNeu-TTS engine.
///
/// Main isolate chỉ nhận lệnh và chuyển tiếp qua port; toàn bộ native
/// (DynamicLibrary + handle + synthesize) sống trong worker isolate.
class VieneuTtsCore {
  VieneuTtsCore._();
  static final VieneuTtsCore instance = VieneuTtsCore._();

  /// File GGUF mặc định (Q8_0, ~170 MB — cân bằng chất lượng/dung lượng;
  /// xem quyết định kỹ thuật docs/adr/0022).
  static const String modelFileName = 'vieneu-v3-turbo-q8_0.gguf';
  static const String _voicesDirName = 'voices';

  /// Giọng mặc định của gói GGUF (xem voices/manifest.json của nhà phát hành).
  static const String defaultVoiceId = 'minh_quan_pro';

  SendPort? _workerPort;
  ReceivePort? _commandPort;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextSeq = 0;

  /// Có thư viện native load được trên platform này?
  ///
  /// Chỉ tra symbol — KHÔNG nạp model, nhanh, an toàn gọi từ UI thread
  /// (dùng cho `isAvailable()` của engine).
  static Future<bool> isNativeLibraryAvailable() async {
    final candidates = <String>[];
    if (Platform.isAndroid) candidates.add('libvieneu_tts.so');
    if (Platform.isWindows) candidates.add('vieneu_tts.dll');
    if (Platform.isLinux || Platform.isMacOS) {
      candidates.add('libvieneu_tts.so');
    }

    for (final name in candidates) {
      try {
        final lib = ffi.DynamicLibrary.open(name);
        try {
          lib.lookupFunction<
              ffi.Pointer<ffi.Void> Function(
                  ffi.Pointer<ffi.Utf8>,
                  ffi.Pointer<ffi.Utf8>,
                  ffi.Pointer<ffi.Utf8>,
                  ffi.Int32),
              ffi.Pointer<ffi.Void> Function(
                  Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)>(
              'vieneu_tts_create');
          return true;
        } catch (_) {}
      } catch (_) {}
    }
    return false;
  }

  /// Đường dẫn file model trong documents của app, hoặc null nếu chưa import.
  static Future<String?> modelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'vieneu_tts', modelFileName));
    return await file.exists() ? file.path : null;
  }

  /// Khởi tạo worker isolate + nạp model vào native. Gọi trước synthesize.
  ///
  /// [modelPath] — file .gguf. [voiceId] — mã giọng preset (mặc định
  /// [defaultVoiceId]; files phải nằm trong [modelDir]/voices/<voiceId>/).
  Future<void> init({
    required String modelPath,
    String? voiceId,
  }) async {
    if (_workerPort != null) return; // đã khởi tạo

    final commandPort = ReceivePort();
    _commandPort = commandPort;
    _commandPort!.listen(_onWorkerMessage);

    Isolate.spawn(_vieneuTtsWorkerEntry, commandPort.sendPort);

    // Chờ worker gửi lại port của mình (handshake).
    final workerPort = await commandPort.first
        .timeout(const Duration(minutes: 1))
        .catchError((_) => throw StateError('VieNeu worker không khởi tạo được'));
    _workerPort = workerPort as SendPort;

    final response = await _call(
      {
        'cmd': 'init',
        'modelPath': modelPath,
        'voiceId': voiceId ?? defaultVoiceId,
        'voicesDir': p.join(p.dirname(modelPath), _voicesDirName),
      },
      timeout: const Duration(minutes: 5), // nạp 170 MB GGUF có thể lâu
    );
    if (response['ok'] != true) {
      await dispose();
      throw StateError(
          'VieNeu-TTS init thất bại: ${response['error'] ?? 'lỗi không xác định'}');
    }
  }

  /// Đổi giọng đọc (không cần nạp lại model — chỉ thay option của session).
  Future<void> selectVoice(String voiceId, String voicesDir) async {
    await _call({
      'cmd': 'select_voice',
      'voiceId': voiceId,
      'voicesDir': voicesDir,
    }, timeout: const Duration(seconds: 10));
  }

  /// Tổng hợp [text] (tiếng Việt) thành WAV bytes.
  ///
  /// Trả null nếu engine chưa init hoặc synthesis thất bại — caller (TTS
  /// engine/service) tự fallback sang engine khác, không crash.
  Future<VieneuTtsResult?> synthesize({
    required String text,
    required String language,
    String? voiceId,
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    if (_workerPort == null) return null;

    final response = await _call({
      'cmd': 'synthesize',
      'text': text,
      'language': language,
      'voiceId': voiceId,
      'speed': speed,
      'pitch': pitch,
    }, timeout: const Duration(minutes: 3));

    if (response['ok'] != true) return null;
    final b64 = response['wav'] as String?;
    if (b64 == null || b64.isEmpty) return null;
    return VieneuTtsResult(
      wavBytes: base64Decode(b64),
      sampleRate: (response['sampleRate'] as num? ?? 48000).toInt(),
    );
  }

  /// Giải phóng worker isolate + native handle.
  Future<void> dispose() async {
    try {
      if (_workerPort != null) {
        await _call(
          {'cmd': 'dispose'},
          timeout: const Duration(seconds: 10),
        ).catchError((_) {});
      }
    } finally {
      _workerPort = null;
      _commandPort?.close();
      _commandPort = null;
      _pending.clear();
      _nextSeq = 0;
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> message,
      {required Duration timeout}) {
    if (_workerPort == null) {
      return Future.error(StateError('VieNeu worker chưa khởi tạo'));
    }
    final seq = _nextSeq++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[seq] = completer;

    final msg = Map<String, dynamic>.from(message)..['seq'] = seq;
    _workerPort!.send(msg);

    return completer.future.timeout(timeout).catchError((e) {
      _pending.remove(seq);
      throw e;
    });
  }

  /// Nhận phản hồi từ worker isolate.
  void _onWorkerMessage(dynamic message) {
    final msg = message as Map?;
    if (msg == null) return;
    final seq = msg['seq'] as int?;
    if (seq == null) return;
    final completer = _pending.remove(seq);
    if (completer != null && !completer.isCompleted) {
      completer.complete(Map<String, dynamic>.from(msg));
    }
  }
}

/// Entry point của worker isolate (chạy ở isolate riêng, KHÔNG async — async
/// công việc nằm trong port.listen callback).
void _vieneuTtsWorkerEntry(SendPort commandPort) {
  final mainPort = ReceivePort();
  commandPort.send(mainPort.sendPort); // handshake

  _VieneuTtsNative? _native;
  ffi.Pointer<ffi.Void>? _handle;
  bool _initialized = false;

  void _reply(Map<String, dynamic> response) {
    mainPort.sendPort.send(response);
  }

  Map<String, dynamic> _respond({
    required bool ok,
    Object? error,
    Map<String, dynamic>? extra,
    int? seq,
  }) {
    final out = <String, dynamic>{'ok': ok, if (seq != null) 'seq': seq};
    if (error != null) out['error'] = error.toString();
    if (extra != null) out.addAll(extra);
    return out;
  }

  mainPort.listen((dynamic message) async {
    final msg = message as Map?;
    final cmd = msg?['cmd'] as String?;
    final seq = msg?['seq'] as int?;

    try {
      switch (cmd) {
        case 'init':
          final modelPath = msg?['modelPath'] as String?;
          final voiceId = msg?['voiceId'] as String?;
          final voicesDir = msg?['voicesDir'] as String?;
          if (modelPath == null || modelPath.isEmpty) {
            mainPort.sendPort.send(_respond(ok: false, error: 'modelPath trống', seq: seq));
            break;
          }
          final file = File(modelPath);
          if (!await file.exists()) {
            mainPort.sendPort.send(
                _respond(ok: false, error: 'Không tìm thấy file model: $modelPath', seq: seq));
            break;
          }
          _native = _VieneuTtsNative.load();
          if (_native == null || !_native!.available) {
            mainPort.sendPort.send(_respond(
                ok: false,
                error: 'Không load được thư viện native libvieneu_tts',
                seq: seq));
            break;
          }
          _handle = _native!.create(
            modelPath,
            _resolveVoiceFile(voicesDir, voiceId, 'ref_codes.txt'),
            _resolveVoiceFile(voicesDir, voiceId, 'speaker.emb.txt'),
            threads: 4,
          );
          if (_handle == ffi.nullptr) {
            mainPort.sendPort.send(_respond(
                ok: false, error: _native!.lastError, seq: seq));
            break;
          }
          _initialized = true;
          mainPort.sendPort.send(_respond(
            ok: true,
            seq: seq,
            extra: {
              'voiceId': voiceId ?? VieneuTtsCore.defaultVoiceId,
              'sampleRate': 48000,
            },
          ));
          break;

        case 'select_voice':
          if (!_initialized || _handle == null) {
            mainPort.sendPort.send(_respond(ok: false, error: 'Chưa init', seq: seq));
            break;
          }
          final voiceId = msg?['voiceId'] as String?;
          final voicesDir = msg?['voicesDir'] as String?;
          _native!.selectVoice(
            _handle!,
            _resolveVoiceFile(voicesDir, voiceId, 'ref_codes.txt'),
            _resolveVoiceFile(voicesDir, voiceId, 'speaker.emb.txt'),
          );
          mainPort.sendPort.send(_respond(
              ok: true,
              seq: seq,
              extra: {'voiceId': voiceId ?? VieneuTtsCore.defaultVoiceId}));
          break;

        case 'synthesize':
          if (!_initialized || _handle == null) {
            mainPort.sendPort.send(_respond(ok: false, error: 'Chưa init', seq: seq));
            break;
          }
          final text = msg?['text'] as String?;
          final language = msg?['language'] as String?;
          final speed = (msg?['speed'] as num? ?? 1.0).toDouble();
          final pitch = (msg?['pitch'] as num? ?? 1.0).toDouble();
          if (text == null || text.isEmpty) {
            mainPort.sendPort.send(_respond(ok: false, error: 'text trống', seq: seq));
            break;
          }

          final outSamples = calloc.allocate<ffi.Pointer<ffi.Float>>(1);
          final outFrames = calloc.allocate<ffi.Uint64>(1);
          final outRate = calloc.allocate<ffi.Int32>(1);

          try {
            final status = _native!.synthesize(
              _handle!,
              text,
              language ?? 'vi-VN',
              speed,
              pitch,
              outSamples,
              outFrames,
              outRate,
            );

            final ptr = outSamples.value;
            final frames = outFrames.value;
            final rate = outRate.value;

            if (status != 0 || ptr == ffi.nullptr || frames == 0) {
              mainPort.sendPort.send(_respond(
                  ok: false, error: _native!.lastError, seq: seq));
            } else {
              final floatList = ptr.asTypedList(frames).toList();
              _native!.freeAudio(ptr);
              final wav = _encodeWav16MonoFloat(floatList, rate);
              mainPort.sendPort.send(_respond(
                ok: true,
                seq: seq,
                extra: {'wav': base64Encode(wav), 'sampleRate': rate},
              ));
            }
          } finally {
            calloc.free(outSamples.cast<Void>());
            calloc.free(outFrames.cast<Void>());
            calloc.free(outRate.cast<Void>());
          }
          break;

        case 'dispose':
          if (_initialized) {
            _native!.destroy(_handle!);
            _handle = null;
            _initialized = false;
          }
          mainPort.sendPort.send(_respond(ok: true, seq: seq));
          break;

        default:
          mainPort.sendPort.send(
              _respond(ok: false, error: 'Lệnh không nhận diện: $cmd', seq: seq));
      }
    } catch (e, st) {
      debugPrint('⚠️ VieNeu worker exception: $e\n$st');
      mainPort.sendPort.send(_respond(ok: false, error: e.toString(), seq: seq));
    }
  });
}

/// Giải ref file của một giọng preset: `voicesDir/<voiceId>/<fileName>`.
String? _resolveVoiceFile(String? voicesDir, String? voiceId, String fileName) {
  if (voicesDir == null || voicesDir.isEmpty ||
      voiceId == null || voiceId.isEmpty) return null;
  final path = p.join(voicesDir, voiceId, fileName);
  return File(path).existsSync() ? path : null;
}

/// Encode Float32 PCM mono [-1, 1] thành WAV 16-bit LE.
Uint8List _encodeWav16MonoFloat(List<double> samples, int sampleRate) {
  final pcm16 = <int>[];
  pcm16.length = samples.length * 2;
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i].clamp(-1.0, 1.0);
    final v = (s * 32767.0).round().clamp(-32768, 32767);
    pcm16[i * 2] = v & 0xFF;
    pcm16[i * 2 + 1] = (v >> 8) & 0xFF;
  }

  final dataSize = pcm16.length;
  final fileSize = 36 + dataSize;
  final wav = <int>[];
  wav.addAll(utf8.encode('RIFF'));
  wav.addAll(_uint32Le(fileSize));
  wav.addAll(utf8.encode('WAVE'));
  wav.addAll(utf8.encode('fmt '));
  wav.addAll(_uint32Le(16)); // fmt chunk size
  wav.addAll(_uint16Le(1)); // format = PCM
  wav.addAll(_uint16Le(1)); // channels = 1
  wav.addAll(_uint32Le(sampleRate));
  wav.addAll(_uint32Le(sampleRate * 2)); // byte rate
  wav.addAll(_uint16Le(2)); // block align
  wav.addAll(_uint16Le(16)); // bits per sample
  wav.addAll(utf8.encode('data'));
  wav.addAll(_uint32Le(dataSize));
  wav.addAll(pcm16);
  return Uint8List.fromList(wav);
}

List<int> _uint32Le(int v) => [
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ];
List<int> _uint16Le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

/// Bindings FFI vào libvieneu_tts.so — chỉ tồn tại bên trong worker isolate.
class _VieneuTtsNative {
  _VieneuTtsNative(this._library);

  final ffi.DynamicLibrary _library;
  bool get available {
    try {
      _create;
      _synthesize;
      return true;
    } catch (_) {
      return false;
    }
  }

  static _VieneuTtsNative? load() {
    final names = Platform.isAndroid
        ? const ['libvieneu_tts.so']
        : Platform.isWindows
            ? const ['vieneu_tts.dll']
            : const ['libvieneu_tts.so'];
    for (final name in names) {
      try {
        final lib = ffi.DynamicLibrary.open(name);
        return _VieneuTtsNative(lib);
      } catch (_) {}
    }
    return null;
  }

  late final _Create _create =
      _library.lookupFunction<_CreateNative, _Create>('vieneu_tts_create');
  late final _SelectVoice _selectVoice = _library
      .lookupFunction<_SelectVoiceNative, _SelectVoice>(
          'vieneu_tts_select_voice');
  late final _Synthesize _synthesize = _library
      .lookupFunction<_SynthesizeNative, _Synthesize>(
          'vieneu_tts_synthesize');
  late final _FreeAudio _freeAudio = _library
      .lookupFunction<_FreeAudioNative, _FreeAudio>('vieneu_tts_free_audio');
  late final _Destroy _destroy = _library
      .lookupFunction<_DestroyNative, _Destroy>('vieneu_tts_destroy');
  late final _LastError _lastError = _library
      .lookupFunction<_LastErrorNative, _LastError>('vieneu_tts_last_error');

  String get lastError {
    final ptr = _lastError();
    if (ptr == ffi.nullptr) return 'lỗi không xác định';
    return ptr.toDartString();
  }

  ffi.Pointer<ffi.Void> create(String modelPath, String? refCodesFile,
      String? embeddingFile, {int threads = 4}) {
    final mp = modelPath.toNativeUtf8();
    final rc = refCodesFile == null ? nullptr : refCodesFile.toNativeUtf8();
    final se = embeddingFile == null ? nullptr : embeddingFile.toNativeUtf8();
    try {
      return _create(mp, rc, se, threads);
    } finally {
      calloc.free(mp.cast<Void>());
      calloc.free(rc.cast<Void>());
      calloc.free(se.cast<Void>());
    }
  }

  int synthesize(ffi.Pointer<ffi.Void> handle, String text, String language,
      double speed, double pitch,
      ffi.Pointer<ffi.Pointer<ffi.Float>> outSamples,
      ffi.Pointer<ffi.Uint64> outFrames, ffi.Pointer<ffi.Int32> outRate) {
    final txt = text.toNativeUtf8();
    final lang = language.toNativeUtf8();
    try {
      return _synthesize(handle, txt, lang, speed, pitch, outSamples,
          outFrames, outRate);
    } finally {
      calloc.free(txt.cast<Void>());
      calloc.free(lang.cast<Void>());
    }
  }

  void selectVoice(ffi.Pointer<ffi.Void> handle, String? refCodesFile,
      String? embeddingFile) {
    final rc = refCodesFile == null ? nullptr : refCodesFile.toNativeUtf8();
    final se = embeddingFile == null ? nullptr : embeddingFile.toNativeUtf8();
    try {
      _selectVoice(handle, rc, se);
    } finally {
      calloc.free(rc.cast<Void>());
      calloc.free(se.cast<Void>());
    }
  }

  void freeAudio(ffi.Pointer<ffi.Float> samples) => _freeAudio(samples);
  void destroy(ffi.Pointer<ffi.Void> handle) => _destroy(handle);
}

typedef _CreateNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Utf8>, ffi.Pointer<ffi.Utf8>, ffi.Pointer<ffi.Utf8>,
    ffi.Int32);
typedef _Create = ffi.Pointer<ffi.Void> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef _SelectVoiceNative = ffi.Void Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Utf8>, ffi.Pointer<ffi.Utf8>);
typedef _SelectVoice = void Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _SynthesizeNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Utf8>,
    ffi.Pointer<ffi.Utf8>,
    ffi.Float,
    ffi.Float,
    ffi.Pointer<ffi.Pointer<ffi.Float>>,
    ffi.Pointer<ffi.Uint64>,
    ffi.Pointer<ffi.Int32>);
typedef _Synthesize = int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    double,
    double,
    Pointer<Pointer<Float>>,
    Pointer<Uint64>,
    Pointer<Int32>);
typedef _FreeAudioNative = ffi.Void Function(ffi.Pointer<ffi.Float>);
typedef _FreeAudio = void Function(Pointer<Float>);
typedef _DestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _Destroy = void Function(Pointer<Void>);
typedef _LastErrorNative = ffi.Pointer<ffi.Utf8> Function();
typedef _LastError = Pointer<Utf8> Function();
