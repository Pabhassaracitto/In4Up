# Tipiṭaka — database setup and fallback

## What the app opens

The Tipiṭaka reader uses the normalized SQLite contract described in
`lib/features/tipitaka/models/README.md`. On startup/opening the feature it
checks, in order:

1. `getApplicationDocumentsDirectory()/in4up/tipitaka/tipitaka.sqlite` — a DB
   previously installed by the developer or user;
2. the optional bundled asset `assets/db/tipitaka.sqlite`, copied to the
   writable location on first use.

The asset is declared in `pubspec.yaml`. Therefore a developer can add a
valid normalized `assets/db/tipitaka.sqlite` and use it immediately after a
fresh build. The checked-in file is a small demo, not the complete canon.

If neither location contains the required tables and rows, the app does not
open a blank database or show fake books. Library/Search show the data manager
with **Import DB** and **Language packs** actions.

## Import a source database

Pa-Auk distributes Pāli and translations as `.db.zip`. A source database is
not the app database: it may contain tables such as `vin01t_tik` or
`e0101n_mul`, and its schema is different between releases. Put any `.db`
files or the `.zip` archives in `reference/` (or another directory) and run:

```bash
python scripts/import_tipitaka.py
python scripts/import_tipitaka.py --source-dir C:/tipitaka_src
```

The importer:

- discovers all source tables and imports all rows (there is no `LIMIT 10000`);
- matches Pāli and translation rows by source table/key, then by reference;
- keeps fixed translations (`en`, `vi`, `my`, `th`) and stores additional
  languages in `tipitaka_translations`;
- accepts `.db`, `.sqlite`, and `.db.zip` files;
- writes a temporary output and atomically replaces the destination only after
  a collection, book, and segment are present.

The default result is `assets/db/tipitaka.sqlite`. For production, pass an
output outside `assets/` and deliver/install it separately; a full database
may be hundreds of megabytes.

The app's **Import DB** button accepts an already normalized `.db`/`.sqlite`
file as well as a raw Pa-Auk `.db`/`.sqlite`/`.zip` source package. Raw files
are inspected, normalized, and installed by the Dart importer; the Python
script remains useful for large developer/release builds. The app never opens
a raw source as an empty application schema.

## Developer file locations and scanning

Use these locations:

| Purpose | Location |
|---|---|
| Python importer input | repository `reference/` (`.db`, `.sqlite`, `.zip`) |
| Bundled fallback DB | `assets/db/tipitaka.sqlite` |
| Runtime scan folder | `<Application Documents>/in4up/tipitaka/imports/` |
| Downloaded packs | `<Application Documents>/in4up/tipitaka/packs/` |

The Tipiṭaka data manager has **Quét thư mục import của developer**. Put one or
more source files into the runtime scan folder and the app will find them,
import Pāli before translation packs, and show one background task banner. The
runtime folder is intentionally not scanned on every app startup: large DBs
must only be imported after the user explicitly presses the scan button.

For a packaged developer build, replace `assets/db/tipitaka.sqlite` and rebuild
when the database should be available on a fresh install. For a device import,
use the application-documents `imports` folder or the file picker.

## Background task behavior

Downloads and imports run through a process-level coordinator rather than the
screen that started them. Leaving the screen does not cancel work; the root
banner and recent-task list show `Đang tải`, `Đang giải nén`, `Đang import`,
`Đã hoàn tất`, or `Thất bại`. The current task history is intentionally
in-memory, so an operating-system process kill does not resume a partially
completed task. Reopen the app and scan/import the source again if that occurs.

## Download language packages in the app

The Language Packs screen has the Pa-Auk URLs from the integration handoff.
Tapping download is explicit (never automatic at startup), streams the zip to
application documents, extracts the DB, and immediately sends it through the
same in-app importer. Import Pāli first; translation packs are then joined by
source key/reference. The extracted source file is retained separately, while
the reader opens only the normalized application DB.

## Release checklist

- [ ] Supply a complete normalized DB, or keep the optional demo asset.
- [ ] Run `python scripts/import_tipitaka.py` and verify collection/book/
      segment counts.
- [ ] Run `flutter pub get`; `archive` is used for extracting language packs and
      `sqflite_common_ffi` enables the same DB path on Windows/Linux.
- [ ] Test a fresh install (asset path) and a build with no asset (data manager
      path).
- [ ] Preserve the Pa-Auk/OpenTipitaka attribution and license terms when
      distributing downloaded/merged data.

## Performance contract (TIPI-PERF-01)

Opening the library or a book must not depend on the size of the canon. The
rules that keep it that way:

1. **One verification per file version.** `TipitakaDb.openReady()` remembers the
   fingerprint (`path + size + mtime`) of the database it already verified and
   returns the open handle for every later call. Open-path probes use
   `SELECT 1 … LIMIT 1` (`EXISTS`), never `COUNT(*)` over `tipitaka_segments`.
2. **No per-screen derivation.** `availableLanguages()` and the
   "has structural headings" flag are memoised per import revision and persisted
   in `SharedPreferences` (`tipitaka_perf_cache.dart`) under the same
   fingerprint. `info()` still returns exact counts for the data manager but no
   longer probes every translation column; screens that only need languages call
   `availableLanguages()`.
3. **Catalogue titles are resolved once per book** and skipped entirely when the
   database has no structural heading rows (the normalised/demo shape), where the
   old correlated subqueries always returned `NULL` after a full scan.
4. **Paging index** `idx_segments_book_order(book_id, order_index, id)` is built
   during import (`scripts/import_tipitaka.py` and the in-app staging open) and
   lazily at runtime only for databases ≤ 250 000 segments. A larger database is
   never indexed while the user is reading — re-import a pack to get it.
5. **Prewarm, then paint.** Entering the Đọc tab calls `TipitakaDb.prewarm()`
   after the first frame; the library paints its cached snapshot from a single
   `stat()` before SQLite is opened and refreshes behind a 2 px progress bar.

Anything that caches must stay fingerprint-keyed: imports install files through
an atomic rename, so a changed size/mtime always invalidates the cache. See
`docs/tipitaka_performance_plan.md` for the measurements behind these rules.
