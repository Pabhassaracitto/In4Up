#!/usr/bin/env python3
"""
tool/generate_pali_en_vi_glossary.py — sinh ra:
  1. assets/glossary/buddhist_pali_en_vi.json — glossary Pali/EN→VI từ
     reference/meditation vocabulary.pdf (qua extract_meditation_vocab).
  2. docs/glossary/buddhist_terms_master_pi_en_vi.md — bảng nguồn 780 dòng
     cho chủ review (agent KHÔNG tự sửa — chủ sửa bảng, chạy lại script).
  3. docs/glossary/audit_extract_pi_en_vi.md — thống kê + danh sách dòng
     có vấn đề (thiếu PI, orphan, cell wrap, ...).

Luật entry (khớp schema in4up-translation-glossary-v1 của
assets/glossary/*.json hiện có):
  - Cặp (pi→vi) khi row có cả PI + VI.
  - Cặp (en→vi) khi row có cả EN + VI.
  - Cột MY: KHÔNG vào glossary (codepoint Burmese trong PDF sai — chỉ
    hiển thị trong master table để chủ đối chiếu).
  - Bỏ: source > 8 từ / > 60 ký tự (câu, không phải thuật ngữ),
    target rỗng, en kết thúc bằng dấu chấm (câu).
  - locked=true khi row sạch (term, không orphan, đủ cell, PI không phải
    tiếng Anh); locked=false khi cần review (orphan, PI không dấu, row
    thiếu my+zh, ...).
"""

import json
import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_meditation_vocab as ex  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_JSON = os.path.join(ROOT, "assets", "glossary", "buddhist_pali_en_vi.json")
OUT_MASTER = os.path.join(ROOT, "docs", "glossary", "buddhist_terms_master_pi_en_vi.md")
OUT_AUDIT = os.path.join(ROOT, "docs", "glossary", "audit_extract_pi_en_vi.md")


def norm_term(t):
    t = unicodedata.normalize("NFD", t or "")
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", t).strip().lower()


def words(t):
    return re.findall(r"[A-Za-z0-9\u00C0-\u1EF9\u1000-\u109F]+", t or "")


PURE_ASCII = re.compile(r"^[\x20-\x7e]+$")


def cell_ok(src, tgt, src_lang):
    """Entry có nên vào glossary không?"""
    if not src or not tgt:
        return False
    s = src.strip()
    sw, tw = words(s), words(tgt)
    if not sw or not tw:
        return False
    if not s[0].isalpha():
        return False  # mảnh "-to", ")"...
    if len(sw) > 8 or len(s) > 60:
        return False
    if len(tgt) > 90 or len(tw) > 14:
        return False
    if src_lang == "en":
        if s.endswith("."):
            return False
        if ex._looks_english(s) and len(sw) >= 5:
            return False  # câu mô tả, không phải thuật ngữ
    else:  # pi: loại mảnh EN lẫn vào ô PI ("Generate And Grow]")
        if PURE_ASCII.match(s) and ("[" in s or "]" in s or ex._looks_english(s)):
            return False
    return True


def pi_is_english(pi):
    return ex._looks_english(pi)


def en_drift(rec):
    """Khối phải (EN) lệch TRÊN anchor — pattern list dày, EN gán có thể
    thuộc row kế. Hoặc số thứ tự trong ô EN khác số trong ô PI. Dùng để
    đánh dấu ⚠ cho entry en→vi."""
    for d in rec.get("dylog", []):
        if "latin" in d["langs"] and d["x0"] > 60 and d["dy"] < -8:
            return True
    pn, en = rec.get("pi_num"), rec.get("en_num")
    if pn is not None and en is not None and pn != en:
        return True
    return False


def row_flags(rec):
    """Danh sách lý do locked=false / đánh dấu ⚠."""
    f = []
    if rec.get("orphan"):
        f.append("orphan (không có PI anchor)")
    if not rec.get("prose") and not rec.get("heading"):
        if not rec["pi"]:
            f.append("thiếu PI (bổ sung tay)")
        elif pi_is_english(rec["pi"]):
            f.append("PI cell là tiếng Anh")
        if not rec["my"] and not rec["zh"]:
            f.append("thiếu MY+ZH (row loãng)")
    return f


def build_entries(recs):
    entries = {}
    stats = {"pi_vi": 0, "en_vi": 0, "skip_long": 0, "skip_sentence": 0, "dup": 0}
    for rec in recs:
        if rec["kind"] != "term":
            continue
        flags = row_flags(rec)
        drift = en_drift(rec)
        if rec["pi"] and rec["vi"]:
            if not cell_ok(rec["pi"], rec["vi"], "pi"):
                stats["skip_long" if len(words(rec["pi"])) > 8 else "skip_sentence"] += 1
                continue
            if pi_is_english(rec["pi"]):
                continue  # pi cell thực là EN (dòng giải thích)
            key = ("pi", norm_term(rec["pi"]))
            stats["pi_vi"] += 1
            e = {
                "source": rec["pi"].strip(),
                "sourceLang": "pi",
                "targetLang": "vi",
                "target": rec["vi"].strip(),
                "locked": bool(not flags),
                "domain": "buddhist",
                "priority": 0,
                "origin": f"pdf-p{rec['page']}",
            }
            if flags:
                e["note"] = "; ".join(flags)
            if key in entries:
                stats["dup"] += 1
                continue
            entries[key] = e
        if rec["en"] and rec["vi"]:
            if not cell_ok(rec["en"], rec["vi"], "en"):
                stats["skip_sentence"] += 1
                continue
            key = ("en", norm_term(rec["en"]))
            stats["en_vi"] += 1
            en_flags = flags + (["EN lệch trên anchor (khối phải drift)"] if drift else [])
            e = {
                "source": rec["en"].strip(),
                "sourceLang": "en",
                "targetLang": "vi",
                "target": rec["vi"].strip(),
                "locked": bool(not en_flags),
                "domain": "buddhist",
                "priority": 0,
                "origin": f"pdf-p{rec['page']}",
            }
            if en_flags:
                e["note"] = "; ".join(en_flags)
            if key in entries:
                stats["dup"] += 1
                continue
            entries[key] = e
    return list(entries.values()), stats


def mark(text, flag, checked=True):
    if not text:
        return "—"
    if flag:
        return f"{text} ⚠"
    if checked:
        return f"{text} ✅"
    return text


def write_master(recs, path):
    lines = [
        "# Bảng thuật ngữ — Pali/EN→VI (trích xuất v2, x-column clustering)",
        "",
        "Nguồn: `reference/meditation vocabulary.pdf` (巴利－中文－英文－缅文, 121 trang, 2022.05.30).",
        "File NGUỒN cho `assets/glossary/buddhist_pali_en_vi.json` — chủ sửa bảng này,",
        "agent KHÔNG tự sửa. Chạy lại `python tool/generate_pali_en_vi_glossary.py` sau khi sửa.",
        "",
        "Dấu hiệu: ✅ = tin cậy (locked) · ⚠ = cần review (locked=false) · — = thiếu ·",
        " (cùm) = dòng giải thích, không vào glossary.",
        "Cột MY: codepoint Burmese trong PDF SAI (font hỏng) — chỉ để đối chiếu hình,",
        "KHÔNG dùng làm source. Cột ZH: chữ phồn thể đúng như PDF.",
        "",
        "| # | trang | Pali (pi) | Tiếng Việt (vi) | English (en) | Trung (zh) | Myanmar (my) |",
        "|---|---|---|---|---|---|---|",
    ]
    n = 0
    for rec in recs:
        if rec["kind"] not in ("term", "other"):
            continue
        n += 1
        pi = rec["pi"]
        vi = rec["vi"]
        en = rec["en"]
        zh = rec["zh"]
        my = rec["my"]
        if rec["kind"] == "other":
            pi = (pi + " (cùm)") if pi else "(cùm)"
        flags = row_flags(rec) if rec["kind"] == "term" else ["cùm"]
        if rec["kind"] == "term" and en_drift(rec):
            flags = flags + ["EN lệch trên anchor (khối phải drift)"]
        bad = bool(flags)
        lines.append(
            f"| {n} | {rec['page']} | {mark(pi, bad)} | {mark(vi, bad)} | "
            f"{mark(en, bad)} | {mark(zh, False)} | {mark(my, False, checked=False)} |"
        )
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return n


def write_audit(recs, stats, entries, path):
    import collections

    kinds = collections.Counter(r["kind"] for r in recs)
    terms = [r for r in recs if r["kind"] == "term"]
    out = [
        "# Audit — trích xuất PDF meditation vocabulary (v2, x-column clustering)",
        "",
        f"- Tổng dòng: {len(recs)} — {dict(kinds)}",
        f"- Glossary entries sinh ra: {len(entries)} "
        f"(pi→vi: {stats['pi_vi']}, en→vi: {stats['en_vi']}; "
        f"bỏ: {stats['skip_long'] + stats['skip_sentence']} câu/dài, dup: {stats['dup']})",
        f"- Row term thiếu PI: {sum(1 for r in terms if not r['pi'])}",
        f"- Row term thiếu VI: {sum(1 for r in terms if not r['vi'])}",
        f"- Row term thiếu EN: {sum(1 for r in terms if not r['en'])}",
        f"- Row term thiếu MY: {sum(1 for r in terms if not r['my'])}",
        "",
        "## Vấn đề đã biết của PDF (không phải lỗi parser)",
        "",
        "1. **Cột Burmese sai codepoint** (font NotoSansMyanmar trong PDF map glyph sai:",
        "   'Đ'→U+1012, 'N'→U+1014, ...) — MY chỉ dùng tham khảo, không vào glossary.",
        "2. **Một số ô PI/MY mất text** (font hỏng, chỉ còn 1-2 từ cuối: 'Visuddhi',",
        "   '8', '25'...) — dòng tương ứng ⚠ trong master, chủ bổ sung tay.",
        "3. **Ô Pali bị truncate** trong bản gốc: 'Ānāpānassat' (thiếu i), 'Sat'",
        "   (thiếu isambojjhaṅga), 'Pīt' (thiếu i), 'Sammāsat' (thiếu i), 'Jāt',",
        "   'Gilāna' — giữ nguyên theo PDF + đánh dấu ⚠.",
        "",
        "## Danh sách dòng cần review (⚠)",
        "",
        "| # | trang | PI | VI | EN | lý do |",
        "|---|---|---|---|---|---|",
    ]
    n = 0
    for rec in recs:
        if rec["kind"] not in ("term", "other"):
            continue
        n += 1
        flags = row_flags(rec) if rec["kind"] == "term" else ["cùm"]
        if rec["kind"] == "other":
            continue
        if flags:
            out.append(
                f"| {n} | {rec['page']} | {rec['pi'][:36] or '—'} | {rec['vi'][:24] or '—'} "
                f"| {rec['en'][:30] or '—'} | {'; '.join(flags)} |"
            )
    out.append("")
    out.append("## Dòng term KHÔNG có PI (bổ sung tay hoặc kiểm tra lại)")
    out.append("")
    out.append("| trang | VI | EN | ZH |")
    out.append("|---|---|---|---|")
    for rec in terms:
        if not rec["pi"]:
            out.append(
                f"| {rec['page']} | {rec['vi'][:40] or '—'} | {rec['en'][:40] or '—'} "
                f"| {rec['zh'][:16] or '—'} |"
            )
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


def main():
    import fitz

    doc = fitz.open(ex.PDF)
    recs = ex.extract(doc)
    entries, stats = build_entries(recs)
    # thứ tự ổn định: theo (sourceLang, source)
    entries.sort(key=lambda e: (e["sourceLang"], e["source"].lower()))
    payload = {
        "schema": "in4up-translation-glossary-v1",
        "note": (
            "Tu reference/meditation vocabulary.pdf (2022.05.30) — trích xuất v2 "
            "(tool/extract_meditation_vocab.py, x-column clustering + slot scoring). "
            "Chi pi→vi + en→vi (cột MY của PDF sai codepoint — khong dung). "
            "locked=false = can chu review (xem docs/glossary/audit_extract_pi_en_vi.md)."
        ),
        "entries": entries,
    }
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
        f.write("\n")
    n_master = write_master(recs, OUT_MASTER)
    write_audit(recs, stats, entries, OUT_AUDIT)
    print(f"entries: {len(entries)} (stats: {stats})")
    print(f"master rows: {n_master}")
    print(f"wrote: {OUT_JSON}")
    print(f"wrote: {OUT_MASTER}")
    print(f"wrote: {OUT_AUDIT}")


if __name__ == "__main__":
    main()
