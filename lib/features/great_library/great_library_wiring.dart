// lib/features/great_library/great_library_wiring.dart
//
// GLIB-004/005 — Thư Viện Chung I4U (PLAN-049).
// Điểm cắm dựng controller mặc định cho UI. Conditional import:
//  - native (dart.library.io): download store trên đĩa + import sinks thật
//  - web (không có dart:io): memory store, import tắt
//
// [vocabulary]: provider app-wide từ UI (context.read) — sink vocab PHẢI ghi
// vào đúng instance app đang dùng, không tự new (lệch dữ liệu hiển thị).

import 'great_library_wiring_stub.dart'
    if (dart.library.io) 'great_library_wiring_io.dart' as impl;

import '../../providers/vocabulary_provider.dart';
import 'great_library_controller.dart';

Future<GreatLibraryController> createGreatLibraryController({
  VocabularyProvider? vocabulary,
}) =>
    impl.createGreatLibraryControllerImpl(vocabulary: vocabulary);
