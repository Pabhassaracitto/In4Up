// lib/features/great_library/contribution_wiring_io.dart
//
// GLIB-006 — native: ContributionStore file + transport Firestore thật +
// storage Firebase thật. authorUid/lấy từ FirebaseRestAuth (đã đăng nhập).

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../services/firebase_rest_auth.dart';
import 'contribution_wiring.dart';
import 'services/contribution_store.dart';
import 'services/contribution_store_file.dart';
import 'services/contribution_transport_firestore.dart';
import 'services/pack_contribution_service.dart';
import 'services/pack_storage_firebase.dart';

Future<ContributionBundle> createContributionBundleImpl() async {
  final supportDir = await getApplicationSupportDirectory();
  final store =
      FileContributionStore(Directory('${supportDir.path}/great_library'));

  final auth = FirebaseRestAuth();
  await auth.restoreSession();
  final user = auth.currentUser;
  final uid = user?.uid ?? '';
  final name = user?.displayName ?? '';

  final service = PackContributionService(
    store: store,
    storage: FirebasePackStorage(),
    transport: FirestoreContributionTransport(),
    authorUid: uid,
    authorName: name,
  );
  return ContributionBundle(service: service, store: store);
}
