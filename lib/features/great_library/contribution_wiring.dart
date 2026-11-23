// lib/features/great_library/contribution_wiring.dart
//
// GLIB-006 — dựng PackContributionService + ContributionStore cho UI wizard.
// Conditional import: native → store file trên đĩa; web → memory (P1 nhắm
// native; web vẫn mở được wizard nhưng record chỉ sống trong phiên).

import 'contribution_wiring_stub.dart'
    if (dart.library.io) 'contribution_wiring_io.dart' as impl;

import 'services/contribution_store.dart';
import 'services/pack_contribution_service.dart';

Future<ContributionBundle> createContributionBundle() =>
    impl.createContributionBundleImpl();

/// Gói service + store cho wizard + màn "Đóng góp của tôi".
class ContributionBundle {
  const ContributionBundle({required this.service, required this.store});

  final PackContributionService service;
  final ContributionStore store;
}
