// packages/in4up_stt/lib/sherpa_model_manager.dart
//
// SherpaModelManager — quản lý model Silero VAD + Piper TTS (MODELS-001).
//
// TẤT CẢ chỉ chạy khi user bấm — không auto-download.
//
// Folder:
//   <documents>/sherpa_vad_models/silero_vad.onnx
//   <documents>/sherpa_piper_models/
//     espeak-ng-data/
//     <voice>.onnx + <voice>_tokens.txt [+ <voice>.onnx.json]
//
// Silero VAD k2-fsa (2026): silero_vad.onnx ~629KB — KHÔNG được đòi >1MB
// (ngưỡng cũ làm tải thành công rồi báo "mạng?").

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'tts/piper_import_paths.dart';
import 'tts/sherpa_piper_tts_core.dart';

enum SherpaModelStatus { notInstalled, downloading, ready, error }

/// Trạng thái 1 model đơn lẻ (Silero VAD).
class SherpaModelInfo {
  final SherpaModelStatus status;
  final double downloadProgress;
  final String? errorMessage;
  final String? localPath;

  const SherpaModelInfo({
    this.status = SherpaModelStatus.notInstalled,
    this.downloadProgress = 0,
    this.errorMessage,
    this.localPath,
  });

  bool get isReady => status == SherpaModelStatus.ready;
  bool get isDownloading => status == SherpaModelStatus.downloading;

  SherpaModelInfo copyWith({
    SherpaModelStatus? status,
    double? downloadProgress,
    String? errorMessage,
    String? localPath,
    bool clearError = false,
  }) {
    return SherpaModelInfo(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      localPath: localPath ?? this.localPath,
    );
  }
}

/// Trạng thái Piper tổng thể (espeak + danh sách giọng).
class SherpaPiperInfo {
  final bool espeakInstalled;
  final List<PiperTtsVoice> voices;
  final SherpaModelStatus status;
  final double downloadProgress;
  final String? errorMessage;

  const SherpaPiperInfo({
    this.espeakInstalled = false,
    this.voices = const [],
    this.status = SherpaModelStatus.notInstalled,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  bool get isDownloading => status == SherpaModelStatus.downloading;
  bool get isReady => voices.isNotEmpty && espeakInstalled;

  SherpaPiperInfo copyWith({
    bool? espeakInstalled,
    List<PiperTtsVoice>? voices,
    SherpaModelStatus? status,
    double? downloadProgress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SherpaPiperInfo(
      espeakInstalled: espeakInstalled ?? this.espeakInstalled,
      voices: voices ?? this.voices,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SherpaModelManager {
  static SherpaModelManager? _instance;
  factory SherpaModelManager() => _instance ??= SherpaModelManager._internal();
  SherpaModelManager._internal();

  static const String vadFolderName = 'sherpa_vad_models';
  static const String vadFileName = 'silero_vad.onnx';

  /// k2-fsa silero_vad.onnx ~629KB; int8 ~208KB. HTML lỗi GitHub thường <80KB.
  static const int vadMinBytes = 80 * 1024;
  static const int vadMaxBytes = 40 * 1024 * 1024;

  static const String vadDownloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'silero_vad.onnx';

  static const List<String> vadDownloadUrls = [
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'silero_vad.onnx',
    'https://huggingface.co/csukuangfj/silero-vad/resolve/main/'
        'silero_vad.onnx?download=true',
  ];

  static const String defaultPiperVoice = 'en_US-libritts_r-medium';

  static String piperBundleUrl(String voice) =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'vits-piper-$voice.tar.bz2';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(minutes: 30),
      followRedirects: true,
      maxRedirects: 8,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (compatible; in4upApp/1.0)',
        'Accept': '*/*',
      },
    ),
  );

  final _vadState =
      BehaviorSubject<SherpaModelInfo>.seeded(const SherpaModelInfo());
  final _piperState =
      BehaviorSubject<SherpaPiperInfo>.seeded(const SherpaPiperInfo());

  CancelToken? _vadToken;
  CancelToken? _piperToken;
  bool _initialized = false;
  String? _documentsDir;

  Future<String> _documents() async {
    if (_documentsDir != null) return _documentsDir!;
    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationSupportDirectory();
    }
    _documentsDir = base.path;
    return base.path;
  }

  Future<String> _vadDir() async {
    final dir = Directory(p.join(await _documents(), vadFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> initialize() async {
    if (!_initialized) {
      await _documents();
      _initialized = true;
    }
    await rescan();
  }

  Stream<SherpaModelInfo> watchVad() => _vadState.stream;
  SherpaModelInfo get vadInfo => _vadState.value;

  Stream<SherpaPiperInfo> watchPiper() => _piperState.stream;
  SherpaPiperInfo get piperInfo => _piperState.value;

  static bool isPlausibleVadFile(int size, {List<int>? head}) {
    if (size < vadMinBytes || size > vadMaxBytes) return false;
    if (head != null && head.isNotEmpty) {
      if (head[0] == 0x3C) return false; // '<' HTML
      final ascii = String.fromCharCodes(
        head.take(80).where((b) => b >= 32 && b < 127),
      ).toLowerCase();
      if (ascii.contains('<html') || ascii.contains('<!doctype')) return false;
    }
    return true;
  }

  Future<void> _replaceFile(String fromPath, String toPath) async {
    final src = File(fromPath);
    final dest = File(toPath);
    if (await dest.exists()) {
      try { await dest.delete(); } catch (_) {}
    }
    try {
      await src.rename(toPath);
    } catch (_) {
      await src.copy(toPath);
      try { await src.delete(); } catch (_) {}
    }
  }

  Future<void> rescan() async {
    try {
      final vadFile = File(p.join(await _vadDir(), vadFileName));
      List<int>? head;
      if (vadFile.existsSync()) {
        final raf = await vadFile.open();
        try {
          head = await raf.read(64);
        } finally {
          await raf.close();
        }
      }
      final vadOk = vadFile.existsSync() &&
          isPlausibleVadFile(vadFile.lengthSync(), head: head);
      _vadState.add(vadOk
          ? SherpaModelInfo(
              status: SherpaModelStatus.ready, localPath: vadFile.path)
          : const SherpaModelInfo(status: SherpaModelStatus.notInstalled));

      final voices = await SherpaPiperTtsCore.discoverVoices();
      final piperDir = Directory(
          p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
      final espeakOk = Directory(
              p.join(piperDir.path, SherpaPiperTtsCore.espeakDataFolder))
          .existsSync();
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: espeakOk,
        voices: voices,
        status: voices.isEmpty
            ? SherpaModelStatus.notInstalled
            : SherpaModelStatus.ready,
      ));
    } catch (e) {
      debugPrint('⚠️ SherpaModelManager.rescan error: $e');
    }
  }

  // ── SILERO VAD ─────────────────────────────────────────────────────────

  Future<bool> downloadVad({int maxRetries = 2}) async {
    if (vadInfo.isReady) return true;
    if (vadInfo.isDownloading) return false;

    final token = CancelToken();
    _vadToken = token;
    _vadState.add(const SherpaModelInfo(status: SherpaModelStatus.downloading));

    try {
      final dir = await _vadDir();
      final savePath = p.join(dir, vadFileName);
      final tmpPath = '$savePath.tmp';
      String lastError = '';

      var ok = false;
      for (final url in vadDownloadUrls) {
        if (ok || token.isCancelled) break;
        var attempt = 0;
        while (attempt < maxRetries && !ok && !token.isCancelled) {
          attempt++;
          try {
            debugPrint('📥 Download $vadFileName từ: $url (lần $attempt)');
            await _dio.download(
              url,
              tmpPath,
              cancelToken: token,
              deleteOnError: true,
              onReceiveProgress: (received, total) {
                if (total > 0) {
                  _vadState.add(_vadState.value
                      .copyWith(downloadProgress: received / total));
                }
              },
            );
            final tmp = File(tmpPath);
            if (!await tmp.exists()) {
              lastError = 'Không ghi được file tạm';
              continue;
            }
            final size = tmp.lengthSync();
            final head = await tmp.openRead(0, 64).first;
            if (!isPlausibleVadFile(size, head: head)) {
              lastError =
                  'File tải về không phải model ($size bytes) — URL trả HTML/lỗi.';
              try { await tmp.delete(); } catch (_) {}
              continue;
            }
            await _replaceFile(tmpPath, savePath);
            ok = true;
          } on DioException catch (e) {
            if (CancelToken.isCancel(e)) break;
            lastError = 'HTTP ${e.response?.statusCode ?? '-'} ${e.message}';
            debugPrint('⚠️ Download VAD thất bại ($url $attempt): $lastError');
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          } catch (e) {
            lastError = '$e';
            debugPrint('⚠️ Download VAD error ($url $attempt): $e');
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          }
        }
      }

      _vadToken = null;
      if (ok) {
        await rescan();
        debugPrint('✅ Download VAD xong: $savePath');
        return true;
      }
      _vadState.add(SherpaModelInfo(
        status: SherpaModelStatus.notInstalled,
        errorMessage:
            'Không tải được $vadFileName. $lastError. Thử lại (Wi-Fi) hoặc Import '
            'file silero_vad.onnx (k2-fsa ~629KB, không phải bắt >1MB).',
      ));
      return false;
    } catch (e) {
      _vadToken = null;
      _vadState.add(SherpaModelInfo(
        status: SherpaModelStatus.error,
        errorMessage: 'Lỗi tải VAD: $e',
      ));
      return false;
    }
  }

  Future<bool> importVadFromPath(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final size = src.lengthSync();
      final head = await src.openRead(0, 64).first;
      if (!isPlausibleVadFile(size, head: head)) {
        debugPrint('❌ File VAD không hợp lệ ($sourcePath, $size bytes)');
        return false;
      }
      final savePath = p.join(await _vadDir(), vadFileName);
      final existing = File(savePath);
      if (await existing.exists()) await existing.delete();
      await src.copy(savePath);
      await rescan();
      debugPrint('✅ Import VAD: $savePath');
      return true;
    } catch (e) {
      debugPrint('❌ Import VAD error: $e');
      return false;
    }
  }

  void cancelVadDownload() {
    _vadToken?.cancel('User cancelled');
    _vadToken = null;
    _vadState.add(const SherpaModelInfo(status: SherpaModelStatus.notInstalled));
  }

  Future<void> deleteVad() async {
    try {
      final f = File(p.join(await _vadDir(), vadFileName));
      if (await f.exists()) await f.delete();
      await rescan();
      debugPrint('🗑️ Deleted VAD model');
    } catch (e) {
      debugPrint('⚠️ Delete VAD error: $e');
    }
  }

  // ── PIPER TTS ──────────────────────────────────────────────────────────

  Future<String> _piperDir() async {
    final dir = Directory(
        p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  bool _isOnnxModelName(String name) => PiperImportPaths.isOnnxModelName(name);

  Future<bool> _tryCopyFile(String fromPath, String toPath) async {
    try {
      final dest = File(toPath);
      await dest.parent.create(recursive: true);
      final src = File(fromPath);
      if (src.existsSync()) {
        await src.copy(toPath);
        return true;
      }
      final bytes = await File(fromPath).readAsBytes();
      if (bytes.isEmpty) return false;
      await dest.writeAsBytes(bytes, flush: true);
      return true;
    } catch (e) {
      debugPrint('⚠️ Piper copy $fromPath → $toPath: $e');
      return false;
    }
  }

  Future<List<String>> _walkPaths(String root) async {
    final out = <String>[];
    Future<void> walk(Directory dir, int depth) async {
      if (depth > 12) return;
      try {
        await for (final entity in dir.list(followLinks: true)) {
          try {
            final type = await FileSystemEntity.type(entity.path);
            if (type == FileSystemEntityType.directory) {
              await walk(Directory(entity.path), depth + 1);
            } else {
              out.add(entity.path);
            }
          } catch (_) {
            out.add(entity.path);
          }
        }
      } catch (e) {
        try {
          for (final entity in dir.listSync(recursive: true, followLinks: true)) {
            out.add(entity.path);
          }
        } catch (e2) {
          debugPrint('⚠️ Piper walk ${dir.path}: $e / $e2');
        }
      }
    }

    await walk(Directory(root), 0);
    return out;
  }

  Future<int> _copyEspeakTree(Directory srcRoot) async {
    final files = await _walkPaths(srcRoot.path);
    if (files.isEmpty) return 0;
    final destRoot = Directory(
        p.join(await _piperDir(), SherpaPiperTtsCore.espeakDataFolder));
    if (!await destRoot.exists()) await destRoot.create(recursive: true);
    var n = 0;
    for (final path in files) {
      final rel = p.relative(path, from: srcRoot.path);
      final dest = p.join(destRoot.path, PiperImportPaths.posixRel(rel));
      if (await _tryCopyFile(path, dest)) n++;
    }
    return n;
  }

  Future<bool> _importEspeakNear(List<String> paths) async {
    for (final path in paths) {
      var dir = Directory(p.dirname(path));
      for (var i = 0; i < 5; i++) {
        final direct =
            Directory(p.join(dir.path, PiperImportPaths.espeakFolder));
        // Do not gate on existsSync — OneDrive/SAF often returns false.
        if (await _copyEspeakTree(direct) > 0) return true;
        try {
          for (final entity in dir.listSync()) {
            if (PiperImportPaths.looksLikeEspeakRoot(p.basename(entity.path))) {
              if (await _copyEspeakTree(Directory(entity.path)) > 0) {
                return true;
              }
            }
          }
        } catch (_) {
          final listing = await _walkPaths(dir.path);
          var copied = 0;
          for (final filePath in listing) {
            final rel = p.relative(filePath, from: dir.path);
            final tail = PiperImportPaths.espeakTail(rel);
            if (tail == null || tail == PiperImportPaths.espeakFolder) {
              continue;
            }
            final dest = p.join(await _piperDir(), tail);
            if (await _tryCopyFile(filePath, dest)) copied++;
          }
          if (copied > 0) return true;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return false;
  }

  Future<String> importPiperFiles(List<String> paths) async {
    if (paths.isEmpty) return 'Chưa chọn file nào';
    final destDir = await _piperDir();
    var onnx = 0;
    var archivePath = '';
    for (final path in paths) {
      final name = p.basename(path);
      if (PiperImportPaths.isPiperArchiveName(name) && archivePath.isEmpty) {
        archivePath = path;
        continue;
      }
      if (PiperImportPaths.isEspeakLeafName(name)) {
        await _tryCopyFile(
          path,
          p.join(destDir, PiperImportPaths.espeakFolder, name),
        );
        continue;
      }
      if (!_isOnnxModelName(name) &&
          !PiperImportPaths.isTokensName(name) &&
          !PiperImportPaths.isOnnxJsonName(name)) {
        continue;
      }
      final ok = await _tryCopyFile(path, p.join(destDir, name));
      if (ok && _isOnnxModelName(name)) onnx++;
    }
    if (onnx == 0 && archivePath.isNotEmpty) {
      try {
        final extractDir = p.join(
          p.dirname(archivePath),
          '${p.basename(archivePath)}-extracted',
        );
        await Directory(extractDir).create(recursive: true);
        if (archivePath.toLowerCase().endsWith('.tar.bz2')) {
          await _extractTarBz2(archivePath, extractDir);
        }
        return importPiperFolder(extractDir);
      } catch (e) {
        return 'Có archive nhưng không giải nén được: $e';
      }
    }
    if (onnx == 0) {
      return 'Thiếu file .onnx — chọn cả bộ (onnx + tokens [+ json]). '
          'espeak-ng-data lấy tự động nếu nằm cạnh file.';
    }
    final espeak = await _importEspeakNear(paths);
    await _normalizeSharedTokens(destDir);
    await rescan();
    final espeakNote = espeak || piperInfo.espeakInstalled
        ? ' · đã lấy espeak-ng-data cạnh file'
        : ' · nếu báo thiếu espeak: Import thư mục vits-piper-* '
            '(chứa espeak-ng-data) một lần — phonemizer dùng chung mọi giọng';
    return '✅ Đã import $onnx file model$espeakNote';
  }

  Future<String> importPiperFolder(String folderPath) async {
    var dir = Directory(folderPath);
    if (!await dir.exists()) return 'Thư mục không tồn tại';

    if (PiperImportPaths.looksLikeEspeakRoot(p.basename(dir.path))) {
      await _copyEspeakTree(dir);
      dir = dir.parent;
    }

    final destDir = await _piperDir();
    var copiedOnnx = 0;
    var copiedTokens = 0;
    var copiedJson = 0;
    var copiedEspeak = 0;
    final seen = <String>[];
    var archivePath = '';

    final listing = await _walkPaths(dir.path);
    for (final path in listing) {
      final name = p.basename(path);
      final rel = p.relative(path, from: dir.path);
      if (seen.length < 24) seen.add(PiperImportPaths.posixRel(rel));

      final espeakTail = PiperImportPaths.espeakTail(rel);
      if (espeakTail != null && espeakTail != PiperImportPaths.espeakFolder) {
        final dest = p.join(destDir, espeakTail);
        if (await _tryCopyFile(path, dest)) copiedEspeak++;
        continue;
      }

      if (_isOnnxModelName(name)) {
        if (await _tryCopyFile(path, p.join(destDir, name))) copiedOnnx++;
      } else if (PiperImportPaths.isTokensName(name)) {
        if (await _tryCopyFile(path, p.join(destDir, name))) copiedTokens++;
      } else if (PiperImportPaths.isOnnxJsonName(name)) {
        if (await _tryCopyFile(path, p.join(destDir, name))) copiedJson++;
      } else if (PiperImportPaths.isPiperArchiveName(name) &&
          archivePath.isEmpty) {
        archivePath = path;
      }
    }

    if (copiedOnnx == 0 && archivePath.isNotEmpty) {
      try {
        final extractDir = p.join(
          p.dirname(archivePath),
          '${p.basename(archivePath)}-extracted',
        );
        await Directory(extractDir).create(recursive: true);
        if (archivePath.toLowerCase().endsWith('.tar.bz2')) {
          await _extractTarBz2(archivePath, extractDir);
        }
        return importPiperFolder(extractDir);
      } catch (e) {
        return 'Có archive nhưng không giải nén được: $e';
      }
    }

    if (copiedOnnx == 0) {
      final parent = dir.parent;
      if (parent.path != dir.path) {
        final parentListing = await _walkPaths(parent.path);
        final parentOnnx = parentListing
            .where((f) => _isOnnxModelName(p.basename(f)))
            .toList();
        if (parentOnnx.isNotEmpty) {
          return importPiperFolder(parent.path);
        }
      }
      final preview = seen.isEmpty
          ? '(thư mục trống với app — Android/SAF?)'
          : seen.join(', ');
      return 'Không tìm thấy file .onnx trong "$folderPath". '
          'App thấy: $preview. '
          'Hãy Import file: chọn .onnx + tokens.txt trong cùng thư mục '
          '(app tự lấy espeak-ng-data cạnh đó), hoặc bấm Tải giọng.';
    }

    if (copiedEspeak == 0) {
      await _importEspeakNear(listing);
    }

    await _normalizeSharedTokens(destDir);
    await rescan();
    debugPrint(
        '✅ Import Piper folder: $copiedOnnx onnx, $copiedTokens tokens, '
        '$copiedJson json, $copiedEspeak espeak files');
    return '✅ Đã import $copiedOnnx file model, $copiedTokens tokens, '
        '$copiedJson config — sẵn sàng dùng.';
  }

  Future<void> _normalizeSharedTokens(String destDir) async {
    final dir = Directory(destDir);
    if (!dir.existsSync()) return;
    final onnxStems = <String>[];
    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (_isOnnxModelName(name)) {
        onnxStems.add(name.substring(0, name.length - '.onnx'.length));
      }
    }
    final shared = File(p.join(destDir, 'tokens.txt'));
    if (!shared.existsSync() || onnxStems.isEmpty) return;
    for (final stem in onnxStems) {
      final named = File(p.join(destDir, '${stem}_tokens.txt'));
      if (!named.existsSync()) {
        await shared.copy(named.path);
      }
    }
  }

  /// Tải bundle + tự giải nén + cài vào sherpa_piper_models.
  /// Trả về thư mục model khi sẵn sàng dùng (không phải file .tar.bz2).
  Future<String?> downloadPiperBundle({
    required String voice,
  }) async {
    if (piperInfo.isDownloading) return null;

    final token = CancelToken();
    _piperToken = token;
    _piperState.add(_piperState.value.copyWith(
        status: SherpaModelStatus.downloading, clearError: true));

    final url = piperBundleUrl(voice);

    try {
      final docs = await _documents();
      final downloadsDir = Directory(p.join(docs, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final fileName = 'vits-piper-$voice.tar.bz2';
      final savePath = p.join(downloadsDir.path, fileName);
      final tmpPath = '$savePath.tmp';

      debugPrint('📥 Download Piper bundle $voice từ: $url');
      await _dio.download(
        url,
        tmpPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _piperState.add(_piperState.value
                .copyWith(downloadProgress: received / total));
          }
        },
      );

      final tmp = File(tmpPath);
      if (!await tmp.exists() || tmp.lengthSync() < 1000000) {
        throw Exception(
            'Bundle tải về quá nhỏ (${tmp.existsSync() ? tmp.lengthSync() : 0} bytes)');
      }
      await _replaceFile(tmpPath, savePath);

      final extractDir =
          p.join(downloadsDir.path, 'vits-piper-$voice-extracted');
      final extract = Directory(extractDir);
      if (await extract.exists()) {
        await extract.delete(recursive: true);
      }
      await extract.create(recursive: true);
      await _extractTarBz2(savePath, extractDir);

      final msg = await importPiperFolder(extractDir);
      if (!msg.startsWith('✅')) {
        throw Exception(msg);
      }

      try { await File(savePath).delete(); } catch (_) {}
      try { await extract.delete(recursive: true); } catch (_) {}

      await rescan();
      debugPrint('✅ Piper $voice đã cài vào ${await _piperDir()}');
      return await _piperDir();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _piperState.add(_piperState.value
            .copyWith(status: SherpaModelStatus.notInstalled, clearError: true));
        return null;
      }
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage:
            'Không tải được bundle Piper (HTTP ${e.response?.statusCode ?? '-'}). '
            'Thử Wi-Fi rồi Tải giọng lại.',
      ));
      return null;
    } catch (e) {
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage: 'Lỗi tải/cài Piper: $e',
      ));
      return null;
    } finally {
      _piperToken = null;
      if (_piperState.value.isDownloading) {
        await rescan();
      }
    }
  }

  Future<void> _extractTarBz2(String tarBz2Path, String destDir) async {
    final raw = await File(tarBz2Path).readAsBytes();
    final tarBytes = BZip2Decoder().decodeBytes(raw);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final file in archive) {
      final name = PiperImportPaths.posixRel(file.name);
      if (name.isEmpty || name == '.' || name == './') continue;
      final outPath = p.join(destDir, name);
      if (file.isDirectory || name.endsWith('/')) {
        await Directory(outPath).create(recursive: true);
        continue;
      }
      final out = File(outPath);
      await out.parent.create(recursive: true);
      final content = file.content;
      if (content is List<int>) {
        await out.writeAsBytes(content, flush: true);
      } else if (content is Uint8List) {
        await out.writeAsBytes(content, flush: true);
      }
    }
  }

  void cancelPiperDownload() {
    _piperToken?.cancel('User cancelled');
    _piperToken = null;
    _piperState.add(_piperState.value
        .copyWith(status: SherpaModelStatus.notInstalled, clearError: true));
  }

  Future<void> deletePiperVoice(String voiceName) async {
    try {
      final dir = await _piperDir();
      for (final suffix in [
        '$voiceName.onnx',
        '${voiceName}_tokens.txt',
        '$voiceName.onnx.json',
      ]) {
        final f = File(p.join(dir, suffix));
        if (await f.exists()) await f.delete();
      }
      await rescan();
      debugPrint('🗑️ Deleted Piper voice: $voiceName');
    } catch (e) {
      debugPrint('⚠️ Delete Piper voice error: $e');
    }
  }

  Future<void> deletePiperAll() async {
    try {
      final dir = Directory(
          p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
      if (await dir.exists()) await dir.delete(recursive: true);
      await rescan();
      debugPrint('🗑️ Deleted all Piper models');
    } catch (e) {
      debugPrint('⚠️ Delete Piper all error: $e');
    }
  }

  void dispose() {
    _vadToken?.cancel('Disposed');
    _piperToken?.cancel('Disposed');
    _vadState.close();
    _piperState.close();
    _instance = null;
  }
}
