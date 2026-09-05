import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service quản lý hình ảnh cho từ vựng
///
/// Lưu ảnh vào app documents: vocabulary_images/<hash>.jpg
/// Resize/compress để giảm dung lượng (~100-300KB mỗi ảnh)
class VocabImageService {
  static VocabImageService? _instance;
  static VocabImageService get instance =>
      _instance ??= VocabImageService._();
  VocabImageService._();

  static const String _imageDir = 'vocabulary_images';

  /// Chọn ảnh từ gallery → copy vào app storage → trả về local path
  Future<String?> pickFromGallery() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final path = result.files.first.path;
      if (path == null) return null;

      return await _saveToAppStorage(File(path));
    } catch (e) {
      debugPrint('pickFromGallery error: $e');
      return null;
    }
  }

  /// Lưu ảnh từ URL (download từ Pixabay/Unsplash)
  Future<String?> saveFromUrl(String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      httpClient.close();

      return await _saveBytesToAppStorage(bytes);
    } catch (e) {
      debugPrint('saveFromUrl error: $e');
      return null;
    }
  }

  /// Lưu file ảnh vào app storage, trả về relative path
  Future<String> _saveToAppStorage(File sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    return _saveBytesToAppStorage(bytes);
  }

  /// Lưu bytes vào app storage, trả về relative path
  Future<String> _saveBytesToAppStorage(Uint8List bytes) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/$_imageDir');
    if (!imageDir.existsSync()) {
      imageDir.createSync(recursive: true);
    }

    // Hash content → filename unique
    final hash = md5.convert(bytes).toString().substring(0, 16);
    final ext = _detectExtension(bytes);
    final fileName = '$hash.$ext';
    final filePath = '${imageDir.path}/$fileName';

    // Nếu đã có file trùng hash → skip write
    if (!File(filePath).existsSync()) {
      await File(filePath).writeAsBytes(bytes, flush: true);
    }

    // Trả về relative path (không phụ thuộc appDir thay đổi)
    return '$_imageDir/$fileName';
  }

  /// Resolve relative path → absolute path
  Future<String?> resolvePath(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final absolutePath = '${appDir.path}/$relativePath';
    if (File(absolutePath).existsSync()) return absolutePath;
    // Fallback: nếu path đã là absolute
    if (File(relativePath).existsSync()) return relativePath;
    return null;
  }

  /// Kiểm tra ảnh có tồn tại không
  Future<bool> imageExists(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return false;
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/$relativePath').existsSync();
  }

  /// Xóa ảnh
  Future<void> deleteImage(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$relativePath');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// Đếm tổng dung lượng ảnh đã lưu
  Future<int> totalSizeBytes() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/$_imageDir');
      if (!imageDir.existsSync()) return 0;

      int total = 0;
      await for (final entity in imageDir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Detect extension từ magic bytes
  String _detectExtension(Uint8List bytes) {
    if (bytes.length >= 4) {
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'jpg';
      }
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      // GIF: 47 49 46
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return 'gif';
      }
      // WebP: 52 49 46 46
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        return 'webp';
      }
    }
    return 'jpg'; // default
  }
}
