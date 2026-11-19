// lib/core/files/export_destination_service.dart
//
// PSRC-204 · ADR-0029 — Dịch vụ lưu tệp công khai dùng chung cho mọi tính năng
// xuất trong app (Media/Audio/Video, Cabin, Phụ đề LRC, Văn bản/Bản dịch…).
//
// Bất biến thiết kế (ADR-0029 § 4 & § 5):
//   1. Dữ liệu nội bộ (model AI, DB Tipitaka, phiên cabin thô, cache, từ điển)
//      KHÔNG đi qua service này — vẫn nằm trong thư mục riêng tư của app.
//   2. Mọi tệp xuất cho người dùng đều qua 1 cổng duy nhất:
//        - Android 10+ (API ≥ 29): `MediaStore.Downloads` (`Download/In4Up/`,
//          `IS_PENDING = 1` → `fsync` → `IS_PENDING = 0`), không xin quyền bộ nhớ.
//        - Android ≤ 9 (API ≤ 28): `WRITE_EXTERNAL_STORAGE` + `Download/In4Up/`.
//        - Android "Đổi…": SAF `ACTION_OPEN_DOCUMENT_TREE` (`in4up/files`).
//        - iOS: `Documents/In4Up` (`On My iPhone/In4Up`).
//        - Windows / Linux / macOS: `<Downloads>/In4Up` (dự phòng `~/In4Up`).
//   3. Ghi nguyên tử: `*.part` → `flush()` (`fsync`) → `rename` (hoặc
//      `IS_PENDING = 1` → `sync()` → `IS_PENDING = 0` trên MediaStore).
//   4. Trùng tên ⇒ tự thêm ` (2)`, ` (3)`… không bao giờ ghi đè tệp cũ.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'export_destination.dart';

/// Lưu đích xuất mặc định tuỳ chọn vào `SharedPreferences`.
class SharedPreferencesExportDestinationStore
    implements ExportDestinationStore {
  const SharedPreferencesExportDestinationStore();

  static const String prefKey = 'in4up.export_destination.custom_default.v1';

  @override
  Future<ExportDestination?> readCustomDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ExportDestination.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCustomDefault(ExportDestination destination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, jsonEncode(destination.toJson()));
  }

  @override
  Future<void> clearCustomDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
  }
}

/// Nền tảng thực thi để có thể giả lập trong unit test mà không lệ thuộc
/// `Platform.isAndroid` cố định của host chạy CI.
enum ExportHostPlatform {
  android,
  ios,
  windows,
  linux,
  macos,
}

class ExportDestinationService {
  ExportDestinationService({
    ExportDestinationStore? store,
    MethodChannel? channel,
    ExportHostPlatform? platformOverride,
    Future<int> Function()? androidSdkIntProvider,
    Future<String?> Function()? androidLegacyDownloadsRootProvider,
    Future<Directory> Function()? appDocumentsDirProvider,
    Future<Directory?> Function()? downloadsDirProvider,
    String? Function()? homeDirProvider,
    Future<String?> Function()? directoryPicker,
    Future<bool> Function()? legacyStoragePermissionRequester,
  })  : _store = store ?? const SharedPreferencesExportDestinationStore(),
        _channel = channel ?? const MethodChannel(channelName),
        _platformOverride = platformOverride,
        _androidSdkIntProvider = androidSdkIntProvider,
        _androidLegacyDownloadsRootProvider =
            androidLegacyDownloadsRootProvider,
        _appDocumentsDirProvider =
            appDocumentsDirProvider ?? getApplicationDocumentsDirectory,
        _downloadsDirProvider = downloadsDirProvider ?? _safeGetDownloadsDir,
        _homeDirProvider = homeDirProvider ?? _defaultHomeDir,
        _directoryPicker = directoryPicker,
        _legacyStoragePermissionRequester = legacyStoragePermissionRequester {
    _policy = ExportDestinationPolicy(
      store: _store,
      builtInDefaultProvider: builtInDefaultDestination,
      isDestinationAccessible: isDestinationAccessible,
    );
  }

  static const String channelName = 'in4up/files';

  static final ExportDestinationService instance = ExportDestinationService();

  final ExportDestinationStore _store;
  final MethodChannel _channel;
  final ExportHostPlatform? _platformOverride;
  final Future<int> Function()? _androidSdkIntProvider;
  final Future<String?> Function()? _androidLegacyDownloadsRootProvider;
  final Future<Directory> Function() _appDocumentsDirProvider;
  final Future<Directory?> Function() _downloadsDirProvider;
  final String? Function() _homeDirProvider;
  final Future<String?> Function()? _directoryPicker;
  final Future<bool> Function()? _legacyStoragePermissionRequester;

  late final ExportDestinationPolicy _policy;

  ExportDestinationPolicy get policy => _policy;

  ExportHostPlatform get _hostPlatform {
    final override = _platformOverride;
    if (override != null) return override;
    if (Platform.isAndroid) return ExportHostPlatform.android;
    if (Platform.isIOS) return ExportHostPlatform.ios;
    if (Platform.isWindows) return ExportHostPlatform.windows;
    if (Platform.isMacOS) return ExportHostPlatform.macos;
    return ExportHostPlatform.linux;
  }

  /// Trả về đích mặc định gốc của nền tảng hiện tại (chưa tính cấu hình "Luôn
  /// lưu vào thư mục này" của người dùng).
  Future<ExportDestination> builtInDefaultDestination() async {
    switch (_hostPlatform) {
      case ExportHostPlatform.android:
        final sdkInt = await _getAndroidSdkInt();
        String? legacyRoot;
        if (sdkInt < 29) {
          legacyRoot = await _getAndroidLegacyDownloadsRoot();
        }
        return ExportDestinationPolicy.buildAndroidDefault(
          sdkInt: sdkInt,
          legacyDownloadsRoot: legacyRoot,
        );
      case ExportHostPlatform.ios:
        final docs = await _appDocumentsDirProvider();
        return ExportDestinationPolicy.buildIosDefault(
          appDocumentsPath: docs.path,
        );
      case ExportHostPlatform.windows:
      case ExportHostPlatform.linux:
      case ExportHostPlatform.macos:
        final downloads = await _downloadsDirProvider();
        final home = _homeDirProvider();
        Directory? docs;
        if (downloads == null && (home == null || home.trim().isEmpty)) {
          docs = await _appDocumentsDirProvider();
        }
        return ExportDestinationPolicy.buildDesktopDefault(
          downloadsPath: downloads?.path,
          homePath: home,
          fallbackAppDocumentsPath: docs?.path ?? Directory.systemTemp.path,
          isWindows: _hostPlatform == ExportHostPlatform.windows,
        );
    }
  }

  /// Phân giải đích xuất mặc định hiện hành (có kiểm tra quyền còn sống nếu là
  /// thư mục tuỳ chọn đã lưu).
  Future<ExportDestinationResolution> resolveDefaultDestination() =>
      _policy.resolveDefault();

  /// Mở một phiên chọn đích cho 1 lần mở hộp thoại xuất.
  Future<ExportDestinationSession> openSession() => _policy.openSession();

  /// Chốt phiên khi người dùng bấm "Xuất".
  Future<ExportDestination> commitSession(ExportDestinationSession session) =>
      _policy.commitSession(session);

  /// Đặt lại nơi lưu mặc định về thư mục `In4Up` gốc của nền tảng.
  Future<ExportDestination> resetToBuiltInDefault() =>
      _policy.resetToBuiltInDefault();

  /// Kiểm tra thư mục đã lưu còn tồn tại và ghi được không.
  Future<bool> isDestinationAccessible(ExportDestination destination) async {
    switch (destination.kind) {
      case ExportDestinationKind.androidMediaStoreDownloads:
        return true;
      case ExportDestinationKind.androidSafTree:
        try {
          final ok = await _channel.invokeMethod<bool>(
            'isExportTreeWritable',
            <String, Object?>{'treeUri': destination.location},
          );
          return ok ?? false;
        } on MissingPluginException {
          return false;
        } on PlatformException {
          return false;
        }
      case ExportDestinationKind.androidLegacyDownloads:
      case ExportDestinationKind.iosDocumentsFolder:
      case ExportDestinationKind.directoryPath:
        // Chỉ coi thư mục tuỳ chọn đã bị xoá khi nó KHÔNG phải mặc định gốc và
        // không còn tồn tại trên đĩa (hoặc không thể đọc/ghi).
        final dir = Directory(destination.location);
        if (destination.isBuiltInDefault) return true;
        return dir.exists();
    }
  }

  /// Mở bộ chọn thư mục ("Đổi…"):
  /// - Android: SAF `ACTION_OPEN_DOCUMENT_TREE` qua channel `in4up/files`.
  /// - Desktop / iOS: `FilePicker.getDirectoryPath()`.
  /// Trả `null` nếu người dùng huỷ.
  Future<ExportDestination?> pickCustomDestination() async {
    if (_hostPlatform == ExportHostPlatform.android &&
        _directoryPicker == null) {
      try {
        final map = await _channel.invokeMapMethod<String, Object?>(
          'pickExportTree',
        );
        if (map == null) return null;
        final uri = map['uri'] as String?;
        if (uri == null || uri.trim().isEmpty) return null;
        final providerName = map['displayName'] as String?;
        return ExportDestination(
          kind: ExportDestinationKind.androidSafTree,
          location: uri,
          displayPath: ExportDestinationPolicy.formatSafTreeLabel(
            uri,
            providerDisplayName: providerName,
          ),
          isBuiltInDefault: false,
        );
      } on PlatformException catch (e) {
        debugPrint('[ExportDestination] pickExportTree failed: $e');
        return null;
      } on MissingPluginException {
        return null;
      }
    }

    String? pickedPath;
    try {
      final picker = _directoryPicker;
      pickedPath = picker != null
          ? await picker()
          : await FilePicker.getDirectoryPath();
    } catch (e) {
      debugPrint('[ExportDestination] getDirectoryPath failed: $e');
      return null;
    }
    if (pickedPath == null || pickedPath.trim().isEmpty) return null;
    final home = _homeDirProvider();
    return ExportDestination(
      kind: ExportDestinationKind.directoryPath,
      location: pickedPath,
      displayPath: ExportDestinationPolicy.shortenWithHome(
        pickedPath,
        homePath: home,
      ),
      isBuiltInDefault: false,
    );
  }

  /// Ghi một tệp nguồn cục bộ ([sourceFile]) sang [destination] (hoặc mặc định
  /// hiện hành nếu truyền `null`) theo đúng bất biến ADR-0029:
  ///   - Ghi qua `.part` + `flush()` (`fsync`) + `rename` (hoặc `IS_PENDING`).
  ///   - Trùng tên ⇒ thêm ` (2)`, ` (3)`… không đè tệp cũ.
  Future<ExportSavedFile> exportLocalFile({
    required File sourceFile,
    required String desiredFileName,
    ExportDestination? destination,
    String? mimeType,
  }) async {
    final target =
        destination ?? (await resolveDefaultDestination()).destination;
    final cleanName = ExportDestinationPolicy.sanitizeFileName(desiredFileName);
    final resolvedMime =
        mimeType ?? ExportDestinationPolicy.mimeTypeForFileName(cleanName);

    switch (target.kind) {
      case ExportDestinationKind.androidMediaStoreDownloads:
        return _saveViaAndroidChannel(
          method: 'saveFileToDownloads',
          arguments: <String, Object?>{
            'sourcePath': sourceFile.path,
            'fileName': cleanName,
            'mimeType': resolvedMime,
            'subFolder': kIn4UpPublicFolderName,
          },
          destination: target,
        );

      case ExportDestinationKind.androidSafTree:
        return _saveViaAndroidChannel(
          method: 'saveFileToSafTree',
          arguments: <String, Object?>{
            'sourcePath': sourceFile.path,
            'treeUri': target.location,
            'fileName': cleanName,
            'mimeType': resolvedMime,
          },
          destination: target,
        );

      case ExportDestinationKind.androidLegacyDownloads:
        final granted = await _ensureLegacyAndroidWritePermission();
        if (!granted) {
          throw const FileSystemException(
            'Chưa được cấp quyền ghi vào thư mục Tải xuống trên Android 9 trở xuống',
          );
        }
        return _saveViaAndroidChannelOrFallback(
          sourceFile: sourceFile,
          cleanName: cleanName,
          resolvedMime: resolvedMime,
          destination: target,
        );

      case ExportDestinationKind.iosDocumentsFolder:
      case ExportDestinationKind.directoryPath:
        return _writeLocalDirectoryAtomically(
          sourceFile: sourceFile,
          targetDirectoryPath: target.location,
          desiredFileName: cleanName,
          destination: target,
        );
    }
  }

  /// Ghi trực tiếp chuỗi UTF-8 (LRC, TXT, SRT, MD, JSON…) vào [destination].
  Future<ExportSavedFile> exportText({
    required String content,
    required String desiredFileName,
    ExportDestination? destination,
    String? mimeType,
  }) {
    return exportBytes(
      bytes: Uint8List.fromList(utf8.encode(content)),
      desiredFileName: desiredFileName,
      destination: destination,
      mimeType: mimeType,
    );
  }

  /// Ghi mảng byte vào [destination] (tạo tệp staging tạm an toàn nếu đích là
  /// Android MediaStore / SAF).
  Future<ExportSavedFile> exportBytes({
    required List<int> bytes,
    required String desiredFileName,
    ExportDestination? destination,
    String? mimeType,
  }) async {
    final target =
        destination ?? (await resolveDefaultDestination()).destination;
    final cleanName = ExportDestinationPolicy.sanitizeFileName(desiredFileName);

    if (target.kind == ExportDestinationKind.directoryPath ||
        target.kind == ExportDestinationKind.iosDocumentsFolder) {
      return _writeBytesToLocalDirectoryAtomically(
        bytes: bytes,
        targetDirectoryPath: target.location,
        desiredFileName: cleanName,
        destination: target,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('in4up_export_stage_');
    final staging = File(p.join(tempDir.path, cleanName));
    try {
      final raf = await staging.open(mode: FileMode.write);
      try {
        await raf.writeFrom(bytes);
        await raf.flush();
      } finally {
        await raf.close();
      }
      return await exportLocalFile(
        sourceFile: staging,
        desiredFileName: cleanName,
        destination: target,
        mimeType: mimeType,
      );
    } finally {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Mở thư mục chứa tệp vừa xuất để người dùng thấy kết quả ngay ("Mở thư mục").
  /// Trả `true` nếu hệ điều hành mở được trình quản lý tệp.
  Future<bool> openContainingFolder({
    required ExportDestination destination,
    String? localFilePath,
    String? fileUri,
  }) async {
    try {
      switch (_hostPlatform) {
        case ExportHostPlatform.android:
          final opened = await _channel.invokeMethod<bool>(
            'openExportLocation',
            <String, Object?>{
              'kind': destination.kind.name,
              'location': destination.location,
              'fileUri': fileUri,
              'localPath': localFilePath,
            },
          );
          return opened ?? false;

        case ExportHostPlatform.windows:
          if (localFilePath != null && File(localFilePath).existsSync()) {
            final res = await Process.run(
              'explorer.exe',
              <String>['/select,', localFilePath],
            );
            if (res.exitCode == 0) return true;
          }
          if (Directory(destination.location).existsSync()) {
            await Process.run('explorer.exe', <String>[destination.location]);
            return true;
          }
          return false;

        case ExportHostPlatform.macos:
          if (localFilePath != null && File(localFilePath).existsSync()) {
            final res = await Process.run('open', <String>['-R', localFilePath]);
            return res.exitCode == 0;
          }
          if (Directory(destination.location).existsSync()) {
            final res =
                await Process.run('open', <String>[destination.location]);
            return res.exitCode == 0;
          }
          return false;

        case ExportHostPlatform.linux:
          final dirPath = localFilePath != null
              ? p.dirname(localFilePath)
              : destination.location;
          if (!Directory(dirPath).existsSync()) return false;
          final res = await Process.run('xdg-open', <String>[dirPath]);
          return res.exitCode == 0;

        case ExportHostPlatform.ios:
          final opened = await _channel.invokeMethod<bool>(
            'openExportLocation',
            <String, Object?>{
              'kind': destination.kind.name,
              'location': destination.location,
              'localPath': localFilePath,
            },
          );
          return opened ?? false;
      }
    } catch (e) {
      debugPrint('[ExportDestination] openContainingFolder failed: $e');
      return false;
    }
  }

  // ── Chi tiết ghi nguyên tử cục bộ & qua MethodChannel ──────────────────────

  Future<ExportSavedFile> _saveViaAndroidChannel({
    required String method,
    required Map<String, Object?> arguments,
    required ExportDestination destination,
  }) async {
    final map = await _channel.invokeMapMethod<String, Object?>(
      method,
      arguments,
    );
    if (map == null) {
      throw const FileSystemException('Không nhận được phản hồi khi lưu tệp');
    }
    final fileName = (map['fileName'] as String?) ??
        (arguments['fileName'] as String? ?? 'export');
    final displayPath = (map['displayPath'] as String?) ??
        '${destination.displayPath}/$fileName';
    final localPath = map['localPath'] as String?;
    final uri = map['uri'] as String?;
    return ExportSavedFile(
      fileName: fileName,
      displayPath: displayPath,
      destination: destination,
      localPath: (localPath != null && localPath.isNotEmpty) ? localPath : null,
      uri: (uri != null && uri.isNotEmpty) ? uri : null,
    );
  }

  Future<ExportSavedFile> _saveViaAndroidChannelOrFallback({
    required File sourceFile,
    required String cleanName,
    required String resolvedMime,
    required ExportDestination destination,
  }) async {
    try {
      return await _saveViaAndroidChannel(
        method: 'saveFileToDownloads',
        arguments: <String, Object?>{
          'sourcePath': sourceFile.path,
          'fileName': cleanName,
          'mimeType': resolvedMime,
          'subFolder': kIn4UpPublicFolderName,
        },
        destination: destination,
      );
    } on MissingPluginException {
      return _writeLocalDirectoryAtomically(
        sourceFile: sourceFile,
        targetDirectoryPath: destination.location,
        desiredFileName: cleanName,
        destination: destination,
      );
    }
  }

  Future<ExportSavedFile> _writeLocalDirectoryAtomically({
    required File sourceFile,
    required String targetDirectoryPath,
    required String desiredFileName,
    required ExportDestination destination,
  }) async {
    final dir = Directory(targetDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final finalName = ExportDestinationPolicy.uniqueDisplayName(
      desiredFileName,
      (candidate) => File(p.join(dir.path, candidate)).existsSync(),
    );
    final finalPath = p.join(dir.path, finalName);
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
      // `flush()` gọi `fsync` / `FlushFileBuffers` xuống đĩa trước khi rename.
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

    final sep = destination.displayPath.contains(r'\') ? r'\' : '/';
    return ExportSavedFile(
      fileName: finalName,
      displayPath: '${destination.displayPath}$sep$finalName',
      destination: destination,
      localPath: finalPath,
      uri: Uri.file(finalPath).toString(),
    );
  }

  Future<ExportSavedFile> _writeBytesToLocalDirectoryAtomically({
    required List<int> bytes,
    required String targetDirectoryPath,
    required String desiredFileName,
    required ExportDestination destination,
  }) async {
    final dir = Directory(targetDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final finalName = ExportDestinationPolicy.uniqueDisplayName(
      desiredFileName,
      (candidate) => File(p.join(dir.path, candidate)).existsSync(),
    );
    final finalPath = p.join(dir.path, finalName);
    final partPath = '$finalPath.part';
    final partFile = File(partPath);

    RandomAccessFile? raf;
    try {
      if (await partFile.exists()) {
        await partFile.delete();
      }
      raf = await partFile.open(mode: FileMode.write);
      await raf.writeFrom(bytes);
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

    final sep = destination.displayPath.contains(r'\') ? r'\' : '/';
    return ExportSavedFile(
      fileName: finalName,
      displayPath: '${destination.displayPath}$sep$finalName',
      destination: destination,
      localPath: finalPath,
      uri: Uri.file(finalPath).toString(),
    );
  }

  Future<int> _getAndroidSdkInt() async {
    final sdkProvider = _androidSdkIntProvider;
    if (sdkProvider != null) {
      return sdkProvider();
    }
    try {
      final sdk = await _channel.invokeMethod<int>('getAndroidSdkInt');
      if (sdk != null && sdk > 0) return sdk;
    } catch (_) {}
    return 29;
  }

  Future<String?> _getAndroidLegacyDownloadsRoot() async {
    final legacyProvider = _androidLegacyDownloadsRootProvider;
    if (legacyProvider != null) {
      return legacyProvider();
    }
    try {
      return await _channel.invokeMethod<String>('getLegacyDownloadsRoot');
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureLegacyAndroidWritePermission() async {
    final permissionRequester = _legacyStoragePermissionRequester;
    if (permissionRequester != null) {
      return permissionRequester();
    }
    try {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;
      final requested = await Permission.storage.request();
      return requested.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<Directory?> _safeGetDownloadsDir() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  static String? _defaultHomeDir() {
    final env = Platform.environment;
    return env['HOME'] ?? env['USERPROFILE'];
  }
}
