#!/usr/bin/env python3
"""Build In4Up's normalized Tipiṭaka SQLite database.

The Pa-Auk downloads are source databases. Their table names and columns vary
between languages/releases (and the files are distributed as ``.db.zip``), so
this script discovers the source schema instead of assuming one table or
silently truncating it.  The output is the only database the Flutter reader
opens: ``assets/db/tipitaka.sqlite`` by default.

Examples::

    # Put .db or .db.zip files in reference/ and import all of them.
    python scripts/import_tipitaka.py

    # Use a download directory on Windows/Linux.
    python scripts/import_tipitaka.py --source-dir C:/tipitaka_src

    # Build a production file outside the repository.
    python scripts/import_tipitaka.py --source-dir ./tipitaka_src \\
        --output ./build/tipitaka.sqlite

The script only replaces the output after at least one usable source has been
found. A missing download therefore cannot destroy an existing database.
"""

from __future__ import annotations

import argparse
import html
import re
import shutil
import sqlite3
import sys
import tempfile
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Iterable, Iterator, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_DIR = REPO_ROOT / "reference"
DEFAULT_OUTPUT = REPO_ROOT / "assets" / "db" / "tipitaka.sqlite"

# These are the links documented in docs/Bangiao/bangiao_tipitaka.md. Matching
# by a keyword keeps dated filename changes from breaking the import.
LANGUAGE_HINTS = {
    "vi": ("vietnamese", "_vi", "-vi"),
    "en": ("english", "_en", "-en"),
    "my": ("myanmar", "burmese", "_my", "-my"),
    "th": ("thai", "_th", "-th"),
    "si": ("sinhala", "_si", "-si"),
    "zh": ("chinese", "_zh", "-zh"),
    "ja": ("japanese", "_ja", "-ja"),
    "ko": ("korean", "_ko", "-ko"),
    "km": ("khmer", "_km", "-km"),
    "lo": ("lao", "_lo", "-lo"),
    "fr": ("french", "_fr", "-fr"),
    "de": ("german", "_de", "-de"),
    "es": ("spanish", "_es", "-es"),
    "id": ("indonesian", "_id", "-id"),
    "pt": ("portuguese", "_pt", "-pt"),
    "hi": ("hindi", "_hi", "-hi"),
    "bn": ("bengali", "_bn", "-bn"),
    "mr": ("marathi", "_mr", "-mr"),
    "bo": ("tibetan", "_bo", "-bo"),
}

TARGET_TRANSLATION_COLUMNS = {"vi": "translation_vi", "en": "translation_en", "my": "translation_my", "th": "translation_th"}


def quote_identifier(value: str) -> str:
    """Quote an SQLite identifier (source names are not trusted)."""
    return '"' + value.replace('"', '""') + '"'


def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def find_column(columns: Iterable[str], candidates: Iterable[str]) -> Optional[str]:
    columns = list(columns)
    by_normalized = {normalized(column): column for column in columns}
    for candidate in candidates:
        if candidate in columns:
            return candidate
        found = by_normalized.get(normalized(candidate))
        if found:
            return found
    # Prefer a column that contains the candidate, but do not match a generic
    # candidate such as "id" against every column name.
    for candidate in candidates:
        needle = normalized(candidate)
        if len(needle) < 3:
            continue
        for column in columns:
            if needle in normalized(column):
                return column
    return None


def table_columns(conn: sqlite3.Connection, table: str) -> list[str]:
    rows = conn.execute(f"PRAGMA table_info({quote_identifier(table)})").fetchall()
    return [str(row[1]) for row in rows]


def table_names(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).fetchall()
    return [str(row[0]) for row in rows]


def row_count(conn: sqlite3.Connection, table: str) -> int:
    try:
        return int(conn.execute(f"SELECT COUNT(*) FROM {quote_identifier(table)}").fetchone()[0])
    except sqlite3.Error:
        return 0


def clean_text(value: object) -> str:
    """Turn Pa-Auk's XML/HTML-ish text into readable text for the reader."""
    if value is None:
        return ""
    text = html.unescape(str(value)).replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"<\s*br\s*/?\s*>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"</\s*p\s*>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def language_from_name(path: Path) -> Optional[str]:
    name = path.name.lower()
    if "pali" in name and ("roman" in name or "text" in name):
        return "pi"
    for language, hints in LANGUAGE_HINTS.items():
        if any(hint in name for hint in hints):
            return language
    return None


def safe_extract_zips(source_dir: Path, temporary_dir: Path) -> list[Path]:
    """Extract only DB files from zip downloads, with zip-slip protection."""
    extracted: list[Path] = []
    for archive in sorted(source_dir.rglob("*.zip")):
        try:
            with zipfile.ZipFile(archive) as zipped:
                for member in zipped.infolist():
                    if member.is_dir():
                        continue
                    member_name = Path(member.filename).name
                    if not member_name.lower().endswith((".db", ".sqlite", ".sqlite3")):
                        continue
                    destination = temporary_dir / f"{archive.stem}__{member_name}"
                    with zipped.open(member) as source, destination.open("wb") as target:
                        shutil.copyfileobj(source, target)
                    extracted.append(destination)
        except (OSError, zipfile.BadZipFile) as error:
            print(f"[WARN] Cannot read {archive}: {error}")
    return extracted


def discover_source_files(source_dir: Path, temporary_dir: Path) -> list[Path]:
    files = [
        path
        for path in source_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in (".db", ".sqlite", ".sqlite3")
    ]
    files.extend(safe_extract_zips(source_dir, temporary_dir))
    # Do not import the same physical file twice.
    unique: dict[str, Path] = {}
    for path in files:
        unique[str(path.resolve())] = path
    return sorted(unique.values(), key=lambda path: path.name.lower())


def choose_sources(files: list[Path], explicit_pali: Optional[Path] = None) -> tuple[Optional[Path], list[tuple[str, Path]]]:
    pali = explicit_pali
    if pali and not pali.exists():
        raise FileNotFoundError(f"Pāli DB not found: {pali}")
    if pali is None:
        for path in files:
            if language_from_name(path) == "pi":
                pali = path
                break

    translations: list[tuple[str, Path]] = []
    for path in files:
        if pali is not None and path.resolve() == pali.resolve():
            continue
        language = language_from_name(path)
        if language and language != "pi":
            translations.append((language, path))
    return pali, translations


def build_target_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA foreign_keys = OFF;
        CREATE TABLE IF NOT EXISTS tipitaka_collections (
          id INTEGER PRIMARY KEY,
          name_pali TEXT NOT NULL DEFAULT '',
          name_en TEXT NOT NULL DEFAULT '',
          name_vi TEXT NOT NULL DEFAULT '',
          order_index INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS tipitaka_books (
          id INTEGER PRIMARY KEY,
          collection_id INTEGER NOT NULL DEFAULT 0,
          code TEXT NOT NULL DEFAULT '',
          name_pali TEXT NOT NULL DEFAULT '',
          name_en TEXT NOT NULL DEFAULT '',
          name_vi TEXT NOT NULL DEFAULT '',
          order_index INTEGER NOT NULL DEFAULT 0,
          metadata_json TEXT
        );
        CREATE TABLE IF NOT EXISTS tipitaka_segments (
          id INTEGER PRIMARY KEY,
          book_id INTEGER NOT NULL DEFAULT 0,
          section_id INTEGER,
          reference TEXT NOT NULL DEFAULT '',
          paragraph_no INTEGER,
          pali_text TEXT NOT NULL DEFAULT '',
          translation_en TEXT,
          translation_vi TEXT,
          translation_my TEXT,
          translation_th TEXT,
          order_index INTEGER NOT NULL DEFAULT 0,
          source_table TEXT,
          source_row_key TEXT
        );
        CREATE TABLE IF NOT EXISTS tipitaka_translations (
          segment_id INTEGER NOT NULL,
          language_code TEXT NOT NULL,
          text TEXT NOT NULL DEFAULT '',
          PRIMARY KEY(segment_id, language_code)
        );
        CREATE TABLE IF NOT EXISTS tipitaka_user_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL DEFAULT 1,
          segment_id INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          tags TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        CREATE TABLE IF NOT EXISTS tipitaka_learning_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL DEFAULT 1,
          segment_id INTEGER NOT NULL,
          next_review_at INTEGER,
          memory_strength REAL NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          UNIQUE(user_id, segment_id)
        );
        """
    )


def collection_for_table(table: str) -> tuple[str, str, str]:
    lower = table.lower()
    if lower.startswith("vin") or "vinaya" in lower:
        return "vinaya", "Vinaya Piṭaka", "Tạng Luật"
    if lower.startswith(("abh", "dhs", "vib", "dht")) or "abhidham" in lower:
        return "abhidhamma", "Abhidhamma Piṭaka", "Tạng Vi Diệu Pháp"
    return "sutta", "Sutta Piṭaka", "Tạng Kinh"


def select_text_table(conn: sqlite3.Connection, language: str) -> Iterator[tuple[str, list[str], str]]:
    """Yield every likely text table; importantly, never apply a row LIMIT."""
    text_candidates = (
        ("pali_text", "text", "content", "paragraph", "body", "html", "xml", "data")
        if language == "pi"
        else ("translation", "translated_text", "translation_text", "text", "content", "paragraph", "body", "html", "xml", "data")
    )
    for table in table_names(conn):
        columns = table_columns(conn, table)
        text_col = find_column(columns, text_candidates)
        if text_col is None or row_count(conn, table) == 0:
            continue
        # Metadata tables sometimes have a generic `data` column. A real
        # source table usually has an id/reference alongside it.
        id_or_ref = find_column(columns, ("id", "rowid", "reference", "ref", "citation", "paragraph_id", "segment_id"))
        if id_or_ref is None and len(columns) < 2:
            continue
        yield table, columns, text_col


def as_int(value: object, fallback: int) -> int:
    try:
        return int(value) if value is not None else fallback
    except (TypeError, ValueError):
        return fallback


def import_pali(conn: sqlite3.Connection, source_path: Path) -> tuple[int, dict[tuple[str, str], int], dict[str, int]]:
    source = sqlite3.connect(f"file:{source_path.resolve()}?mode=ro", uri=True)
    target_key_to_id: dict[tuple[str, str], int] = {}
    reference_to_id: dict[str, int] = {}
    collection_ids: dict[str, int] = {}
    book_ids: dict[str, int] = {}
    inserted = 0
    try:
        for table, columns, text_col in select_text_table(source, "pi"):
            ref_col = find_column(columns, ("reference", "ref", "citation", "section_ref", "book_code"))
            key_col = find_column(columns, ("id", "rowid", "paragraph_id", "segment_id", "para_id", "seq", "number"))
            para_col = find_column(columns, ("paragraph_no", "paragraph_number", "para", "line_no", "segment_no", "number"))
            collection_key, collection_en, collection_vi = collection_for_table(table)
            if collection_key not in collection_ids:
                conn.execute(
                    "INSERT INTO tipitaka_collections(name_pali,name_en,name_vi,order_index) VALUES(?,?,?,?)",
                    (collection_en, collection_en, collection_vi, len(collection_ids) + 1),
                )
                collection_ids[collection_key] = int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])
            if table not in book_ids:
                code = re.sub(r"[^A-Za-z0-9]+", "_", table).upper()
                conn.execute(
                    "INSERT INTO tipitaka_books(collection_id,code,name_pali,name_en,name_vi,order_index,metadata_json) VALUES(?,?,?,?,?,?,?)",
                    (collection_ids[collection_key], code, table, table, table, len(book_ids) + 1, '{"source":"OpenTipitaka"}'),
                )
                book_ids[table] = int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])

            selected_key = quote_identifier(key_col) if key_col else "rowid"
            selected_ref = quote_identifier(ref_col) if ref_col else "NULL"
            selected_para = quote_identifier(para_col) if para_col else selected_key
            query = f"SELECT {selected_key}, {selected_ref}, {selected_para}, {quote_identifier(text_col)} FROM {quote_identifier(table)}"
            order_index = 0
            for key, reference, paragraph, text in source.execute(query):
                row_key = str(key if key is not None else order_index + 1)
                readable_text = clean_text(text)
                # Keep structural/header rows too; the original markup often
                # carries useful book and chapter boundaries.
                ref = clean_text(reference) if reference is not None else ""
                if not ref:
                    ref = f"{table}:{row_key}"
                paragraph_number = as_int(paragraph, order_index + 1)
                conn.execute(
                    """INSERT INTO tipitaka_segments
                       (book_id,reference,paragraph_no,pali_text,order_index,source_table,source_row_key)
                       VALUES(?,?,?,?,?,?,?)""",
                    (book_ids[table], ref, paragraph_number, readable_text, order_index, table, row_key),
                )
                segment_id = int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])
                target_key_to_id[(table, row_key)] = segment_id
                reference_to_id.setdefault(ref, segment_id)
                inserted += 1
                order_index += 1
        conn.commit()
    finally:
        source.close()
    return inserted, target_key_to_id, reference_to_id


def looks_like_normalized(conn: sqlite3.Connection) -> bool:
    names = set(table_names(conn))
    return {"tipitaka_collections", "tipitaka_books", "tipitaka_segments"}.issubset(names)


def import_normalized(conn: sqlite3.Connection, path: Path) -> tuple[int, dict[tuple[str, str], int], dict[str, int]]:
    """Accept a DB already produced by this script or an equivalent adapter."""
    source = sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)
    key_to_id: dict[tuple[str, str], int] = {}
    refs: dict[str, int] = {}
    count = 0
    try:
        for row in source.execute("SELECT id,name_pali,name_en,name_vi,order_index FROM tipitaka_collections ORDER BY id"):
            conn.execute("INSERT OR IGNORE INTO tipitaka_collections(id,name_pali,name_en,name_vi,order_index) VALUES(?,?,?,?,?)", row)
        for row in source.execute("SELECT id,collection_id,code,name_pali,name_en,name_vi,order_index,metadata_json FROM tipitaka_books ORDER BY id"):
            conn.execute("INSERT OR IGNORE INTO tipitaka_books(id,collection_id,code,name_pali,name_en,name_vi,order_index,metadata_json) VALUES(?,?,?,?,?,?,?,?)", row)
        columns = {row[1] for row in source.execute("PRAGMA table_info(tipitaka_segments)")}
        source_table = "source_table" if "source_table" in columns else "NULL"
        source_row = "source_row_key" if "source_row_key" in columns else "NULL"
        rows = source.execute(
            f"SELECT id,book_id,section_id,reference,paragraph_no,pali_text,translation_en,translation_vi,translation_my,translation_th,order_index,{source_table},{source_row} FROM tipitaka_segments ORDER BY id"
        )
        for row in rows:
            conn.execute(
                """INSERT OR REPLACE INTO tipitaka_segments
                   (id,book_id,section_id,reference,paragraph_no,pali_text,translation_en,translation_vi,translation_my,translation_th,order_index,source_table,source_row_key)
                   VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                row,
            )
            segment_id = int(row[0])
            if row[11] is not None and row[12] is not None:
                key_to_id[(str(row[11]), str(row[12]))] = segment_id
            refs.setdefault(str(row[3]), segment_id)
            count += 1
        conn.commit()
    finally:
        source.close()
    return count, key_to_id, refs


def translation_text_column(columns: list[str]) -> Optional[str]:
    return find_column(columns, ("translation", "translated_text", "translation_text", "text", "content", "paragraph", "body", "html", "xml", "data"))


def import_translation(
    conn: sqlite3.Connection,
    path: Path,
    language: str,
    target_key_to_id: dict[tuple[str, str], int],
    reference_to_id: dict[str, int],
) -> int:
    source = sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)
    updated = 0
    try:
        if looks_like_normalized(source):
            # Normalized packs are useful when a developer supplies one DB
            # containing translations rather than separate source tables.
            for row in source.execute("SELECT id,translation_en,translation_vi,translation_my,translation_th FROM tipitaka_segments"):
                index = {"en": 1, "vi": 2, "my": 3, "th": 4}.get(language)
                if index is not None and row[index]:
                    cursor = conn.execute(
                        f"UPDATE tipitaka_segments SET {TARGET_TRANSLATION_COLUMNS[language]}=? WHERE id=?",
                        (clean_text(row[index]), row[0]),
                    )
                    updated += cursor.rowcount
            conn.commit()
            return updated

        for table, columns, text_col in select_text_table(source, language):
            key_col = find_column(columns, ("id", "rowid", "paragraph_id", "segment_id", "ref_id", "para_id", "text_id", "seq", "number"))
            ref_col = find_column(columns, ("reference", "ref", "citation", "section_ref", "book_code"))
            table_col = find_column(columns, ("source_table", "table", "book", "book_code", "document"))
            query = f"SELECT {quote_identifier(key_col) if key_col else 'rowid'}, {quote_identifier(ref_col) if ref_col else 'NULL'}, {quote_identifier(table_col) if table_col else 'NULL'}, {quote_identifier(text_col)} FROM {quote_identifier(table)}"
            for key, reference, source_table, text in source.execute(query):
                target_id = None
                if source_table is not None:
                    target_id = target_key_to_id.get((str(source_table), str(key)))
                if target_id is None:
                    target_id = target_key_to_id.get((table, str(key)))
                if target_id is None and reference is not None:
                    target_id = reference_to_id.get(clean_text(reference))
                if target_id is None:
                    continue
                value = clean_text(text)
                if not value:
                    continue
                fixed_column = TARGET_TRANSLATION_COLUMNS.get(language)
                if fixed_column:
                    conn.execute(f"UPDATE tipitaka_segments SET {fixed_column}=? WHERE id=?", (value, target_id))
                else:
                    conn.execute(
                        "INSERT OR REPLACE INTO tipitaka_translations(segment_id,language_code,text) VALUES(?,?,?)",
                        (target_id, language, value),
                    )
                updated += 1
        conn.commit()
    finally:
        source.close()
    return updated


def create_indexes(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE INDEX IF NOT EXISTS idx_segments_book ON tipitaka_segments(book_id);
        CREATE INDEX IF NOT EXISTS idx_segments_ref ON tipitaka_segments(reference);
        CREATE INDEX IF NOT EXISTS idx_segments_source ON tipitaka_segments(source_table,source_row_key);
        CREATE INDEX IF NOT EXISTS idx_translation_language ON tipitaka_translations(language_code);
        """
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR, help="Directory containing .db/.zip downloads")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Normalized SQLite output path")
    parser.add_argument("--pali", type=Path, help="Explicit Pāli source DB path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_dir = args.source_dir.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if not source_dir.exists():
        print(f"[ERROR] Source directory does not exist: {source_dir}", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="tipitaka-import-") as temporary:
        files = discover_source_files(source_dir, Path(temporary))
        if not files:
            print(f"[ERROR] No .db/.sqlite/.zip database found in {source_dir}", file=sys.stderr)
            return 2
        try:
            pali, translations = choose_sources(files, args.pali.resolve() if args.pali else None)
        except FileNotFoundError as error:
            print(f"[ERROR] {error}", file=sys.stderr)
            return 2
        if pali is None:
            # A developer may provide a normalized DB only; otherwise a source
            # DB without a Pāli filename is ambiguous and must not be guessed.
            normalized_file = next((file for file in files if _file_is_normalized(file)), None)
            if normalized_file is None:
                print("[ERROR] Pāli Roman DB not found. Use --pali or name it with 'pali'/'roman'.", file=sys.stderr)
                return 2
            pali = normalized_file

        output.parent.mkdir(parents=True, exist_ok=True)
        temporary_output = Path(temporary) / output.name
        conn = sqlite3.connect(temporary_output)
        try:
            build_target_schema(conn)
            if _file_is_normalized(pali):
                count, key_map, refs = import_normalized(conn, pali)
            else:
                count, key_map, refs = import_pali(conn, pali)
            print(f"[PALI] {pali.name}: imported {count:,} segments")
            for language, path in translations:
                if path.resolve() == pali.resolve():
                    continue
                changed = import_translation(conn, path, language, key_map, refs)
                print(f"[TRANS:{language}] {path.name}: updated {changed:,} segments")
            create_indexes(conn)
            conn.commit()
            total = int(conn.execute("SELECT COUNT(*) FROM tipitaka_segments").fetchone()[0])
            books = int(conn.execute("SELECT COUNT(*) FROM tipitaka_books").fetchone()[0])
            collections = int(conn.execute("SELECT COUNT(*) FROM tipitaka_collections").fetchone()[0])
            if total == 0 or books == 0 or collections == 0:
                print("[ERROR] Import produced no usable navigation data; output was not replaced.", file=sys.stderr)
                return 1
        finally:
            conn.close()

        # Atomic replacement avoids leaving a half-written DB after a failed or
        # interrupted import. Keep the old output until this point.
        backup = output.with_suffix(output.suffix + ".bak")
        if output.exists():
            if backup.exists():
                backup.unlink()
            output.replace(backup)
        shutil.move(str(temporary_output), str(output))

    print(f"[DONE] {output} ({output.stat().st_size:,} bytes)")
    return 0


def _file_is_normalized(path: Path) -> bool:
    try:
        conn = sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)
        names = set(table_names(conn))
        conn.close()
        return {"tipitaka_collections", "tipitaka_books", "tipitaka_segments"}.issubset(names)
    except sqlite3.Error:
        return False


if __name__ == "__main__":
    raise SystemExit(main())
