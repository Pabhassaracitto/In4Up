# Tipiṭaka database contract

The Flutter reader opens the normalized database contract below. A raw Pa-Auk
file is detected and converted to this contract inside the app before it is
installed; `scripts/import_tipitaka.py` remains an offline/developer option:

```text
assets/db/tipitaka.sqlite                         # optional bundled/demo DB
<application documents>/in4up/tipitaka/tipitaka.sqlite  # installed DB
```

## Required tables

- `tipitaka_collections`: the three Piṭaka collections.
- `tipitaka_books`: books belonging to a collection.
- `tipitaka_segments`: ordered Pāli paragraphs, structural block type (`book`,
  `chapter`, `heading`, `center`, or `paragraph`), and fixed translations
  (`en`, `vi`, `my`, `th`).
- `tipitaka_translations`: additional language packs, keyed by
  `(segment_id, language_code)`.
- `tipitaka_user_notes` and `tipitaka_learning_items`: app-owned tables; they
  are created/migrated on open. A release refresh should migrate/back up these
  tables before replacing the content database.

A usable database must have at least one collection, book, and segment. The
app does not create an empty database as a fallback: it shows the data manager
instead.

## Demo fallback (PSRC-158)

The checked-in asset is only a fallback for a fresh install. Every staged
import removes its demo books, segments, translations, annotations and
now-empty collections *before* copying real rows, so imported books never end
up under the `Tipiṭaka — bản demo` collection and demo paragraphs are never
returned by search or counted in the data manager. Databases created by older
builds can be cleaned once with `TipitakaDb.purgeDemoData()`; real books that
were attached to a demo-named collection are kept and the collection is
renamed. Cleanup is staged and atomic, exactly like an import.

## Database management (PSRC-160)

The data manager exposes three explicit, confirmed operations; deletion is
never inferred from a failed open or a partially downloaded file.

- `TipitakaDb.importHistory(db)` lists imported packages with a normalized
  `language_code` (older rows without the column are attributed from the source
  filename). The manager shows one removable row per installed language.
- `TipitakaDb.deleteLanguagePack(code)` clears the fixed translation column
  (or `pali_text` for Pāli), removes matching `tipitaka_translations` rows and
  their import-history entries, but keeps every other language and all reader
  annotations. It is staged, transactional and serialized with imports.
- `TipitakaDb.deleteDatabase()` closes the open handle, removes the installed
  DB plus journal/WAL/SHM, `.bak`, `.swap`, `.part`, `.importing-*` sidecars and
  (optionally) downloaded pack files. A sticky `.demo_disabled` marker prevents
  `openReady()` from silently re-seeding the bundled demo on the next launch.
- `TipitakaDb.restoreBundledDemo()` is the only opt-in way to remove that
  marker and copy the sample back. A subsequent real import clears the marker
  automatically when the library reopens the installed database.
- `TipitakaDb.purgeDemoData()` remains available for databases created by
  older builds that still contain demo rows (PSRC-158).

Removing the last readable language also sets the sticky marker, so an empty
merged DB is not mistaken for a fresh install. Every operation bumps
`importRevision`, which invalidates cached catalogs and lets the library
reload. All destructive paths accept an explicit `destinationPath` for
hermetic tests; the marker and pack cleanup only apply to the real installed
path.

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

For a developer device, place files in
`<Application Documents>/in4up/tipitaka/imports/` and press the scan button in
the data manager. Pāli files are processed before translation files. The app
keeps downloads/imports off the startup path so a large database never blocks
or unexpectedly changes the library.

Worklist entries can additionally carry `TipitakaSourceAnchor` and
`TipitakaContextSnapshot` data. The anchor stores book/segment/reference,
source-row key and selected-text offsets; the snapshot stores the full Pāli
paragraph, translation and adjacent context. `TipitakaSourceResolver` uses
those fields to reopen the current DB after an import or replacement.

For contributors integrating new books or editions, see the
[Tipiṭaka book integration guide](../../../../docs/tipitaka-book-integration.md).
