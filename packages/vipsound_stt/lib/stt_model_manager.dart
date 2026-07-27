import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'models/stt_model_info.dart';

class SttModelManager {
  static SttModelManager? _instance;
  factory SttModelManager() => _instance ??= SttModelManager._internal();
  SttModelManager._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      headers: const {
        'User-Agent': 'Mozilla/5.0 (compatible; VipsoundApp/1.0)',
      },
    ),
  );

  static const Map<WhisperModelLevel, String> _bundledAssetPaths = {
    WhisperModelLevel.tiny: 'assets/whisper_models/ggml-tiny.bin',
    WhisperModelLevel.base: 'assets/whisper_models/ggml-base.bin',
    WhisperModelLevel.small: 'assets/whisper_models/ggml-small.bin',
    WhisperModelLevel.medium: 'assets/whisper_models/ggml-medium.bin',
    WhisperModelLevel.large: 'assets/whisper_models/ggml-large-v2.bin',
  };

  final _modelStates = <WhisperModelLevel, BehaviorSubject<SttModelInfo>>{};
  final _activeDownloads = <WhisperModelLevel, CancelToken>{};

  final Map<WhisperModelLevel, List<String>> _urlOverrides = {};
  final Map<WhisperModelLevel, List<String>> _nameOverrides = {};

  String? _modelDirectory;
  bool _initialized = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Public config
  // ───────────────────────────────────────────────────────────────────────────

  /// Gọi trước initialize().
  ///
  /// - urls: đúng 5 link bạn chỉ định cho từng model
  /// - acceptedFileNames: thêm tên file custom nếu bạn muốn app auto nhận
  void configureSources({
    Map<WhisperModelLevel, List<String>>? urls,
    Map<WhisperModelLevel, List<String>>? acceptedFileNames,
  }) {
    if (urls != null) {
      _urlOverrides
        ..clear()
        ..addAll(urls.map(
          (key, value) => MapEntry(key, _normalizeStringList(value)),
        ));
    }

    if (acceptedFileNames != null) {
      _nameOverrides
        ..clear()
        ..addAll(acceptedFileNames.map(
          (key, value) => MapEntry(key, _normalizeStringList(value)),
        ));
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _ensureSubjects();
    _modelDirectory = await _resolveModelDirectory();
    debugPrint('📁 STT model dir: $_modelDirectory');

    // ★ Chỉ SCAN, không copy - nhanh hơn nhiều
    await _scanExistingModels();

    // ★ Copy model chạy background, không await
    _copyBundledAssetsIfAvailable().then((_) {
      // Scan lại sau khi copy xong để cập nhật UI
      _scanExistingModels();
    }).catchError((e) {
      debugPrint('⚠️ Copy bundled assets error: $e');
    });

    _initialized = true;
  }

  Stream<SttModelInfo> watchModel(WhisperModelLevel level) {
    _ensureSubjects();
    return _modelStates[level]!.stream;
  }

  SttModelInfo getModelInfo(WhisperModelLevel level) {
    _ensureSubjects();
    return _modelStates[level]!.value;
  }

  bool isModelReady(WhisperModelLevel level) => getModelInfo(level).isReady;

  String? getModelPath(WhisperModelLevel level) {
    final info = getModelInfo(level);
    return info.isReady ? info.localPath : null;
  }

  String get modelDirectoryPath => _modelDirectory ?? 'Chưa khởi tạo';

  Future<int> getFreeSpaceMB() => _getFreeSpaceMB();

  Future<void> rescan() async {
    _ensureInitialized();
    await _scanExistingModels();
  }

  Future<bool> ensureModel(WhisperModelLevel level) async {
    _ensureInitialized();

    final existing = await _findExistingModelFile(level);
    if (existing != null) {
      _emitState(
        level,
        ModelStatus.downloaded,
        localPath: existing.path,
        progress: 1.0,
      );
      return true;
    }

    return downloadModel(level);
  }

  Future<bool> downloadModel(
    WhisperModelLevel level, {
    int maxRetries = 2,
  }) async {
    _ensureInitialized();

    if (isModelReady(level)) return true;
    if (_activeDownloads.containsKey(level)) return false;

    final urls = _urlsFor(level);
    if (urls.isEmpty) {
      _emitState(
        level,
        ModelStatus.notDownloaded,
        errorMessage: 'Chưa cấu hình URL download cho model ${level.name}',
      );
      return false;
    }

    final hasSpace = await _checkFreeSpace(level);
    if (!hasSpace) {
      final freeMB = await _getFreeSpaceMB();
      _emitState(
        level,
        ModelStatus.insufficientSpace,
        errorMessage: 'Cần ${level.requiredFreeSpaceMB}MB, còn $freeMB MB',
      );
      return false;
    }

    final cancelToken = CancelToken();
    _activeDownloads[level] = cancelToken;
    _emitState(level, ModelStatus.downloading, progress: 0.0);

    try {
      for (final url in urls) {
        final success = await _downloadFromUrl(
          level: level,
          url: url,
          cancelToken: cancelToken,
          maxRetries: maxRetries,
        );

        if (success) {
          _activeDownloads.remove(level);
          return true;
        }

        if (cancelToken.isCancelled) {
          _activeDownloads.remove(level);
          _emitState(level, ModelStatus.notDownloaded);
          return false;
        }
      }

      _activeDownloads.remove(level);
      _emitState(
        level,
        ModelStatus.notDownloaded,
        errorMessage:
            'Không tải được model ${level.name} từ tất cả nguồn đã cấu hình',
      );
      return false;
    } catch (e) {
      _activeDownloads.remove(level);
      _emitState(
        level,
        ModelStatus.notDownloaded,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void cancelDownload(WhisperModelLevel level) {
    _activeDownloads[level]?.cancel('User cancelled');
    _activeDownloads.remove(level);
    _emitState(level, ModelStatus.notDownloaded);
  }

  Future<void> deleteModel(WhisperModelLevel level) async {
    _ensureInitialized();

    final files = await _listLocalBinFiles();
    for (final file in files) {
      if (await _belongsToLevel(file, level)) {
        await file.delete().catchError((_) {});
        await File('${file.path}.level').delete().catchError((_) {});
        debugPrint('🗑️ Deleted model file: ${file.path}');
      }
    }

    _emitState(level, ModelStatus.notDownloaded);
  }

  /// Import file .bin từ bất kỳ path nào.
  ///
  /// Nếu [level] == null:
  /// - app sẽ cố detect theo tên file
  /// - nếu không detect được, file vẫn được copy vào thư mục model
  ///   nhưng bạn nên gọi lại với level cụ thể để pin chính xác
  Future<bool> importModelFromPath(
    String sourcePath, {
    WhisperModelLevel? level,
  }) async {
    _ensureInitialized();

    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('❌ Source không tồn tại: $sourcePath');
        return false;
      }

      if (p.extension(sourcePath).toLowerCase() != '.bin') {
        debugPrint('❌ File không phải .bin: $sourcePath');
        return false;
      }

      final detectedLevel = level ?? detectLevelFromFileName(sourcePath);
      final fileName = p.basename(sourcePath);
      final destPath = p.join(_modelDirectory!, fileName);

      _emitState(
        detectedLevel ?? WhisperModelLevel.base,
        ModelStatus.downloading,
        progress: 0.0,
      );

      final total = await sourceFile.length();
      var copied = 0;

      final outFile = File(destPath);
      final sink = outFile.openWrite();

      await for (final chunk in sourceFile.openRead()) {
        sink.add(chunk);
        copied += chunk.length;

        if (detectedLevel != null && total > 0) {
          _emitState(
            detectedLevel,
            ModelStatus.downloading,
            progress: copied / total,
          );
        }
      }

      await sink.flush();
      await sink.close();

      if (detectedLevel != null) {
        final valid = await _verifyFile(destPath, detectedLevel);
        if (!valid) {
          await outFile.delete().catchError((_) {});
          _emitState(detectedLevel, ModelStatus.corrupted);
          return false;
        }

        await _writePinnedLevel(destPath, detectedLevel);
        _emitState(
          detectedLevel,
          ModelStatus.downloaded,
          localPath: destPath,
          progress: 1.0,
        );
      }

      await _scanExistingModels();
      debugPrint('✅ Import thành công: $destPath');
      return true;
    } catch (e) {
      debugPrint('❌ Import error: $e');
      return false;
    }
  }

  WhisperModelLevel? detectLevelFromFileName(String pathOrName) {
    final fileName = p.basename(pathOrName).toLowerCase();

    for (final level in WhisperModelLevel.values) {
      if (_matchScore(fileName, level) > 0) {
        return level;
      }
    }
    return null;
  }

  void dispose() {
    for (final token in _activeDownloads.values) {
      token.cancel('Disposed');
    }
    _activeDownloads.clear();

    for (final subject in _modelStates.values) {
      subject.close();
    }
    _modelStates.clear();

    _instance = null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal
  // ───────────────────────────────────────────────────────────────────────────

  void _ensureSubjects() {
    for (final level in WhisperModelLevel.values) {
      _modelStates.putIfAbsent(
        level,
        () => BehaviorSubject<SttModelInfo>.seeded(
          SttModelInfo(level: level, status: ModelStatus.notDownloaded),
        ),
      );
    }
  }

  void _ensureInitialized() {
    if (_modelDirectory == null) {
      throw StateError(
        'SttModelManager chưa được khởi tạo. Gọi initialize() trước.',
      );
    }
  }

  Future<String> _resolveModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'vipsound_whisper_models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  List<String> _normalizeStringList(List<String> input) {
    final result = <String>{};
    for (final item in input) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) result.add(trimmed);
    }
    return result.toList();
  }

  List<String> _acceptedFileNamesFor(WhisperModelLevel level) {
    final merged = <String>{
      ...level.candidateFileNames,
      ...?_nameOverrides[level],
    };
    return merged.map((e) => e.toLowerCase()).toList();
  }

  List<String> _urlsFor(WhisperModelLevel level) {
    final override = _urlOverrides[level];
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return [level.downloadUrl, level.mirrorUrl];
  }

  Future<List<File>> _listLocalBinFiles() async {
    _ensureInitialized();
    final dir = Directory(_modelDirectory!);
    final result = <File>[];

    if (!await dir.exists()) return result;

    await for (final entity in dir.list()) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.bin') {
        result.add(entity);
      }
    }
    return result;
  }

  Future<void> _scanExistingModels() async {
    _ensureInitialized();

    final files = await _listLocalBinFiles();
    debugPrint(
        'DEBUG [STT]: Scanning models in $_modelDirectory. Found ${files.length} candidates.');

    for (final level in WhisperModelLevel.values) {
      File? found;

      for (final file in files) {
        debugPrint('DEBUG [STT]: Checking file $file for level ${level.name}');
        if (await _belongsToLevel(file, level) &&
            await _verifyFile(file.path, level)) {
          found = file;
          break;
        }
      }

      if (found != null) {
        debugPrint(
            'DEBUG [STT]: Model ${level.name} resolved to ${found.path}');
        _emitState(
          level,
          ModelStatus.downloaded,
          localPath: found.path,
          progress: 1.0,
        );
      } else {
        _emitState(level, ModelStatus.notDownloaded);
      }
    }
  }

  Future<bool> _belongsToLevel(File file, WhisperModelLevel level) async {
    final pinned = await _readPinnedLevel(file.path);
    if (pinned == level) return true;

    final name = p.basename(file.path).toLowerCase();
    return _matchScore(name, level) > 0;
  }

  int _matchScore(String fileName, WhisperModelLevel level) {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.bin')) return 0;

    final accepted = _acceptedFileNamesFor(level);
    if (accepted.contains(lower)) return 1000;

    final levelName = level.name.toLowerCase();

    if (lower.contains('ggml-$levelName')) return 900;
    if (lower.contains('whisper-$levelName')) return 850;
    if (_containsToken(lower, levelName)) return 800;

    if (level == WhisperModelLevel.large && lower.contains('large-v3')) {
      return 880;
    }

    return 0;
  }

  bool _containsToken(String text, String token) {
    final regex = RegExp('(^|[^a-z])${RegExp.escape(token)}([^a-z]|\$)');
    return regex.hasMatch(text);
  }

  Future<File?> _findExistingModelFile(WhisperModelLevel level) async {
    final files = await _listLocalBinFiles();

    // Ưu tiên file pinned chính xác
    for (final file in files) {
      final pinned = await _readPinnedLevel(file.path);
      if (pinned == level && await _verifyFile(file.path, level)) {
        return file;
      }
    }

    // Sau đó đến tên file exact/fuzzy
    final scored = <MapEntry<File, int>>[];
    for (final file in files) {
      final score = _matchScore(p.basename(file.path), level);
      if (score > 0) {
        scored.add(MapEntry(file, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    for (final entry in scored) {
      if (await _verifyFile(entry.key.path, level)) {
        return entry.key;
      }
    }

    return null;
  }

  Future<void> _copyBundledAssetsIfAvailable() async {
    _ensureInitialized();

    for (final entry in _bundledAssetPaths.entries) {
      final level = entry.key;
      final assetPath = entry.value;

      // ★ Kiểm tra file đã tồn tại chưa trước khi copy
      final existing = await _findExistingModelFile(level);
      if (existing != null) {
        debugPrint('✅ Model ${level.name} đã có: ${existing.path}');
        continue;
      }

      try {
        // ★ Check asset có tồn tại không trước khi load
        ByteData? data;
        try {
          data = await rootBundle.load(assetPath);
        } catch (_) {
          continue;
        }

        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        // ★ File rỗng thì bỏ qua
        if (bytes.isEmpty) continue;

        final savePath = p.join(_modelDirectory!, level.fileName);
        await File(savePath).writeAsBytes(bytes, flush: true);

        final valid = await _verifyFile(savePath, level);
        if (!valid) {
          try {
            await File(savePath).delete();
          } catch (_) {}
          continue;
        }

        await _writePinnedLevel(savePath, level);

        _emitState(
          level,
          ModelStatus.downloaded,
          localPath: savePath,
          progress: 1.0,
        );
        debugPrint('✅ Copied bundled model: ${level.name}');
      } catch (e) {
        debugPrint('ℹ️ Không có bundled asset cho ${level.name}: $e');
      }
    }
  }

  Future<bool> _downloadFromUrl({
    required WhisperModelLevel level,
    required String url,
    required CancelToken cancelToken,
    required int maxRetries,
  }) async {
    var attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      if (cancelToken.isCancelled) return false;

      try {
        final fileName = _safeFileNameFromUrl(url, fallback: level.fileName);
        final savePath = p.join(_modelDirectory!, fileName);
        final tmpPath = '$savePath.tmp';

        debugPrint('📥 Download ${level.name} từ: $url');

        await _dio.download(
          url,
          tmpPath,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            _emitState(
              level,
              ModelStatus.downloading,
              progress: received / total,
            );
          },
        );

        final tmpFile = File(tmpPath);
        if (!await tmpFile.exists()) return false;

        final finalFile = File(savePath);
        if (await finalFile.exists()) {
          await finalFile.delete().catchError((_) {});
        }
        await tmpFile.rename(savePath);

        final valid = await _verifyFile(savePath, level);
        if (!valid) {
          await File(savePath).delete().catchError((_) {});
          throw Exception('File verify failed: $savePath');
        }

        await _writePinnedLevel(savePath, level);

        _emitState(
          level,
          ModelStatus.downloaded,
          localPath: savePath,
          progress: 1.0,
        );

        debugPrint('✅ Download thành công: $savePath');
        return true;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          debugPrint('🚫 Download bị huỷ');
          return false;
        }

        debugPrint(
          '⚠️ Download ${level.name} thất bại '
          '($attempt/$maxRetries) - HTTP ${e.response?.statusCode}: ${e.message}',
        );

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } catch (e) {
        debugPrint(
            '⚠️ Download ${level.name} error ($attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    return false;
  }

  String _safeFileNameFromUrl(String url, {required String fallback}) {
    try {
      final uri = Uri.parse(url);
      final name = p.basename(uri.path);
      if (name.toLowerCase().endsWith('.bin')) return name;
    } catch (_) {}
    return fallback;
  }

  Future<bool> _verifyFile(String path, WhisperModelLevel level) async {
    debugPrint('DEBUG [STT]: Verifying file $path for level ${level.name}');
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      if (p.extension(path).toLowerCase() != '.bin') return false;

      final sizeMB = await file.length() / (1024 * 1024);
      if (sizeMB < level.minimumAcceptedSizeMB) {
        debugPrint(
          '❌ File quá nhỏ cho ${level.name}: ${sizeMB.toStringAsFixed(1)}MB',
        );
        return false;
      }

      final expectedSha1 = level.expectedSha1;
      final baseName = p.basename(path).toLowerCase();

      // Chỉ cảnh báo SHA1, không block file custom khác nguồn.
      if (expectedSha1.isNotEmpty &&
          _acceptedFileNamesFor(level).contains(baseName)) {
        final actualSha1 = await _computeSha1(file);
        if (actualSha1 != expectedSha1) {
          debugPrint(
            '⚠️ SHA1 khác kỳ vọng cho ${level.name}: '
            '$actualSha1 != $expectedSha1 (chấp nhận vì có thể là nguồn custom)',
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Verify error: $e');
      return false;
    }
  }

  Future<String> _computeSha1(File file) async {
    final digest = await sha1.bind(file.openRead()).last;
    return digest.toString();
  }

  Future<bool> _checkFreeSpace(WhisperModelLevel level) async {
    final freeMB = await _getFreeSpaceMB();
    return freeMB >= level.requiredFreeSpaceMB;
  }

  Future<int> _getFreeSpaceMB() async {
    try {
      return 2048;
    } catch (_) {
      return 512;
    }
  }

  Future<void> _writePinnedLevel(
    String modelPath,
    WhisperModelLevel level,
  ) async {
    final sidecar = File('$modelPath.level');
    await sidecar.writeAsString(level.name, flush: true);
  }

  Future<WhisperModelLevel?> _readPinnedLevel(String modelPath) async {
    try {
      final sidecar = File('$modelPath.level');
      if (!await sidecar.exists()) return null;

      final raw = (await sidecar.readAsString()).trim();
      for (final level in WhisperModelLevel.values) {
        if (level.name == raw) return level;
      }
    } catch (_) {}
    return null;
  }

  void _emitState(
    WhisperModelLevel level,
    ModelStatus status, {
    String? localPath,
    double? progress,
    String? errorMessage,
  }) {
    final current = _modelStates[level]!.value;
    _modelStates[level]!.add(
      current.copyWith(
        status: status,
        localPath: localPath,
        downloadProgress: progress,
        errorMessage: errorMessage,
      ),
    );
  }

  WhisperModelLevel? getBestAvailableLocalModel({
    List<WhisperModelLevel>? preferredOrder,
  }) {
    final order = preferredOrder ??
        const [
          WhisperModelLevel.base,
          WhisperModelLevel.tiny,
          WhisperModelLevel.small,
          WhisperModelLevel.medium,
          WhisperModelLevel.large,
        ];

    for (final level in order) {
      final info = getModelInfo(level);
      if (info.isReady && info.localPath != null) {
        return level;
      }
    }
    return null;
  }

  bool get hasAnyLocalModel =>
      WhisperModelLevel.values.any((level) => getModelInfo(level).isReady);
}
