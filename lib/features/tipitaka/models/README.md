# Tipiṭaka database contract

The Flutter module opens **only** the normalized database produced by
`scripts/import_tipitaka.py`:

```text
assets/db/tipitaka.sqlite                         # optional bundled/demo DB
<application documents>/in4up/tipitaka/tipitaka.sqlite  # installed DB
```

## Required tables

- `tipitaka_collections`: the three Piṭaka collections.
- `tipitaka_books`: books belonging to a collection.
- `tipitaka_segments`: ordered Pāli paragraphs and fixed translations (`en`,
  `vi`, `my`, `th`).
- `tipitaka_translations`: additional language packs, keyed by
  `(segment_id, language_code)`.
- `tipitaka_user_notes` and `tipitaka_learning_items`: app-owned tables; they
  are created/migrated on open. A release refresh should migrate/back up these
  tables before replacing the content database.

A usable database must have at least one collection, book, and segment. The
app does not create an empty database as a fallback: it shows the data manager
instead.

## Developer workflow

1. Download one or more Pa-Auk `.db.zip` packages and extract them, or leave
   the archives in `reference/`.
2. Run from the repository root:

   ```bash
   python scripts/import_tipitaka.py
   # or: python scripts/import_tipitaka.py --source-dir C:/tipitaka_src
   ```

3. For a release, do **not** commit the full 200–500 MB database into the
   asset bundle. Build it outside `assets/` and install it into the app's
   documents directory. The small checked-in DB is only a demo/fallback.
4. For a developer build, a valid `assets/db/tipitaka.sqlite` is copied to
   the writable application directory automatically on first open. The
   asset is declared in `pubspec.yaml`, so adding/replacing it no longer
   requires another Dart code change.

The Flutter data manager accepts both an already normalized `.db`/`.sqlite`
file and a raw Pa-Auk `.db`/`.sqlite`/`.zip` source package. Raw source tables
are detected and normalized in Dart before installation, so Python is not
required on a user device. The Python importer remains available for
developer/release builds and very large offline imports.
