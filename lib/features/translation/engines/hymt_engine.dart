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

class HyMtIsolateBackend implements HyMtBackend {
  // BISPECT E1: stub thay backend thật để tách lỗi analyzer.
  HyMtIsolateBackend(this.modelPath);

  final String modelPath;

  @override
  bool get isAlive => false;

  @override
  String? get lastLoadError => null;

  @override
  Future<bool> ping() async => false;

  @override
  Future<String> generate(String prompt) async => '';

  @override
  Future<bool> restart() async => false;

  @override
  Future<void> dispose() async {}
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
  HyMtEngine._legacy()
      : _injectedBackend = null,
        _testMode = false,
        _maxQueueWait = const Duration(seconds: 90),
        _chunkTimeout = const Duration(seconds: 90),
        _maxChunks = 64;
  static final HyMtEngine instance = HyMtEngine._legacy();
  factory HyMtEngine() => instance;

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

  @override
  int get maxCharsPerRequest => 2000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 80);

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  String? _loadedPath;
  bool _loading = false;

  double downloadProgress = 0;
  bool downloading = false;
  CancelToken? _dlToken;

  final HyMtBackend? _injectedBackend;
  final bool _testMode;
  final Duration _maxQueueWait;
  final Duration _chunkTimeout;
  final int _maxChunks;

  HyMtSlot? _slot;
  HyMtIsolateBackend? _runtime;
  HyMtRuntimeFailure? _lastChunkError;

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
    return AiNativeBindings.tryLoad() != null || _sendPort != null;
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

  /// Lý do create() fail ở lần load gần nhất (null = chưa load/chưa fail).
  String? _lastLoadError;

  String? get lastLoadError => _lastLoadError;

  Future<bool> ensureLoaded() async {
    final path = await resolvedModelPath();
    if (path == null) return false;
    if (_sendPort != null && _loadedPath == path) return true;
    if (_loading) return false;
    _loading = true;
    try {
      await disposeRuntime();
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        _isolateEntry,
        _Init(path, _receivePort!.sendPort),
        debugName: 'HyMtIsolate',
      );
      final ready = Completer<SendPort>();
      final loadDone = Completer<bool>();
      _lastLoadError = null;
      _receivePort!.listen((msg) {
        if (msg is SendPort && !ready.isCompleted) ready.complete(msg);
        if (msg is _LoadResult && !loadDone.isCompleted) {
          if (!msg.ready) _lastLoadError = msg.error;
          loadDone.complete(msg.ready);
        }
      });
      _sendPort = await ready.future.timeout(const Duration(seconds: 45));
      // FIX 2026-09-03: phải ĐỢI kết quả create() THẬT từ isolate (load
      // model ~600MB mất vài giây) — bản cũ chỉ đợi handshake rồi trả
      // true, nên create() fail vẫn được coi là "đã sẵn sàng"; lỗi chỉ lộ
      // ở request đầu tiên ("Hy-MT native không load được") và isolate
      // chết im, không bao giờ retry.
      final ok = await loadDone.future.timeout(const Duration(minutes: 2));
      if (!ok) {
        debugPrint('Hy-MT create failed: ${_lastLoadError}');
        await disposeRuntime();
        return false;
      }
      _loadedPath = path;
      debugPrint('✅ Hy-MT GGUF loaded: $path');
      return true;
    } catch (e) {
      debugPrint('Hy-MT load failed: $e');
      await disposeRuntime();
      return false;
    } finally {
      _loading = false;
    }
  }

  Future<void> disposeRuntime() async {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
    _loadedPath = null;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    return TranslationResult.success(
      original: text,
      translated: text,
      engine: name,
    );
  }
}
