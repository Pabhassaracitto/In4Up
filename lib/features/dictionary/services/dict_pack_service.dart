// lib/features/dictionary/services/dict_pack_service.dart
//
// DICT-PACK-001 — tải & cài "bộ từ điển" đóng gói sẵn (ZIP: .mdx + .mdd +
// .css) hoặc file .mdx/.mdd lẻ, rồi đưa vào `DictionaryService` như một lần
// import bình thường (cùng mã index/ghép bundle ⇒ không có nhánh xử lý thứ 2).
//
// Nguyên tắc:
// - CHỈ tải khi người dùng bấm (không auto-download lúc mở app).
// - Ghi ra file .part rồi đổi tên khi xong (mạng đứt không để lại file hỏng).
// - Giải nén có kiểm tra đường dẫn: entry `../evil.mdx` bị bỏ (zip-slip).
// - `sha256` trong danh mục (nếu có) được kiểm tra trước khi cài.
// - Danh mục tải qua mạng; mất mạng ⇒ rơi về danh mục đóng gói trong app
//   (`assets/dictionary/packs.json`) để màn hình không trắng.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dict_info.dart';
import '../models/dict_pack.dart';
import 'dictionary_service.dart';

/// Kết quả một lần cài bộ từ điển.
class DictPackInstallResult {
  const DictPackInstallResult({
    this.imported = const <DictInfo>[],
    this.error,
    this.missingParts = const <String>[],
  });

  final List<DictInfo> imported;
  final String? error;
  final List<String> missingParts;

  bool get isSuccess => imported.isNotEmpty;
}

/// Tải/cài bộ từ điển + đọc danh mục.
class DictPackService {
  DictPackService._();

  static final DictPackService _instance = DictPackService._();
  factory DictPackService() => _instance;

  /// Danh mục mặc định (owner có thể thay bằng URL HuggingFace/GitHub Pages).
  ///
  /// Đây là file JSON CÙNG repo (`assets/dictionary/packs.json` được đẩy lên
  /// `main` thì URL này luôn có bản mới nhất). Người dùng vẫn đổi được trong
  /// màn "Tải bộ từ điển" (ô "Nguồn danh mục").
  static const String defaultCatalogUrl =
      'https://raw.githubusercontent.com/Pabhassaracitto/In4Up/main/'
      'assets/dictionary/packs.json';

  /// Tên asset danh mục đóng gói kèm app (dự phòng khi offline).
  static const String bundledCatalogAsset = 'assets/dictionary/packs.json';

  static const String _prefsCatalogUrlKey = 'dict_pack_catalog_url';

  /// Override cho test: thay vì gọi mạng, trả JSON thẳng.
  static Future<String> Function(String url)? fetchOverride;

  /// Đọc URL danh mục người dùng đã lưu ('' ⇒ dùng mặc định).
  Future<String> catalogUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsCatalogUrlKey)?.trim() ?? '';
      return saved.isEmpty ? defaultCatalogUrl : saved;
    } catch (_) {
      return defaultCatalogUrl;
    }
  }

  Future<void> saveCatalogUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCatalogUrlKey, url.trim());
    } catch (_) {
      // Không lưu được cũng không chặn tải.
    }
  }

  /// Tải danh mục; thất bại ⇒ dùng bản đóng gói trong app.
  Future<DictPackCatalog> loadCatalog({String? url}) async {
    final target = (url ?? await catalogUrl()).trim();
    final remote = await _fetchText(target);
    if (remote != null) {
      final catalog =
          DictPackCatalog.fromJsonString(remote, sourceUrl: target);
      if (!catalog.isEmpty) return catalog;
    }
    final bundled = await _readBundledCatalog();
    if (bundled != null) {
      final catalog = DictPackCatalog.fromJsonString(bundled);
      if (!catalog.isEmpty) return catalog;
    }
    return DictPackCatalog.empty;
  }

  Future<String?> _fetchText(String url) async {
    if (url.isEmpty) return null;
    final override = fetchOverride;
    if (override != null) {
      try {
        return await override(url);
      } catch (_) {
        return null;
      }
    }
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<String?> _readBundledCatalog() async {
    try {
      return await rootBundle.loadString(bundledCatalogAsset);
    } catch (_) {
      return null;
    }
  }

  /// Tải + cài [pack]. [onProgress] nhận (0..1, thông điệp).
  Future<DictPackInstallResult> install(
    DictPack pack, {
    void Function(double progress, String message)? onProgress,
  }) async {
    if (pack.downloadUrl.trim().isEmpty) {
      return const DictPackInstallResult(
        error: 'Bộ từ điển này chưa có link tải.',
      );
    }
    final uri = Uri.tryParse(pack.downloadUrl);
    if (uri == null || !uri.hasScheme) {
      return const DictPackInstallResult(error: 'Link tải không hợp lệ.');
    }

    onProgress?.call(0.02, 'Đang kết nối…');
    final staging = await _stagingDir(pack.id);
    final archivePath = p.join(staging.path, _archiveName(uri));
    try {
      final bytes = await _download(
        uri,
        archivePath,
        onProgress: (received, total) {
          if (total == null || total <= 0) {
            onProgress?.call(0.05, 'Đang tải… (${_mb(received)} MB)');
            return;
          }
          final fraction = (received / total).clamp(0.0, 1.0).toDouble();
          onProgress?.call(
            0.05 + fraction * 0.6,
            'Đang tải… ${_mb(received)}/${_mb(total)} MB',
          );
        },
      );
      if (bytes <= 0) {
        return const DictPackInstallResult(error: 'File tải về rỗng.');
      }

      final expected = (pack.sha256 ?? '').trim().toLowerCase();
      if (expected.isNotEmpty) {
        onProgress?.call(0.68, 'Đang kiểm tra file…');
        final actual = await _sha256OfFile(archivePath);
        if (actual != expected) {
          return const DictPackInstallResult(
            error: 'File tải về không khớp mã kiểm tra (sha256). '
                'Có thể bản tải đã đổi hoặc bị lỗi — thử lại sau.',
          );
        }
      }

      onProgress?.call(0.7, 'Đang giải nén…');
      final root = await _extract(archivePath, staging);
      if (root == null) {
        return const DictPackInstallResult(
          error: 'Không giải nén được file tải về (không phải ZIP/MDX hợp lệ).',
        );
      }

      onProgress?.call(0.76, 'Đang lập chỉ mục từ điển…');
      final files = await _listDictionaryFiles(root);
      if (files.isEmpty) {
        return const DictPackInstallResult(
          error: 'Bộ từ điển này không có file .mdx/.mdd nào.',
        );
      }

      // Cài vào BỘ NHỚ APP (ổn định lâu dài) — người dùng bấm "tải" là muốn có
      // bản dùng được, không phải liên kết tới thư mục tạm sẽ bị xoá.
      final outcome = await DictionaryService.instance.importDictionaryBundle(
        absoluteFilePaths: files,
        rootPath: root,
        mode: DictStorageMode.imported,
        onProgress: (progress, message) =>
            onProgress?.call(0.8 + progress * 0.2, message),
      );
      onProgress?.call(1.0, outcome.isSuccess ? 'Đã cài xong' : 'Cài thất bại');
      return DictPackInstallResult(
        imported: outcome.imported,
        error: outcome.error,
        missingParts: outcome.missingParts,
      );
    } catch (error) {
      return DictPackInstallResult(error: error.toString());
    } finally {
      // Luôn dọn bản tạm: bản đã cài nằm trong thư mục của app.
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Cài từ một URL trực tiếp (ZIP hoặc .mdx) — không cần danh mục.
  Future<DictPackInstallResult> installFromUrl(
    String url, {
    void Function(double progress, String message)? onProgress,
  }) {
    final pack = DictPack(
      id: 'direct_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Từ điển tải trực tiếp',
      downloadUrl: url.trim(),
    );
    return install(pack, onProgress: onProgress);
  }

  // ── Tải xuống ───────────────────────────────────────────────────────────

  Future<int> _download(
    Uri uri,
    String targetPath, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final client = http.Client();
    final temporaryPath = '$targetPath.part';
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Tải thất bại (HTTP ${response.statusCode})',
          uri: uri,
        );
      }
      final sink = File(temporaryPath).openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
      await sink.close();
      final target = File(targetPath);
      if (await target.exists()) await target.delete();
      await File(temporaryPath).rename(targetPath);
      return received;
    } finally {
      client.close();
      try {
        final partial = File(temporaryPath);
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
    }
  }

  Future<String> _sha256OfFile(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  // ── Giải nén ────────────────────────────────────────────────────────────

  /// Giải nén vào [staging]; trả thư mục gốc chứa file từ điển.
  ///
  /// File không phải ZIP (người dùng dán link .mdx trực tiếp) được giữ nguyên
  /// và trả về thư mục staging. ZIP: ghi từng file, bỏ entry có đường dẫn
  /// thoát khỏi staging (zip-slip).
  Future<String?> _extract(String archivePath, Directory staging) async {
    if (!await _looksLikeZip(archivePath)) {
      return staging.path;
    }
    final targetRoot = Directory(p.join(staging.path, 'unpacked'));
    await targetRoot.create(recursive: true);
    final input = InputFileStream(archivePath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final safeName = _safeEntryName(entry.name);
        if (safeName == null) continue;
        final outputPath = p.join(targetRoot.path, safeName);
        await Directory(p.dirname(outputPath)).create(recursive: true);
        final output = OutputFileStream(outputPath);
        entry.writeContent(output);
        output.closeSync();
      }
    } catch (_) {
      return null;
    } finally {
      input.closeSync();
    }
    return targetRoot.path;
  }

  static Future<bool> _looksLikeZip(String path) async {
    try {
      final raf = await File(path).open();
      final header = await raf.read(4);
      await raf.close();
      return header.length >= 4 &&
          header[0] == 0x50 &&
          header[1] == 0x4b &&
          header[2] == 0x03 &&
          header[3] == 0x04;
    } catch (_) {
      return false;
    }
  }

  /// `../x.mdx` / đường dẫn tuyệt đối ⇒ null (bỏ).
  static String? _safeEntryName(String name) {
    final normalized = name.replaceAll('\\', '/');
    if (normalized.startsWith('/')) return null;
    final parts = <String>[];
    for (final segment in normalized.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') return null;
      parts.add(segment);
    }
    if (parts.isEmpty) return null;
    return parts.join('/');
  }

  static const Set<String> _dictExtensions = <String>{
    'mdx',
    'mdd',
    'css',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'svg',
    'wav',
    'mp3',
    'ogg',
    'm4a',
    'ttf',
    'otf',
    'woff',
    'woff2',
  };

  Future<List<String>> _listDictionaryFiles(String root) async {
    final dir = Directory(root);
    if (!await dir.exists()) return const <String>[];
    final files = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path).toLowerCase();
      final dot = name.lastIndexOf('.');
      if (dot < 0) continue;
      final ext = name.substring(dot + 1);
      if (_dictExtensions.contains(ext)) files.add(p.normalize(entity.path));
    }
    files.sort();
    return files;
  }

  Future<Directory> _stagingDir(String id) async {
    final temp = await getTemporaryDirectory();
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final dir = Directory(
      p.join(
        temp.path,
        'in4up_dict_pack_${safeId}_'
        '${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }

  static String _archiveName(Uri uri) {
    final base = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');
    if (safe.isEmpty) return 'download.zip';
    // Giữ đuôi gốc: link .mdx trực tiếp phải lưu đúng .mdx thì mới được nhận
    // là file từ điển; chỉ thêm .zip khi link không có đuôi.
    return safe.contains('.') ? safe : '$safe.zip';
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
