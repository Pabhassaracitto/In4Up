#!/usr/bin/env python3
"""
tool/extract_meditation_vocab.py — trích xuất bảng chuyên ngữ Phật học từ
reference/meditation vocabulary.pdf (巴利－中文－英文－缅文, 121 trang,
2022.05.30). Nguồn sự thật cho glossary Pali/EN→VI.

Layout (khảo sát span-level, PyMuPDF):
  - Pali: Calibri, có/không dấu Pali (ā ē ī ō ū ṅ  ṭ ḍ  ṃ).
  - Burmese: NotoSansMyanmar — ⚠ CODEPOINT SAI (font hỏng: "Đ"→U+1012,
    "N"→U+1014, ...) — Cột MY chỉ dùng THAM KHẢO, không làm source.
  - Vietnamese: Calibri có dấu Việt (Latin-1 à-ÿ trừ ñ, ăđơư, block
    U+1EA0-U+1EF9). Một số từ KHÔNG dấu ("Da", "Tay", "Con") → phân loại
    bằng VỊ TRÍ (giáng cấp: latin-trái y≥anchor+30 → VI).
  - Chinese: PingFangSC (CJK + fullwidth).
  - English: Calibri thường hoặc Tahoma 8pt (prose).

Variant hàng (row):
  A. 2 khối: trái x≈26-36 (Pali, Burmese +18, Việt +49), phải x≈177-240
     (Chinese -3.4 hoặc -27.8, English +24.4 hoặc 0).
  B. Inline: Pali+Chinese+Việt CÙNG dòng, Burmese+English dòng dưới
     (Pali có thể x≈90-165).
  - Danh sách đánh số: "N. Word" trong Pali/Việt, "NN word" My — strip.
  - Prose (cùm): 8pt mép trái (Chinese + Tahoma EN) + marker số 7.3pt.
  - Heading chương: 13pt ("Chapter/Chương/第..章").
  - Số trang: Tahoma 9pt y≈556.8. Row có thể gãy trang (hiếm) — cross-page.

Thuật toán:
  1. spans → lọc (số trang, prose, marker, dấu câu rời) → split span
     EN+VI lẫn nhau → lines (y±4pt, x gap≤15pt).
  2. PI-ANCHOR: span trái nhất là latin x0≤60, HOẶC dòng mixed (≥2 lang,
     span trái là latin). VI không dấu ("Da") cũng thành anchor giả →
     GIÁNG CẤP: anchor thuần latin-trái, không dấu Pali, cách anchor
     trước 38-62pt, dòng trước thiếu VI → gộp làm VI của row trước.
  3. Gán line vào row: ZH được phép TRÊN anchor (0≤anchor-y≤34);
     EN/MY/VI chỉ DƯỚI anchor (0≤y-anchor≤64).
  4. Cột: anchor line — latin trái → PI; dòng khác — x≤60: PI (y<anchor+30)
     / VI (y≥anchor+30); x>60: có zh/vi cùng dòng SAU → PI, khác → EN.
  5. Cross-page: row đầu trang thiếu PI (y<100) + row cuối trang trước
     (y>400) chưa khép → ghép.

Chạy:
  python tool/extract_meditation_vocab.py               # bảng mọi trang
  python tool/extract_meditation_vocab.py 3 8 14 63     # trang chọn
  python tool/extract_meditation_vocab.py --json rows.json
"""

import json
import re
import sys

import fitz  # PyMuPDF

PDF = "reference/meditation vocabulary.pdf"

# --- ngôn ngữ / ký tự ----------------------------------------------------

MYANMAR = re.compile(r"[\u1000-\u109F]")
MYANMAR_DIGIT = re.compile(r"[\u1040-\u1049\u1062-\u1064]")
CJK = re.compile(
    r"[\u2E80-\u2EFF\u3000-\u303F\u3400-\u4DBF\u4E00-\u9FFF"
    r"\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFFEF]"
)
# Dấu Việt: Latin-1 accented (À-ÿ) TRỪ ñ/Ñ (Pali), ăđơưĩ (Ext-A), block Việt
VIET_CHARS = re.compile(
    "[\u00C0-\u00D0\u00D2-\u00F0\u00F2-\u00FF\u0103\u0104\u0110\u0111\u0128\u0129"
    "\u01A0\u01A1\u01AF\u01B0\u1EA0-\u1EF9]"
)
# Dấu Pali (không trùng dấu Việt)
PALI_DIAG = re.compile(
    "[\u00D1\u00F1\u0100\u0101\u0112\u0113\u012A\u012B\u014C\u014D"
    "\u016A\u016B\u1E45\u1E46\u1E43\u1E44\u1E6D\u1E6C\u1E37\u1E38"
    "\u1E0F\u1E0E]"
)
PUNCT_ONLY = re.compile(r"^[^\w\s]*$")
LEAD_NUM = re.compile(r"^\d{1,2}[\.、]\s*")
CHAPTER_RE = re.compile(r"(Chapter|Chương|第.+章)", re.I)


def has_viet(text):
    return bool(VIET_CHARS.search(text))


def has_pali_diag(text):
    return bool(PALI_DIAG.search(text))


class Span:
    __slots__ = ("y0", "x0", "x1", "text", "font", "size", "lang")

    def __init__(self, y0, x0, x1, text, font, size):
        self.y0, self.x0, self.x1 = y0, x0, x1
        self.text, self.font, self.size = text, font, size
        if MYANMAR.search(text):
            self.lang = "my"
        elif CJK.search(text):
            self.lang = "zh"
        elif has_viet(text):
            self.lang = "vi"
        else:
            self.lang = "latin"


def split_latin_span(sp):
    """Tách span latin có lẫn EN thuần + VI có dấu thành các pseudo-span
    (vd 'Meditation subject Đề mục thiền'). Split tại khoảng trắng NƠI
    tính chất (VI hay không) của chữ KẾ TIẾP đổi."""
    if sp.lang != "latin" or not has_viet(sp.text):
        return [sp]
    text = sp.text
    stripped = text.strip()
    if not stripped:
        return [sp]
    parts = []
    start = 0
    cur_is_viet = VIET_CHARS.match(stripped[0]) is not None
    for i, ch in enumerate(stripped):
        if ch in " \t\n" and i + 1 < len(stripped):
            nxt_viet = VIET_CHARS.match(stripped[i + 1]) is not None
            if nxt_viet != cur_is_viet:
                seg = stripped[start:i].strip()
                if seg:
                    parts.append(Span(sp.y0, sp.x0, sp.x1, seg, sp.font, sp.size))
                start = i + 1
                cur_is_viet = nxt_viet
    seg = stripped[start:].strip()
    if seg:
        parts.append(Span(sp.y0, sp.x0, sp.x1, seg, sp.font, sp.size))
    return [p for p in parts if p.text]


class Line:
    __slots__ = ("y0", "x0", "x1", "spans", "size", "my_below")

    def __init__(self, y0, x0, size):
        self.y0, self.x0, self.x1, self.size = y0, x0, x0, size
        self.spans = []
        self.my_below = False

    def add(self, sp):
        self.spans.append(sp)
        self.x0 = min(self.x0, sp.x0)
        self.x1 = max(self.x1, sp.x1)

    @property
    def text(self):
        return "".join(s.text for s in self.spans)

    @property
    def langs(self):
        return {s.lang for s in self.spans}

    @property
    def first(self):
        return min(self.spans, key=lambda s: s.x0)

    @property
    def heading(self):
        return any(s.size >= 12.5 for s in self.spans)

    @property
    def bold(self):
        return any("Bold" in s.font for s in self.spans)

    def __repr__(self):
        return f"<L y={self.y0:.1f} x={self.x0:.1f} {''.join(self.langs)} {self.text[:36]!r}>"


# ---------------- tầng 1: spans → lines → rows ----------------

def get_spans(doc, pno):
    """Trả về (spans_bảng, prose_spans, markers)."""
    table, prose, markers = [], [], []
    for block in doc[pno].get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            for span in line["spans"]:
                t = span["text"].strip()
                if not t:
                    continue
                x0, y0, x1, y1 = span["bbox"]
                sz = span["size"]
                if sz < 10 and y0 > 550:  # số trang
                    continue
                # marker số nguồn (danh sách sách cuối PDF: "8." "9." 9pt)
                if 8.5 <= sz < 10 and re.fullmatch(r"\d{1,2}\.?", t):
                    markers.append(Span(y0, x0, x1, t, span["font"], sz))
                    continue
                # số đánh số danh sách đứng riêng ("3", "13", "10.") —
                # tách khỏi bảng để khỏi tạo anchor giả / ô số rác
                if re.fullmatch(r"\d{1,2}\.?", t):
                    markers.append(Span(y0, x0, x1, t, span["font"], sz))
                    continue
                if sz < 8.5:
                    # prose cùm (đáy trang), số trong câu Chinese (480,
                    # 10x48), marker số danh sách (1, 2, ...)
                    if x0 < 45 or not re.fullmatch(r"\d{1,2}", t):
                        prose.append(Span(y0, x0, x1, t, span["font"], sz))
                    else:
                        markers.append(Span(y0, x0, x1, t, span["font"], sz))
                    continue
                if PUNCT_ONLY.match(t) and len(t) <= 2:  # dấu câu rời
                    continue
                # bbox hỏng (rộng bất thường so với số chữ) — latin/VI chỉ
                if (
                    not MYANMAR.search(t)
                    and not CJK.search(t)
                    and (x1 - x0) > len(t) * 9 + 20
                ):
                    continue
                table.append(Span(y0, x0, x1, t, span["font"], sz))
    table.sort(key=lambda s: (s.y0, s.x0))
    return table, prose, markers


def to_lines(spans, y_tol=4.0, x_gap=25.0):
    """Gom span thành line: cùng y (±4pt) + x overlap HOẶC cách ≤25pt.
    (Inline row có khoảng trống 5-25pt giữa phân đoạn pi/zh/vi; hai khối
    trái/phải cách nhau ≥100pt nên an toàn.)"""
    spans = [sp for s in spans for sp in split_latin_span(s)]
    lines = []
    for sp in spans:
        target = None
        for ln in reversed(lines[-8:]):
            if abs(sp.y0 - ln.y0) > y_tol:
                continue
            if sp.x0 <= ln.x1 + x_gap and sp.x1 >= ln.x0 - x_gap:
                target = ln  # overlap hoặc liền kề → cùng line
                break
        if target is None:
            target = Line(sp.y0, sp.x0, sp.size)
            lines.append(target)
        target.add(sp)
    for ln in lines:
        ln.spans.sort(key=lambda s: s.x0)
    lines.sort(key=lambda l: (l.y0, l.x0))
    return lines


def is_pi_anchor(line):
    if not line.spans or line.heading:
        return False
    first = line.first
    if first.lang != "latin":
        return False
    if first.x0 <= 60:
        return True  # khối trái (PI — hoặc VI không dấu, xử lý giáng cấp)
    # inline mixed x>60: PI chỉ khi span đầu có dấu Pali HOẶC dòng có
    # Chinese (inline PI luôn đi kèm zh: "Nimitta 禪相"). EN+VI
    # ("Produced By Nutriment Sắc vật thực") không có zh/dấu → không anchor.
    if len(line.langs) >= 2:
        return has_pali_diag(first.text) or "zh" in line.langs
    # latin độc lập x>60: PI nếu có dấu Pali + dòng MY ngay dưới (+18pt).
    # (Loại EN chứa từ Pali: "First jhāna (absorption)" — không có MY
    #  ở +18pt vì MY của row nằm TRÊN dòng EN 6pt.)
    if has_pali_diag(line.text) and line.my_below:
        return True
    return False


def mark_my_below(lines):
    """Đặt line.my_below = True nếu có dòng Burmese ở y+14..y+22."""
    my_ys = [ln.y0 for ln in lines if "my" in ln.langs]
    for ln in lines:
        ln.my_below = any(14 <= my_y - ln.y0 <= 22 for my_y in my_ys)


def line_score(ln, anchor_y):
    """Điểm gán line vào anchor (nhỏ = tốt). None = ngoài cửa sổ.
    Slot chuẩn → 0; ngoài slot → khoảng cách; dòng trên anchor (zh/vi,
    offset khối phải -3.4/-27.8) → slot 0 hoặc dy_up+12.
    Slot VI: +48.9 (pitch 76.3) tới +69 (list dày pitch 73.4)."""
    dy_up = anchor_y - ln.y0
    dy_dn = ln.y0 - anchor_y
    best = None
    # dưới anchor (mọi ngôn ngữ, cửa sổ 70pt)
    if 0 <= dy_dn <= 70:
        d = None
        if "vi" in ln.langs and 40 <= dy_dn <= 70:
            d = 0.0
        else:
            for lang, slot in (("my", 18.2), ("en", 24.4)):
                if lang in ln.langs and abs(dy_dn - slot) <= 8:
                    d = abs(dy_dn - slot) * 0.1
                    break
            if d is None:
                d = dy_dn
        best = d
    # trên anchor: zh 34pt (slot -3.4/-27.8), vi 56pt (pattern p14)
    for g, win in (("zh", 34), ("vi", 56)):
        if g in ln.langs and 0 <= dy_up <= win:
            if g == "zh" and (abs(dy_up - 3.4) <= 8 or abs(dy_up - 27.8) <= 8):
                d = 0.0
            else:
                d = dy_up + 12
            if best is None or d < best:
                best = d
    return best


def build_rows(lines):
    mark_my_below(lines)
    anchors = [ln for ln in lines if is_pi_anchor(ln)]
    rows = []
    for a in anchors:
        rows.append({"anchor": a, "lines": [a]})

    def has_lang(r, g):
        return any(s.lang == g for l in r["lines"] for s in l.spans)

    first_en_y = {}  # id(row) -> y của dòng EN đầu tiên đã gán

    def en_line_score(ln, r):
        """EN riêng (x>60): cell của row (dưới, chưa có EN) / wrap
        (+14..+26 sau EN đầu) / cell EN TRÊN anchor (offset -24.5 tới
        -48.9, pattern p50)."""
        a_y = r["anchor"].y0
        dy_dn = ln.y0 - a_y
        dy_up = a_y - ln.y0
        best = None
        fe = first_en_y.get(id(r))
        if 0 <= dy_dn <= 70:
            if fe is not None and 14 <= ln.y0 - fe <= 26:
                d = 0.0  # wrap của EN row hiện tại
            elif fe is None:
                # cell EN của row này — slot +24.4 (±8)
                d = abs(dy_dn - 24.4) * 0.1 if abs(dy_dn - 24.4) <= 8 else dy_dn
            else:
                d = dy_dn + 30  # row đã có EN, không phải wrap
            best = d
        if 0 <= dy_up <= 34:
            d = dy_up if fe is None else dy_up + 12
            if best is None or d < best:
                best = d
        return best

    for ln in lines:
        if any(ln is r["anchor"] for r in rows):
            continue
        is_en = ln.langs == {"latin"} and ln.x0 > 60
        # Pattern heading (zh → vi → en): EN đứng SẮP VI 24.5pt — gán thẳng
        # về row chứa dòng VI đó (p4: "The four factors..." sau "Bốn chi
        # pháp..."; p50 "Descend wind" KHÔNG có VI ở E-24.5 → qua scoring).
        direct = None
        if is_en:
            target_vy = ln.y0 - 24.5
            for ri, r in enumerate(rows):
                for l in r["lines"]:
                    if "vi" in l.langs and abs(l.y0 - target_vy) <= 5:
                        direct = ri
                        break
                if direct is not None:
                    break
        cands = []
        for ri, r in enumerate(rows):
            if ri == direct:
                s = 0.0  # gán thẳng (bỏ qua cửa sổ khoảng cách)
            else:
                s = (
                    en_line_score(ln, r)
                    if is_en
                    else line_score(ln, r["anchor"].y0)
                )
                if s is None:
                    continue
            dy_dn = ln.y0 - r["anchor"].y0
            cands.append(
                (s, max(0.0, dy_dn), abs(ln.y0 - r["anchor"].y0), ri)
            )
        if not cands:
            rows.append({"anchor": ln, "lines": [ln], "orphan": True})
            continue
        cands.sort()
        best = rows[cands[0][3]]
        # Dòng zh/vi nằm TRÊN anchor thắng bằng fallback (không khớp slot)
        # nhưng có row DƯỚI trong cửa sổ đã có sẵn ngôn ngữ đó → line là
        # cell wrap của row dưới — gán về row dưới (vd VI wrap +69pt).
        s_best = cands[0][0]
        if (
            not is_en
            and s_best > 0
            and ln.y0 < best["anchor"].y0
            and (ln.langs & {"zh", "vi"})
        ):
            for s2, base2, d2, ri in cands[1:]:
                r = rows[ri]
                if ln.y0 <= r["anchor"].y0:
                    continue
                for g in ("vi", "zh"):
                    if g in ln.langs and has_lang(r, g):
                        best = r
                        break
                else:
                    continue
                break
        best["lines"].append(ln)
        if is_en and id(best) not in first_en_y:
            first_en_y[id(best)] = ln.y0
    rows.sort(key=lambda r: r["anchor"].y0)
    # giáng cấp VI không dấu: anchor giả (thuần latin trái, không dấu Pali)
    # cách anchor trước 38-62pt mà row trước thiếu VI → VI của row trước
    i = 1
    while i < len(rows):
        r = rows[i]
        a = r["anchor"]
        prev = rows[i - 1]
        pa = prev["anchor"]
        prev_has_vi = any(
            s.lang == "vi" or (s.lang == "latin" and has_viet(s.text))
            for l in prev["lines"]
            for s in l.spans
        )
        if (
            a.x0 <= 60
            and not a.heading
            and a.langs == {"latin"}
            and not any(has_pali_diag(s.text) for s in a.spans)
            and 38 <= a.y0 - pa.y0 <= 62
            and not prev_has_vi
            and len(r["lines"]) == 1
        ):
            prev["lines"].extend(r["lines"])
            rows.pop(i)
            i = max(1, i - 1)  # row trước nay có thể cũng là ứng viên
        else:
            i += 1
    return rows


def row_columns(row, page_no):
    a = row["anchor"]
    # orphan anchor: dòng latin độc lập x>60, không dấu Pali → EN (row
    # thiếu PI, vd dòng giải thích đứng giữa trang)
    orphan_en_anchor = bool(
        row.get("orphan")
        and a.x0 > 60
        and a.langs == {"latin"}
        and not has_pali_diag(a.text)
    )
    has_bold = any(ln.bold for ln in row["lines"])
    pi, my, vi, zh, en = [], [], [], [], []
    dy_log = []  # (lang, dy) — kiểm tra drift khối phải
    for idx, ln in enumerate(row["lines"]):
        is_anchor_line = ln is a
        dy = ln.y0 - a.y0
        # latin TRÁI NHẤT của line (cho quy tắc PI đầu line)
        first_latin = next((s for s in ln.spans if s.lang == "latin"), None)
        # mode theo thứ tự span TRÊN ANCHOR LINE: PI liên tiếp cho tới
        # khi gặp zh/vi (sau đó latin là EN) — "Maggāmagga... Visuddhi"
        # là PI; "...kalāpa 時節⽣ Opaque And Produced" → EN sau zh.
        cjk_gap = ln.first.lang in ("zh", "vi") if is_anchor_line else False
        seen_latin = False
        for sp in ln.spans:
            if sp.lang in ("zh", "vi"):
                if is_anchor_line and seen_latin:
                    cjk_gap = True
                if sp.lang == "zh":
                    zh.append(sp.text)
                else:
                    vi.append(sp.text)
                continue
            if sp.lang == "my":
                my.append(sp.text)
                continue
            # latin
            if is_anchor_line:
                if orphan_en_anchor and sp is first_latin:
                    en.append(sp.text)
                    cjk_gap = True
                    seen_latin = True
                    continue
                if (not cjk_gap) or has_pali_diag(sp.text) and sp.x0 <= 60:
                    pi.append(sp.text)
                else:
                    en.append(sp.text)
                cjk_gap = False
                seen_latin = True
                continue
            # dòng KHÔNG phải anchor line
            if has_pali_diag(sp.text):
                # Pali có dấu — Pali, TRỪ EN khối phải (vd "First jhāna")
                if sp.x0 <= 60:
                    pi.append(sp.text)
                else:
                    en.append(sp.text)
                continue
            if sp.x0 <= 60:
                if dy < 30:
                    pi.append(sp.text)
                else:
                    vi.append(sp.text)
            else:
                # PI đầu line inline: không có latin nào trước nó trong
                # line + có zh/vi SAU nó
                prev_latin = any(
                    s.lang == "latin" and s.x0 < sp.x0 for s in ln.spans
                )
                has_zh_vi_after = any(
                    s.x0 > sp.x1 and s.lang in ("zh", "vi") for s in ln.spans
                )
                if (not prev_latin) and has_zh_vi_after:
                    pi.append(sp.text)
                else:
                    en.append(sp.text)
    raw_pi = " ".join(pi).strip()
    raw_en = " ".join(en).strip()
    pi = LEAD_NUM.sub("", raw_pi)
    vi = LEAD_NUM.sub("", " ".join(vi).strip())
    en_t = LEAD_NUM.sub("", raw_en)
    my_t = re.sub(r"^[\u1040-\u1049\u1062-\u1064\s\.]+", "", " ".join(my).strip())
    # log offset từng line so với anchor — phát hiện drift khối phải
    for ln in row["lines"]:
        dy_log.append(
            {
                "langs": "".join(sorted(ln.langs)),
                "dy": round(ln.y0 - a.y0, 1),
                "x0": round(ln.x0, 1),
            }
        )
    m_pi = re.match(r"^(\d{1,2})[\.、]\s*", raw_pi)
    m_en = re.match(r"^(\d{1,2})[\.、]\s*", raw_en)
    return {
        "page": page_no,
        "y": round(a.y0, 1),
        "pi": pi,
        "my": my_t,
        "vi": vi,
        "zh": " ".join(zh).strip(),
        "en": en_t,
        "orphan": bool(row.get("orphan")),
        "heading": a.heading,
        "bold": has_bold,
        "nlines": len(row["lines"]),
        "dylog": dy_log,
        "pi_num": int(m_pi.group(1)) if m_pi else None,
        "en_num": int(m_en.group(1)) if m_en else None,
    }


def build_prose(prose_spans, page_no):
    if not prose_spans:
        return None
    ordered = sorted(prose_spans, key=lambda s: (s.y0, s.x0))
    return {
        "page": page_no,
        "y": round(ordered[0].y0, 1),
        "pi": "",
        "my": "",
        "vi": " ".join(s.text for s in ordered if s.lang == "vi"),
        "zh": " ".join(s.text for s in ordered if s.lang == "zh"),
        "en": " ".join(s.text for s in ordered if s.lang == "latin"),
        "orphan": False,
        "heading": False,
        "nlines": 0,
        "prose": True,
    }


EN_FUNC = {
    "the", "a", "an", "of", "to", "and", "or", "in", "on", "by", "for",
    "with", "no", "are", "is", "refer", "same", "all", "each", "only",
    "types", "kind", "kinds", "part", "parts", "called", "known",
}


def _looks_english(text):
    words = [w.lower().strip(".,;:()") for w in text.split()]
    if not words:
        return False
    hit = sum(1 for w in words if w in EN_FUNC)
    return hit >= 2 or (hit >= 1 and len(words) >= 4)


def classify(rec):
    if rec.get("prose"):
        return "prose"
    if rec.get("heading"):
        return "heading"
    text = rec["pi"] + rec["en"] + rec["vi"] + rec["zh"]
    if not rec["my"] and not rec["pi"] and CHAPTER_RE.search(text):
        return "heading"
    # heading mục (bOLD, không PI/MY — vd "The 28 material phenomena",
    # "The Fifty-two Factors At A Glance"). Row thuật ngữ đánh số (Sīmā-
    # sambheda, Cattāro mahābhūta...) CŨNG BOLD nhưng có PI → term.
    if rec.get("bold") and not rec["pi"] and not rec["my"]:
        return "heading"
    # dòng giải thích (cùm): PI cell là tiếng Anh, hoặc zh dẫn trích
    # nguồn sách (《》) — không phải thuật ngữ
    if _looks_english(rec["pi"]) or "《" in rec["zh"] or "》" in rec["zh"]:
        return "other"
    if rec["pi"] or (rec["en"] and rec["vi"]) or (rec["zh"] and rec["vi"]):
        return "term"
    if rec["zh"] or rec["en"] or rec["vi"] or rec["my"]:
        return "other"
    return "empty"


def extract(doc):
    all_recs = []
    for pno in range(1, len(doc)):
        table, prose, markers = get_spans(doc, pno)
        lines = to_lines(table)
        rows = build_rows(lines)
        recs = [row_columns(r, pno + 1) for r in rows]
        # cross-page: row cuối trang trước (chưa đủ cell) + row đầu trang
        # kế (y<140, không PI/heading/bold) → ghép: điền cell trống, nối
        # EN/VI wrap. Cho phép 1 trang trống giữa (p78).
        dropped = 0
        while (
            recs
            and not recs[0]["pi"]
            and recs[0]["y"] < 140
            and not recs[0].get("prose")
            and not recs[0].get("heading")
            and not recs[0].get("bold")
        ):
            last = next(
                (
                    r
                    for r in reversed(all_recs)
                    if r.get("kind") == "term"
                    and r["page"] >= pno - 1
                ),
                None,
            )
            if last is None or last["y"] <= 300:
                break
            if last["vi"] and last["en"] and last["my"]:
                break  # row cuối đã đủ — không phải continuation
            first = recs[0]
            moved = False
            for k in ("my", "zh"):
                if first[k] and not last[k]:
                    last[k] = first[k]
                    moved = True
            if first["vi"] and not last["vi"]:
                last["vi"] = first["vi"]
                moved = True
            elif first["vi"] and last["vi"]:
                last["vi"] = (last["vi"] + " " + first["vi"]).strip()
                moved = True
            if first["en"]:
                last["en"] = (last["en"] + " " + first["en"]).strip()
                moved = True
            if moved:
                recs = recs[1:]
                dropped += 1
                continue
            break
        prose_rec = build_prose(prose, pno + 1)
        for m in markers:
            if recs:
                nearest = min(recs, key=lambda r: abs(r["y"] - m.y0))
                nearest.setdefault("num", []).append(m.text)
        if prose_rec:
            recs.append(prose_rec)
        for rec in recs:
            rec["kind"] = classify(rec)
            all_recs.append(rec)
    return all_recs


def main():
    doc = fitz.open(PDF)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    json_out = None
    if "--json" in sys.argv:
        json_out = sys.argv[sys.argv.index("--json") + 1]
    pages = [int(a) - 1 for a in args if a.isdigit()]
    all_recs = extract(doc)
    if pages:
        all_recs = [r for r in all_recs if r["page"] in {p + 1 for p in pages}]
    if json_out:
        with open(json_out, "w", encoding="utf-8") as f:
            json.dump(all_recs, f, ensure_ascii=False, indent=1)
        print(f"wrote {json_out}: {len(all_recs)} rows", file=sys.stderr)
    else:
        for rec in all_recs:
            print(
                f"p{rec['page']:3d} y={rec['y']:6.1f} [{rec['kind']:7s}] "
                f"PI:{rec['pi'][:38]:38s} MY:{rec['my'][:12]:12s} "
                f"VI:{rec['vi'][:24]:24s} ZH:{rec['zh'][:12]:12s} "
                f"EN:{rec['en'][:34]}"
            )


if __name__ == "__main__":
    main()
