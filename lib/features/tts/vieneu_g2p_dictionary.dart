// lib/features/tts/vieneu_g2p_dictionary.dart
//
// Lane L6 / ADR-0028 (1.29.0) — đưa **từ điển phát âm SEA-G2P** vào app.
//
// Vì sao cần: engine native VieNeu-TTS đã nằm trong bản cài (module Gradle
// `:vieneu`), nhưng model **không nhận chữ thô** — audio.cpp gọi SEA-G2P để
// chuyển câu tiếng Việt thành phoneme, và SEA-G2P cần `sea_g2p.bin` (≈60 MiB).
// Trước đây người dùng phải tự chép file này bằng trình quản lý tệp; thiếu nó
// thì mọi lần đọc đều lỗi "missing sea_g2p.bin" dù APK đã có engine.
//
// Nguyên tắc (theo khuôn `FfmpegRuntimeInstaller` đã có trong app):
//   * Tải/ghi ra `sea_g2p.bin.part` rồi `rename` ⇒ mạng đứt không để lại file
//     hỏng mà engine lại tưởng "đã có từ điển".
//   * Bản tải từ GitHub **bắt buộc** khớp sha256 của tag v0.10.0 — native lib
//     trong APK cũng là v0.10.0, lệch bản là lỗi khó hiểu về sau.
//   * File do người dùng tự chọn: không có digest tin cậy ⇒ chỉ kiểm tên +
//     kích thước tối thiểu (40 MiB) rồi vẫn ghi atomically.
//   * Sau khi cài: `VieneuTtsEngine.invalidate()` để lần đọc sau nạp lại model
//     (worker cũ có thể đang giữ trạng thái "thiếu từ điển").

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

import './engines/vieneu_tts_engine.dart';

/// Lý do thất bại — UI dịch sang câu tiếng Việt (giữ service không phụ thuộc
/// `BuildContext`).
enum VieneuG2pFailure {
  /// Mạng/HTTP lỗi, hoặc người dùng huỷ.
  network,

  /// sha256 không khớp asset của tag đang ghim.
  checksum,

  /// File người dùng chọn không phải `sea_g2p.bin` / quá nhỏ.
  notDictionary,

  /// Không đọc/ghi được thư mục dữ liệu.
  storage,
}

class VieneuG2pException implements Exception {
  const VieneuG2pException(this.reason, [this.detail]);

  final VieneuG2pFailure reason;
  final String? detail;

  @override
  String toString() =>
      'VieneuG2pException(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Trạng thái từ điển trên đĩa.
class VieneuG2pStatus {
  const VieneuG2pStatus({
    required this.installed,
    this.path,
    this.bytes = 0,
  });

  /// File tồn tại VÀ đủ lớn để engine dùng được.
  final bool installed;
  final String? path;
  final int bytes;

  String get sizeLabel => formatVieneuDictionarySize(bytes);
}

class VieneuG2pDictionaryService {
  VieneuG2pDictionaryService({http.Client? client})
      : _client = client ?? http.Client();

  static final VieneuG2pDictionaryService instance =
      VieneuG2pDictionaryService();

  final http.Client _client;

  Future<Directory> _modelDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'vieneu_tts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Từ điển đã có chưa (đọc đĩa, không nạp model).
  Future<VieneuG2pStatus> status() async {
    try {
      final dir = await _modelDir();
      final file = File(vieneuG2pDictionaryPath(dir.path));
      if (!await file.exists()) {
        return const VieneuG2pStatus(installed: false);
      }
      final bytes = await file.length();
      return VieneuG2pStatus(
        installed: isPlausibleVieneuG2pDictionarySize(bytes),
        path: file.path,
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('[VieNeuG2P] đọc trạng thái lỗi: $e');
      return const VieneuG2pStatus(installed: false);
    }
  }

  /// Tải từ GitHub release (tag đang ghim) + kiểm sha256 + cài atomically.
  Future<VieneuG2pStatus> download({
    void Function(double fraction)? onProgress,
    Future<void>? cancelToken,
  }) async {
    final Directory dir;
    try {
      dir = await _modelDir();
    } catch (e) {
      throw VieneuG2pException(VieneuG2pFailure.storage, '$e');
    }

    final target = vieneuG2pDictionaryPath(dir.path);
    final partial = '$target.part';
    var cancelled = false;
    cancelToken?.then((_) => cancelled = true);

    try {
      final request = http.Request('GET', Uri.parse(vieneuG2pDictDownloadUrl));
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VieneuG2pException(
          VieneuG2pFailure.network,
          'HTTP ${response.statusCode}',
        );
      }

      final total = response.contentLength ?? vieneuG2pDictBytes;
      final sink = File(partial).openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          if (cancelled) {
            throw const VieneuG2pException(VieneuG2pFailure.network, 'cancelled');
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total <= 0 ? 0 : (received / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }

      // Kiểm digest TRƯỚC khi thay file đang dùng.
      final digest = await sha256.bind(File(partial).openRead()).first;
      if (digest.toString() != vieneuG2pDictSha256) {
        await _deleteQuietly(partial);
        throw VieneuG2pException(
          VieneuG2pFailure.checksum,
          digest.toString(),
        );
      }

      await _deleteQuietly(target);
      await File(partial).rename(target);
      await _afterInstall();
      return status();
    } catch (e) {
      await _deleteQuietly(partial);
      if (e is VieneuG2pException) rethrow;
      throw VieneuG2pException(VieneuG2pFailure.network, '$e');
    }
  }

  /// Cài từ file người dùng tự chọn (trình chọn tệp / thẻ nhớ / Drive).
  Future<VieneuG2pStatus> importFromFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const VieneuG2pException(VieneuG2pFailure.storage, 'not-found');
    }
    final bytes = await source.length();
    if (!isVieneuG2pDictionaryFile(sourcePath) ||
        !isPlausibleVieneuG2pDictionarySize(bytes)) {
      throw VieneuG2pException(
        VieneuG2pFailure.notDictionary,
        '${p.basename(sourcePath)} · $bytes byte',
      );
    }

    final Directory dir;
    try {
      dir = await _modelDir();
    } catch (e) {
      throw VieneuG2pException(VieneuG2pFailure.storage, '$e');
    }

    final target = vieneuG2pDictionaryPath(dir.path);
    final partial = '$target.part';
    try {
      await _deleteQuietly(partial);
      await source.copy(partial);
      await _deleteQuietly(target);
      await File(partial).rename(target);
      await _afterInstall();
      return status();
    } catch (e) {
      await _deleteQuietly(partial);
      if (e is VieneuG2pException) rethrow;
      throw VieneuG2pException(VieneuG2pFailure.storage, '$e');
    }
  }

  /// Xoá từ điển (dùng khi file hỏng / người dùng muốn tải lại).
  Future<void> remove() async {
    try {
      final dir = await _modelDir();
      await _deleteQuietly(vieneuG2pDictionaryPath(dir.path));
      await VieneuTtsEngine.instance.invalidate();
    } catch (e) {
      debugPrint('[VieNeuG2P] xoá từ điển lỗi: $e');
    }
  }

  Future<void> _afterInstall() async {
    // Worker cũ có thể đã ghi nhớ "thiếu sea_g2p.bin"; dọn để lần đọc sau nạp
    // lại model với từ điển mới.
    await VieneuTtsEngine.instance.invalidate();
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[VieNeuG2P] không xoá được $path: $e');
    }
  }
}
