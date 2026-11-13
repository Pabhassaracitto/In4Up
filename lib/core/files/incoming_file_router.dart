// lib/core/files/incoming_file_router.dart
//
// PSRC-222 · BETA-1.29.0 (lane L7) — Điều phối "Mở bằng in4up" cho cả lúc khởi
// động lạnh (`getInitialIncomingFile` + `argv`) lẫn khi ứng dụng đang chạy nền
// (`onIncomingFile` từ `MainActivity.onNewIntent` / `AppDelegate.open`).
//
// Bất biến an toàn:
//   1. Mọi tệp từ ngoài đều được chép sang thư mục bền vững của app TRƯỚC khi
//      chuyển cho màn hình đọc / nghe / xem (quyền đọc tạm của `content://` và
//      security-scoped URL sẽ hết hạn ngay sau khi phiên intent kết thúc).
//   2. Hàng đợi giữ yêu cầu đến sớm (trước khi `MainShell` mount xong) rồi xả
//      đúng thứ tự ngay khi giao diện sẵn sàng.
//   3. Khử trùng lặp intent bắn kép sát nhau (< 1200 ms cùng URI + nguồn), nhưng
//      vẫn cho phép người dùng mở lại cùng tệp đó ở lần bấm sau.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/audio_import_service.dart';
import 'export_destination.dart';
import 'incoming_file_classifier.dart';

/// Hợp đồng giao diện để `MainShell` gắn vào mà unit test thuần vẫn kiểm được
/// toàn bộ luồng định tuyến mà không cần dựng cây Provider/Hive nặng.
abstract class IncomingFileOpenHost {
  bool get isReady;

  Future<void> openPdf({
    required String localPath,
    required String displayName,
  });

  Future<void> openTextDocument({
    required String localPath,
    required String displayName,
  });

  Future<void> openAudio({
    required String localPath,
    required String displayName,
  });

  Future<void> openVideo({
    required String localPath,
    required String displayName,
  });

  Future<void> openDictionary({
    required String localPath,
    required String displayName,
  });

  void showUnsupportedMessage({
    required IncomingUnsupportedReason reason,
    required String displayName,
  });

  void showOpenError({
    required String displayName,
  });
}

class IncomingFileRouter {
  IncomingFileRouter({
    MethodChannel? channel,
    Future<Directory> Function()? appDocumentsDirProvider,
    Future<String> Function({
      required String sourcePath,
      required String displayName,
    })? audioPersister,
    DateTime Function()? clock,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _appDocumentsDirProvider =
            appDocumentsDirProvider ?? getApplicationDocumentsDirectory,
        _audioPersister = audioPersister ?? _defaultAudioPersister,
        _clock = clock ?? DateTime.now;

  static const String channelName = 'in4up/files';

  static final IncomingFileRouter instance = IncomingFileRouter();

  final MethodChannel _channel;
  final Future<Directory> Function() _appDocumentsDirProvider;
  final Future<String> Function({
    required String sourcePath,
    required String displayName,
  }) _audioPersister;
  final DateTime Function() _clock;

  final List<IncomingFilePayload> _pendingQueue = <IncomingFilePayload>[];
  IncomingFileOpenHost? _host;
  bool _started = false;
  bool _draining = false;

  String? _lastDedupSignature;
  DateTime? _lastDedupAt;

  static Future<String> _defaultAudioPersister({
    required String sourcePath,
    required String displayName,
  }) async {
    final imported = await AudioImportService.instance.ensurePersistent(
      sourcePath: sourcePath,
      displayName: displayName,
    );
    return imported.path;
  }

  /// Khởi động cầu nối nhận tệp lúc mở app (`args` + `getInitialIncomingFile`)
  /// và đăng ký lắng nghe `onIncomingFile` khi app đang chạy nền.
  Future<void> start(List<String> cliArgs) async {
    if (!_started) {
      _started = true;
      _channel.setMethodCallHandler(_handleChannelCall);
    }

    for (final rawArg in cliArgs) {
      final parsedPath = IncomingFileClassifier.parseCliFilePath(rawArg);
      if (parsedPath == null) continue;
      final file = File(parsedPath);
      if (await file.exists()) {
        await enqueue(
          IncomingFilePayload(
            localPath: file.path,
            displayName: p.basename(file.path),
            originalUri: rawArg,
            source: 'cli_arg',
          ),
        );
      }
    }

    try {
      final initialMap = await _channel.invokeMapMethod<Object?, Object?>(
        'getInitialIncomingFile',
      );
      final initialPayload = IncomingFilePayload.fromChannelMap(initialMap);
      if (initialPayload != null) {
        await enqueue(initialPayload);
      }
    } on MissingPluginException {
      // Desktop / môi trường test không gắn handler native.
    } on PlatformException catch (e) {
      debugPrint('[IncomingFileRouter] getInitialIncomingFile error: $e');
    } catch (e) {
      debugPrint('[IncomingFileRouter] unexpected init error: $e');
    }
  }

  /// Nhận đường dẫn tệp từ `in4up://open?path=…` (cầu nối với `DictDeepLinkRouter`).
  Future<void> handleOpenPathLink(String rawPath) async {
    final clean = rawPath.trim();
    if (clean.isEmpty) return;
    await enqueue(
      IncomingFilePayload(
        localPath: clean,
        displayName: p.basename(clean),
        originalUri: 'in4up://open?path=$clean',
        source: 'deep_link',
      ),
    );
  }

  Future<void> attachHost(IncomingFileOpenHost host) {
    _host = host;
    return _drainQueue();
  }

  void detachHost(IncomingFileOpenHost host) {
    if (identical(_host, host)) {
      _host = null;
    }
  }

  Future<dynamic> _handleChannelCall(MethodCall call) async {
    if (call.method == 'onIncomingFile') {
      final raw = call.arguments;
      if (raw is Map) {
        final payload = IncomingFilePayload.fromChannelMap(raw);
        if (payload != null) {
          await enqueue(payload);
        }
      }
      return true;
    }
    throw MissingPluginException('Method ${call.method} not implemented');
  }

  /// Đưa một tệp từ ngoài vào hàng đợi và xử lý ngay nếu `MainShell` đã sẵn sàng.
  Future<void> enqueue(IncomingFilePayload payload) async {
    if (_isRapidDuplicate(payload)) return;
    _pendingQueue.add(payload);
    await _drainQueue();
  }

  bool _isRapidDuplicate(IncomingFilePayload payload) {
    final now = _clock();
    final sig =
        '${payload.source}|${payload.originalUri ?? payload.localPath}|${payload.displayName}';
    final prevAt = _lastDedupAt;
    if (_lastDedupSignature == sig &&
        prevAt != null &&
        now.difference(prevAt).inMilliseconds.abs() < 1200) {
      return true;
    }
    _lastDedupSignature = sig;
    _lastDedupAt = now;
    return false;
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    final host = _host;
    if (host == null || !host.isReady) return;

    _draining = true;
    try {
      while (_pendingQueue.isNotEmpty) {
        final currentHost = _host;
        if (currentHost == null || !currentHost.isReady) break;
        final payload = _pendingQueue.removeAt(0);
        await _processOne(payload, currentHost);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _processOne(
    IncomingFilePayload payload,
    IncomingFileOpenHost host,
  ) async {
    final srcFile = File(payload.localPath);
    if (!await srcFile.exists()) {
      host.showOpenError(displayName: payload.displayName);
      return;
    }

    List<int>? headerBytes;
    try {
      headerBytes = await _readHeaderBytes(srcFile, maxBytes: 4096);
    } catch (_) {
      headerBytes = null;
    }

    final classification = IncomingFileClassifier.classify(
      displayName: payload.displayName,
      localPath: payload.localPath,
      originalUri: payload.originalUri,
      mimeType: payload.mimeType,
      headerBytes: headerBytes,
    );

    if (!classification.isSupported) {
      await _deleteIfStagingFile(srcFile);
      host.showUnsupportedMessage(
        reason: classification.unsupportedReason ??
            IncomingUnsupportedReason.unknownFormat,
        displayName: payload.displayName,
      );
      return;
    }

    final normalizedDisplayName =
        IncomingFileClassifier.ensureFileNameHasExtension(
      payload.displayName,
      classification.canonicalExtension,
    );

    String persistentPath;
    try {
      persistentPath = await _persistIntoAppStorage(
        sourceFile: srcFile,
        displayName: normalizedDisplayName,
        classification: classification,
      );
    } catch (e) {
      debugPrint('[IncomingFileRouter] persist failed: $e');
      host.showOpenError(displayName: normalizedDisplayName);
      return;
    }

    if (persistentPath != srcFile.path) {
      await _deleteIfStagingFile(srcFile);
    }

    try {
      switch (classification.category) {
        case IncomingFileCategory.pdf:
          await host.openPdf(
            localPath: persistentPath,
            displayName: normalizedDisplayName,
          );
        case IncomingFileCategory.textDocument:
          await host.openTextDocument(
            localPath: persistentPath,
            displayName: normalizedDisplayName,
          );
        case IncomingFileCategory.audio:
          await host.openAudio(
            localPath: persistentPath,
            displayName: normalizedDisplayName,
          );
        case IncomingFileCategory.video:
          await host.openVideo(
            localPath: persistentPath,
            displayName: normalizedDisplayName,
          );
        case IncomingFileCategory.dictionary:
          await host.openDictionary(
            localPath: persistentPath,
            displayName: normalizedDisplayName,
          );
        case IncomingFileCategory.unsupported:
          break;
      }
    } catch (e) {
      debugPrint('[IncomingFileRouter] open failed: $e');
      host.showOpenError(displayName: normalizedDisplayName);
    }
  }

  Future<String> _persistIntoAppStorage({
    required File sourceFile,
    required String displayName,
    required IncomingFileClassification classification,
  }) async {
    if (classification.category == IncomingFileCategory.audio) {
      return _audioPersister(
        sourcePath: sourceFile.path,
        displayName: displayName,
      );
    }

    final appDocs = await _appDocumentsDirProvider();
    final targetDir = Directory(
      p.join(appDocs.path, classification.appStorageSubfolder),
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final normalizedSrc = p.normalize(sourceFile.absolute.path);
    final normalizedTargetDir = p.normalize(targetDir.absolute.path);
    if (p.isWithin(normalizedTargetDir, normalizedSrc)) {
      return sourceFile.path;
    }

    final cleanDesired = ExportDestinationPolicy.sanitizeFileName(displayName);
    final uniqueName = ExportDestinationPolicy.uniqueDisplayName(
      cleanDesired,
      (candidate) => File(p.join(targetDir.path, candidate)).existsSync(),
    );
    final finalPath = p.join(targetDir.path, uniqueName);
    final partPath = '$finalPath.part';
    final partFile = File(partPath);

    RandomAccessFile? raf;
    try {
      if (await partFile.exists()) {
        await partFile.delete();
      }
      raf = await partFile.open(mode: FileMode.write);
      await for (final chunk in sourceFile.openRead()) {
        await raf.writeFrom(chunk);
      }
      await raf.flush();
      await raf.close();
      raf = null;
      await partFile.rename(finalPath);
    } catch (_) {
      try {
        await raf?.close();
      } catch (_) {}
      try {
        if (await partFile.exists()) {
          await partFile.delete();
        }
      } catch (_) {}
      rethrow;
    }

    return finalPath;
  }

  Future<List<int>> _readHeaderBytes(File file, {required int maxBytes}) async {
    final out = <int>[];
    await for (final chunk in file.openRead(0, maxBytes)) {
      out.addAll(chunk);
      if (out.length >= maxBytes) break;
    }
    return out.length > maxBytes ? out.sublist(0, maxBytes) : out;
  }

  Future<void> _deleteIfStagingFile(File file) async {
    final normalized = file.path.replaceAll(r'\', '/');
    if (!normalized.contains('/in4up_incoming/')) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
