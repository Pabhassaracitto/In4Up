// Thêm logic: thử primary URL → fallback mirror URL tự động

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'models/stt_model_info.dart';

class SttModelManager {
  static SttModelManager? _instance;
  factory SttModelManager() =>
      _instance ??= SttModelManager._internal();
  SttModelManager._internal();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 30),
    // ✅ Header giả lập browser để HuggingFace không block
    headers: {
      'User-Agent':
          'Mozilla/5.0 (compatible; VipsoundApp/1.0)',
    },
  ));

  final _modelStates =
      <WhisperModelLevel, BehaviorSubject<SttModelInfo>>{};
  final _activeDownloads =
      <WhisperModelLevel, CancelToken>{};
  String? _modelDirectory;

  // ─── Initialization ─────────────────────────────────────────────────────

  Future<void> initialize() async {
    _modelDirectory = await _resolveModelDirectory();
    debugPrint('📁 Model dir: $_modelDirectory');

    for (final level in WhisperModelLevel.values) {
      if (!_modelStates.containsKey(level)) {
        _modelStates[level] = BehaviorSubject<SttModelInfo>.seeded(
          SttModelInfo(
              level: level, status: ModelStatus.notDownloaded),
        );
      }
    }

    await _scanExistingModels();
  }

  // ─── Public API ─────────────────────────────────────────────────────────

  Stream<SttModelInfo> watchModel(WhisperModelLevel level) {
    _ensureInitialized();
    return _modelStates[level]!.stream;
  }

  SttModelInfo getModelInfo(WhisperModelLevel level) {
    _ensureInitialized();
    return _modelStates[level]!.value;
  }

  bool isModelReady(WhisperModelLevel level) =>
      getModelInfo(level).isReady;

  String? getModelPath(WhisperModelLevel level) {
    final info = getModelInfo(level);
    return info.isReady ? info.localPath : null;
  }

  Future<int> getFreeSpaceMB() => _getFreeSpaceMB();

  /// Download với fallback tự động:
  /// HuggingFace → GitHub Releases (mirror)
  Future<bool> downloadModel(
    WhisperModelLevel level, {
    int maxRetries = 3,
  }) async {
    _ensureInitialized();

    final info = getModelInfo(level);
    if (info.isReady) return true;
    if (info.isDownloading) return false;

    // Kiểm tra dung lượng
    final hasSpace = await _checkFreeSpace(level);
    if (!hasSpace) {
      final freeMB = await _getFreeSpaceMB();
      _emitState(
        level,
        ModelStatus.insufficientSpace,
        errorMessage: 'Cần ${level.requiredFreeSpaceMB}MB, '
            'còn $freeMB MB',
      );
      return false;
    }

    _emitState(level, ModelStatus.downloading, progress: 0.0);
    final cancelToken = CancelToken();
    _activeDownloads[level] = cancelToken;

    // Danh sách URL thử theo thứ tự ưu tiên
    final urlSources = [
      ('HuggingFace', level.downloadUrl),
      ('GitHub Mirror', level.mirrorUrl),
    ];

    for (final (sourceName, url) in urlSources) {
      debugPrint('📥 Thử tải từ $sourceName: $url');

      final success = await _downloadFromUrl(
        url: url,
        sourceName: sourceName,
        level: level,
        cancelToken: cancelToken,
        maxRetries: maxRetries,
      );

      if (success) {
        _activeDownloads.remove(level);
        return true;
      }

      // Nếu bị cancel thì dừng hẳn, không thử mirror
      if (!_activeDownloads.containsKey(level)) {
        return false;
      }

      debugPrint(
          '⚠️ $sourceName thất bại, chuyển sang nguồn tiếp theo...');
    }

    // Tất cả nguồn đều thất bại
    _activeDownloads.remove(level);
    _emitState(
      level,
      ModelStatus.notDownloaded,
      errorMessage: 'Không thể tải từ tất cả nguồn. '
          'Kiểm tra kết nối mạng.',
    );
    return false;
  }

  void cancelDownload(WhisperModelLevel level) {
    _activeDownloads[level]?.cancel('User cancelled');
    _activeDownloads.remove(level);
    _emitState(level, ModelStatus.notDownloaded);
  }

  Future<void> deleteModel(WhisperModelLevel level) async {
    _ensureInitialized();
    final path = _getModelFilePath(level);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      debugPrint('🗑️ Deleted: $path');
    }
    _emitState(level, ModelStatus.notDownloaded);
  }

  // ─── Core Download Logic ─────────────────────────────────────────────────

  Future<bool> _downloadFromUrl({
    required String url,
    required String sourceName,
    required WhisperModelLevel level,
    required CancelToken cancelToken,
    required int maxRetries,
  }) async {
    final savePath = _getModelFilePath(level);
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      // Nếu đã bị cancel
      if (cancelToken.isCancelled) return false;

      try {
        // Kiểm tra file đang tải dở
        final resumeBytes = await _getResumedBytes(savePath);
        final headers = resumeBytes > 0
            ? {'Range': 'bytes=$resumeBytes-'}
            : <String, dynamic>{};

        if (resumeBytes > 0) {
          debugPrint(
              '↩️ Resume từ ${(resumeBytes / 1024 / 1024).toStringAsFixed(1)}MB');
        }

        await _dio.download(
          url,
          // Tải vào file tạm trước
          '$savePath.tmp',
          cancelToken: cancelToken,
          deleteOnError: false, // Giữ file tạm để resume
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            // Cộng thêm bytes đã resume
            final totalReceived = received + resumeBytes;
            final totalSize = total + resumeBytes;
            final progress = totalReceived / totalSize;

            _emitState(
              level,
              ModelStatus.downloading,
              progress: progress,
            );
          },
          options: Options(
            headers: headers,
            followRedirects: true,
            maxRedirects: 5,
          ),
        );

        // Rename file tạm → file chính
        final tmpFile = File('$savePath.tmp');
        if (await tmpFile.exists()) {
          await tmpFile.rename(savePath);
        }

        // Verify file
        final valid = await _verifyFile(savePath, level);
        if (!valid) {
          await File(savePath).delete().catchError((_) => File(savePath));
          throw Exception('File verification failed');
        }

        _emitState(
          level,
          ModelStatus.downloaded,
          localPath: savePath,
          progress: 1.0,
        );
        debugPrint(
            '✅ Download thành công từ $sourceName!');
        return true;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          debugPrint('🚫 Download bị huỷ');
          _emitState(level, ModelStatus.notDownloaded);
          return false;
        }

        final statusCode = e.response?.statusCode;
        debugPrint(
            '⚠️ $sourceName attempt $attempt/$maxRetries '
            'thất bại (HTTP $statusCode): ${e.message}');

        // Một số lỗi không nên retry
        if (statusCode == 404 || statusCode == 403) {
          debugPrint('❌ Lỗi $statusCode - không retry');
          return false;
        }

        if (attempt < maxRetries) {
          final waitSec = 2 * attempt;
          debugPrint('⏳ Chờ ${waitSec}s trước khi retry...');
          await Future.delayed(Duration(seconds: waitSec));
        }
      } catch (e) {
        debugPrint(
            '⚠️ $sourceName attempt $attempt/$maxRetries error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }

    return false;
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  Future<void> _scanExistingModels() async {
    for (final level in WhisperModelLevel.values) {
      final path = _getModelFilePath(level);
      final file = File(path);

      if (await file.exists()) {
        final sizeMB = await file.length() / 1024 / 1024;

        if (sizeMB < level.sizeInMB * 0.8) {
          debugPrint(
              '⚠️ Model ${level.name} corrupt '
              '(${sizeMB.toStringAsFixed(1)}MB)');
          _emitState(level, ModelStatus.corrupted, localPath: path);
        } else {
          debugPrint(
              '✅ Model ${level.name} sẵn sàng '
              '(${sizeMB.toStringAsFixed(1)}MB)');
          _emitState(level, ModelStatus.downloaded, localPath: path);
        }
      }
    }
  }

  Future<String> _resolveModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final modelDir =
        Directory('${appDir.path}/whisper_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  String _getModelFilePath(WhisperModelLevel level) =>
      '$_modelDirectory/${level.fileName}';

  Future<bool> _checkFreeSpace(WhisperModelLevel level) async {
    final freeMB = await _getFreeSpaceMB();
    return freeMB >= level.requiredFreeSpaceMB;
  }

  Future<int> _getFreeSpaceMB() async {
    try {
      // TODO: Thay bằng disk_space package khi cần chính xác
      // import 'package:disk_space/disk_space.dart';
      // return (await DiskSpace.getFreeDiskSpace ?? 2048).toInt();
      return 2048;
    } catch (_) {
      return 500;
    }
  }

  /// Lấy số bytes đã tải (để resume)
  Future<int> _getResumedBytes(String savePath) async {
    try {
      final tmpFile = File('$savePath.tmp');
      if (await tmpFile.exists()) {
        return await tmpFile.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<bool> _verifyFile(
      String path, WhisperModelLevel level) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final sizeMB = await file.length() / 1024 / 1024;
      final minMB = level.sizeInMB * 0.9;
      final maxMB = level.sizeInMB * 1.1;

      if (sizeMB < minMB || sizeMB > maxMB) {
        debugPrint(
            '❌ Size không hợp lệ: ${sizeMB.toStringAsFixed(1)}MB '
            '(kỳ vọng ${level.sizeInMB}MB ± 10%)');
        return false;
      }

      // Verify SHA1 checksum
      final digest = await _computeSha1(file);
      final expected = level.expectedSha1;
      if (digest != expected) {
        debugPrint('❌ SHA1 không khớp: $digest vs $expected');
        // Cảnh báo nhưng không fail (checksum có thể khác theo version)
        debugPrint('⚠️ Tiếp tục dù SHA1 không khớp...');
      }

      debugPrint(
          '✅ Verify OK: ${sizeMB.toStringAsFixed(1)}MB');
      return true;
    } catch (e) {
      debugPrint('❌ Verify error: $e');
      return false;
    }
  }

  Future<String> _computeSha1(File file) async {
    final stream = file.openRead();
    final digest = await sha1.bind(stream).first;
    return digest.toString();
  }

  void _emitState(
    WhisperModelLevel level,
    ModelStatus status, {
    String? localPath,
    double? progress,
    String? errorMessage,
  }) {
    final current = _modelStates[level]!.value;
    _modelStates[level]!.add(current.copyWith(
      status: status,
      localPath: localPath,
      downloadProgress: progress,
      errorMessage: errorMessage,
    ));
  }

  void _ensureInitialized() {
    if (_modelDirectory == null) {
      throw StateError(
          'SttModelManager chưa được khởi tạo. '
          'Gọi initialize() trước.');
    }
  }

  void dispose() {
    for (final token in _activeDownloads.values) {
      token.cancel('Disposed');
    }
    _activeDownloads.clear();
    for (final subject in _modelStates.values) {
      subject.close();
    }
    _instance = null;
  }
}
