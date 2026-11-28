// lib/features/great_library/contribution_wiring_stub.dart
//
// GLIB-006 — web/stub: ContributionStore in-memory (record chỉ sống trong
// phiên), storage Firebase vẫn thật (upload cần đăng nhập), transport thật.

import '../../services/firebase_rest_auth.dart';
import 'contribution_wiring.dart';
import 'services/contribution_store.dart';
import 'services/contribution_transport_firestore.dart';
import 'services/pack_contribution_service.dart';
import 'services/pack_storage_firebase.dart';

Future<ContributionBundle> createContributionBundleImpl() async {
  final store = MemoryContributionStore();

  final auth = FirebaseRestAuth();
  await auth.restoreSession();
  final user = auth.currentUser;

  final service = PackContributionService(
    store: store,
    storage: FirebasePackStorage(),
    transport: FirestoreContributionTransport(),
    authorUid: user?.uid ?? '',
    authorName: user?.displayName ?? '',
  );
  return ContributionBundle(service: service, store: store);
}
