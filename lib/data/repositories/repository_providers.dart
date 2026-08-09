// lib/data/repositories/repository_providers.dart
//
// DI — Single place để đổi backend cho toàn app.
// Chỉ cần đổi 1 flag ở đây là toàn bộ app chuyển từ Firebase sang Supabase
// (hoặc từ Hive sang Drift) mà không đụng tới UI.
//
// Cách dùng trong main.dart:
//   MultiProvider(
//     providers: [
//       Provider<VocabRepository>(create: (_) => VocabRepositoryFactory.create(useSupabase: kUseSupabase)),
//       Provider<TextLibraryRepository>(create: (_) => TextLibraryRepositoryFactory.create(useSupabase: kUseSupabase)),
//       Provider<CanonRepository>(create: (_) => CanonRepositoryFactory.create()),
//     ],
//   )
//
// Hiện tại mặc định useSupabase = false để giữ Firebase đang chạy ổn.

import 'package:flutter/foundation.dart';

import '../../features/canon/canon_repository.dart';
import 'impl/offline_first_text_library_repository.dart';
import 'impl/offline_first_vocab_repository.dart';
import 'interfaces/canon_repository.dart';
import 'interfaces/text_library_repository.dart';
import 'interfaces/vocab_repository.dart';

// ── Feature flags ────────────────────────────────────────
// Đổi thành true khi bạn đã cấu hình Supabase project và muốn test song song.
// Có thể đọc từ --dart-define hoặc remote config.
const bool kUseSupabaseVocab = bool.fromEnvironment('USE_SUPABASE_VOCAB', defaultValue: false);
const bool kUseSupabaseTextLibrary = bool.fromEnvironment('USE_SUPABASE_TEXT', defaultValue: false);
const bool kUseSupabaseCanon = bool.fromEnvironment('USE_SUPABASE_CANON', defaultValue: false);

// ── Factories re-export để main.dart chỉ import 1 file ──

VocabRepository createVocabRepository({bool useSupabase = kUseSupabaseVocab}) =>
    VocabRepositoryFactory.create(useSupabase: useSupabase);

TextLibraryRepository createTextLibraryRepository({bool useSupabase = kUseSupabaseTextLibrary}) =>
    TextLibraryRepositoryFactory.create(useSupabase: useSupabase);

CanonRepository createCanonRepository({bool useSupabase = kUseSupabaseCanon}) =>
    CanonRepositoryFactory.create(useSupabase: useSupabase);

// ── Helper để log trạng thái DI ──────────────────────────

void logRepositoryConfig() {
  debugPrint('── Repository Config ──');
  debugPrint(' Vocab:       ${kUseSupabaseVocab ? "Supabase" : "Firestore (Hive local-first)"}');
  debugPrint(' TextLibrary: ${kUseSupabaseTextLibrary ? "Supabase" : "Firestore (Hive cache)"}');
  debugPrint(' Canon:       ${kUseSupabaseCanon ? "Supabase" : "Assets .md + Hive FTS"}');
  debugPrint('──────────────────────');
}
