# Integrating a Tipiṭaka book

This guide is for contributors adding a new text or language edition to In4Up's
Tipiṭaka catalogue. The reader consumes the normalized SQLite contract; the
in-app data manager can also normalize supported raw Pa-Auk `.db`, `.sqlite`,
and `.zip` sources.

## Before importing

1. Confirm the source and edition are suitable for distribution, and record
   the source, language, edition, and any license/provenance details.
2. Prefer the in-app data manager for device imports. For developer/release
   preparation, use `python scripts/import_tipitaka.py` as described in
   [`lib/features/tipitaka/models/README.md`](../lib/features/tipitaka/models/README.md).
3. Keep large release databases outside the bundled demo asset. Do not replace
   the user's installed database manually: import through the app or its
   transactional importer so existing user-owned notes and learning data are
   retained.

## Normalized database contract

A normalized book belongs to one collection and is represented by a row in
`tipitaka_books`. Its ordered text is stored in `tipitaka_segments`; optional
language packs use `tipitaka_translations` with one row per segment and
language code. The `tipitaka_collections`, `tipitaka_books`,
`tipitaka_segments`, and `tipitaka_translations` tables are described in the
[database contract](../lib/features/tipitaka/models/README.md#required-tables).

For every book, provide:

- A stable, unique `code` (normally the source table or canonical text ID).
- Correct `collection_id`, `order_index`, and human-readable Pāli/English/
  Vietnamese names when available.
- A stable `reference` and reading order for each segment.
- The appropriate text column (`pali_text`, `translation_en`,
  `translation_vi`, `translation_my`, or `translation_th`) and/or normalized
  rows in `tipitaka_translations` for other languages.
- Structural `block_type` values such as `book`, `chapter`, `heading`,
  `center`, and `paragraph` when the source provides structure. Preserve the
  actual invocation and other text in the segment body; do not mark repeated
  invocations such as “Namo Tassa…” as book/chapter headings.

Use UTF-8 and preserve Pāli diacritics and source order. Keep source-row keys
and source-table metadata where available; they help the importer match
parallel language editions and preserve stable reading anchors.

## Catalogue sections and titles

The catalogue derives a human-readable title from the first structural book,
chapter, or heading row, preferring the active display language. It falls back
to the book's name fields and finally a safe generated label. Technical source
table codes are for source identity, not visible titles. Do not put table IDs,
reference codes, or repeated `Namo Tassa…` rows in title fields.

`TipitakaCatalogSection.classify` routes known Mūla, Aṭṭhakathā, and Ṭīkā
editions automatically. Mark other collections with JSON metadata when the
classification is not obvious, for example:

```json
{"catalog_section":"extra-canonical"}
```

“Tạng Ngoại” includes, among others, Visuddhimagga / Path of Purification
(Thanh Tịnh Đạo), Buddhist Council question-and-answer texts (including Vấn
Đáp Kết Tập Kinh Điển), and works by Ledi Sayadaw (including Tuyển Tập Ledi
Sayadaw). Sri Lankan chronicles belong in the Sri Lankan branch. Add titles or
aliases to the classifier when a new work cannot be identified from its code,
metadata, or names; cover each new alias with a focused test.

## Validate an integration

1. Import into a temporary database first; never test against the only copy of
   a user's installed database.
2. Check that `TipitakaDb.getCollections` and
   `TipitakaDb.getBooksByCollection` show the expected hierarchy and localized
   titles.
3. Check several references at the beginning, middle, and end of the book;
   verify text order, language fallback, and any outline entries.
4. Check that opening the book does not promote invocations or technical IDs
   into the title/outline, and that search finds representative text.
5. Import a translation independently if it is supplied separately; confirm it
   joins the intended Pāli segments without duplicates or loss of notes.
6. Add or update tests under `test/` for classification, title/outline, import
   matching, and language behavior as applicable. Run the focused Tipiṭaka
   tests and `flutter analyze` before proposing the change.

The checked-in `assets/db/tipitaka.sqlite` is a small fallback/demo database.
It remains available when no populated non-demo catalogue exists, and is hidden
from the library, search, and highlight results once real catalogue content is
installed.
