// lib/features/great_library/great_library_wiring_stub.dart
//
// GLIB-004/005 — web/stub: không dart:io → download store in-memory.
// Import vào Studio tắt trên web (sinks cần dart:io/path_provider) — P0
// nhắm nền tảng native; UI hiện ghi chú thay nút nhập.

import '../../providers/vocabulary_provider.dart';
import 'great_library_controller.dart';
import 'services/gl_catalog_service.dart';
import 'services/gl_catalog_transport_firestore.dart';
import 'services/pack_download_manager.dart';
import 'services/pack_download_store_memory.dart';
import 'services/pack_storage_firebase.dart';

Future<GreatLibraryController> createGreatLibraryControllerImpl({
  VocabularyProvider? vocabulary,
}) async {
  final transport = FirestoreGlCatalogTransport();
  final catalog = GlCatalogService(
    transport: transport,
    cache: GlCatalogMemoryCache(),
  );
  final downloads = PackDownloadManager(
    backend: FirebasePackStorage(),
    store: MemoryPackDownloadStore(),
  );
  return GreatLibraryController(catalog: catalog, downloads: downloads);
}
