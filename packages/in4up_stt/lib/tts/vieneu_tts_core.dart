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
// riêng (`vieneuTtsWorkerEntry`) để native synthesize (có thể mất vài giây
// cho đoạn dài) KHÔNG block UI thread — câu hỏi architecture của ticket:
// ✅ cần isolate riêng, tương tự Gemma-IT generate (PR #23).

import 'dart:async';
import 'dart:convert';
// ⚠ KHÔNG import `dart:ffi` / `package:ffi/ffi.dart` kèm prefix (`as ffi`)
// trừ khi đổi TOÀN BỘ lời gọi. Bản đầu của PR #133 vừa import không
// prefix vừa dùng `ffi.Pointer` / `ffi.Utf8` ⇒ analyzer + mọi test job
// đỏ với "'ffi' doesn't refer to an import prefix".
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

// ============================================================================
// GIAI ĐOẠN 3 — nhiều phiên bản model GGUF (Q8_0 mặc định, bf16 tùy chọn).
//
// ⚠ PHẢI khai báo ở TOP-LEVEL: Dart KHÔNG cho `enum` / `extension` lồng trong
// `class` (analyzer: "Enums can't be declared inside classes" /
// "Extensions can't be declared inside classes"). Bản `eea5ee9` khai báo lồng
// trong `VieneuTtsCore` ⇒ lỗi compile ⇒ toàn bộ test job đỏ (job listen queue
// 42425879194) + build web đỏ (42425879182).
// ============================================================================

/// Phiên bản model VieNeu-TTS được hỗ trợ.
enum VieneuModelVariant {
  /// Q8_0 (~170 MB) — cân bằng chất lượng / dung lượng, mặc định.
  q8_0,

  /// bf16 (~292 MB) — chất lượng cao hơn, dung lượng lớn hơn.
  bf16,
}

/// Tên file GGUF + nhãn hiển thị cho từng phiên bản model.
extension VieneuModelVariantExt on VieneuModelVariant {
  /// Tên file `.gguf` tương ứng (dùng khi import + khi dò file đã có).
  String get fileName {
    switch (this) {
      case VieneuModelVariant.q8_0:
        return 'vieneu-v3-turbo-q8_0.gguf';
      case VieneuModelVariant.bf16:
        return 'vieneu-v3-turbo-bf16.gguf';
    }
  }

  /// Nhãn hiển thị kèm dung lượng ước tính.
  String get label {
    switch (this) {
      case VieneuModelVariant.q8_0:
        return 'Q8_0 (~170 MB)';
      case VieneuModelVariant.bf16:
        return 'bf16 (~292 MB)';
    }
  }
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

  /// Đường dẫn file model của [variant] trong documents của app, hoặc null nếu
  /// chưa import. Persistence của biến thể được chọn lưu ở tầng cao hơn
  /// (`TtsService`, có `shared_preferences`) — class này chỉ cung cấp path.
  static Future<String?> modelPathFor(VieneuModelVariant variant) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'vieneu_tts', variant.fileName));
    return await file.exists() ? file.path : null;
  }

  /// Kiểm tra phiên bản mô hình nào đã có file trên thiết bị.
  static Future<List<VieneuModelVariant>> getAvailableVariants() async {
    final result = <VieneuModelVariant>[];
    for (final v in VieneuModelVariant.values) {
      if (await modelPathFor(v) != null) result.add(v);
    }
    return result;
  }
  /// =========================================================================

  SendPort? _workerPort;
  /// Port nhận handshake (worker gửi SendPort của mình).
  ReceivePort? _commandPort;
  /// Port nhận MỌI phản hồi có `seq`. PSRC-183/184: bản cũ worker gửi
  /// response ngược lại vào chính `mainPort.sendPort` của nó ⇒ `_pending`
  /// không bao giờ được complete ⇒ init/clone/synthesize timeout rồi báo
  /// "worker chưa khởi tạo" dù model GGUF đã import xong. Phải tách riêng
  /// port trả lời của main isolate.
  ReceivePort? _responsePort;
  Isolate? _workerIsolate;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextSeq = 0;

  /// Future của lần [init] đang chạy (nếu có). PSRC-187: hai caller gọi
  /// `init` đồng thời (Settings voice picker + Read tab phát) đều thấy
  /// `_workerPort == null` và spawn HAI isolate cùng nạp model 170 MB ⇒
  /// OOM/văng app. Khóa này đảm bảo chỉ một lần spawn tại một thời điểm;
  /// caller thứ hai chờ cùng một future.
  Future<void>? _initFuture;

  /// Native đã trả lời `init` THÀNH CÔNG (không phải chỉ handshake xong).
  bool _ready = false;
  String? _activeModelPath;
  String? _activeVoiceId;

  /// Worker đã nạp model xong, sẵn sàng synthesize/clone.
  bool get isInitialized => _ready;

  /// Đường dẫn model đang nạp trong worker (để phát hiện đổi biến thể).
  String? get activeModelPath => _activeModelPath;

  /// Giọng đang được worker dùng.
  String? get activeVoiceId => _activeVoiceId;

  /// Chờ lần init đang bay (nếu có) kết thúc trước khi gửi lệnh khác sang
  /// worker. Không có bước này thì `clone_voice` có thể tới TRƯỚC khi native
  /// `init` xong và bị từ chối với lỗi "Chưa init" (PSRC-184).
  Future<void> _awaitReady() async {
    final inFlight = _initFuture;
    if (inFlight == null) return;
    try {
      await inFlight;
    } catch (_) {
      // Lỗi init được ném lại bởi caller của init; ở đây chỉ tránh gửi lệnh
      // sang worker đang ở trạng thái hỏng.
    }
  }

  /// Kết quả dò thư viện native (không đổi trong suốt một lần chạy app).
  static bool? _nativeLibraryProbe;

  /// Có thư viện native load được trên platform này?
  ///
  /// Chỉ tra symbol — KHÔNG nạp model, nhanh, an toàn gọi từ UI thread
  /// (dùng cho `isAvailable()` của engine).
  ///
  /// PSRC-187 (audit 1.27.0): kết quả được NHỚ — hàm này được hỏi ở mỗi câu
  /// đọc; và khi thư viện không có trong bản cài thì [init] dừng ngay, không
  /// spawn isolate nào.
  static Future<bool> isNativeLibraryAvailable() async {
    final cached = _nativeLibraryProbe;
    if (cached != null) return cached;
    final found = _probeNativeLibrary();
    _nativeLibraryProbe = found;
    return found;
  }

  /// Chỉ dùng cho test: ép (hoặc xoá, với `null`) kết quả dò thư viện native.
  @visibleForTesting
  static void debugSetNativeLibraryProbe(bool? value) {
    _nativeLibraryProbe = value;
  }

  static bool _probeNativeLibrary() {
    final candidates = <String>[];
    if (Platform.isAndroid) candidates.add('libvieneu_tts.so');
    if (Platform.isWindows) candidates.add('vieneu_tts.dll');
    if (Platform.isLinux || Platform.isMacOS) {
      candidates.add('libvieneu_tts.so');
    }

    for (final name in candidates) {
      try {
        final lib = DynamicLibrary.open(name);
        try {
          lib.lookupFunction<
              Pointer<Void> Function(
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Int32),
              Pointer<Void> Function(
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
  /// [defaultVoiceId]). [refCodesFile] / [speakerEmbeddingFile] cho phép
  /// truyền ĐÚNG file giọng đã liệt kê (kể cả giọng clone nằm ở
  /// `cloned_voices/`), thay vì chỉ dò `voices/<voiceId>/` (PSRC-184/186).
  ///
  /// An toàn gọi đồng thời: các lần gọi trong lúc đang init chờ cùng một
  /// future (PSRC-187). Nếu modelPath đổi (đổi Q8_0 ↔ bf16 hoặc import đè
  /// file mới) worker cũ được dispose và nạp lại — bản cũ `return` ngay khi
  /// `_workerPort != null` nên vẫn đọc model cũ dù UI báo đã import xong.
  Future<void> init({
    required String modelPath,
    String? voiceId,
    String? refCodesFile,
    String? speakerEmbeddingFile,
    String? clonedVoicesDir,
  }) {
    final inFlight = _initFuture;
    if (inFlight != null) {
      return inFlight.catchError((_) {}).then((_) => init(
            modelPath: modelPath,
            voiceId: voiceId,
            refCodesFile: refCodesFile,
            speakerEmbeddingFile: speakerEmbeddingFile,
            clonedVoicesDir: clonedVoicesDir,
          ));
    }
    if (_ready && _activeModelPath == modelPath) return Future.value();

    final future = _initOnce(
      modelPath: modelPath,
      voiceId: voiceId,
      refCodesFile: refCodesFile,
      speakerEmbeddingFile: speakerEmbeddingFile,
      clonedVoicesDir: clonedVoicesDir,
    );
    _initFuture = future;
    // Xóa khóa khi xong (thành công hay thất bại) để lần gọi sau được thử lại.
    // PSRC-187: `whenComplete` trả về một future MỚI mang cùng lỗi với
    // [future]; không ai nghe nó ⇒ mỗi lần init thất bại lại thành một lỗi
    // async không ai nhận. Caller vẫn nhận lỗi qua chính [future].
    future.whenComplete(() {
      if (identical(_initFuture, future)) _initFuture = null;
    }).ignore();
    return future;
  }

  Future<void> _initOnce({
    required String modelPath,
    String? voiceId,
    String? refCodesFile,
    String? speakerEmbeddingFile,
    String? clonedVoicesDir,
  }) async {
    // PSRC-187 (audit 1.27.0): bản cài không có thư viện native ⇒ dừng TRƯỚC
    // khi spawn. Thiếu chốt này, mỗi lần thử (mỗi câu đọc) spawn một isolate
    // chỉ để nghe worker báo "Không load được thư viện native".
    if (!await isNativeLibraryAvailable()) {
      throw StateError(
        'VieNeu-TTS native library (libvieneu_tts) is not bundled in this '
        'build',
      );
    }

    // Dọn worker cũ TRƯỚC khi spawn worker mới: không bao giờ giữ 2 model
    // 170–292 MB cùng lúc.
    if (_workerPort != null || _workerIsolate != null || _ready) {
      await dispose();
    }

    final commandPort = ReceivePort();
    final responsePort = ReceivePort();
    _commandPort = commandPort;
    _responsePort = responsePort;
    responsePort.listen(_onWorkerMessage);

    try {
      final isolate = await Isolate.spawn(
        vieneuTtsWorkerEntry,
        <SendPort>[commandPort.sendPort, responsePort.sendPort],
      );
      _workerIsolate = isolate;

      // Chờ worker gửi lại port nhận lệnh (handshake).
      final workerPort = await commandPort.first
          .timeout(const Duration(seconds: 30));
      _workerPort = workerPort as SendPort;

      final response = await _call(
        {
          'cmd': 'init',
          'modelPath': modelPath,
          'voiceId': voiceId ?? defaultVoiceId,
          'voicesDir': p.join(p.dirname(modelPath), _voicesDirName),
          'clonedVoicesDir': clonedVoicesDir ??
              p.join(p.dirname(modelPath), 'cloned_voices'),
          'refCodesFile': refCodesFile,
          'speakerEmbeddingFile': speakerEmbeddingFile,
        },
        timeout: const Duration(minutes: 5), // nạp 170 MB GGUF có thể lâu
      );
      if (response['ok'] != true) {
        throw StateError(
            'VieNeu-TTS init thất bại: ${response['error'] ?? 'lỗi không xác định'}');
      }
      _ready = true;
      _activeModelPath = modelPath;
      _activeVoiceId = voiceId ?? defaultVoiceId;
    } catch (e) {
      await dispose();
      if (e is TimeoutException) {
        throw StateError('VieNeu worker không khởi tạo được: ${e.message ?? e}');
      }
      rethrow;
    }
  }

  /// Đổi giọng đọc (không cần nạp lại model — chỉ thay option của session).
  ///
  /// [refCodesFile] / [speakerEmbeddingFile] là đường dẫn TUYỆT ĐỐI đã được
  /// engine kiểm tra; worker ưu tiên chúng, rồi mới dò `voices/<id>/` và
  /// `cloned_voices/<id>/` (PSRC-184/186).
  Future<void> selectVoice(
    String voiceId,
    String voicesDir, {
    String? clonedVoicesDir,
    String? refCodesFile,
    String? speakerEmbeddingFile,
  }) async {
    await _awaitReady();
    final response = await _call({
      'cmd': 'select_voice',
      'voiceId': voiceId,
      'voicesDir': voicesDir,
      'clonedVoicesDir': clonedVoicesDir,
      'refCodesFile': refCodesFile,
      'speakerEmbeddingFile': speakerEmbeddingFile,
    }, timeout: const Duration(seconds: 10));
    if (response['ok'] != true) {
      throw StateError(
          'VieNeu-TTS đổi giọng thất bại: ${response['error'] ?? 'lỗi không xác định'}');
    }
    _activeVoiceId = voiceId;
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
    await _awaitReady();
    if (_workerPort == null || !_ready) return null;

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

  /// TTS-CLONE-001 — Clone giọng nói từ các file mẫu WAV.
  ///
  /// [voiceId] — mã giọng mới (tên thư mục trong voices/).
  /// [samplesDir] — thư mục chứa các file WAV mẫu (30–60 giây tổng cộng).
  ///
  /// Trả về đường dẫn file speaker.emb.txt đã tạo, hoặc ném exception nếu
  /// thất bại. Sau khi clone thành công, giọng mới sẽ xuất hiện trong
  /// [getAvailableVoices] và có thể chọn qua [selectVoice].
  Future<String> cloneVoice({
    required String voiceId,
    required String samplesDir,
  }) async {
    await _awaitReady();
    if (_workerPort == null || !_ready) {
      throw StateError('VieNeu worker chưa khởi tạo');
    }

    // samplesDir = <cloned_voices>/<voiceId>/samples ⇒ embedding nằm cùng
    // thư mục giọng: <cloned_voices>/<voiceId>/speaker.emb.txt. Bản cũ dùng
    // `..` + voiceId khiến native tạo thư mục lồng <voiceId>/<voiceId> và
    // embedding không khớp nơi UI tìm (PSRC-184).
    final outputEmbedding =
        p.join(p.dirname(samplesDir), 'speaker.emb.txt');
    final response = await _call(
      {
        'cmd': 'clone_voice',
        'voiceId': voiceId,
        'samplesDir': samplesDir,
        'outputEmbedding': outputEmbedding,
      },
      timeout: const Duration(minutes: 2),
    );

    if (response['ok'] != true) {
      throw StateError(
          'VieNeu-TTS clone thất bại: ${response['error'] ?? 'lỗi không xác định'}');
    }

    return response['embeddingPath'] as String? ?? outputEmbedding;
  }

  /// Giải phóng worker isolate + native handle.
  ///
  /// PSRC-183/184: phải reset `_ready` và kill isolate, nếu không lần
  /// synthesize/clone sau khi import model mới vẫn hỏi worker cũ (đã mang
  /// model cũ / đang hỏng) và UI báo trạng thái sai.
  Future<void> dispose() async {
    try {
      if (_workerPort != null) {
        await _call(
          {'cmd': 'dispose'},
          timeout: const Duration(seconds: 10),
        ).catchError((_) => <String, dynamic>{});
      }
    } finally {
      _workerPort = null;
      _ready = false;
      _activeModelPath = null;
      _activeVoiceId = null;
      _initFuture = null;
      _workerIsolate?.kill(priority: Isolate.immediate);
      _workerIsolate = null;
      _commandPort?.close();
      _commandPort = null;
      _responsePort?.close();
      _responsePort = null;
      for (final completer in _pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('VieNeu worker đã giải phóng'));
        }
      }
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
///
/// Public để test máy bắt được lỗi
/// "gửi response nhầm port" (PSRC-183/184) mà không cần native lib.
///
/// [ports][0]: port handshake của main isolate (worker gửi SendPort nhận lệnh).
/// [ports][1]: port TRẢ LỜI của main isolate (mọi response có `seq` đi qua đây).
@visibleForTesting
void vieneuTtsWorkerEntry(List<SendPort> ports) {
  if (ports.length < 2) {
    throw ArgumentError('VieNeu worker cần handshakePort + replyPort');
  }
  final handshakePort = ports[0];
  final replyPort = ports[1];
  final mainPort = ReceivePort();
  handshakePort.send(mainPort.sendPort); // handshake

  _VieneuTtsNative? _native;
  Pointer<Void>? _handle;
  bool _initialized = false;

  void _reply(Map<String, dynamic> response) {
    // ⚠ KHÔNG dùng `mainPort.sendPort.send(...)`: đó là port của CHÍNH
    // worker, response sẽ quay lại worker thay vì main isolate ⇒ mọi lệnh
    // `_call` treo tới timeout (PSRC-183/184).
    replyPort.send(response);
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
          final clonedVoicesDir = msg?['clonedVoicesDir'] as String?;
          final explicitRefCodes = msg?['refCodesFile'] as String?;
          final explicitEmbedding = msg?['speakerEmbeddingFile'] as String?;
          if (modelPath == null || modelPath.isEmpty) {
            _reply(_respond(ok: false, error: 'modelPath trống', seq: seq));
            break;
          }
          final file = File(modelPath);
          if (!await file.exists()) {
            _reply(
                _respond(ok: false, error: 'Không tìm thấy file model: $modelPath', seq: seq));
            break;
          }
          _native = _VieneuTtsNative.load();
          if (_native == null || !_native!.available) {
            _reply(_respond(
                ok: false,
                error: 'Không load được thư viện native libvieneu_tts',
                seq: seq));
            break;
          }
          _handle = _native!.create(
            modelPath,
            _voiceFileFor(explicitRefCodes, voicesDir, clonedVoicesDir,
                voiceId, 'ref_codes.txt'),
            _voiceFileFor(explicitEmbedding, voicesDir, clonedVoicesDir,
                voiceId, 'speaker.emb.txt'),
            threads: 4,
          );
          if (_handle == nullptr) {
            _reply(_respond(
                ok: false, error: _native!.lastError, seq: seq));
            break;
          }
          _initialized = true;
          _reply(_respond(
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
            _reply(_respond(ok: false, error: 'Chưa init', seq: seq));
            break;
          }
          final voiceId = msg?['voiceId'] as String?;
          final voicesDir = msg?['voicesDir'] as String?;
          final clonedVoicesDir = msg?['clonedVoicesDir'] as String?;
          final explicitRefCodes = msg?['refCodesFile'] as String?;
          final explicitEmbedding = msg?['speakerEmbeddingFile'] as String?;
          _native!.selectVoice(
            _handle!,
            _voiceFileFor(explicitRefCodes, voicesDir, clonedVoicesDir,
                voiceId, 'ref_codes.txt'),
            _voiceFileFor(explicitEmbedding, voicesDir, clonedVoicesDir,
                voiceId, 'speaker.emb.txt'),
          );
          _reply(_respond(
              ok: true,
              seq: seq,
              extra: {'voiceId': voiceId ?? VieneuTtsCore.defaultVoiceId}));
          break;

        case 'synthesize':
          if (!_initialized || _handle == null) {
            _reply(_respond(ok: false, error: 'Chưa init', seq: seq));
            break;
          }
          final text = msg?['text'] as String?;
          final language = msg?['language'] as String?;
          final speed = (msg?['speed'] as num? ?? 1.0).toDouble();
          final pitch = (msg?['pitch'] as num? ?? 1.0).toDouble();
          if (text == null || text.isEmpty) {
            _reply(_respond(ok: false, error: 'text trống', seq: seq));
            break;
          }

          // PSRC-187 (audit 1.27.0): `calloc<T>()` cấp ĐỦ sizeOf<T>. Bản cũ
          // gọi `calloc.allocate<T>(1)` — tham số là SỐ BYTE — tức xin 1 byte
          // cho một con trỏ 8 byte / một uint64 8 byte / một int32 4 byte, rồi
          // để native ghi vào đó.
          final outSamples = calloc<Pointer<Float>>();
          final outFrames = calloc<Uint64>();
          final outRate = calloc<Int32>();

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

            if (status != 0 || ptr == nullptr || frames == 0) {
              _reply(_respond(
                  ok: false, error: _native!.lastError, seq: seq));
            } else {
              // Chép mẫu ra khỏi heap native TRƯỚC khi trả bộ đệm cho native.
              final samples = Float32List.fromList(ptr.asTypedList(frames));
              _native!.freeAudio(ptr);
              final wav = encodeWav16MonoFloat(samples, rate);
              _reply(_respond(
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

        case 'clone_voice':
          if (!_initialized || _handle == null) {
            _reply(_respond(ok: false, error: 'Chưa init', seq: seq));
            break;
          }
          final voiceId = msg?['voiceId'] as String?;
          final samplesDir = msg?['samplesDir'] as String?;
          final outputEmbedding = msg?['outputEmbedding'] as String?;
          if (voiceId == null || voiceId.isEmpty ||
              samplesDir == null || samplesDir.isEmpty ||
              outputEmbedding == null || outputEmbedding.isEmpty) {
            _reply(_respond(
                ok: false, error: 'Thiếu tham số clone giọng', seq: seq));
            break;
          }
          final status = _native!.cloneVoice(
            voiceId,
            samplesDir,
            outputEmbedding,
          );
          if (status != 0) {
            _reply(_respond(
                ok: false, error: _native!.lastError, seq: seq));
          } else {
            _reply(_respond(
              ok: true,
              seq: seq,
              extra: {'embeddingPath': outputEmbedding, 'voiceId': voiceId},
            ));
          }
          break;

        case 'dispose':
          if (_initialized) {
            _native!.destroy(_handle!);
            _handle = null;
            _initialized = false;
          }
          _reply(_respond(ok: true, seq: seq));
          break;

        default:
          _reply(
              _respond(ok: false, error: 'Lệnh không nhận diện: $cmd', seq: seq));
      }
    } catch (e, st) {
      debugPrint('⚠️ VieNeu worker exception: $e\n$st');
      _reply(_respond(ok: false, error: e.toString(), seq: seq));
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

/// PSRC-184/186 — ưu tiên đường dẫn tuyệt đối do engine đã kiểm tra, rồi
/// dò preset `voices/`, cuối cùng là giọng clone `cloned_voices/`.
/// Bản cũ chỉ dò `voices/<id>/` nên giọng clone (nằm ở `cloned_voices/`)
/// được liệt kê trong dropdown nhưng KHÔNG BAO GIỜ được nạp.
String? _voiceFileFor(
  String? explicitPath,
  String? voicesDir,
  String? clonedVoicesDir,
  String? voiceId,
  String fileName,
) {
  if (explicitPath != null && explicitPath.isNotEmpty &&
      File(explicitPath).existsSync()) {
    return explicitPath;
  }
  final preset = _resolveVoiceFile(voicesDir, voiceId, fileName);
  if (preset != null) return preset;
  return _resolveVoiceFile(clonedVoicesDir, voiceId, fileName);
}

/// Encode Float32 PCM mono [-1, 1] thành WAV 16-bit LE.
///
/// PSRC-187 (audit 1.27.0): ghi thẳng vào một `Uint8List` (bản cũ dựng
/// `List<int>` — mỗi BYTE âm thanh chiếm cả một ô 4–8 byte — rồi chép lại hai
/// lần) và coi mẫu NaN là im lặng (bản cũ để `clamp` đổi NaN thành +1.0, tức
/// ghi ra một mẫu ở biên độ cực đại: `clamp` xếp NaN là giá trị lớn nhất).
@visibleForTesting
Uint8List encodeWav16MonoFloat(Float32List samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final bytes = Uint8List(44 + dataSize);
  final view = ByteData.sublistView(bytes);

  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes[offset + i] = text.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  view.setUint32(16, 16, Endian.little); // fmt chunk size
  view.setUint16(20, 1, Endian.little); // format = PCM
  view.setUint16(22, 1, Endian.little); // channels = 1
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  view.setUint16(32, 2, Endian.little); // block align
  view.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  view.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final sample = samples[i];
    // NaN ⇒ im lặng. Không tách riêng thì `clamp` đổi NaN thành cận trên
    // (+1.0); còn `round()` thẳng trên NaN thì ném lỗi.
    final clamped = sample.isNaN ? 0.0 : sample.clamp(-1.0, 1.0);
    final value = (clamped * 32767.0).round();
    view.setInt16(44 + i * 2, value, Endian.little);
  }
  return bytes;
}

/// Bindings FFI vào libvieneu_tts.so — chỉ tồn tại bên trong worker isolate.
class _VieneuTtsNative {
  _VieneuTtsNative(this._library);

  final DynamicLibrary _library;
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
        final lib = DynamicLibrary.open(name);
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
  late final _CloneVoice _cloneVoice = _library
      .lookupFunction<_CloneVoiceNative, _CloneVoice>(
          'vieneu_tts_clone_voice');

  String get lastError {
    final ptr = _lastError();
    if (ptr == nullptr) return 'lỗi không xác định';
    return ptr.toDartString();
  }

  Pointer<Void> create(String modelPath, String? refCodesFile,
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

  int synthesize(Pointer<Void> handle, String text, String language,
      double speed, double pitch,
      Pointer<Pointer<Float>> outSamples,
      Pointer<Uint64> outFrames, Pointer<Int32> outRate) {
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

  void selectVoice(Pointer<Void> handle, String? refCodesFile,
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

  void freeAudio(Pointer<Float> samples) => _freeAudio(samples);
  void destroy(Pointer<Void> handle) => _destroy(handle);

  int cloneVoice(String voiceId, String samplesDir, String outputEmbedding) {
    final vid = voiceId.toNativeUtf8();
    final sd = samplesDir.toNativeUtf8();
    final oe = outputEmbedding.toNativeUtf8();
    try {
      return _cloneVoice(vid, sd, oe);
    } finally {
      calloc.free(vid.cast<Void>());
      calloc.free(sd.cast<Void>());
      calloc.free(oe.cast<Void>());
    }
  }
}

typedef _CreateNative = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
    Int32);
typedef _Create = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef _SelectVoiceNative = Void Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _SelectVoice = void Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _SynthesizeNative = Int32 Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Float,
    Float,
    Pointer<Pointer<Float>>,
    Pointer<Uint64>,
    Pointer<Int32>);
typedef _Synthesize = int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    double,
    double,
    Pointer<Pointer<Float>>,
    Pointer<Uint64>,
    Pointer<Int32>);
typedef _FreeAudioNative = Void Function(Pointer<Float>);
typedef _FreeAudio = void Function(Pointer<Float>);
typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _Destroy = void Function(Pointer<Void>);
typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _LastError = Pointer<Utf8> Function();

typedef _CloneVoiceNative = Int32 Function(
    Pointer<Utf8>,  // voice_id
    Pointer<Utf8>,  // samples_dir
    Pointer<Utf8>); // output_embedding
typedef _CloneVoice = int Function(
    Pointer<Utf8>,  // voice_id
    Pointer<Utf8>,  // samples_dir
    Pointer<Utf8>); // output_embedding
