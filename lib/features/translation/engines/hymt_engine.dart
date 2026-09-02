// Hy-MT 1.5 (Tencent Hunyuan) — engine dịch câu offline qua GGUF + llama.cpp.
// Model ~600MB. KHÔNG load lúc bootstrap. User bấm Import hoặc Tải về.

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

import 'hymt_prompts.dart';
import 'translation_engine.dart';

enum HyMtOfflinePreference { auto, hymt, mlkit }

class HyMtEngine extends TranslationEngine {
  HyMtEngine._();
  static final HyMtEngine instance = HyMtEngine._();
  factory HyMtEngine() => instance;

  static const fileName = 'Hy-MT1.5-1.8B-2bit.gguf';
  static const folderName = 'in4up_hymt';
  static const minBytes = 80 * 1024 * 1024; // 80MB — ngưỡng tuyệt đối thấp
  /// Size file thật trên HF (tencent/Hy-MT1.5-1.8B-2bit-GGUF, xác minh
  /// 2026-09-03): 601MB. File nhỏ hơn rõ ràng ngưỡng này = download/import
  /// BỊ CẮT → `llama_model_load_from_file` fail trả NULL → lỗi
  /// "Hy-MT native không load được" dù file vẫn nằm đó.
  static const expectedBytes = 601 * 1024 * 1024;

  /// File < 80% expected coi là cắt (chấp nhận file LỚN hơn — có thể là
  /// quant khác của cùng model).
  static int get minPlausibleBytes => (expectedBytes * 0.8).round();
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

  static bool _headIsGguf(String path) {
    try {
      final rand = File(path).openSync();
      try {
        return _isGgufMagic(rand.readBytesSync(4, 0));
      } finally {
        rand.closeSync();
      }
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
      if (n >= minPlausibleBytes && _headIsGguf(saved)) return saved;
    }
    final def = await defaultSavePath();
    if (await File(def).exists() &&
        File(def).lengthSync() >= minPlausibleBytes &&
        _headIsGguf(def)) {
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
      for (final path in {saved, def}) {
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
    final src = HyMtPrompts.normalizeCode(sourceLang == 'auto' ? 'EN' : sourceLang);
    final tgt = HyMtPrompts.normalizeCode(targetLang);
    if (!HyMtPrompts.supports(src) || !HyMtPrompts.supports(tgt)) {
      return TranslationResult.failure(
        original: text,
        error: 'Hy-MT không hỗ trợ cặp $sourceLang → $targetLang',
        engine: name,
        detectedLang: src,
        targetLang: tgt,
      );
    }
    if (!await hasModel) {
      return TranslationResult.failure(
        original: text,
        // Cụ thể: "chưa có" hay "có file nhưng bị cắt/hỏng (tải lại)".
        error: await modelIssue(),
        engine: name,
        detectedLang: src,
        targetLang: tgt,
      );
    }
    final native = AiNativeBindings.tryLoad();
    if (native == null && _sendPort == null) {
      return TranslationResult.failure(
        original: text,
        error: 'Build chưa có llama.cpp (in4up_ai_native). Hy-MT cần bản app có AI native.',
        engine: name,
        detectedLang: src,
        targetLang: tgt,
      );
    }
    final ok = await ensureLoaded();
    if (!ok || _sendPort == null) {
      return TranslationResult.failure(
        original: text,
        // _lastLoadError = lý do create() fail THẬT từ isolate (file hỏng,
        // quant, RAM, thiếu native lib...). Lần sau bấm lại sẽ RETRY create
        // (isolate đã bị dispose sau lần fail) — vd sau khi tải lại model.
        error: 'Không nạp được Hy-MT GGUF: ${_lastLoadError ?? 'thiếu RAM hoặc llama.cpp không hỗ trợ.'} '
            'Thử "Tải về" lại model rồi dịch lại.',
        engine: name,
        detectedLang: src,
        targetLang: tgt,
      );
    }
    final prompt = HyMtPrompts.build(
      text: text,
      sourceLang: src,
      targetLang: tgt,
    );
    final reply = ReceivePort();
    _sendPort!.send(_Req(prompt, reply.sendPort));
    try {
      final msg = await reply.first.timeout(const Duration(minutes: 2));
      if (msg is String && msg.trim().isNotEmpty) {
        final cleaned = HyMtPrompts.cleanOutput(msg, text);
        if (cleaned.isEmpty) {
          return TranslationResult.failure(
            original: text,
            error: 'Hy-MT trả về rỗng',
            engine: name,
            detectedLang: src,
            targetLang: tgt,
          );
        }
        return TranslationResult.success(
          original: text,
          translated: cleaned,
          engine: name,
          detectedLang: src,
          targetLang: tgt,
        );
      }
      return TranslationResult.failure(
        original: text,
        error: msg is String ? msg : 'Hy-MT lỗi',
        engine: name,
        detectedLang: src,
        targetLang: tgt,
      );
    } on TimeoutException {
      return TranslationResult.failure(
        original: text,
        error: 'Hy-MT timeout',
        engine: name,
        detectedLang: src,
        targetLang: tgt,
      );
    } finally {
      reply.close();
    }
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
    // FIX 2026-09-03: báo kết quả create() THẬT cho main side (trước đây
    // main không biết create fail → ensureLoaded trả true → request đầu
    // trả "không load được" và không bao giờ retry).
    init.main.send(_LoadResult(ready: handle != null, error: loadError));
    await for (final msg in port) {
      if (msg is _Req) {
        try {
          if (native == null || handle == null) {
            msg.reply.send(loadError ?? 'Hy-MT native không load được');
            continue;
          }
          final out = native.generate(
            handle,
            msg.prompt,
            maxTokens: 512,
            temperature: 0.3,
          );
          msg.reply.send(out ?? '');
        } catch (e) {
          msg.reply.send('Hy-MT: $e');
        }
      }
    }
    if (native != null && handle != null) native.destroy(handle);
  }
}

class _Init {
  final String modelPath;
  final SendPort main;
  _Init(this.modelPath, this.main);
}

/// Kết quả create() thật từ isolate (gửi SAU khi create hoàn tất).
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
