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
