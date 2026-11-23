// lib/features/great_library/great_library_wiring.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049).
// Điểm cắm dựng controller mặc định cho UI. Conditional import:
//  - native (dart.library.io): download store trên đĩa (app support dir)
//  - web (không có dart:io): memory store (tải giữ trong phiên)

import 'great_library_wiring_stub.dart'
    if (dart.library.io) 'great_library_wiring_io.dart' as impl;

import 'great_library_controller.dart';

Future<GreatLibraryController> createGreatLibraryController() =>
    impl.createGreatLibraryControllerImpl();
