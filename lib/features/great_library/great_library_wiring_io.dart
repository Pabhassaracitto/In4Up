// lib/features/great_library/great_library_wiring_io.dart
//
// GLIB-004/005 — native (Android/iOS/Windows/Linux): download store trên đĩa
// (application support dir / great_library) để resume sống qua phiên app;
// GLIB-005: import sinks thật (vocab/audio/image) + installed store bền vững.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../providers/vocabulary_provider.dart';
import 'great_library_controller.dart';
import 'services/gl_catalog_file_cache.dart';
import 'services/gl_catalog_service.dart';
import 'services/gl_catalog_transport_firestore.dart';
import 'services/pack_download_manager.dart';
import 'services/pack_download_store_file.dart';
import 'services/pack_import_service.dart';
import 'services/pack_import_sinks_io.dart';
import 'services/pack_storage_firebase.dart';

Future<GreatLibraryController> createGreatLibraryControllerImpl({
  VocabularyProvider? vocabulary,
}) async {
  final supportDir = await getApplicationSupportDirectory();
  final store =
      FilePackDownloadStore(Directory('${supportDir.path}/great_library'));
  final transport = FirestoreGlCatalogTransport();
  final catalog = GlCatalogService(
    transport: transport,
    // GLIB-004b: persist snapshot ra đĩa — mở app offline vẫn thấy catalog cũ.
    cache: GlCatalogFileCache(Directory('${supportDir.path}/great_library')),
  );
  final downloads = PackDownloadManager(
    backend: FirebasePackStorage(),
    store: store,
  );
  final installedStore = PrefsInstalledPackStore();
  final importService = PackImportService(
    vocabSink: GlVocabPackSink(vocabulary: vocabulary),
    audioSink: GlAudioPackSink(),
    imageSink: GlImagePackSink(),
    installedStore: installedStore,
  );
  return GreatLibraryController(
    catalog: catalog,
    downloads: downloads,
    downloadStore: store,
    importService: importService,
    installedStore: installedStore,
  );
}
