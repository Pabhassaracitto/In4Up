// lib/features/great_library/great_library_wiring_stub.dart
//
// GLIB-004 — web/stub: không dart:io → download store in-memory.

import 'great_library_controller.dart';
import 'services/gl_catalog_service.dart';
import 'services/gl_catalog_transport_firestore.dart';
import 'services/pack_download_manager.dart';
import 'services/pack_download_store_memory.dart';
import 'services/pack_storage_firebase.dart';

Future<GreatLibraryController> createGreatLibraryControllerImpl() async {
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
