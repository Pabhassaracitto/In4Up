// lib/features/great_library/great_library_wiring_io.dart
//
// GLIB-004 — native (Android/iOS/Windows/Linux): download store trên đĩa
// (application support dir / great_library) để resume sống qua phiên app.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'great_library_controller.dart';
import 'services/gl_catalog_service.dart';
import 'services/gl_catalog_transport_firestore.dart';
import 'services/pack_download_manager.dart';
import 'services/pack_download_store_file.dart';
import 'services/pack_storage_firebase.dart';

Future<GreatLibraryController> createGreatLibraryControllerImpl() async {
  final supportDir = await getApplicationSupportDirectory();
  final store =
      FilePackDownloadStore(Directory('${supportDir.path}/great_library'));
  final transport = FirestoreGlCatalogTransport();
  final catalog = GlCatalogService(
    transport: transport,
    cache: GlCatalogMemoryCache(), // TODO(GLIB-004b): persist snapshot ra file
  );
  final downloads = PackDownloadManager(
    backend: FirebasePackStorage(),
    store: store,
  );
  return GreatLibraryController(catalog: catalog, downloads: downloads);
}
