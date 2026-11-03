#!/usr/bin/env python3
"""Probe thiết kế bộ phân tích tên pháp thoại (PLAN-042) trên TÊN THẬT.

Chỉ để khảo sát: in ra metadata đoán được từ từng tên, để chốt luật
"đoán an toàn" trước khi viết Dart. Không phải test CI.
"""
import csv
import re
import sys

ORDINAL = re.compile(r'^\s*(?:[Bb](\d{1,2})|(\d{1,3}))\s*[.)\-]\s*')
DATE8 = re.compile(r'(?<!\d)(20\d{6})(?!\d)')
DATE6 = re.compile(r'(?<!\d)(\d{6})(?!\d)')
PART = re.compile(r'(?:Phần|Phan|P)\s*(\d{1,2})(?!\d)', re.I)
RANGE = re.compile(r'^\s*(\d{1,3})\s*-\s*(\d{1,3})')
DUR = re.compile(r'\((\d{1,3})\s*(?:phút|phut)?\s*\)', re.I)
YEAR = re.compile(r'(?<!\d)(19|20)(\d{2})(?!\d)')
SPEAKER = re.compile(
    r'(Sayadaw\s+U\s+[A-Za-zÀ-ỹĀ-ſ.\u0100-\u024F]+'
    r'|Pa[- ]Auk\s+Sayadawgyi'
    r'|Sayalay\s+[A-Za-zÀ-ỹĀ-ſ]+'
    r'|Sayadaw\s+[A-Z]?[a-z]*[A-Za-zÀ-ỹ]*'
    r'|\bSU\s+[A-Z][A-Za-z.]*)'
)
LANG = [
    ('vi', re.compile(r'Tiếng Việt|\bVi\b|Vi-En', re.I)),
    ('bi', re.compile(r'Song ngữ|En-Vi|En - Vi', re.I)),
    ('en', re.compile(r'\bEnglish\b', re.I)),
]
NOISE = re.compile(r'\b(end sound|final)\b', re.I)


def parse_date(raw):
    m = DATE8.search(raw)
    if m:
        s = m.group(1)
        return f'{s[0:4]}-{s[4:6]}-{s[6:8]}', 'yyyymmdd'
    for m in DATE6.finditer(raw):
        s = m.group(1)
        d, mo, y = int(s[0:2]), int(s[2:4]), int(s[4:6])
        if 1 <= d <= 31 and 1 <= mo <= 12:
            return f'20{y:02d}-{mo:02d}-{d:02d}', 'ddmmyy'
    return None, None


def parse(kind, raw):
    name = raw
    out = {}
    if kind == 'file':
        stem = re.sub(r'\.[A-Za-z0-9]{2,4}$', '', name).strip()
    else:
        stem = name.strip()

    # F3/F1: range buổi ('05-06.') phải xét TRƯỚC ordinal, nếu không sẽ chỉ
    # lấy '05' và để lại '06.' trong tiêu đề.
    rng = RANGE.match(stem)
    if rng:
        out['range'] = f"{rng.group(1)}-{rng.group(2)}"
        stem = stem[rng.end():]
    else:
        m = ORDINAL.match(stem)
        if m:
            out['ordinal'] = m.group(1) or m.group(2)
            stem = stem[m.end():]

    date, how = parse_date(stem)
    if date:
        out['date'] = date
        out['dateFrom'] = how
        # bỏ token ngày để không lẫn vào chủ đề
        stem_wo = DATE8.sub(' ', DATE6.sub(' ', stem))
    else:
        stem_wo = stem

    if DUR.search(stem):
        out['durationMinHint'] = DUR.search(stem).group(1)
    parts = [p for p in PART.findall(stem) if int(p) <= 60]
    if parts:
        out['part'] = parts[-1]
    y = YEAR.search(stem)
    if y:
        out['year'] = y.group(1) + y.group(2)
    sp = SPEAKER.search(stem if kind == 'series' else raw)
    if sp:
        out['speaker'] = re.sub(r'\s+', ' ', sp.group(1)).strip(' .-')
    for code, rx in LANG:
        if rx.search(stem):
            out['language'] = code
            break
    if NOISE.search(stem):
        out['noiseFlag'] = True
    # F2: bỏ hẳn token ngày khỏi tiêu đề (nếu không '2024-03-18' lọt vào title).
    title = stem_wo
    for token in (date or '',):
        if token:
            for fmt in (token, token[8:10] + token[5:7] + token[2:4], token[2:4] + token[5:7] + token[8:10]):
                title = title.replace(fmt, ' ')
    title = DUR.sub(' ', title)
    title = re.sub(r'\s+', ' ', title).strip(' .-_')
    out['title'] = title
    return out


def main():
    path = sys.argv[1]
    with open(path, encoding='utf-8') as fh:
        rows = [r for r in csv.DictReader(
            (l for l in fh if not l.startswith('#')), fieldnames=('scope', 'name'))]
    for r in rows:
        got = parse(r['scope'], r['name'])
        print(f"[{r['scope']:10}] {r['name']}")
        for k in ('ordinal', 'range', 'date', 'dateFrom', 'year',
                  'durationMinHint', 'part', 'speaker', 'language',
                  'noiseFlag', 'title'):
            if k in got:
                print(f"             {k:16}= {got[k]}")
        print()


if __name__ == '__main__':
    main()
