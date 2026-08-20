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
        'User-Agent': 'Mozilla/5.0 (compatible; in4upApp/1.0)',
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

  /// Rule 2 — Disable Auto-Download (Handover SECTION 1)
  /// Nguyên nhân gốc: sai filePath -> fallback tự động gọi HTTP GET HuggingFace CDN
  /// -> HttpException: Connection closed.
  /// Directive: Xóa/disable hoàn toàn downloadModel() tự động từ URL xa.
  /// App chỉ được nạp file đã chép sẵn tại modelPath (absolute path).
  static const bool _kDisableAutoDownload = true;

  Future<bool> ensureModel(WhisperModelLevel level) async {
    _ensureInitialized();

    final existing = await _findExistingModelFile(level);
    if (existing != null) {
      // Rule 3 — Local Verification trước khi coi là ready
      final ok = await _verifyFileWithAbsoluteCheck(existing.path, level);
      if (ok) {
        _emitState(
          level,
          ModelStatus.downloaded,
          localPath: existing.path,
          progress: 1.0,
        );
        return true;
      }
    }

    // Không auto-download nữa — báo lỗi thân thiện
    _emitState(
      level,
      ModelStatus.notDownloaded,
      errorMessage:
          'Model ${level.name} chưa có tại ${_modelDirectory}. '
          'Hãy chép file ${level.fileName} vào thư mục trên (Rule 2: disable auto-download, '
          'tránh HttpException HuggingFace CDN)',
    );
    return false;
  }

  Future<bool> downloadModel(
    WhisperModelLevel level, {
    int maxRetries = 2,
  }) async {
    _ensureInitialized();

    if (isModelReady(level)) return true;

    if (_kDisableAutoDownload) {
      debugPrint(
        '⛔️ Auto-download DISABLED by handover Rule 2 — model ${level.name} '
        'must be manually placed at ${_modelDirectory}. '
        'Blocking HuggingFace CDN call that caused HttpException.',
      );
      _emitState(
        level,
        ModelStatus.notDownloaded,
        errorMessage:
            'Auto-download đã tắt (fix HttpException). '
            'Vui lòng chép thủ công file ${level.fileName} hoặc ggml-tiny-q4_0.bin '
            'vào ${_modelDirectory}.',
      );
      return false;
    }

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

  /// Rule 3 — Local Verification helper
  /// Kiểm tra absolute path tồn tại + size > 1_000_000 trước init Whisper
  Future<bool> _verifyFileWithAbsoluteCheck(
      String absolutePath, WhisperModelLevel level) async {
    try {
      final file = File(absolutePath);
      // Dùng existsSync() như yêu cầu handover
      if (!file.existsSync()) {
        debugPrint('❌ Verify Rule3: File không tồn tại (existsSync false): $absolutePath');
        return false;
      }
      final size = file.lengthSync();
      if (size <= 1000000) {
        debugPrint('❌ Verify Rule3: File quá nhỏ ($size bytes) — yêu cầu >1_000_000: $absolutePath');
        return false;
      }
      // Kiểm tra thêm minimum theo level
      return await _verifyFile(absolutePath, level);
    } catch (e) {
      debugPrint('❌ Verify Rule3 exception: $e');
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

  /// Rule 1 — Absolute Path via path_provider (handover SECTION 1)
  /// Trước đây hardcode string gây lỗi trên Android Tablet.
  /// Giờ dùng getApplicationDocumentsDirectory() để có absolute path chuẩn,
  /// không phụ thuộc flavor / sandbox của Android.
  Future<String> _resolveModelDirectory() async {
    // Handover yêu cầu: final dir = await getApplicationDocumentsDirectory();
    // Tạo folder con để gom model
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      // Fallback nếu documents không khả dụng (test env)
      baseDir = await getApplicationSupportDirectory();
    }
    final dir = Directory(p.join(baseDir.path, 'in4up_whisper_models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Đồng thời đảm bảo folder cũ (support dir) vẫn được quét khi rescan
    // để không mất model của user cũ — scan sẽ merge từ _listLocalBinFiles
    // có thêm fallback scan ở dưới.
    return dir.path;
  }

  /// Thêm scan fallback: nếu model không có ở documents, thử tìm ở support dir cũ
  Future<String?> _resolveLegacySupportDirectory() async {
    try {
      final sup = await getApplicationSupportDirectory();
      final legacy = Directory(p.join(sup.path, 'in4up_whisper_models'));
      if (await legacy.exists()) return legacy.path;
    } catch (_) {}
    return null;
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
    final result = <File>[];

    // Primary: documents/in4up_whisper_models (Rule 1)
    final primaryDir = Directory(_modelDirectory!);
    if (await primaryDir.exists()) {
      await for (final entity in primaryDir.list()) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.bin') {
          result.add(entity);
        }
      }
    }

    // Fallback: legacy support dir — để không mất model cũ khi migrate
    try {
      final legacyPath = await _resolveLegacySupportDirectory();
      if (legacyPath != null && legacyPath != _modelDirectory) {
        final legacyDir = Directory(legacyPath);
        if (await legacyDir.exists()) {
          await for (final entity in legacyDir.list()) {
            if (entity is File &&
                p.extension(entity.path).toLowerCase() == '.bin') {
              // Tránh duplicate cùng tên đã có ở primary
              final name = p.basename(entity.path);
              if (!result.any((f) => p.basename(f.path) == name)) {
                result.add(entity);
              }
            }
          }
        }
      }
    } catch (_) {}

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
    // FIX OOM Android: uu tien tiny truoc base de tiet kiem RAM (tiny 75MB vs base 142MB)
    // Tren device RAM thap (gts9fe SM-X516B) base model 3phut da gay Scudo OOM
    final order = preferredOrder ??
        const [
          WhisperModelLevel.tiny,
          WhisperModelLevel.base,
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
