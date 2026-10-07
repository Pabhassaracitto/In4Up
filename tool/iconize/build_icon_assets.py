#!/usr/bin/env python3
"""ICONIZE-001a — Build tool sinh core asset cho Iconize Engine.

Sinh 4 file vào assets/iconize/ (format đặc tả trong tool/iconize/README.md,
loader Dart ở lane ICONIZE-001b phải đọc đúng format này):

  concreteness.bin   — bảng word → (concreteness, POS), sorted, binary-search
  icon_index.bin     — bảng "lemma|POS" → iconId, sorted, binary-search
  icons_bundle.bin   — TOC + SVG bytes (Twemoji), iconId = chỉ số TOC
  irregular_lemmas.json — copy từ tool/iconize/data/irregular_lemmas.json

Nguồn dữ liệu (tải thủ công / git sparse clone — KHÔNG commit vào repo):
  --brysbaert  Concreteness_ratings_Brysbaert_et_al_BRM.txt (Brysbaert et al.
               2014, Behavior Research Methods — có cột SUBTLEX + Dom_Pos)
  --cldr       cldr-annotations-full/annotations/en/annotations.json
               (unicode-org/cldr-json)
  --twemoji    thư mục assets/svg của github.com/jdecked/twemoji

Luật chọn từ (ADR-0013, blueprint mục 10):
  - Danh từ (Dom_Pos=Noun)      : Conc.M >= 4.0
  - Tính từ (Dom_Pos=Adjective) : Conc.M >= 4.5
  - Động từ: KHÔNG vào index v1 (chốt #1 — default giữ chữ; Action Pack = v2)
  - Xếp hạng theo SUBTLEX giảm dần, cắt tại --max-icons (mặc định 2000)

Mọi file .bin mở đầu bằng Magic Header 8 byte ASCII "ICNB0001" + u32 version.
Little-endian toàn bộ. Chạy: python3 tool/iconize/build_icon_assets.py --help
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import sys
from pathlib import Path

MAGIC = b"ICNB0001"
VERSION = 1

POS_NOUN, POS_VERB, POS_ADJ, POS_OTHER = 0, 1, 2, 3
POS_LABEL = {POS_NOUN: "NOUN", POS_ADJ: "ADJ"}  # chỉ 2 loại vào icon_index v1

# Chỉ giữ concreteness >= ngưỡng này trong concreteness.bin (engine chỉ cần
# membership quanh ngưỡng 4.0/4.5; từ mờ nghĩa hơn 3.5 chắc chắn giữ chữ).
CONC_KEEP_MIN = 3.5
CONC_NOUN_MIN = 4.0
CONC_ADJ_MIN = 4.5

SKIN_TONES = set(range(0x1F3FB, 0x1F400))
REGIONAL = set(range(0x1F1E6, 0x1F200))
FE0F = 0xFE0F


def parse_brysbaert(path: Path):
    """→ dict word -> (conc: float, pos: int, subtlex: int). Chỉ từ đơn."""
    out = {}
    pos_map = {"Noun": POS_NOUN, "Verb": POS_VERB, "Adjective": POS_ADJ}
    with path.open(encoding="utf-8", errors="replace") as f:
        header = f.readline().rstrip("\r\n").split("\t")
        idx = {name: i for i, name in enumerate(header)}
        for line in f:
            cols = line.rstrip("\r\n").split("\t")
            if len(cols) < len(header):
                continue
            word = cols[idx["Word"]].strip().lower()
            if cols[idx["Bigram"]] != "0":  # bỏ cụm 2 từ
                continue
            if not re.fullmatch(r"[a-z][a-z'-]*", word):
                continue
            try:
                conc = float(cols[idx["Conc.M"]])
                subtlex = int(float(cols[idx["SUBTLEX"]]))
            except ValueError:
                continue
            pos = pos_map.get(cols[idx["Dom_Pos"]].strip(), POS_OTHER)
            prev = out.get(word)
            if prev is None or subtlex > prev[2]:
                out[word] = (conc, pos, subtlex)
    return out


def parse_cldr(path: Path):
    """→ dict emoji -> (tts: str, keywords: set[str])."""
    data = json.loads(path.read_text(encoding="utf-8"))
    ann = data["annotations"]["annotations"]
    out = {}
    for emoji, entry in ann.items():
        cps = [ord(c) for c in emoji]
        if any(cp in SKIN_TONES or cp in REGIONAL for cp in cps):
            continue
        tts = (entry.get("tts") or [""])[0].strip().lower()
        kws = {k.strip().lower() for k in entry.get("default") or []}
        if tts or kws:
            out[emoji] = (tts, kws)
    return out


def twemoji_file(twemoji_dir: Path, emoji: str) -> Path | None:
    """Tìm file SVG theo quy ước tên của Twemoji (thử có & không FE0F)."""
    cps = [ord(c) for c in emoji]
    cand = [cps, [c for c in cps if c != FE0F]]
    for seq in cand:
        if not seq:
            continue
        p = twemoji_dir / ("-".join(f"{c:x}" for c in seq) + ".svg")
        if p.is_file():
            return p
    return None


def score(word: str, tts: str, kws: set[str]) -> int:
    if tts == word:
        return 100
    if tts == f"{word} face":
        return 90
    if word in kws:
        return 60
    return 0


def pick_icons(bry, cldr, twemoji_dir: Path, max_icons: int):
    """→ (index: dict key->icon_name, bundle: dict icon_name->svg_path)."""
    # ứng viên: (−score, −subtlex, số codepoint, tên file) để sort tất định
    candidates = []
    for word, (conc, pos, subtlex) in bry.items():
        if pos == POS_NOUN and conc >= CONC_NOUN_MIN:
            pass
        elif pos == POS_ADJ and conc >= CONC_ADJ_MIN:
            pass
        else:
            continue
        best = None
        for emoji, (tts, kws) in cldr.items():
            s = score(word, tts, kws)
            if s == 0:
                continue
            svg = twemoji_file(twemoji_dir, emoji)
            if svg is None:
                continue
            # tie-break: tts ít từ hơn = emoji generic hơn ("automobile"
            # thắng "racing car" cho keyword "car"), rồi ít codepoint, rồi tên
            key = (-s, len(tts.split()), len(emoji), svg.stem)
            if best is None or key < best[0]:
                best = (key, svg)
        if best is not None:
            candidates.append((-best[0][0], subtlex, word, pos, best[1]))
    # ưu tiên: score cao → SUBTLEX cao → chữ cái (tất định)
    candidates.sort(key=lambda t: (-t[0], -t[1], t[2]))
    index: dict[str, str] = {}
    bundle: dict[str, Path] = {}
    for _s, _f, word, pos, svg in candidates:
        if len(index) >= max_icons:
            break
        index[f"{word}|{POS_LABEL[pos]}"] = svg.stem
        bundle.setdefault(svg.stem, svg)
    return index, bundle


# ---------- writers (format: xem tool/iconize/README.md) ----------

def _header(count: int) -> bytes:
    return MAGIC + struct.pack("<II", VERSION, count)


def write_concreteness(path: Path, bry):
    rows = sorted(
        (w, conc, pos)
        for w, (conc, pos, _f) in bry.items()
        if conc >= CONC_KEEP_MIN
    )
    blob = bytearray()
    offsets = []
    for w, conc, pos in rows:
        offsets.append(len(blob))
        wb = w.encode("utf-8")
        blob += struct.pack("<H", len(wb)) + wb
        blob += struct.pack("<BB", round(conc * 10), pos)
    out = _header(len(rows)) + struct.pack(f"<{len(rows)}I", *offsets) + blob
    path.write_bytes(out)
    return len(rows)


def write_icon_index(path: Path, index: dict[str, str], icon_ids: dict[str, int]):
    rows = sorted(index.items())
    blob = bytearray()
    offsets = []
    for key, icon_name in rows:
        offsets.append(len(blob))
        kb = key.encode("utf-8")
        blob += struct.pack("<H", len(kb)) + kb
        blob += struct.pack("<H", icon_ids[icon_name])
    out = _header(len(rows)) + struct.pack(f"<{len(rows)}I", *offsets) + blob
    path.write_bytes(out)
    return len(rows)


def write_icons_bundle(path: Path, bundle: dict[str, Path]):
    names = sorted(bundle)  # iconId = chỉ số trong danh sách sorted này
    toc = bytearray()
    name_blob = bytearray()
    data_blob = bytearray()
    for name in names:
        data = bundle[name].read_bytes()
        nb = name.encode("ascii")
        toc += struct.pack(
            "<IIIH", len(data_blob), len(data), len(name_blob), len(nb)
        )
        name_blob += nb
        data_blob += data
    out = _header(len(names)) + bytes(toc) + bytes(name_blob) + bytes(data_blob)
    path.write_bytes(out)
    return {n: i for i, n in enumerate(names)}


# ---------- verify (đọc lại chính file vừa ghi) ----------

def _read_header(b: bytes, label: str) -> int:
    assert b[:8] == MAGIC, f"{label}: magic sai"
    version, count = struct.unpack_from("<II", b, 8)
    assert version == VERSION, f"{label}: version {version}"
    return count


def _lookup_sorted(b: bytes, key: bytes):
    """Binary search chung cho concreteness.bin / icon_index.bin."""
    count = struct.unpack_from("<I", b, 12)[0]
    off0 = 16
    blob0 = off0 + 4 * count
    lo, hi = 0, count - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        rec = blob0 + struct.unpack_from("<I", b, off0 + 4 * mid)[0]
        klen = struct.unpack_from("<H", b, rec)[0]
        k = b[rec + 2 : rec + 2 + klen]
        if k == key:
            return rec + 2 + klen
        if k < key:
            lo = mid + 1
        else:
            hi = mid - 1
    return None


def verify(out_dir: Path):
    conc = (out_dir / "concreteness.bin").read_bytes()
    idx = (out_dir / "icon_index.bin").read_bytes()
    pack = (out_dir / "icons_bundle.bin").read_bytes()
    n_conc = _read_header(conc, "concreteness")
    n_idx = _read_header(idx, "icon_index")
    n_icons = _read_header(pack, "icons_bundle")

    p = _lookup_sorted(conc, b"cat")
    assert p is not None, "concreteness: thiếu 'cat'"
    c10, pos = struct.unpack_from("<BB", conc, p)
    assert c10 >= 40 and pos == POS_NOUN, f"cat: conc={c10/10} pos={pos}"
    assert _lookup_sorted(conc, b"freedom") is None, "'freedom' phải bị loại"

    p = _lookup_sorted(idx, b"cat|NOUN")
    assert p is not None, "icon_index: thiếu 'cat|NOUN'"
    icon_id = struct.unpack_from("<H", idx, p)[0]
    assert icon_id < n_icons
    # đọc SVG của cat từ bundle
    toc_at = 16 + 14 * icon_id
    d_off, d_len, _n_off, _n_len = struct.unpack_from("<IIIH", pack, toc_at)
    name_blob0 = 16 + 14 * n_icons
    # data blob bắt đầu sau toàn bộ name blob
    total_names = sum(
        struct.unpack_from("<IIIH", pack, 16 + 14 * i)[3] for i in range(n_icons)
    )
    svg = pack[name_blob0 + total_names + d_off :][:d_len]
    assert svg.lstrip()[:4] == b"<svg", "bundle: payload không phải SVG"

    lemmas = json.loads((out_dir / "irregular_lemmas.json").read_text("utf-8"))
    assert lemmas.get("mice") == "mouse" and lemmas.get("caught") == "catch"
    print(
        f"VERIFY OK — concreteness={n_conc} từ, index={n_idx} khóa, "
        f"bundle={n_icons} icon, irregular={len(lemmas)} dạng"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--brysbaert", type=Path, required=True)
    ap.add_argument("--cldr", type=Path, required=True)
    ap.add_argument("--twemoji", type=Path, required=True, help="thư mục assets/svg")
    ap.add_argument("--out", type=Path, default=Path("assets/iconize"))
    ap.add_argument("--max-icons", type=int, default=2000)
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    bry = parse_brysbaert(args.brysbaert)
    cldr = parse_cldr(args.cldr)
    print(f"Brysbaert: {len(bry)} từ đơn · CLDR: {len(cldr)} emoji chú giải")

    index, bundle = pick_icons(bry, cldr, args.twemoji, args.max_icons)
    print(f"Match được {len(index)} khóa lemma|POS → {len(bundle)} icon duy nhất")

    icon_ids = write_icons_bundle(args.out / "icons_bundle.bin", bundle)
    write_icon_index(args.out / "icon_index.bin", index, icon_ids)
    n = write_concreteness(args.out / "concreteness.bin", bry)
    print(f"concreteness.bin giữ {n} từ (Conc.M >= {CONC_KEEP_MIN})")

    src = Path(__file__).parent / "data" / "irregular_lemmas.json"
    shutil.copyfile(src, args.out / "irregular_lemmas.json")

    for f in sorted(args.out.iterdir()):
        print(f"  {f.name:24} {f.stat().st_size:>9,} B")
    verify(args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
