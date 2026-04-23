import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Kết quả load model
class ModelLoadResult {
  final bool success;
  final String? modelPath;
  final ModelSource source;
  final String? errorMessage;

  const ModelLoadResult({
    required this.success,
    this.modelPath,
    required this.source,
    this.errorMessage,
  });
}

enum ModelSource {
  bundledAsset,  // Tầng A: assets/models/
  userImported,  // Tầng B: user chọn file
  downloaded,    // Tầng C: download từ URL
  none,          // Không tìm thấy
}

/// Config model mặc định
class AiModelConfig {
  /// Tên file .gguf trong assets/models/ (Tầng A)
  static const String defaultModelFileName = 'gemma-2b-it-q4_k_m.gguf';

  /// Key lưu path model đã import (Tầng B)
  static const String _prefKeyModelPath = 'vipsound_ai_model_path';
  static const String _prefKeyModelSource = 'vipsound_ai_model_source';

  /// URL download backup (Tầng C) - thay bằng server của bạn
  /// Không dùng Firebase Storage
  static const String downloadUrl =
      'https://your-server.com/models/gemma-2b-it-q4_k_m.gguf';

  /// MD5 hash để verify sau download (optional)
  static const String? expectedMd5 = null;
}

/// Quản lý 3 tầng tìm model file
class AiModelLoader {
  static AiModelLoader? _instance;
  factory AiModelLoader() => _instance ??= AiModelLoader._();
  AiModelLoader._();

  String? _cachedModelPath;
  ModelSource _currentSource = ModelSource.none;

  String? get currentModelPath => _cachedModelPath;
  ModelSource get currentSource => _currentSource;
  bool get hasModel => _cachedModelPath != null;

  // ── Entry Point ──────────────────────────────────────────

  /// Tìm model theo thứ tự ưu tiên A → B → C
  /// Gọi khi app start, không block UI
  Future<ModelLoadResult> findOrLoadModel({
    /// Callback để UI hiển thị progress khi download
    void Function(double progress)? onDownloadProgress,
    /// Có cho phép download không (cần WiFi)
    bool allowDownload = false,
  }) async {
    // ── Tầng A: Check assets/models/ ──
    final bundledResult = await _checkBundledAsset();
    if (bundledResult.success) {
      _cacheResult(bundledResult);
      debugPrint('[AiModelLoader] ✅ Tầng A: Found bundled model');
      return bundledResult;
    }

    // ── Tầng B: Check previously imported path ──
    final importedResult = await _checkPreviouslyImported();
    if (importedResult.success) {
      _cacheResult(importedResult);
      debugPrint('[AiModelLoader] ✅ Tầng B: Found previously imported model');
      return importedResult;
    }

    // ── Tầng C: Download (chỉ khi được phép) ──
    if (allowDownload) {
      final downloadResult = await _downloadModel(
        onProgress: onDownloadProgress,
      );
      if (downloadResult.success) {
        _cacheResult(downloadResult);
        debugPrint('[AiModelLoader] ✅ Tầng C: Downloaded model');
        return downloadResult;
      }
    }

    debugPrint('[AiModelLoader] ❌ No model found');
    return const ModelLoadResult(
      success: false,
      source: ModelSource.none,
      errorMessage: 'Không tìm thấy AI model. Vui lòng import file .gguf.',
    );
  }

  // ── Tầng A: Bundled Asset ────────────────────────────────

  Future<ModelLoadResult> _checkBundledAsset() async {
    try {
      // Kiểm tra file tồn tại trong assets
      // Flutter không cho phép đọc binary lớn từ assets trực tiếp vào RAM
      // → Copy ra Documents directory lần đầu
      final docsDir = await getApplicationDocumentsDirectory();
      final cachedPath =
          '${docsDir.path}/ai_models/${AiModelConfig.defaultModelFileName}';
      final cachedFile = File(cachedPath);

      if (await cachedFile.exists()) {
        // Đã copy trước đó, dùng luôn
        return ModelLoadResult(
          success: true,
          modelPath: cachedPath,
          source: ModelSource.bundledAsset,
        );
      }

      // Thử load từ assets
      try {
        final data = await rootBundle
            .load('assets/models/${AiModelConfig.defaultModelFileName}');

        // Copy ra Documents để llama.cpp đọc được
        await cachedFile.parent.create(recursive: true);
        await cachedFile.writeAsBytes(data.buffer.asUint8List());

        return ModelLoadResult(
          success: true,
          modelPath: cachedPath,
          source: ModelSource.bundledAsset,
        );
      } on FlutterError {
        // File không có trong assets → bình thường, thử Tầng B
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
        );
      }
    } catch (e) {
      return ModelLoadResult(
        success: false,
        source: ModelSource.none,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Tầng B: User Import ──────────────────────────────────

  Future<ModelLoadResult> _checkPreviouslyImported() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(AiModelConfig._prefKeyModelPath);

      if (savedPath == null) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
        );
      }

      // Verify file vẫn còn tồn tại
      final file = File(savedPath);
      if (!await file.exists()) {
        // File đã bị xóa, clear cache
        await prefs.remove(AiModelConfig._prefKeyModelPath);
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Model file đã bị xóa khỏi thiết bị',
        );
      }

      return ModelLoadResult(
        success: true,
        modelPath: savedPath,
        source: ModelSource.userImported,
      );
    } catch (e) {
      return const ModelLoadResult(
        success: false,
        source: ModelSource.none,
      );
    }
  }

  /// Cho user chọn file .gguf thủ công
  /// Gọi khi user nhấn nút "Import Model"
  Future<ModelLoadResult> importModelFromUser() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Chọn file AI Model (.gguf)',
      );

      if (result == null || result.files.isEmpty) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Người dùng hủy chọn file',
        );
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Không thể lấy đường dẫn file',
        );
      }

      // Validate: phải là .gguf
      if (!filePath.toLowerCase().endsWith('.gguf')) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'File phải có đuôi .gguf',
        );
      }

      // Copy vào Documents để an toàn (tránh permission issues trên iOS)
      final docsDir = await getApplicationDocumentsDirectory();
      final destPath = '${docsDir.path}/ai_models/${file.name}';
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await File(filePath).copy(destPath);

      // Lưu path để dùng lần sau
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AiModelConfig._prefKeyModelPath, destPath);

      _cacheResult(ModelLoadResult(
        success: true,
        modelPath: destPath,
        source: ModelSource.userImported,
      ));

      return ModelLoadResult(
        success: true,
        modelPath: destPath,
        source: ModelSource.userImported,
      );
    } catch (e) {
      return ModelLoadResult(
        success: false,
        source: ModelSource.none,
        errorMessage: 'Lỗi import: $e',
      );
    }
  }

  // ── Tầng C: Download ─────────────────────────────────────

  Future<ModelLoadResult> _downloadModel({
    void Function(double)? onProgress,
  }) async {
    try {
      // Kiểm tra network
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Không có kết nối mạng',
        );
      }

      // Chỉ download trên WiFi (model lớn ~1.5GB)
      if (!connectivity.contains(ConnectivityResult.wifi)) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Cần WiFi để tải model (~1.5GB)',
        );
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final destPath =
          '${docsDir.path}/ai_models/${AiModelConfig.defaultModelFileName}';
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);

      // Download với progress
      final request = http.Request('GET', Uri.parse(AiModelConfig.downloadUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final sink = destFile.openWrite();
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(downloadedBytes / totalBytes);
        }
      });
      await sink.close();

      // Verify MD5 nếu có
      if (AiModelConfig.expectedMd5 != null) {
        final isValid = await _verifyMd5(destPath, AiModelConfig.expectedMd5!);
        if (!isValid) {
          await destFile.delete();
          return const ModelLoadResult(
            success: false,
            source: ModelSource.none,
            errorMessage: 'File download bị lỗi (MD5 không khớp)',
          );
        }
      }

      // Lưu path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AiModelConfig._prefKeyModelPath, destPath);

      return ModelLoadResult(
        success: true,
        modelPath: destPath,
        source: ModelSource.downloaded,
      );
    } catch (e) {
      return ModelLoadResult(
        success: false,
        source: ModelSource.none,
        errorMessage: 'Download thất bại: $e',
      );
    }
  }

  Future<bool> _verifyMd5(String filePath, String expectedMd5) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString() == expectedMd5.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  void _cacheResult(ModelLoadResult result) {
    _cachedModelPath = result.modelPath;
    _currentSource = result.source;
  }

  /// Xóa model đã lưu (để user chọn lại)
  Future<void> clearCachedModel() async {
    _cachedModelPath = null;
    _currentSource = ModelSource.none;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AiModelConfig._prefKeyModelPath);
  }

  /// Thông tin model hiện tại để hiển thị UI
  String get modelSourceLabel {
    switch (_currentSource) {
      case ModelSource.bundledAsset:
        return 'Model tích hợp sẵn';
      case ModelSource.userImported:
        return 'Model đã import';
      case ModelSource.downloaded:
        return 'Model đã tải về';
      case ModelSource.none:
        return 'Chưa có model';
    }
  }
}
