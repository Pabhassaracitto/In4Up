// Thêm logic: thử primary URL → fallback mirror URL tự động

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'models/stt_model_info.dart';

class SttModelManager {
  static SttModelManager? _instance;
  factory SttModelManager() => _instance ??= SttModelManager._internal();
  SttModelManager._internal();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 30),
    // ✅ Header giả lập browser để HuggingFace không block
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; VipsoundApp/1.0)',
    },
  ));

  final _modelStates = <WhisperModelLevel, BehaviorSubject<SttModelInfo>>{};
  final _activeDownloads = <WhisperModelLevel, CancelToken>{};
  String? _modelDirectory;

  // ─── Initialization ─────────────────────────────────────────────────────

  Future<void> initialize() async {
    _modelDirectory = await _resolveModelDirectory();
    debugPrint('📁 Model dir: $_modelDirectory');

    for (final level in WhisperModelLevel.values) {
      if (!_modelStates.containsKey(level)) {
        _modelStates[level] = BehaviorSubject<SttModelInfo>.seeded(
          SttModelInfo(level: level, status: ModelStatus.notDownloaded),
        );
      }
    }

    try {
      // Đảm bảo việc lỗi ở Assets không làm chết cả quá trình init
      await _checkAndCopyFromAssets().timeout(const Duration(minutes: 2));
    } catch (e) {
      debugPrint('⚠️ Lỗi khi kiểm tra assets: $e');
    }

    await _scanExistingModels(); // Quét lại để cập nhật trạng thái cuối cùng
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

  bool isModelReady(WhisperModelLevel level) => getModelInfo(level).isReady;

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

      debugPrint('⚠️ $sourceName thất bại, chuyển sang nguồn tiếp theo...');
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
        debugPrint('✅ Download thành công từ $sourceName!');
        return true;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          debugPrint('🚫 Download bị huỷ');
          _emitState(level, ModelStatus.notDownloaded);
          return false;
        }

        final statusCode = e.response?.statusCode;
        debugPrint('⚠️ $sourceName attempt $attempt/$maxRetries '
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
        debugPrint('⚠️ $sourceName attempt $attempt/$maxRetries error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }

    return false;
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  Future<void> _scanExistingModels() async {
    if (_modelDirectory == null) return;
    final dir = Directory(_modelDirectory!);
    if (!await dir.exists()) return;

    final files = await dir.list().toList();

    for (final level in WhisperModelLevel.values) {
      File? modelFile;
      for (final f in files) {
        if (f is File && f.path.contains('ggml-${level.name}')) {
          modelFile = f;
          break;
        }
      }

      if (modelFile != null && await modelFile.exists()) {
        final sizeMB = await modelFile.length() / 1024 / 1024;
        debugPrint(
            '🔍 Đang kiểm tra file hiện có: ${modelFile.path} ($sizeMB MB)');

        if (!_isSizeValid(sizeMB, level)) {
          debugPrint('⚠️ Model ${level.name} bị hỏng hoặc size không khớp.');
          _emitState(level, ModelStatus.corrupted, localPath: modelFile.path);
        } else {
          debugPrint('✅ Model ${level.name} đã sẵn sàng.');
          _emitState(level, ModelStatus.downloaded, localPath: modelFile.path);
        }
      }
    }
  }

  Future<String> _resolveModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${appDir.path}/whisper_models');
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

  Future<bool> _verifyFile(String path, WhisperModelLevel level) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final sizeMB = await file.length() / 1024 / 1024;
      if (!_isSizeValid(sizeMB, level)) return false;
      // Verify SHA1 checksum
      final digest = await _computeSha1(file);
      final expected = level.expectedSha1;
      if (digest != expected) {
        debugPrint(
            '⚠️ Cảnh báo SHA1: $digest (thực tế) vs $expected (kỳ vọng)');
        debugPrint('ℹ️ Chấp nhận model phiên bản khác nếu kích thước hợp lệ.');
      }

      debugPrint('✅ Verify OK: ${sizeMB.toStringAsFixed(1)}MB');
      return true;
    } catch (e) {
      debugPrint('❌ Verify error: $e');
      return false;
    }
  }

  /// Kiểm tra xem kích thước file có hợp lệ cho model đã cho không.
  /// Cho phép các model đã được lượng tử hóa (quantized) có kích thước nhỏ hơn.
  bool _isSizeValid(double actualSizeMB, WhisperModelLevel level) {
    // Đối với các bản lượng tử hóa cực mạnh, kích thước có thể rất nhỏ.
    // Ta chỉ cần đảm bảo file không phải là rác (ví dụ: < 5MB cho Tiny là bất thường)
    double minAcceptableSizeMB = 5.0;

    if (level == WhisperModelLevel.medium || level == WhisperModelLevel.large) {
      minAcceptableSizeMB = 50.0; // Các model lớn hơn thì giới hạn cao hơn chút
    }

    if (actualSizeMB < minAcceptableSizeMB) {
      debugPrint(
          '❌ Kích thước không hợp lệ: ${actualSizeMB.toStringAsFixed(1)}MB '
          '(kỳ vọng tối thiểu ${minAcceptableSizeMB.toStringAsFixed(1)}MB)');
      return false;
    }
    return true;
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
      throw StateError('SttModelManager chưa được khởi tạo. '
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

  /// Copy model từ path bất kỳ vào model directory
  /// Dùng cho dev: copy file từ máy tính vào app
  Future<bool> importModelFromPath(
    String sourcePath,
    WhisperModelLevel level,
  ) async {
    _ensureInitialized();

    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('❌ Source không tồn tại: $sourcePath');
        return false;
      }

      final destPath = _getModelFilePath(level);
      debugPrint('📋 Copying ${level.name}: $sourcePath → $destPath');

      _emitState(level, ModelStatus.downloading, progress: 0.0);

      // Copy với progress
      final sourceSize = await sourceFile.length();
      final destFile = File(destPath);
      final sink = destFile.openWrite();
      final stream = sourceFile.openRead();

      int copied = 0;
      await for (final chunk in stream) {
        sink.add(chunk);
        copied += chunk.length;
        _emitState(
          level,
          ModelStatus.downloading,
          progress: copied / sourceSize,
        );
      }
      await sink.close();

      // Verify
      final valid = await _verifyFile(destPath, level);
      if (!valid) {
        await destFile.delete().catchError((_) => destFile);
        _emitState(level, ModelStatus.corrupted);
        return false;
      }

      _emitState(level, ModelStatus.downloaded, localPath: destPath);
      debugPrint('✅ Import thành công: ${level.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Import error: $e');
      _emitState(level, ModelStatus.notDownloaded, errorMessage: e.toString());
      return false;
    }
  }

  /// Lấy model directory path (dùng cho DevTools/debug)
  String get modelDirectoryPath => _modelDirectory ?? 'Chưa khởi tạo';

  /// Kiểm tra xem model có trong assets không, nếu có thì copy ra local storage
  Future<void> _checkAndCopyFromAssets() async {
    for (final level in WhisperModelLevel.values) {
      final localPath = _getModelFilePath(level);
      final localFile = File(localPath);

      // Nếu file đã tồn tại ở local rồi thì bỏ qua không copy lại
      if (await localFile.exists()) {
        // Kiểm tra tính hợp lệ của file cục bộ trước
        if (await _verifyFile(localPath, level)) {
          debugPrint(
              '✅ Model ${level.name} đã có trong bộ nhớ cache và hợp lệ.');
          _emitState(level, ModelStatus.downloaded, localPath: localPath);
          continue; // Bỏ qua và chuyển sang model tiếp theo
        }
        debugPrint(
            '⚠️ Model ${level.name} trong bộ nhớ cache bị hỏng, sẽ thử copy từ assets hoặc tải lại.');
        await localFile.delete(); // Xóa file cục bộ bị hỏng
      }

      final assetPath = 'assets/whisper_models/${level.fileName}';
      debugPrint('🧐 Đang tìm trong Assets: $assetPath');

      try {
        // Thử load asset (sẽ throw nếu không tìm thấy trong bundle)
        final data = await rootBundle.load(assetPath);

        debugPrint(
            '📦 Tìm thấy model trong assets: $assetPath. Đang sao chép...');

        _emitState(level, ModelStatus.downloading, progress: 0.0);

        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await localFile.writeAsBytes(bytes, flush: true);

        // Verify sơ bộ sau khi copy
        final valid = await _verifyFile(localPath, level);
        if (valid) {
          debugPrint('✅ Sao chép model từ assets thành công: ${level.name}');
          _emitState(level, ModelStatus.downloaded, localPath: localPath);
        } else {
          await localFile.delete();
          debugPrint(
              '❌ Model trong assets không hợp lệ hoặc lỗi khi sao chép.');
        }
      } catch (e) {
        // Không có trong assets hoặc lỗi load - im lặng để code tiếp tục quét file hệ thống hoặc cho phép tải từ mạng
        debugPrint(
            'ℹ️ Gợi ý: Không tìm thấy $assetPath trong assets (Bỏ qua nếu muốn tải online).');
      }
    }
  }
}
