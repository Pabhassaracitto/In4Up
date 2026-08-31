#!/usr/bin/env python3
"""
Import OpenTipitaka SQLite DB(s) into unified tipitaka.sqlite
"""
import sqlite3
import os
from pathlib import Path

SOURCE_DIR = Path("reference")
OUTPUT_DB = Path("assets/db/tipitaka.sqlite")
SOURCE_PALI_DB = SOURCE_DIR / "tipitaka-roman-pali.db"
SOURCE_VI_DB = SOURCE_DIR / "vietnamese_tipitaka_translation_data-2026-04-29.db"
SOURCE_EN_DB = SOURCE_DIR / "english_tipitaka_translation_data-2026-04-28.db"

def resolve_db(path: Path):
  if path.exists():
    return path
  folder_path = path / path.name
  if folder_path.exists() and folder_path.is_dir():
    for child in folder_path.iterdir():
      if child.is_file() and child.suffix == ".db":
        return child
  return None

def discover_tables(conn):
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    return [row[0] for row in cur.fetchall()]

def find_column(conn, table, candidates):
    cur = conn.cursor()
    cur.execute(f"PRAGMA table_info({table})")
    cols = [row[1] for row in cur.fetchall()]
    for c in candidates:
        if c in cols:
            return c
    for c in cols:
        for cand in candidates:
            if cand.replace("_","").lower() in c.replace("_","").lower():
                return c
    return None

def build_target_schema(conn):
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS tipitaka_collections (
      id INTEGER PRIMARY KEY, name_pali TEXT, name_en TEXT, name_vi TEXT, order_index INTEGER
    );
    CREATE TABLE IF NOT EXISTS tipitaka_books (
      id INTEGER PRIMARY KEY, collection_id INTEGER, code TEXT,
      name_pali TEXT, name_en TEXT, name_vi TEXT, order_index INTEGER, metadata_json TEXT
    );
    CREATE TABLE IF NOT EXISTS tipitaka_segments (
      id INTEGER PRIMARY KEY, book_id INTEGER, section_id INTEGER,
      reference TEXT, paragraph_no INTEGER,
      pali_text TEXT, translation_en TEXT, translation_vi TEXT,
      translation_my TEXT, translation_th TEXT, order_index INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_seg_book ON tipitaka_segments(book_id);
    CREATE INDEX IF NOT EXISTS idx_seg_ref ON tipitaka_segments(reference);
    """)

def import_pali(conn, source_path):
    if not source_path or not source_path.exists():
        print("[SKIP] Pali DB not found:", source_path)
        return
    src = sqlite3.connect(str(source_path))
    tables = discover_tables(src)
    print("[PALI] Tables:", tables)
    text_table = None
    for t in ["texts","paragraphs","pali_text","tipitaka_pali","data"]:
        if t in tables:
            text_table = t; break
    if not text_table:
        cur = src.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        best = None; best_n = 0
        for (t,) in cur.fetchall():
            try:
                cur.execute(f"SELECT COUNT(*) FROM {t}")
                n = cur.fetchone()[0]
                if n > best_n: best_n = n; best = t
            except: pass
        text_table = best
    if not text_table:
        print("[WARN] Could not find text table"); return
    print("[PALI] Using table:", text_table)
    cur = src.cursor()
    cur.execute(f"PRAGMA table_info({text_table})")
    cols = [row[1] for row in cur.fetchall()]
    ref_col = None
    for c in cols:
        if c.lower() in ("reference","ref","book_code","book_id","section_ref","citation"):
            ref_col = c; break
    text_col = None
    for c in ["pali_text","text","paragraph","content","pali","segment_text"]:
        if c in cols: text_col = c; break
    if not text_col: text_col = (cols[2] if len(cols) > 2 else cols[-1])
    para_col = None
    for c in ["paragraph_no","para","line_no","paragraph_number","segment_no","id"]:
        if c in cols: para_col = c; break
    if not para_col: para_col = "id"
    cur.execute(f"SELECT {para_col}, {text_col}, {ref_col if ref_col else 'NULL'} FROM {text_table} LIMIT 10000")
    target_cur = conn.cursor()
    inserted = 0
    for row in cur.fetchall():
        para_no = row[0] if row[0] is not None else inserted + 1
        pali = row[1] or ''
        ref = row[2] if ref_col and row[2] else f"SEG {inserted+1}"
        target_cur.execute("""
          INSERT OR IGNORE INTO tipitaka_segments (book_id, reference, paragraph_no, pali_text, order_index)
          VALUES (?, ?, ?, ?, ?)
        """, (0, str(ref), int(para_no) if isinstance(para_no, int) else inserted+1, str(pali), inserted))
        inserted += 1
    conn.commit()
    print(f"[PALI] Imported {inserted} segments")

def import_translation(conn, source_path, lang_col_map):
    if not source_path or not source_path.exists():
        print("[SKIP] Translation DB not found:", source_path)
        return
    src = sqlite3.connect(str(source_path))
    tables = discover_tables(src)
    print("[TRANS] Tables:", tables)
    ttable = None
    for t in ["translations","translation","text_trans","tipitaka_translation"]:
        if t in tables: ttable = t; break
    if not ttable:
        cur = src.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        for (t,) in cur.fetchall():
            try:
                cur.execute(f"PRAGMA table_info({t})")
                cols = [r[1] for r in cur.fetchall()]
                if any("translation" in c.lower() or "trans" in c.lower() for c in cols):
                    ttable = t; break
            except: pass
    if not ttable:
        print("[WARN] No translation table found"); return
    print("[TRANS] Using table:", ttable)
    cur = src.cursor()
    cur.execute(f"PRAGMA table_info({ttable})")
    cols = [row[1] for row in cur.fetchall()]
    text_col = None
    for c in ["translation","translated_text","text","vi_text","en_text"]:
        if c in cols: text_col = c; break
    if not text_col:
        for c in cols:
            if c.lower().endswith("_text") or c.lower() == "text":
                text_col = c; break
    if not text_col: text_col = cols[-1]
    link_col = None
    for c in cols:
        low = c.lower()
        if low in ("paragraph_id","segment_id","id","ref_id","para_id","text_id"):
            link_col = c; break
    if not link_col: link_col = cols[0]
    print("[TRANS] Link col:", link_col, "Text col:", text_col)
    cur.execute(f"SELECT {link_col}, {text_col} FROM {ttable} LIMIT 20000")
    target_cur = conn.cursor()
    updated = 0
    for row in cur.fetchall():
        link_val = row[0]
        txt = row[1] or ''
        target_cur.execute("""
          UPDATE tipitaka_segments SET translation_vi = ?
          WHERE id = (SELECT id FROM tipitaka_segments WHERE reference LIKE ? LIMIT 1)
        """, (str(txt), f"%{link_val}%"))
        if target_cur.rowcount > 0:
            updated += target_cur.rowcount
    conn.commit()
    print(f"[TRANS] Updated ~{updated} rows")

def main():
    repo_root = Path(__file__).resolve().parent.parent
    os.chdir(str(repo_root))
    ROOT = Path(".")
    (ROOT / "assets/db").mkdir(parents=True, exist_ok=True)
    out_path = ROOT / OUTPUT_DB
    if out_path.exists() and out_path.stat().st_size > 1_000_000:
        backup = out_path.with_suffix(out_path.suffix + ".bak")
        out_path.rename(backup)
        print("[INFO] Backed up existing DB to", backup)
    conn = sqlite3.connect(str(out_path))
    build_target_schema(conn)
    pali_resolved = resolve_db(SOURCE_PALI_DB) or SOURCE_PALI_DB
    import_pali(conn, pali_resolved)
    if SOURCE_VI_DB.exists() or (SOURCE_DIR / "vietnamese_tipitaka_translation_data.db").exists():
        vi_path = resolve_db(SOURCE_VI_DB) or SOURCE_VI_DB if SOURCE_VI_DB.exists() else (SOURCE_DIR / "vietnamese_tipitaka_translation_data.db")
        import_translation(conn, vi_path, "translation_vi")
    else:
        print("[INFO] Vietnamese DB not found")
    if SOURCE_EN_DB.exists():
        import_translation(conn, resolve_db(SOURCE_EN_DB) or SOURCE_EN_DB, "translation_en")
    conn.close()
    print("[DONE] Output DB:", out_path.resolve())

if __name__ == "__main__":
    main()