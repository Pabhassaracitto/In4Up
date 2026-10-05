# ADR-0010 — Dictionary import across Windows and Android

- **Status:** accepted
- **Date:** 2026-10-05
- **Scope:** I4U18-DICT-001

## Context

The first MDX/MDD import implementation assumed that every selected source could
be represented by a normal filesystem path and that `sqflite`'s default database
factory was available everywhere. Those assumptions are false on the two target
platforms reported by device QA:

- Android's scoped storage picker grants a `content://` document/tree URI. The
  raw `/storage/...` path returned by a directory picker is not necessarily
  readable by `dart:io`.
- `sqflite` is the mobile database backend. Windows/Linux need the FFI database
  factory before the first database operation.

## Decision

1. Keep the platform-independent pipeline unchanged after it receives files:
   `MDX/MDD source → seekable files → isolate parser → SQLite index → manifest`.
2. On Android, select a folder with the native Storage Access Framework,
   recursively scan supported dictionary files, and copy them to a private
   staging directory through `ContentResolver`. Import the staged set into app
   documents before deleting staging files.
   - Android exposes **copy/import** only. A SAF/content URI is not a durable
     linked filesystem path, so recording `linked` there would create a
     manifest that breaks after a restart or cache cleanup.
   - The native scan returns a relative path so nested resources and multiple
     dictionary sets do not collide.
3. For Android file multi-select, use `withReadStream` as a fallback when the
   provider does not return a path. The normal file-picker cache path is also
   treated as copy/import rather than a durable link.
4. On Windows/Linux, lazily initialize `sqflite_common_ffi` and assign
   `databaseFactoryFfi` before create, insert, lookup, prefix lookup, or delete.
5. Keep desktop folder link/index mode. It avoids duplicating large dictionaries
   while the original folder remains available. Imported bundles are deleted
   using an app-documents ownership check that is path-separator safe on
   Windows.

## Consequences

- Android may use additional temporary storage while an import is running, but
  the final copy is stable in app documents and no scoped-storage permission is
  required beyond the SAF grant.
- Large MDD copies run off Android's main thread to avoid an ANR.
- The MDX parser and SQLite schema remain shared, so lookup behavior is the same
  on Windows and Android after import.
- Android folder imports report provider/read/copy errors instead of silently
  treating a selected folder as empty.

## Verification

- Existing MDX parser, SQLite, scanner, and import integration tests remain the
  regression suite.
- Desktop DB calls now exercise the FFI factory in production, not only in test
  setup.
- Android manual QA should cover a folder with `mdx + mdd + css`, an MDX-only
  folder, a nested set, provider-backed files, app restart, and a revoked SAF
  permission.
