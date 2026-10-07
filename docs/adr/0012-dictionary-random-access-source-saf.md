# ADR-0012 — Dictionary random-access sources and Android SAF linking

- **Status:** source/link implementation in progress; analysis, Android/provider verification, and MDD media rendering pending.
- **Date:** 2026-10-07
- **Scope:** DICT-LINK-001 — dictionary source access and linked imports.

## Context

Android's Storage Access Framework grants `content://` document/tree URIs, not
ordinary filesystem paths. The existing MDX parser opens `File` paths, so Android
folder imports had to copy files into staging and only offered the app-owned
copy mode. Copy mode must remain available, but users also need a linked mode
that leaves the dictionary bundle in one place.

## Decision

1. Introduce `RandomAccessSource` (`length`, `seek`, `read`, `close`) with
   `FileRandomAccessSource` for filesystem paths and `SafRandomAccessSource`
   for Android document URIs. The existing `MdxParser.parse(String, ...)` API
   remains intact; source-based parsing is additive.
2. SAF folder and multi-document grants are persisted at picker completion.
   Kotlin keeps a `ParcelFileDescriptor` per active reader and serves explicit
   offset reads capped at 64 KiB. Dart caches at most four 64 KiB pages per SAF
   source. Linked import keeps the selected MDX/MDD/CSS document URIs in the
   manifest and does not stage or copy those files.
3. Preserve the established MDX decode behavior: SAF data is fetched in bounded
   chunks, then the current CPU-heavy MDX decode runs in a worker isolate. The
   MDX parser does not open or materialize MDD files; linked mode never loads
   an MDD into Dart memory. The SQLite lookup index remains app-owned and is
   separate from the dictionary bundle.
4. Keep `DictStorageMode.imported` as the stable copy-to-app option. It copies
   into app storage and never deletes or alters the selected original source.
5. Persist the primary MDX URI and source filenames. If the URI cannot be
   opened after restart or a card/folder move, set `needsReselect`, retain the
   SQLite index, and offer a source rebind action. Rebinding updates source
   metadata only; it does not delete or rebuild the index.
6. If a SAF provider exposes only a pipe/non-seekable descriptor, fail with a
   readable source error instead of silently falling back to a full-file copy.

## Consequences

- Linked Android mode stores one source bundle plus the app's small SQLite
  lookup index; it does not duplicate the MDX/MDD bundle.
- Copy mode continues to use extra storage while preserving the user's original
  files. Users may remove the original themselves if they choose, but the app
  never does so.
- SAF permission and seek behavior varies by provider and removable-storage
  state, so final acceptance requires a real Android device, including restart,
  revocation/move, and SD-card tests.
- Current dictionary result rendering remains unchanged; this ADR covers source
  access and indexing, not expansion of the UI's existing HTML/media renderer.
