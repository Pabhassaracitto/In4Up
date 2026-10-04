import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'vocab_image_web_service.dart';
import 'vocab_media_type.dart';

/// Service quản lý hình ảnh cho từ vựng
class VocabImageService {
  static VocabImageService? _instance;
  static VocabImageService get instance =>
      _instance ??= VocabImageService._();
  VocabImageService._();

  static const String _imageDir = 'vocabulary_images';

  /// LOTTIE-001 — trần kích thước file animation (.json/.lottie) được phép
  /// lưu. Lottie minh họa từ vựng chuẩn chỉ 20-100KB; file >2MB thường là
  /// animation phức tạp → decode/render nặng RAM, không hợp flashcard.
  static const int kMaxLottieBytes = 2 * 1024 * 1024;

  /// Chọn ảnh từ gallery → copy vào app storage → trả về local path
  Future<String?> pickFromGallery() async {
    try {
      final result = await fp.FilePicker.pickFiles(
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

  /// Đọc một ảnh từ gallery nhưng chưa lưu, để editor có thể cho người dùng
  /// xem ảnh gốc và ảnh đã tách nền trước khi bấm Lưu.
  Future<Uint8List?> pickGalleryBytes() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
      final path = file.path;
      return path == null ? null : Uint8List.fromList(await File(path).readAsBytes());
    } catch (e) {
      debugPrint('pickGalleryBytes error: $e');
      return null;
    }
  }

  /// Chụp một ảnh bằng camera nhưng chưa lưu.
  Future<Uint8List?> pickCameraBytes() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      return picked == null ? null : await picked.readAsBytes();
    } catch (e) {
      debugPrint('pickCameraBytes error: $e');
      return null;
    }
  }

  /// Lưu bytes ảnh (từ web / camera / chia sẻ) vào app storage.
  /// Trả về relative path để nhét vào WordEntry.imageUrl, hoặc null nếu lỗi.
  Future<String?> saveFromBytes(Uint8List bytes) async {
    try {
      if (bytes.isEmpty) return null;
      return _saveBytesToAppStorage(bytes);
    } catch (e) {
      debugPrint('saveFromBytes error: $e');
      return null;
    }
  }

  /// Tải ảnh từ URL (kết quả tìm kiếm trên mạng) → lưu app storage.
  ///
  /// Không lưu thẳng URL vào [imageUrl]: ảnh ngoài mạng chết link là mất
  /// hình, mà tính năng này cần ảnh sống được offline khi ôn tập.
  ///
  /// LOTTIE-001 — URL trỏ tới Lottie (đuôi .json/.lottie) cũng được nhận:
  /// guard kích thước 2MB cho animation (bảo vệ RAM khi render — ảnh tĩnh
  /// vẫn theo guard 8MB mặc định của downloader).
  Future<String?> saveFromUrl(
    String url, {
    VocabImageWebService? client,
    int? maxLottieBytes,
  }) async {
    final service = client ?? VocabImageWebService();
    try {
      final lottie = isLottieMediaUrl(url);
      final bytes = await service.download(
        url,
        allowJson: lottie,
        maxBytes: lottie
            ? (maxLottieBytes ?? kMaxLottieBytes)
            : 8 * 1024 * 1024,
      );
      return await saveFromBytes(bytes);
    } catch (e) {
      debugPrint('saveFromUrl error ($url): $e');
      return null;
    } finally {
      if (client == null) service.dispose();
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

    // Trả về relative path
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
    } catch (e) {
      debugPrint('deleteImage error: $e');
    }
  }

  /// Detect extension từ magic bytes
  String _detectExtension(Uint8List bytes) {
    if (bytes.isNotEmpty) {
      // Lottie JSON: bắt đầu bằng '{' (0x7B) — LOTTIE-001.
      if (bytes[0] == 0x7B) {
        return 'json';
      }
    }
    if (bytes.length >= 4) {
      // dotLottie / ZIP: 50 4B 03 04 ("PK\x03\x04") — LOTTIE-001.
      if (bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04) {
        return 'lottie';
      }
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
