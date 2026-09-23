// ignore_for_file: implementation_imports, depend_on_referenced_packages, unnecessary_brace_in_string_interps
// Hy-MT 1.5 (Tencent Hunyuan) — engine dịch câu offline qua GGUF + llama.cpp.
// Model ~600MB. KHÔNG load lúc bootstrap. User bấm Import hoặc Tải về.
//
// HYMT-002 (2026-09-16) — đóng timeout theo lớp, KHÔNG chỉ tăng 2→4 phút:
//   1. Single-flight: [HyMtSlot] — 1 request tại một thời điểm; request
//      kế tiếp queue có giới hạn chờ (mặc định 90s < 2 phút) hoặc trả
//      trạng thái "đang bận" có cấu trúc (errorCode 'busy') — không treo.
//   2. Health trước request: liveness + ping (heartbeat) TRƯỚC khi gửi;
//      isolate chết (OOM/kill) hoặc load hỏng → dispose, spawn lại, retry
//      chunk hỏng TỐI ĐA 1 LẦN rồi báo lỗi cuối rõ ràng (mã lỗi cấu trúc).
//   3. Text dài tách theo ranh giới câu/cụm ([HyMtChunking], mục tiêu
//      ≤500 ký tự/chunk) — MỖI chunk có timeout hữu hạn riêng; ghép đúng
//      thứ tự (phân hoạch chính xác — không lặp/mất đoạn); lỗi chunk KHÔNG
//      bị nuốt (lỗi cuối nêu đúng segment i/N).
//   4. Mọi timeout đều hữu hạn (chờ slot, load, ping, mỗi chunk) — không
//      có đường nào treo vô hạn; UI báo "Đang dịch bằng Hy-MT offline, có
//      thể chậm" và kết thúc ở success hoặc error hữu hạn.

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:in4up_ai/src/engine/ai_native_bindings.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hymt_chunking.dart';
import 'hymt_prompts.dart';
import 'hymt_slot.dart';
import 'translation_engine.dart';

enum HyMtOfflinePreference { auto, hymt, mlkit }

/// Mã lỗi cấu trúc — UI/service phân nhánh theo mã thay vì match chuỗi.
enum HyMtErrorCode {
  /// Request khác vẫn đang chạy (hết hạn chờ slot).
  busy,

  /// Isolate chết (OOM/kill) — đã tự restart + retry 1 lần.
  isolateDead,

  /// Không create/load được model (file hỏng, quant, RAM, thiếu native).
  loadFailed,

  /// Một chunk vượt timeout (native có thể đang treo).
  requestTimeout,

  /// Isolate trả lỗi trong quá trình generate.
  requestFailed,

  /// Model trả output rỗng (sạch rác xong).
  emptyOutput,

  /// Text vượt giới hạn của Hy-MT offline.
  tooLong,

  /// Cặp ngôn ngữ không hỗ trợ.
  unsupported,

  /// Chưa có model (hoặc file bị cắt/hỏng).
  noModel,

  /// Build thiếu native lib llama.cpp.
  noNative,
}

/// Lỗi runtime của Hy-MT (isolate chết, load hỏng, treo, ...).
class HyMtRuntimeFailure implements Exception {
  const HyMtRuntimeFailure(this.code, this.message);

  final HyMtErrorCode code;
  final String message;

  @override
  String toString() => 'HyMtRuntimeFailure(${code.name}): $message';
}

/// Lớp "gửi prompt → nhận output thô" của Hy-MT.
///
/// [HyMtIsolateBackend] là backend thật (isolate llama.cpp). Test inject
/// backend giả qua [HyMtEngine.forTest] để kiểm tra logic queue/retry/
/// chunk MÀ KHÔNG cần native lib, isolate hay model 600MB.
abstract class HyMtBackend {
  /// Runtime đang alive và có thể nhận request ngay (đã load).
  bool get isAlive;

  /// Lỗi thật của lần load gần nhất (null = chưa load hoặc chưa fail).
  String? get lastLoadError;

  /// Heartbeat ngắn trước request (HYMT-002 mục 2).
  /// `false` = chết hoặc treo — caller phải [restart].
  Future<bool> ping();

  /// Sinh output blocking cho [prompt]. Ném [HyMtRuntimeFailure] khi
  /// isolate chết / trả lỗi. (Timeout do caller áp lên future.)
  Future<String> generate(String prompt);

  /// dispose + spawn + chờ kết quả load THẬT.
  /// `false` = load fail (xem [lastLoadError]).
  Future<bool> restart();

  /// Dọn runtime (kill isolate + destroy model).
  Future<void> dispose();
}

/// Runtime Hy-MT thật: llama.cpp trong [Isolate] (FFI blocking → phải
/// khỏi main isolate). 1 isolate = 1 model — KHÔNG load song song 2 model
/// (gây OOM).
class HyMtIsolateBackend implements HyMtBackend {
  HyMtIsolateBackend(this.modelPath,
      {Duration pingTimeout = const Duration(seconds: 5)})
      : _pingTimeout = pingTimeout;

  final String modelPath;
  final Duration _pingTimeout;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool _loading = false;
  bool _dead = false;
  Object? _deathError;
  String? _lastLoadError;

  /// Request đang chạy — isolate chết phải fail chúng NGAY (không đợi
  /// timeout của caller).
  final Set<Completer<Object?>> _inFlight = <Completer<Object?>>{};

  @override
  bool get isAlive => !_dead && _sendPort != null;

  @override
  String? get lastLoadError => _lastLoadError;

  void _markDead(Object? error) {
    if (_dead) return;
    _dead = true;
    _deathError = error;
    final pending = List<Completer<Object?>>.of(_inFlight);
    _inFlight.clear();
    for (final c in pending) {
      if (!c.isCompleted) {
        c.completeError(HyMtRuntimeFailure(
          HyMtErrorCode.isolateDead,
          'Isolate Hy-MT đã chết: ${error == null ? 'không rõ lý do (có thể OOM)' : error}',
        ));
      }
    }
  }

  @override
  Future<bool> ping() async {
    final sendPort = _sendPort;
    if (_dead || sendPort == null) return false;
    final reply = ReceivePort();
    sendPort.send(_Ping(reply.sendPort));
    try {
      final msg = await reply.first.timeout(_pingTimeout);
      if (msg == _pong) return true;
      _markDead('Heartbeat trả về sai');
      return false;
    } on TimeoutException {
      _markDead('Không có heartbeat trong ${_pingTimeout.inSeconds}s');
      return false;
    } finally {
      reply.close();
    }
  }

  @override
  Future<String> generate(String prompt) async {
    final sendPort = _sendPort;
    if (_dead) {
      throw HyMtRuntimeFailure(
        HyMtErrorCode.isolateDead,
        'Isolate Hy-MT không còn sống: ${_deathError ?? 'không rõ lý do'}',
      );
    }
    if (sendPort == null) {
      throw const HyMtRuntimeFailure(
        HyMtErrorCode.loadFailed,
        'Runtime Hy-MT chưa được load',
      );
    }
    final reply = ReceivePort();
    final done = Completer<Object?>();
    reply.listen((Object? msg) {
      if (!done.isCompleted) done.complete(msg);
    });
    _inFlight.add(done);
    sendPort.send(_Req(prompt, reply.sendPort));
    try {
      final msg = await done.future;
      if (msg is HyMtReply) {
        if (msg.error != null) {
          throw HyMtRuntimeFailure(HyMtErrorCode.requestFailed, msg.error);
        }
        return msg.output;
      }
      throw HyMtRuntimeFailure(
        HyMtErrorCode.isolateDead,
        'Isolate Hy-MT trả về kết quả không hợp lệ',
      );
    } finally {
      _inFlight.remove(done);
      reply.close();
    }
  }

  @override
  Future<bool> restart() async {
    if (_loading) return false; // không 2 load song song (RAM/OOM)
    _loading = true;
    try {
      await _teardown();
      _dead = false;
      _deathError = null;
      _lastLoadError = null;

      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        HyMtIsolateBackend._isolateEntry,
        _Init(modelPath, _receivePort!.sendPort),
        debugName: 'HyMtIsolate',
      );
      // Isolate chết (OOM/kill) → đánh dấu + fail request đang chạy NGAY.
      // Listener gắn vào đúng isolate instance — exit cũ của isolate
      // đã bị kill (do dispose) không làm "chết nhầm" runtime mới.
      final thisIsolate = _isolate!;
      thisIsolate.addOnExitListener((Object? error) {
        if (identical(_isolate, thisIsolate)) _markDead(error);
      });

      final ready = Completer<SendPort>();
      final loadDone = Completer<bool>();
      _receivePort!.listen((Object? msg) {
        if (msg is SendPort && !ready.isCompleted) ready.complete(msg);
        if (msg is _LoadResult && !loadDone.isCompleted) {
          if (!msg.ready) _lastLoadError = msg.error;
          loadDone.complete(msg.ready);
        }
      });
      _sendPort = await ready.future.timeout(const Duration(seconds: 45));
      // FIX 2026-09-03 (HYMT-001): phải ĐỢI kết quả create() THẬT từ
      // isolate — bản cũ chỉ đợi handshake rồi trả true, nên create()
      // fail vẫn được coi là "đã sẵn sàng".
      final ok = await loadDone.future.timeout(const Duration(minutes: 2));
      if (!ok) {
        debugPrint('Hy-MT create failed: $_lastLoadError');
        await _teardown();
        return false;
      }
      debugPrint('✅ Hy-MT GGUF loaded: $modelPath');
      return true;
    } catch (e) {
      debugPrint('Hy-MT load failed: $e');
      _lastLoadError = e.toString();
      await _teardown();
      return false;
    } finally {
      _loading = false;
    }
  }

  Future<void> _teardown() async {
    final isolate = _isolate;
    _isolate = null;
    _sendPort = null;
    final port = _receivePort;
    _receivePort = null;
    if (isolate != null) isolate.kill(priority: Isolate.immediate);
    port?.close();
  }

  @override
  Future<void> dispose() async {
    await _teardown();
    _lastLoadError = null;
  }

  static void _isolateEntry(_Init init) async {
    final port = ReceivePort();
    init.main.send(port.sendPort);
    final native = AiNativeBindings.tryLoad();
    ffi.Pointer<ffi.Void>? handle;
    String? loadError;
    if (native == null) {
      loadError = 'Build chưa có llama.cpp (in4up_ai_native) — cần bản app '
          'có AI native.';
    } else {
      handle = native.create(init.modelPath, contextSize: 2048, threads: 4);
      if (handle == ffi.nullptr) {
        handle = null;
        loadError = 'llama_model_load_from_file thất bại: file GGUF '
            'hỏng/cắt, quant không được llama.cpp hỗ trợ, hoặc thiếu RAM.';
      }
    }
    // FIX 2026-09-03 (HYMT-001): báo kết quả create() THẬT cho main side
    // (gửi SAU khi create hoàn tất).
    init.main.send(_LoadResult(ready: handle != null, error: loadError));
    await for (final Object? msg in port) {
      if (msg is _Ping) {
        // Heartbeat (HYMT-002): chứng minh isolate còn sống và xử lý
        // được message TRƯỚC khi request dài.
        msg.reply.send(_pong);
        continue;
      }
      if (msg is _Req) {
        try {
          if (native == null || handle == null) {
            msg.reply.send(HyMtReply.fail(loadError ?? 'Hy-MT native không load được'));
            continue;
          }
          final out = native.generate(
            handle,
            msg.prompt,
            maxTokens: 512,
            temperature: 0.3,
          );
          msg.reply.send(HyMtReply.ok(out ?? ''));
        } catch (e) {
          msg.reply.send(HyMtReply.fail('Hy-MT: $e'));
        }
      }
    }
    if (native != null && handle != null) native.destroy(handle);
  }
}

/// Reply có cấu trúc từ isolate — phân biệt "output model" với "lỗi"
/// (code cũ coi mọi String khác rỗng là output → chuỗi lỗi hiển thị như
/// bản dịch).
class HyMtReply {
  const HyMtReply.ok(this.output) : error = null;
  const HyMtReply.fail(this.error) : output = '';

  final String output;
  final String? error;
}

class _Init {
  final String modelPath;
  final SendPort main;
  _Init(this.modelPath, this.main);
}

class _LoadResult {
  final bool ready;
  final String? error;
  _LoadResult({required this.ready, this.error});
}

class _Req {
  final String prompt;
  final SendPort reply;
  _Req(this.prompt, this.reply);
}

class _Ping {
  final SendPort reply;
  _Ping(this.reply);
}

const Object _pong = 'HYMT_PONG';

class HyMtEngine extends TranslationEngine {
  HyMtEngine._({
    HyMtBackend? backend,
    Duration? queueWait,
    Duration? chunkTimeout,
    int? maxChunks,
  })  : _injectedBackend = backend,
        _testMode = backend != null,
        _maxQueueWait = queueWait ?? const Duration(seconds: 90),
        _chunkTimeout = chunkTimeout ?? const Duration(seconds: 90),
        _maxChunks = maxChunks ?? 64;

  static final HyMtEngine instance = HyMtEngine._();
  factory HyMtEngine() => instance;

  /// Constructor DUY NHẤT cho test — inject backend giả (không isolate,
  /// không native lib, không model 600MB) để kiểm tra logic
  /// single-flight/retry/chunk/timeout của HYMT-002.
  factory HyMtEngine.forTest({
    required HyMtBackend backend,
    Duration queueWait = const Duration(seconds: 90),
    Duration chunkTimeout = const Duration(seconds: 90),
    int maxChunks = 64,
  }) {
    return HyMtEngine._(
      backend: backend,
      queueWait: queueWait,
      chunkTimeout: chunkTimeout,
      maxChunks: maxChunks,
    );
  }

  static const fileName = 'Hy-MT1.5-1.8B-2bit.gguf';
  static const folderName = 'in4up_hymt';
  static const minBytes = 80 * 1024 * 1024; // 80MB — ngưỡng tuyệt đối thấp
  /// Size file thật trên HF (tencent/Hy-MT1.5-1.8B-2bit-GGUF, xác minh
  /// 2026-09-03): 601MB. File nhỏ hơn rõ ràng ngưỡng này = download/import
  /// BỊ CẮT → llama_model_load_from_file fail trả NULL → lỗi
  /// "Hy-MT native không load được" dù file vẫn nằm đó.
  static const expectedBytes = 601 * 1024 * 1024;

  /// File < ~80% expected coi là cắt (chấp nhận file LỚN hơn — có thể là
  /// quant khác của cùng model). 481MB ≈ 80% × 601MB.
  static const int minPlausibleBytes = 481 * 1024 * 1024;

  static const downloadUrl =
      'https://huggingface.co/tencent/Hy-MT1.5-1.8B-2bit-GGUF/resolve/main/'
      'Hy-MT1.5-1.8B-2bit.gguf?download=true';
  static const _prefPath = 'hymt_gguf_path';
  static const _prefEngine = 'translation_offline_engine';

  @override
  String get name => 'Hy-MT 1.5 (GGUF)';

  @override
  String get id => 'hymt';

  /// Mỗi request gửi cho isolate là MỘT chunk (≤ ~500 ký tự).
  @override
  int get maxCharsPerRequest => HyMtChunking.defaultMaxChars;

  @override
  Duration get requestDelay => const Duration(milliseconds: 80);

  final HyMtBackend? _injectedBackend;
  final bool _testMode;
  final Duration _maxQueueWait;
  final Duration _chunkTimeout;
  final int _maxChunks;

  HyMtSlot? _slot;
  HyMtIsolateBackend? _runtime;
  HyMtRuntimeFailure? _lastChunkError;

  double downloadProgress = 0;
  bool downloading = false;
  CancelToken? _dlToken;

  /// Slot single-flight (lazy) — 1 request tại một thời điểm (HYMT-002).
  HyMtSlot get slot => _slot ??= HyMtSlot(maxWait: _maxQueueWait);

  Future<String> _docs() async {
    try {
      return (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      return (await getApplicationSupportDirectory()).path;
    }
  }

  Future<String> defaultSavePath() async {
    final dir = Directory(p.join(await _docs(), folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return p.join(dir.path, fileName);
  }

  static bool _isGgufMagic(List<int> head) {
    return head.length >= 4 &&
        head[0] == 0x47 &&
        head[1] == 0x47 &&
        head[2] == 0x55 &&
        head[3] == 0x46; // GGUF
  }

  static bool looksLikeGguf(List<int> head, int size) {
    // Từ 2026-09-03: yêu cầu size ≥ minPlausible (~480MB) — file 80-100MB
    // đầu magic GGUF mà thiếu phần thân là file CẮT (vẫn qua kiểm tra cũ
    // → llama load fail → "không load được" triền miên).
    if (size < minPlausibleBytes) return false;
    return _isGgufMagic(head);
  }

  static Future<bool> _headIsGguf(String path) async {
    try {
      // openRead(0, 4).first — pattern đã proof trong file này
      // (importFromUser dùng openRead(0, 8)); chỉ đọc 4 byte đầu.
      // KHÔNG dùng RandomAccessFile sync API (analyzer CI từ chối compile —
      // bài học HYMT-001, 8 vòng bisect).
      final head = await File(path).openRead(0, 4).first;
      return _isGgufMagic(head);
    } catch (_) {
      return false;
    }
  }

  /// Path model HỢP LỆ (tồn tại + size đủ + magic GGUF ở đầu). Trả null
  /// nếu file bị cắt/hỏng — coi như chưa có model (fallback engine khác).
  Future<String?> resolvedModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefPath);
    if (saved != null && await File(saved).exists()) {
      final n = File(saved).lengthSync();
      if (n >= minPlausibleBytes && await _headIsGguf(saved)) return saved;
    }
    final def = await defaultSavePath();
    if (await File(def).exists() &&
        File(def).lengthSync() >= minPlausibleBytes &&
        await _headIsGguf(def)) {
      return def;
    }
    return null;
  }

  Future<bool> get hasModel async => (await resolvedModelPath()) != null;

  /// null = model OK; text = lý do cụ thể (cho message lỗi + UI).
  /// Phân biệt "chưa có" với "có file nhưng bị cắt/hỏng" — trường hợp
  /// user hay gặp: đã tải/import model nhưng llama vẫn không load được.
  Future<String?> modelIssue() async {
    if (await hasModel) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefPath);
      final def = await defaultSavePath();
      final candidates = <String?>[saved, def];
      for (final path in candidates) {
        if (path == null) continue;
        final f = File(path);
        if (await f.exists()) {
          final mb = (f.lengthSync() / 1048576).toStringAsFixed(0);
          return 'File Hy-MT bị cắt/hỏng (${mb}MB/~601MB) — '
              'bấm "Tải về" để tải lại file đầy đủ.';
        }
      }
    } catch (_) {}
    return 'Chưa có model Hy-MT. Cài đặt dịch → Hy-MT → '
        'Import .gguf hoặc Tải về (~600MB).';
  }

  @override
  Future<bool> isAvailable() async {
    if (!await hasModel) return false;
    return AiNativeBindings.tryLoad() != null || _runtime?.isAlive ?? false;
  }

  static Future<HyMtOfflinePreference> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_prefEngine)) {
      case 'hymt':
        return HyMtOfflinePreference.hymt;
      case 'mlkit':
        return HyMtOfflinePreference.mlkit;
      default:
        return HyMtOfflinePreference.auto;
    }
  }

  static Future<void> savePreference(HyMtOfflinePreference value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefEngine, value.name);
  }

  Future<String?> importFromUser() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      dialogTitle: 'Chọn Hy-MT1.5-1.8B-2bit.gguf',
    );
    final srcPath = result?.files.single.path;
    if (srcPath == null || srcPath.isEmpty) return null;
    final src = File(srcPath);
    if (!await src.exists()) return 'File không tồn tại';
    if (!srcPath.toLowerCase().endsWith('.gguf')) {
      return 'Cần file .gguf (Hy-MT1.5-1.8B-2bit.gguf)';
    }
    final size = src.lengthSync();
    final head = await src.openRead(0, 8).first;
    if (!looksLikeGguf(head, size)) {
      return 'Không phải GGUF hợp lệ hoặc file quá nhỏ ($size bytes)';
    }
    final dest = await defaultSavePath();
    if (p.normalize(src.path) != p.normalize(dest)) {
      await src.copy(dest);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPath, dest);
    await disposeRuntime();
    return null; // success
  }

  Future<String?> downloadModel() async {
    if (downloading) return 'Đang tải';
    downloading = true;
    downloadProgress = 0;
    _dlToken = CancelToken();
    try {
      final dest = await defaultSavePath();
      final tmp = '$dest.tmp';
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(minutes: 60),
        followRedirects: true,
        maxRedirects: 8,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; in4upApp/1.0)',
          'Accept': '*/*',
        },
      ));
      await dio.download(
        downloadUrl,
        tmp,
        cancelToken: _dlToken,
        deleteOnError: true,
        onReceiveProgress: (a, b) {
          if (b > 0) downloadProgress = a / b;
        },
      );
      final f = File(tmp);
      if (!await f.exists()) return 'Không ghi được file';
      final size = f.lengthSync();
      final head = await f.openRead(0, 8).first;
      if (!looksLikeGguf(head, size)) {
        await f.delete();
        return 'File tải về không phải GGUF ($size bytes)';
      }
      final out = File(dest);
      if (await out.exists()) await out.delete();
      try {
        await f.rename(dest);
      } catch (_) {
        await f.copy(dest);
        await f.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPath, dest);
      await disposeRuntime();
      return null;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return 'Đã huỷ';
      return 'Không tải được Hy-MT (HTTP ${e.response?.statusCode ?? '-'}). Wi-Fi rồi thử lại.';
    } catch (e) {
      return 'Lỗi tải Hy-MT: $e';
    } finally {
      downloading = false;
      _dlToken = null;
    }
  }

  void cancelDownload() => _dlToken?.cancel('User cancelled');

  Future<void> deleteModel() async {
    await disposeRuntime();
    final path = await resolvedModelPath();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPath);
  }

  /// Lý do load/create() fail gần nhất (null = chưa load/chưa fail).
  String? get lastLoadError =>
      _runtime?.lastLoadError ?? _injectedBackend?.lastLoadError;

  /// Backend runtime cho [path] (lazy). Nếu model file đổi (tải lại),
  /// dispose runtime cũ TRƯỚC khi spawn mới — luôn ≤1 model trong RAM.
  Future<HyMtIsolateBackend> _runtimeFor(String path) async {
    final current = _runtime;
    if (current != null && current.modelPath == path) return current;
    if (current != null) {
      unawaited(current.dispose());
      // Chờ nhẹ cho isolate cũ thoát — model ~600MB, 2 model song song
      // = nguy cơ OOM (yêu cầu HYMT-002).
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final next = HyMtIsolateBackend(path);
    _runtime = next;
    return next;
  }

  Future<bool> ensureLoaded() async {
    if (_testMode) {
      final backend = _injectedBackend!;
      if (backend.isAlive && backend.lastLoadError == null) return true;
      return backend.restart();
    }
    final path = await resolvedModelPath();
    if (path == null) return false;
    final runtime = await _runtimeFor(path);
    if (runtime.isAlive && runtime.lastLoadError == null) return true;
    return runtime.restart();
  }

  Future<void> disposeRuntime() async {
    final runtime = _runtime;
    _runtime = null;
    if (runtime != null) await runtime.dispose();
    final injected = _injectedBackend;
    if (injected != null) await injected.dispose();
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    final src =
        HyMtPrompts.normalizeCode(sourceLang == 'auto' ? 'EN' : sourceLang);
    final tgt = HyMtPrompts.normalizeCode(targetLang);
    if (!HyMtPrompts.supports(src) || !HyMtPrompts.supports(tgt)) {
      return _fail(
        text,
        'Hy-MT không hỗ trợ cặp $sourceLang → $targetLang',
        HyMtErrorCode.unsupported,
        src,
        tgt,
      );
    }

    final started = Stopwatch()..start();
    HyMtBackend backend;
    if (_testMode) {
      backend = _injectedBackend!;
    } else {
      final path = await resolvedModelPath();
      if (path == null) {
        return _fail(
          text,
          (await modelIssue()) ?? 'Chưa có model Hy-MT.',
          HyMtErrorCode.noModel,
          src,
          tgt,
        );
      }
      final runtime = await _runtimeFor(path);
      if (AiNativeBindings.tryLoad() == null && !runtime.isAlive) {
        return _fail(
          text,
          'Build chưa có llama.cpp (in4up_ai_native). Hy-MT cần bản app có AI native.',
          HyMtErrorCode.noNative,
          src,
          tgt,
        );
      }
      backend = runtime;
    }

    // (1) Single-flight — 1 request tại một thời điểm. Request kế tiếp
    // queue trong _maxQueueWait rồi mới chạy; quá hạn → "busy" cấu trúc,
    // KHÔNG treo thêm 2 phút (HYMT-002 mục 1).
    final slotGuard = slot;
    final acquired = await slotGuard.acquire();
    if (!acquired) {
      return _fail(
        text,
        'Hy-MT đang bận: request trước vẫn đang chạy '
            '(đã chờ ${_fmtDuration(_maxQueueWait)}). Thử lại sau ít phút.',
        HyMtErrorCode.busy,
        src,
        tgt,
      );
    }
    try {
      // (2) Health TRƯỚC request: alive + heartbeat; chết/treo/load hỏng
      // → dispose + spawn lại (restart) rồi mới gửi (HYMT-002 mục 2).
      var ready = backend.isAlive && backend.lastLoadError == null;
      if (!ready || !await backend.ping()) {
        ready = await backend.restart();
        if (!ready) {
          return _fail(
            text,
            'Không nạp được Hy-MT GGUF: '
                '${backend.lastLoadError ?? 'không rõ lý do'}. '
                'Thử "Tải về" lại model rồi dịch lại.',
            HyMtErrorCode.loadFailed,
            src,
            tgt,
          );
        }
      }

      // (3) Text dài tách theo ranh giới câu/cụm — mỗi chunk timeout hữu
      // hạn RIÊNG; ghép đúng thứ tự; lỗi chunk không bị nuốt
      // (HYMT-002 mục 3).
      final chunks =
          HyMtChunking.chunk(text, maxChars: HyMtChunking.defaultMaxChars);
      if (chunks.isEmpty) {
        return TranslationResult.success(
          original: text,
          translated: '',
          engine: name,
          detectedLang: src,
          targetLang: tgt,
        );
      }
      if (chunks.length > _maxChunks) {
        return _fail(
          text,
          'Văn bản quá dài cho Hy-MT offline (${text.length} ký tự, tối đa '
              '${_maxChunks * HyMtChunking.defaultMaxChars}). '
              'Dùng engine online hoặc tách văn bản ra.',
          HyMtErrorCode.tooLong,
          src,
          tgt,
        );
      }

      final outputs = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        final piece = chunks[i].text;
        final prompt =
            HyMtPrompts.build(text: piece, sourceLang: src, targetLang: tgt);
        final out = await _generateChunk(
          backend,
          prompt,
          sourcePiece: piece,
          chunkIndex: i,
          chunkCount: chunks.length,
        );
        if (out == null) {
          final last = _lastChunkError;
          return _fail(
            text,
            'Hy-MT lỗi ở segment ${i + 1}/${chunks.length}: '
                '${last?.message ?? 'lỗi không xác định'}',
            last?.code ?? HyMtErrorCode.requestFailed,
            src,
            tgt,
          );
        }
        outputs.add(out);
      }

      final translated = HyMtChunking.assemble(outputs, chunks);
      if (translated.trim().isEmpty) {
        return _fail(
          text,
          'Hy-MT trả về rỗng',
          HyMtErrorCode.emptyOutput,
          src,
          tgt,
        );
      }
      final elapsed = started.elapsed;
      debugPrint(
        '⏱️ Hy-MT: ${text.length} ký tự → ${chunks.length} segment, '
        '${elapsed.inMilliseconds}ms',
      );
      return TranslationResult.success(
        original: text,
        translated: translated,
        engine: name,
        detectedLang: src,
        targetLang: tgt,
        responseTime: elapsed,
      );
    } finally {
      slotGuard.release();
    }
  }

  static String _fmtDuration(Duration d) => d.inSeconds >= 60
      ? '${d.inMinutes} phút'
      : d.inMilliseconds >= 1000
          ? '${d.inSeconds}s'
          : '${d.inMilliseconds}ms';

  /// Dịch 1 chunk: thử lần đầu + TỐI ĐA 1 retry. Lỗi runtime (isolate
  /// chết/treo/native hỏng) → restart runtime (dispose + spawn + load)
  /// rồi mới retry. Trả output đã clean; `null` = fail hẳn
  /// ([_lastChunkError] giữ lỗi cuối RÕ RÀNG cho message).
  Future<String?> _generateChunk(
    HyMtBackend backend,
    String prompt, {
    required String sourcePiece,
    required int chunkIndex,
    required int chunkCount,
  }) async {
    var needsRestart = false;
    for (var attempt = 1; attempt <= 2; attempt++) {
      if (needsRestart) {
        final ok = await backend.restart();
        if (!ok) {
          _lastChunkError = HyMtRuntimeFailure(
            HyMtErrorCode.loadFailed,
            'Không khởi động lại runtime Hy-MT: '
                '${backend.lastLoadError ?? 'không rõ lý do'}',
          );
          return null;
        }
      }
      try {
        final raw = await backend.generate(prompt).timeout(_chunkTimeout);
        final cleaned = HyMtPrompts.cleanOutput(raw, sourcePiece);
        if (cleaned.isEmpty) {
          _lastChunkError = HyMtRuntimeFailure(
            HyMtErrorCode.emptyOutput,
            'Hy-MT trả về rỗng cho segment ${chunkIndex + 1}/$chunkCount',
          );
          needsRestart = false; // output rỗng không phải runtime chết
          continue;
        }
        return cleaned;
      } on HyMtRuntimeFailure catch (e) {
        _lastChunkError = e;
        // isolateDead / requestTimeout / requestFailed → restart runtime
        // rồi retry 1 lần (HYMT-002 mục 2).
        needsRestart = e.code != HyMtErrorCode.emptyOutput;
      } on TimeoutException {
        _lastChunkError = HyMtRuntimeFailure(
          HyMtErrorCode.requestTimeout,
          'Segment ${chunkIndex + 1}/$chunkCount quá '
              '${_fmtDuration(_chunkTimeout)} (native có thể đang treo)',
        );
        needsRestart = true; // isolate có thể hung — phải dispose
      }
    }
    return null;
  }

  TranslationResult _fail(
    String text,
    String error,
    HyMtErrorCode code,
    String src,
    String tgt,
  ) {
    return TranslationResult.failure(
      original: text,
      error: error,
      engine: name,
      detectedLang: src,
      targetLang: tgt,
      errorCode: code.name,
    );
  }
}
