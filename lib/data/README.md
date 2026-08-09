# Data Layer — Repository Pattern (Offline-First)

> Mục tiêu: UI không biết backend là Hive/Firestore hay Supabase/SQLite. Đổi 1 dòng DI là đổi backend.

## Kiến trúc

```
UI (Widget/Provider)
   ↓
Repository (abstract)  ←── lib/data/repositories/interfaces/
   ↓
Implementation (offline-first) ←── lib/data/repositories/impl/
   ↓
Local DataSource (Hive)  +  Remote DataSource (Firestore/Supabase)
   ↓                        ↓
 Hive Boxes              Firestore / Supabase
```

## Các Repository hiện có

| Repository | Interface | Local | Remote | Offline-First Impl |
|------------|-----------|-------|--------|-------------------|
| **Vocab** | `VocabRepository` | `VocabLocalDataSource` (Hive `vocabulary_v2`) | `FirestoreVocabRemoteDataSource` / `SupabaseVocabRemoteDataSource` (stub) | `OfflineFirstVocabRepository` |
| **TextLibrary** | `TextLibraryRepository` | `TextLibraryLocalDataSource` (Hive `text_library_cache`) | `FirestoreTextLibraryRemoteDataSource` | `OfflineFirstTextLibraryRepository` |
| **Canon** | `CanonRepository` | `CanonLoader` (assets .md + Hive cache) + `HiveCanonFtsService` | — (tương lai: Supabase) | `AssetCanonRepository` |

## Cách đổi backend (1 dòng)

`lib/data/repositories/repository_providers.dart`:

```dart
// Firebase (mặc định, đang chạy)
final vocabRepo = VocabRepositoryFactory.create(useSupabase: false);

// Supabase (khi đã cấu hình)
final vocabRepo = VocabRepositoryFactory.create(useSupabase: true);

// Hoặc chi tiết hơn:
final vocabRepo = OfflineFirstVocabRepository(
  local: VocabLocalDataSource(),
  remote: SupabaseVocabRemoteDataSource(), // tự implement
);
```

Tương tự cho TextLibrary và Canon. Có thể bật bằng `--dart-define`:

```bash
flutter run --dart-define=USE_SUPABASE_VOCAB=true
```

## Luồng Offline-First Vocab

1. `save()` → ghi Hive trước (0ms) → `markDirty(id)` vào `vocab_sync_pending`
2. Debounce 5s → `flushPending()` batch 400 docs lên Firestore (có mạng mới chạy)
3. `enableSync(uid)` → `pullFromFirestore(after: checkpoint)` → merge local (last-write-wins theo `updatedAt`) → flush pending còn lại
4. Mất mạng: vẫn ghi Hive bình thường, pending queue giữ lại, có mạng tự flush qua `Connectivity().onConnectivityChanged`

## Luồng Offline-First TextLibrary (mới)

Trước: chỉ `watchAll()` Firestore → mất mạng trắng.
Giờ:
- `getCached()` trả Hive cache ngay 0ms
- `watchAll()` lắng cả Hive + Firestore, Firestore có gì mới → ghi đè cache nếu `updatedAt` mới hơn
- `add/update/delete` ghi cache trước, thử remote, nếu fail → `text_library_pending` (sẽ sync khi có mạng)

## Migration path sang Supabase + Drift

1. Implement `SupabaseVocabRemoteDataSource` (thay các TODO trong file).
2. Thêm `drift` + `sqlite3_flutter_libs` vào pubspec, tạo `DriftVocabLocalDataSource` thay `HiveVocabLocalDataSource` (API giữ nguyên).
3. Đổi flag `useSupabase: true` / inject Drift local. Không đụng UI.

## Test

- Đổi `VocabRepository` thành mock trong test: `class MockVocabRepo implements VocabRepository { ... }`
- Test offline: `disableSync()` → `save()` → check Hive → `enableSync()` → check remote mock được gọi.

## Lưu ý Hive

Hive đang dùng `vocabulary_v2` (JSON String). Khi chuyển sang Drift, cần viết migration `Hive -> Drift` 1 lần (đọc Hive, ghi Drift, xóa Hive).
