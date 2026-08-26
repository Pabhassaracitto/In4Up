import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bundledAsset, // Tầng A: assets/models/
  userImported, // Tầng B: user chọn file
  downloaded, // Tầng C: download từ URL
  none, // Không tìm thấy
}

/// Config model mặc định
class AiModelConfig {
  /// Tên file .gguf trong assets/models/ (Tầng A)
  static const String defaultModelFileName = 'gemma-2b-it-q4_k_m.gguf';

  /// Key lưu path model đã import (Tầng B)
  static const String _prefKeyModelPath = 'in4up_ai_model_path';
  static const String _prefKeyModelSource = 'in4up_ai_model_source';

  /// URL download backup (Tầng C) - thay bằng server của bạn
  /// Không dùng Firebase Storage
  static const String downloadUrl = defaultDownloadUrl;

  /// URL mẫu (HuggingFace) cho Gemma-2-2B-it Q4_K_M (~1.5GB) — dùng cho nút
  /// "Tải về" trong trung tâm model; người dùng sửa được trong dialog.
  static const String defaultDownloadUrl =
      'https://huggingface.co/cognitivecomputations/Gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf';

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
  String? _currentModelName;
  int? _currentModelSizeBytes;

  String? get currentModelPath => _cachedModelPath;
  ModelSource get currentSource => _currentSource;
  bool get hasModel => _cachedModelPath != null;

  /// Tên file model hiện tại (cho UI).
  String? get currentModelName => _currentModelName;

  /// Dung lượng model hiện tại bằng bytes (null nếu chưa biết).
  int? get currentModelSizeBytes => _currentModelSizeBytes;

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
      await _rememberFileSize();
      debugPrint('[AiModelLoader] ✅ Tầng A: Found bundled model');
      return bundledResult;
    }

    // ── Tầng B: Check previously imported path ──
    final importedResult = await _checkPreviouslyImported();
    if (importedResult.success) {
      _cacheResult(importedResult);
      await _rememberFileSize();
      debugPrint('[AiModelLoader] ✅ Tầng B: Found previously imported model');
      return importedResult;
    }

    // ── Tầng C: Download (chỉ khi được phép) ──
    if (allowDownload) {
      final downloadResult = await downloadModel(
        url: AiModelConfig.downloadUrl,
        onProgress: onDownloadProgress,
        expectedMd5: AiModelConfig.expectedMd5,
      );
      if (downloadResult.success) {
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

      // Verify file có header GGUF hợp lệ (tránh native engine chết khi load
      // file hỏng và tránh UI báo "model sẵn sàng" sai).
      final validationError = await _validateGguf(file);
      if (validationError != null) {
        await prefs.remove(AiModelConfig._prefKeyModelPath);
        return ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: validationError,
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
  /// [onCopyProgress]: 0.0–1.0 trong lúc copy file vào app directory.
  Future<ModelLoadResult> importModelFromUser(
      {void Function(double progress)? onCopyProgress}) async {
    try {
      final result = await FilePicker.pickFiles(
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

      // Validate: header GGUF hợp lệ trước khi copy (tránh file rác/giả mạo)
      final validationError = await _validateGguf(File(filePath));
      if (validationError != null) {
        return ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: validationError,
        );
      }

      // Copy vào Documents để an toàn (tránh permission issues trên iOS).
      // Copy theo chunk để UI báo tiến độ (file GGUF thường 1–2GB).
      final docsDir = await getApplicationDocumentsDirectory();
      final destPath = '${docsDir.path}/ai_models/${file.name}';
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await _copyFileWithProgress(
        src: File(filePath),
        dest: destFile,
        onProgress: onCopyProgress,
      );

      // Lưu path để dùng lần sau
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AiModelConfig._prefKeyModelPath, destPath);

      final modelResult = ModelLoadResult(
        success: true,
        modelPath: destPath,
        source: ModelSource.userImported,
      );
      _cacheResult(modelResult);
      await _rememberFileSize();

      return modelResult;
    } catch (e) {
      return ModelLoadResult(
        success: false,
        source: ModelSource.none,
        errorMessage: 'Lỗi import: $e',
      );
    }
  }

  // ── Tầng C: Download ─────────────────────────────────────

  /// Download model từ URL trực tiếp (HuggingFace/GitHub release/...).
  /// Dùng cho "Tải về" trong trung tâm model. Chỉ chạy trên WiFi (model lớn).
  /// [expectedMd5] optional — verify sau tải, fail thì xóa file.
  Future<ModelLoadResult> downloadModel({
    required String url,
    String? fileName,
    String? expectedMd5,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.isAbsolute || !url.trim().isNotEmpty) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'URL model không hợp lệ',
        );
      }

      // Kiểm tra network
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Không có kết nối mạng',
        );
      }

      // Chỉ download trên WiFi (model lớn ~1.5GB)
      if (!results.contains(ConnectivityResult.wifi)) {
        return const ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: 'Cần WiFi để tải model (~1.5GB)',
        );
      }

      final targetName = (fileName != null && fileName.isNotEmpty)
          ? fileName
          : (uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : AiModelConfig.defaultModelFileName);

      final docsDir = await getApplicationDocumentsDirectory();
      final destPath = '${docsDir.path}/ai_models/$targetName';
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);

      // Download với progress
      final request = http.Request('GET', uri);
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
      if (expectedMd5 != null && expectedMd5.isNotEmpty) {
        final isValid = await _verifyMd5(destPath, expectedMd5);
        if (!isValid) {
          await destFile.delete();
          return const ModelLoadResult(
            success: false,
            source: ModelSource.none,
            errorMessage: 'File download bị lỗi (MD5 không khớp)',
          );
        }
      }

      // Validate header GGUF trước khi dùng
      final validationError = await _validateGguf(destFile);
      if (validationError != null) {
        await destFile.delete();
        return ModelLoadResult(
          success: false,
          source: ModelSource.none,
          errorMessage: validationError,
        );
      }

      // Lưu path để dùng lần sau
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AiModelConfig._prefKeyModelPath, destPath);

      final result = ModelLoadResult(
        success: true,
        modelPath: destPath,
        source: ModelSource.downloaded,
      );
      _cacheResult(result);
      await _rememberFileSize();

      return result;
    } catch (e) {
      return ModelLoadResult(
        success: false,
        source: ModelSource.none,
        errorMessage: 'Download thất bại: $e',
      );
    }
  }

  /// Copy file theo chunk (8MB) kèm tiến độ — cho import model lớn.
  /// (Dart SDK mới: `File.openRead()` đã bị REMOVE — dùng `await src.open()`;
  /// `openWrite()` giữ nguyên nhưng thêm `await` cho an toàn — await trên
  /// giá trị non-Future là no-op hợp lệ.)
  Future<void> _copyFileWithProgress({
    required File src,
    required File dest,
    void Function(double progress)? onProgress,
  }) async {
    final total = await src.length();
    final rs = await src.open();
    try {
      final ws = await dest.openWrite();
      try {
        var copied = 0;
        final buffer = Uint8List(8 * 1024 * 1024);
        while (true) {
          final n = await rs.readInto(buffer, 0, buffer.length);
          if (n == 0) break;
          ws.add(buffer.sublist(0, n));
          copied += n;
          if (total > 0) onProgress?.call(copied / total);
        }
        onProgress?.call(1.0);
      } finally {
        await ws.close();
      }
    } finally {
      await rs.close();
    }
  }

  /// Kiểm tra magic header "GGUF" (4 byte đầu) của file model.
  /// Trả về thông báo lỗi nếu không hợp lệ, `null` nếu OK.
  Future<String?> _validateGguf(File file) async {
    try {
      final length = await file.length();
      if (length < 8) return 'File model quá nhỏ hoặc bị hỏng';
      final header = await file.openRead(0, 4).fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      final magic = String.fromCharCodes(header);
      if (magic != 'GGUF') return 'File không phải model GGUF hợp lệ';
      return null;
    } catch (e) {
      return 'Không thể đọc model: $e';
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
    _currentModelName = result.modelPath != null
        ? result.modelPath!.split(RegExp(r'[/\\]')).last
        : null;
    _currentModelSizeBytes = null;
  }

  /// Đo kích thước file model đã cache (gọi sau [_cacheResult]).
  Future<void> _rememberFileSize() async {
    final path = _cachedModelPath;
    if (path == null) return;
    try {
      _currentModelSizeBytes = await File(path).length();
    } catch (_) {
      _currentModelSizeBytes = null;
    }
  }

  /// Xóa model đã lưu (để user chọn lại)
  Future<void> clearCachedModel() async {
    _cachedModelPath = null;
    _currentSource = ModelSource.none;
    _currentModelName = null;
    _currentModelSizeBytes = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AiModelConfig._prefKeyModelPath);
  }

  /// Xóa file model khỏi thiết bị + clear cache (nút "Xóa" trong trung tâm model).
  Future<void> removeModel() async {
    final path = _cachedModelPath;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await clearCachedModel();
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
