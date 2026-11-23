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

import 'package:flutter/foundation.dart';

import 'models/gl_pack_entry.dart';
import 'services/gl_catalog_service.dart';
import 'services/pack_download_manager.dart';

class GreatLibraryController extends ChangeNotifier {
  GreatLibraryController({
    required GlCatalogService catalog,
    required PackDownloadManager downloads,
  })  : _catalog = catalog,
        _downloads = downloads;

  final GlCatalogService _catalog;
  final PackDownloadManager _downloads;

  bool _loading = false;
  String? _errorMessage;
  List<GlPackEntry> _entries = const <GlPackEntry>[];
  GlCatalogQuery _query = const GlCatalogQuery();

  /// packId → trạng thái tải gần nhất (cho progress bar).
  final Map<String, PackDownloadProgress> downloadStates =
      <String, PackDownloadProgress>{};

  /// packId đã tải xong trong phiên (verify checksum pass).
  final Set<String> downloadedIds = <String>{};

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
}
