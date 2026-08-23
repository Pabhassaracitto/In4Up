// packages/in4up_stt/lib/sherpa_model_manager.dart
//
// SherpaModelManager — quản lý model Silero VAD + Piper TTS (MODELS-001).
//
// Cùng pattern với SttModelManager (Whisper): singleton + BehaviorSubject
// + dio download (progress + cancel) + import (copy file, không move) +
// verify size. TẤT CẢ chỉ chạy khi user bấm — không auto-download
// (bài học "Connection closed" bootstrap — xem SttModelManager).
//
// Folder convention (Rule 1 — absolute path via path_provider):
//   Android:  /sdcard/Android/data/<pkg>/documents/...
//   Windows:  %LOCALAPPDATA%\<org>\<app>_documents/...
//
//   <documents>/sherpa_vad_models/silero_vad.onnx        (2-5MB, 1 file)
//   <documents>/sherpa_piper_models/
//     espeak-ng-data/                     ← phonemizer data, DÙNG CHUNG
//     <voice>.onnx + <voice>_tokens.txt [+ <voice>.onnx.json]
//     (hoặc bundle k2-fsa: <voice>.onnx + tokens.txt dùng chung)
//
// Nguồn download ổn định (verify 2026-08-23):
//   VAD:  https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx
//   Piper: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-<voice>.tar.bz2
//     (bundle gồm onnx + tokens + espeak-ng-data; 536 giọng, có vi_VN)

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'tts/sherpa_piper_tts_core.dart';

enum SherpaModelStatus { notInstalled, downloading, ready, error }

/// Trạng thái 1 model đơn lẻ (Silero VAD).
class SherpaModelInfo {
  final SherpaModelStatus status;
  final double downloadProgress;
  final String? errorMessage;
  final String? localPath;

  const SherpaModelInfo({
    this.status = SherpaModelStatus.notInstalled,
    this.downloadProgress = 0,
    this.errorMessage,
    this.localPath,
  });

  bool get isReady => status == SherpaModelStatus.ready;
  bool get isDownloading => status == SherpaModelStatus.downloading;

  SherpaModelInfo copyWith({
    SherpaModelStatus? status,
    double? downloadProgress,
    String? errorMessage,
    String? localPath,
    bool clearError = false,
  }) {
    return SherpaModelInfo(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      localPath: localPath ?? this.localPath,
    );
  }
}

/// Trạng thái Piper tổng thể (espeak + danh sách giọng).
class SherpaPiperInfo {
  final bool espeakInstalled;
  final List<PiperTtsVoice> voices;
  final SherpaModelStatus status; // download/import đang chạy
  final double downloadProgress;
  final String? errorMessage;

  const SherpaPiperInfo({
    this.espeakInstalled = false,
    this.voices = const [],
    this.status = SherpaModelStatus.notInstalled,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  bool get isDownloading => status == SherpaModelStatus.downloading;
  bool get isReady => voices.isNotEmpty && espeakInstalled;

  SherpaPiperInfo copyWith({
    bool? espeakInstalled,
    List<PiperTtsVoice>? voices,
    SherpaModelStatus? status,
    double? downloadProgress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SherpaPiperInfo(
      espeakInstalled: espeakInstalled ?? this.espeakInstalled,
      voices: voices ?? this.voices,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SherpaModelManager {
  static SherpaModelManager? _instance;
  factory SherpaModelManager() => _instance ??= SherpaModelManager._internal();
  SherpaModelManager._internal();

  static const String vadFolderName = 'sherpa_vad_models';
  static const String vadFileName = 'silero_vad.onnx';
  static const String vadDownloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'silero_vad.onnx';

  /// Voice Piper mặc định gợi ý tải (EN, ~75MB bundle).
  static const String defaultPiperVoice = 'en_US-libritts_r-medium';

  static String piperBundleUrl(String voice) =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'vits-piper-$voice.tar.bz2';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      headers: const {
        'User-Agent': 'Mozilla/5.0 (compatible; in4upApp/1.0)',
      },
    ),
  );

  final _vadState =
      BehaviorSubject<SherpaModelInfo>.seeded(const SherpaModelInfo());
  final _piperState =
      BehaviorSubject<SherpaPiperInfo>.seeded(const SherpaPiperInfo());

  CancelToken? _vadToken;
  CancelToken? _piperToken;
  bool _initialized = false;
  String? _documentsDir;

  Future<String> _documents() async {
    if (_documentsDir != null) return _documentsDir!;
    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationSupportDirectory();
    }
    _documentsDir = base.path;
    return base.path;
  }

  Future<String> _vadDir() async {
    final dir = Directory(p.join(await _documents(), vadFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Gọi 1 lần khi mở màn hình Quản lý Model.
  Future<void> initialize() async {
    if (!_initialized) {
      await _documents();
      _initialized = true;
    }
    await rescan();
  }

  // ── WATCH ──────────────────────────────────────────────────────────────

  Stream<SherpaModelInfo> watchVad() => _vadState.stream;
  SherpaModelInfo get vadInfo => _vadState.value;

  Stream<SherpaPiperInfo> watchPiper() => _piperState.stream;
  SherpaPiperInfo get piperInfo => _piperState.value;

  /// Quét lại đĩa (sau import/xoá).
  Future<void> rescan() async {
    try {
      // VAD
      final vadFile = File(p.join(await _vadDir(), vadFileName));
      final vadOk =
          vadFile.existsSync() && vadFile.lengthSync() > 1000000;
      _vadState.add(vadOk
          ? const SherpaModelInfo(
              status: SherpaModelStatus.ready, localPath: '')
          : const SherpaModelInfo(status: SherpaModelStatus.notInstalled));

      // Piper
      final voices = await SherpaPiperTtsCore.discoverVoices();
      final piperDir =
          Directory(p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
      final espeakOk = Directory(
              p.join(piperDir.path, SherpaPiperTtsCore.espeakDataFolder))
          .existsSync();
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: espeakOk,
        voices: voices,
        status: voices.isEmpty
            ? SherpaModelStatus.notInstalled
            : SherpaModelStatus.ready,
      ));
    } catch (e) {
      debugPrint('⚠️ SherpaModelManager.rescan error: $e');
    }
  }

  // ── SILERO VAD ─────────────────────────────────────────────────────────

  Future<bool> downloadVad({int maxRetries = 2}) async {
    if (vadInfo.isReady) return true;
    if (vadInfo.isDownloading) return false;

    final token = CancelToken();
    _vadToken = token;
    _vadState.add(const SherpaModelInfo(status: SherpaModelStatus.downloading));

    try {
      final dir = await _vadDir();
      final savePath = p.join(dir, vadFileName);
      final tmpPath = '$savePath.tmp';

      var attempt = 0;
      bool ok = false;
      while (attempt < maxRetries && !ok) {
        attempt++;
        if (token.isCancelled) break;
        try {
          debugPrint('📥 Download $vadFileName từ: $vadDownloadUrl');
          await _dio.download(
            vadDownloadUrl,
            tmpPath,
            cancelToken: token,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                _vadState.add(_vadState.value.copyWith(
                    downloadProgress: received / total));
              }
            },
          );
          final tmp = File(tmpPath);
          if (await tmp.exists() && tmp.lengthSync() > 1000000) {
            final finalFile = File(savePath);
            if (await finalFile.exists()) {
              await finalFile.delete().catchError((_) {});
            }
            await tmp.rename(savePath);
            ok = true;
          }
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) break;
          debugPrint('⚠️ Download VAD thất bại ($attempt/$maxRetries): $e');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        } catch (e) {
          debugPrint('⚠️ Download VAD error ($attempt/$maxRetries): $e');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }

      _vadToken = null;
      if (ok) {
        await rescan();
        debugPrint('✅ Download VAD xong: $savePath');
        return true;
      }
      _vadState.add(
        const SherpaModelInfo(
          status: SherpaModelStatus.notInstalled,
          errorMessage: 'Không tải được $vadFileName (mạng?) — thử lại hoặc '
              'Import file silero_vad.onnx đã có sẵn.',
        ),
      );
      return false;
    } catch (e) {
      _vadToken = null;
      _vadState.add(SherpaModelInfo(
        status: SherpaModelStatus.error,
        errorMessage: 'Lỗi tải VAD: $e',
      ));
      return false;
    }
  }

  /// Import file silero_vad.onnx từ bất kỳ path nào (file picker).
  Future<bool> importVadFromPath(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      if (src.lengthSync() <= 1000000) {
        debugPrint('❌ File VAD quá nhỏ ($sourcePath) — cần >1MB');
        return false;
      }
      final savePath = p.join(await _vadDir(), vadFileName);
      final existing = File(savePath);
      if (await existing.exists()) await existing.delete();
      await src.copy(savePath);
      await rescan();
      debugPrint('✅ Import VAD: $savePath');
      return true;
    } catch (e) {
      debugPrint('❌ Import VAD error: $e');
      return false;
    }
  }

  void cancelVadDownload() {
    _vadToken?.cancel('User cancelled');
    _vadToken = null;
    _vadState.add(const SherpaModelInfo(status: SherpaModelStatus.notInstalled));
  }

  Future<void> deleteVad() async {
    try {
      final f = File(p.join(await _vadDir(), vadFileName));
      if (await f.exists()) await f.delete();
      await rescan();
      debugPrint('🗑️ Deleted VAD model');
    } catch (e) {
      debugPrint('⚠️ Delete VAD error: $e');
    }
  }

  // ── PIPER TTS ──────────────────────────────────────────────────────────

  Future<String> _piperDir() async {
    final dir = Directory(
        p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Import TỪNG FILE (multi-pick: onnx + json + tokens).
  Future<String> importPiperFiles(List<String> paths) async {
    if (paths.isEmpty) return 'Chưa chọn file nào';
    final destDir = await _piperDir();
    var onnx = 0;
    for (final path in paths) {
      final src = File(path);
      if (!await src.exists()) continue;
      final name = p.basename(path).toLowerCase();
      // Chỉ nhận đúng 3 loại file cần thiết
      if (!name.endsWith('.onnx') &&
          !name.endsWith('_tokens.txt') &&
          name != 'tokens.txt' &&
          !name.endsWith('.onnx.json')) {
        continue;
      }
      await src.copy(p.join(destDir, p.basename(path)));
      if (name.endsWith('.onnx')) onnx++;
    }
    if (onnx == 0) {
      return 'Thiếu file .onnx — chọn cả bộ (onnx + tokens [+ json])';
    }
    await rescan();
    return '✅ Đã import $onnx file model';
  }

  /// Import THƯ MỤC giọng Piper (bundle k2-fsa đã giải nén, hoặc thư mục
  /// giọng tự copy). Tự phát hiện: *.onnx, <name>_tokens.txt / tokens.txt,
  /// *.onnx.json, espeak-ng-data/ (dùng chung, chỉ copy khi thiếu).
  Future<String> importPiperFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return 'Thư mục không tồn tại';

    final destDir = await _piperDir();
    var copiedOnnx = 0;
    var copiedTokens = 0;
    var copiedJson = 0;

    try {
      for (final entity in dir.listSync(followLinks: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final rel = p.relative(entity.path, from: folderPath);
        final relLower = rel.toLowerCase();

        // espeak-ng-data: copy recursive vào chỗ dùng chung
        if (relLower.startsWith('${SherpaPiperTtsCore.espeakDataFolder}${p.context.separator}')) {
          final dest = File(p.join(destDir, rel));
          if (!dest.existsSync()) {
            await dest.parent.create(recursive: true);
            await entity.copy(dest.path);
          }
          continue;
        }

        // Chỉ nhận file ở TẦNG GỐC của thư mục giọng
        // (tránh chôn vùi file rác bên trong espeak-ng-data).
        if (rel.contains(p.context.separator)) continue;

        if (name.endsWith('.onnx')) {
          await entity.copy(p.join(destDir, name));
          copiedOnnx++;
        } else if (name == 'tokens.txt' || name.endsWith('_tokens.txt')) {
          await entity.copy(p.join(destDir, name));
          copiedTokens++;
        } else if (name.endsWith('.onnx.json')) {
          await entity.copy(p.join(destDir, name));
          copiedJson++;
        }
      }
    } catch (e) {
      return 'Lỗi đọc thư mục: $e';
    }

    if (copiedOnnx == 0) {
      return 'Không tìm thấy file .onnx trong thư mục này';
    }

    await rescan();
    debugPrint(
        '✅ Import Piper folder: $copiedOnnx onnx, $copiedTokens tokens, '
        '$copiedJson json');
    return '✅ Đã import $copiedOnnx file model, $copiedTokens tokens, '
        '$copiedJson config';
  }

  /// Tải bundle giọng Piper (tar.bz2, gồm espeak-ng-data).
  /// Trả về path file đã tải — UI hướng dẫn user GIẢI NÉN rồi Import.
  /// (App không tự giải nén .tar.bz2 để không thêm dependency nặng.)
  Future<String?> downloadPiperBundle({
    required String voice,
  }) async {
    if (piperInfo.isDownloading) return null;

    final token = CancelToken();
    _piperToken = token;
    _piperState.add(_piperState.value.copyWith(
        status: SherpaModelStatus.downloading, clearError: true));

    try {
      final docs = await _documents();
      final downloadsDir = Directory(p.join(docs, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final fileName = 'vits-piper-$voice.tar.bz2';
      final savePath = p.join(downloadsDir.path, fileName);
      final tmpPath = '$savePath.tmp';
      final url = piperBundleUrl(voice);

      debugPrint('📥 Download Piper bundle $voice từ: $url');
      await _dio.download(
        url,
        tmpPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _piperState.add(_piperState.value
                .copyWith(downloadProgress: received / total));
          }
        },
      );

      final tmp = File(tmpPath);
      if (await tmp.exists()) {
        final finalFile = File(savePath);
        if (await finalFile.exists()) await finalFile.delete();
        await tmp.rename(savePath);
        debugPrint('✅ Download Piper bundle xong: $savePath');
        return savePath;
      }
      return null;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _piperState.add(_piperState.value
            .copyWith(status: SherpaModelStatus.notInstalled, clearError: true));
        return null;
      }
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage:
            'Không tải được bundle Piper (mạng?) — thử lại hoặc tải tay '
            '$url rồi Import thư mục đã giải nén.',
      ));
      return null;
    } catch (e) {
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage: 'Lỗi tải Piper: $e',
      ));
      return null;
    } finally {
      _piperToken = null;
      if (_piperState.value.isDownloading) {
        _piperState.add(_piperState.value
            .copyWith(status: SherpaModelStatus.notInstalled));
      }
    }
  }

  void dispose() {
    _vadToken?.cancel('Disposed');
    _piperToken?.cancel('Disposed');
    _vadState.close();
    _piperState.close();
    _instance = null;
  }
}
