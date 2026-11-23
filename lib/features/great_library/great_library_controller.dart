// lib/features/great_library/great_library_controller.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049, ADR-0031).
// ChangeNotifier nối catalog (GLIB-003) + download manager (GLIB-002) cho UI:
//  - load({force}) → entries / loading / errorMessage
//  - query (filter + sort) qua GlCatalogQuery thuần
//  - download(entry) → progress theo packId → downloadedIds (phiên hiện tại)
//
// Import vào Studio (Vườn nhớ / Tab Nghe / flashcard) = GLIB-005 — controller
// giữ sẵn bytes đã tải trong store để import sau.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'models/gl_pack_entry.dart';
import 'services/gl_catalog_service.dart';
import 'services/pack_content.dart';
import 'services/pack_download_manager.dart';
import 'services/pack_file.dart';
import 'services/pack_import_service.dart';
import 'services/pack_storage_backend.dart';

/// GLIB-004b — gói xem trước nội dung pack đã tải (plan + media + data để UI
/// render: thẻ từ / danh sách track + LRC / lưới ảnh).
class PackPreview {
  const PackPreview({
    required this.plan,
    required this.media,
    required this.dataFiles,
  });

  final PackContentPlan plan;
  final PackMediaLookup media;
  final Map<String, Uint8List> dataFiles;
}

class GreatLibraryController extends ChangeNotifier {
  GreatLibraryController({
    required GlCatalogService catalog,
    required PackDownloadManager downloads,
    PackDownloadStore? downloadStore,
    PackImportService? importService,
    InstalledPackStore? installedStore,
  })  : _catalog = catalog,
        _downloads = downloads,
        _downloadStore = downloadStore,
        _importService = importService,
        _installedStore = installedStore;

  final GlCatalogService _catalog;
  final PackDownloadManager _downloads;

  /// GLIB-005 — đọc pack đã tải để import; null (web stub) → import tắt.
  final PackDownloadStore? _downloadStore;
  final PackImportService? _importService;
  final InstalledPackStore? _installedStore;

  bool _loading = false;
  String? _errorMessage;
  List<GlPackEntry> _entries = const <GlPackEntry>[];
  GlCatalogQuery _query = const GlCatalogQuery();

  /// packId → trạng thái tải gần nhất (cho progress bar).
  final Map<String, PackDownloadProgress> downloadStates =
      <String, PackDownloadProgress>{};

  /// packId đã tải xong trong phiên (verify checksum pass).
  final Set<String> downloadedIds = <String>{};

  /// GLIB-005 — packId đang import (progress UI).
  final Set<String> importingIds = <String>{};

  /// GLIB-005 — kết quả import gần nhất theo packId.
  final Map<String, PackImportResult> importResults =
      <String, PackImportResult>{};

  /// GLIB-005 — packId → version đã cài (nạp từ InstalledPackStore lúc load).
  Map<String, int> _installed = <String, int>{};

  /// GLIB-004b — cache preview trong phiên (khỏi giải nén lại mỗi lần mở).
  final Map<String, PackPreview> _previews = <String, PackPreview>{};

  bool get canImport => _importService != null && _downloadStore != null;

  /// Đã cài pack này vào Studio chưa.
  bool isInstalled(String packId) => _installed.containsKey(packId);

  /// Catalog có bản mới hơn bản đã cài (chip "Có bản mới").
  bool hasUpdate(GlPackEntry entry) => PackImportService.needsUpdate(
      installedVersion: _installed[entry.packId],
      catalogVersion: entry.manifest.version);

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  /// Danh sách hiển thị = catalog sau khi áp query hiện tại.
  List<GlPackEntry> get visibleEntries => _query.apply(_entries);

  GlCatalogQuery get query => _query;

  Future<void> load({bool forceRefresh = false}) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await _catalog.getCatalog(forceRefresh: forceRefresh);
      final store = _installedStore;
      if (store != null) _installed = await store.readAll();
    } on GlCatalogException catch (e) {
      _errorMessage = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  void setQuery(GlCatalogQuery query) {
    _query = query;
    notifyListeners();
  }

  /// Tải pack về máy (resume + verify). Không ném — lỗi nằm trong
  /// [downloadStates] và trả về qua [PackDownloadResult].
  Future<PackDownloadResult> download(GlPackEntry entry) async {
    final packId = entry.packId;
    final storage = entry.manifest.storage;
    if (storage == null || storage.backend.isEmpty) {
      final result = PackDownloadResult.failed(
          PackStorageErrorCode.invalidRef, 'pack thiếu storage ref');
      downloadStates[packId] = const PackDownloadProgress(
          state: PackDownloadState.failed, receivedBytes: 0, totalBytes: 0);
      notifyListeners();
      return result;
    }
    final result = await _downloads.downloadPack(
      packId: packId,
      ref: storage,
      expectedBytes: entry.fileBytes,
      expectedFileSha256: entry.fileSha256,
      onProgress: (progress) {
        downloadStates[packId] = progress;
        notifyListeners();
      },
    );
    if (result.isSuccess) downloadedIds.add(packId);
    notifyListeners();
    return result;
  }

  /// GLIB-004b — giải nén pack đã tải để xem trước. Trả null khi chưa tải
  /// xong / pack lỗi. Kết quả cache trong phiên theo packId.
  Future<PackPreview?> previewDownloaded(String packId) async {
    final cached = _previews[packId];
    if (cached != null) return cached;
    final store = _downloadStore;
    if (store == null) return null;
    final bytes = await store.readFinal(packId);
    if (bytes == null) return null;
    try {
      final contents = PackFile.extract(bytes);
      final plan = PackContent.parse(contents);
      final preview = PackPreview(
        plan: plan,
        media: PackMediaLookup(contents.mediaFiles),
        dataFiles: contents.dataFiles,
      );
      _previews[packId] = preview;
      return preview;
    } on Object {
      return null; // pack hỏi — UI ẩn khu xem trước
    }
  }

  /// GLIB-005 — nhập pack đã tải vào Studio (route theo loại qua
  /// [PackImportService]). Trả null khi chưa tải xong hoặc import tắt (web).
  Future<PackImportResult?> importDownloaded(String packId) async {
    final importService = _importService;
    final store = _downloadStore;
    final installedStore = _installedStore;
    if (importService == null || store == null || installedStore == null) {
      return null;
    }
    importingIds.add(packId);
    notifyListeners();
    try {
      final bytes = await store.readFinal(packId);
      if (bytes == null) {
        final result = PackImportResult.failed('pack-not-downloaded');
        importResults[packId] = result;
        return result;
      }
      final PackContents contents;
      try {
        contents = PackFile.extract(bytes);
      } on FormatException catch (e) {
        final result = PackImportResult.failed(e.message);
        importResults[packId] = result;
        return result;
      } on Object catch (e) {
        // ArchiveException & lỗi giải nén khác từ package:archive.
        final result = PackImportResult.failed('$e');
        importResults[packId] = result;
        return result;
      }
      final result = await importService.importPack(contents);
      importResults[packId] = result;
      if (result.isSuccess) {
        _installed = await installedStore.readAll();
      }
      return result;
    } finally {
      importingIds.remove(packId);
      notifyListeners();
    }
  }
}
