#!/usr/bin/env python3
"""Detective report: which chrome strings still leak English/Vietnamese?

The app translates hard-coded chrome through `AppUITranslations` (ARB map +
priority overrides + the priority native pack). This tool answers, per screen
area and per priority locale:

    "what will the user still read in English or Vietnamese?"

It mirrors the runtime precedence of `lib/core/language/app_ui_translations.dart`
and scans the same presentation files as
`tool/generate_legacy_ui_fallbacks.py` (screens/widgets/sheets/dialogs/views).

Usage
-----
    python3 tool/lang_ui_inventory.py                 # summary + top offenders
    python3 tool/lang_ui_inventory.py --locale zh      # one locale
    python3 tool/lang_ui_inventory.py --list zh        # every leaked string
    python3 tool/lang_ui_inventory.py --write-report   # refresh docs/language/
    python3 tool/lang_ui_inventory.py --fail-on-leak   # CI gate (optional)

Exit code: 0 unless `--fail-on-leak` is passed and a leak exists.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
LANGUAGE_DIR = LIB / "core" / "language"
PACK_JSON = ROOT / "tool" / "priority_native_pack.json"
REPORT = ROOT / "docs" / "language" / "PRIORITY_LOCALE_LEAK_REPORT.md"

PRIORITY_LOCALES = ["zh", "zh_TW", "hi", "si", "my", "th", "ja"]

# Strict set: characters that exist ONLY in Vietnamese (used to judge whether a
# *rendered translation* leaked). Broader set: includes the tones shared with
# French/Spanish so Vietnamese *source* text is recognised as Vietnamese.
VIETNAMESE_RE = re.compile(
    r"[đĐơƠưƯ]|[ảạằắẳẵặầấẩẫậ]|[ẻẽẹềếểễệ]|[ỉĩị]|[ỏọồốổỗộờớởỡợ]|[ủũụừứửữự]|[ỳỷỹỵ]"
)
VIETNAMESE_SOURCE_RE = re.compile(
    r"[ăâđêôơưĂÂĐÊÔƠƯ]|[àáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]"
)
# `\uXXXX` escapes are shown decoded by Dart, but the repo scanner keeps the
# raw token; such artefacts are not real chrome text.
ESCAPE_ARTIFACT_RE = re.compile(r"u[0-9A-Fa-f]{4}")
PLACEHOLDER_RE = re.compile(r"\{value\d+\}")

# Same scope rule as tool/generate_legacy_ui_fallbacks.py
CURATED_UI_VALUE_FILES = {
    "models/vocab_context.dart",
    "features/grammar/models/grammar_category.dart",
    "features/grammar/models/grammar_highlight_preset.dart",
    "features/grammar/services/grammar_preset_library_service.dart",
    "core/language/reviewed_runtime_ui_labels.dart",
}


def is_presentation_file(path: Path) -> bool:
    relative = path.relative_to(LIB).as_posix()
    name = path.name
    return (
        relative == "main.dart"
        or relative in CURATED_UI_VALUE_FILES
        or "/screens/" in f"/{relative}"
        or "/widgets/" in f"/{relative}"
        or name.endswith(("_screen.dart", "_sheet.dart", "_dialog.dart", "_view.dart"))
    )


def area_of(path: Path) -> str:
    try:
        relative = path.relative_to(LIB).as_posix()
    except ValueError:
        relative = path.as_posix()
    for prefix, label in [
        ("screens/home", "Home"),
        ("screens/settings", "Settings"),
        ("screens/listen_mode", "Listen"),
        ("screens/read_mode", "Read"),
        ("screens/memory_mode", "Memory"),
        ("screens/understand_mode", "Understand"),
        ("screens/tools", "Tools / WordList"),
        ("screens/ai_chat", "AI Chat"),
        ("features/video", "Video library"),
        ("features/youtube", "YouTube"),
        ("features/pdf_reader", "PDF Reader"),
        ("features/tipitaka", "Tipiṭaka"),
        ("features/cabin", "Cabin"),
        ("features/learn_by_heart", "Learn by heart"),
        ("features/web_reader", "Web Reader"),
        ("features/dictionary", "Dictionary"),
        ("features/grammar", "Grammar / Understand"),
        ("features/translation", "Translation"),
        ("features/tts", "TTS"),
        ("features/ocr", "OCR"),
        ("features/", "Other features"),
        ("widgets/", "Shared widgets"),
        ("screens/", "Other screens"),
    ]:
        if relative.startswith(prefix):
            return label
    return "Other"


def dart_unescape(value: str) -> str:
    return (
        value.replace("\\'", "'")
        .replace('\\"', '"')
        .replace("\\$", "$")
        .replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\\\", "\\")
    )


def load_generated_map(path: Path) -> dict[str, dict[str, str]]:
    text = path.read_text(encoding="utf-8")
    result: dict[str, dict[str, str]] = {}
    for block in re.finditer(
        r"^  '((?:[^'\\]|\\.)*)': \{\n(.*?)^  \},", text, re.M | re.S
    ):
        source = dart_unescape(block.group(1))
        values = {
            dart_unescape(key): dart_unescape(value)
            for key, value in re.findall(
                r"^    '((?:[^'\\]|\\.)*)': '((?:[^'\\]|\\.)*)',$",
                block.group(2),
                re.M,
            )
        }
        result[source] = values
    return result


def load_priority_overrides() -> dict[str, dict[str, str]]:
    text = (LANGUAGE_DIR / "priority_ui_overrides.dart").read_text(encoding="utf-8")
    result: dict[str, dict[str, str]] = {}
    pattern = re.compile(
        r"^  '((?:[^'\\]|\\.)*)':\s*\n?\s*\{\n(.*?)^  \},", re.M | re.S
    )
    for block in pattern.finditer(text):
        source = dart_unescape(block.group(1))
        values = {
            dart_unescape(key): dart_unescape(value)
            for key, value in re.findall(
                r"^    '([A-Za-z_]+)':\s*\n?\s*'((?:[^'\\]|\\.)*)',",
                block.group(2),
                re.M,
            )
        }
        if values:
            result[source] = values
    return result


def load_legacy_english() -> dict[str, str]:
    text = (LANGUAGE_DIR / "generated_legacy_ui_fallbacks.dart").read_text(
        encoding="utf-8"
    )
    return {
        dart_unescape(key): dart_unescape(value)
        for key, value in re.findall(
            r"^  '((?:[^'\\]|\\.)*)': '((?:[^'\\]|\\.)*)',$", text, re.M
        )
    }


def scan_strings(text: str) -> list[str]:
    """Runtime-shaped Dart presentation literals (interpolation → {valueN})."""
    from generate_legacy_ui_fallbacks import scan_strings as _scan  # type: ignore

    return _scan(text)


NAMED_CHROME_RE = re.compile(
    r"(?:label|tooltip|hintText|labelText|helperText|errorText|semanticLabel|"
    r"subtitle|title|content|message|placeholder|header|description)\s*:\s*"
)


def _named_chrome_values(text: str) -> set[str]:
    """String literals assigned to named presentation parameters."""
    sys.path.insert(0, str(ROOT / "tool"))
    from generate_legacy_ui_fallbacks import scan_strings  # type: ignore

    values: set[str] = set()
    for match in NAMED_CHROME_RE.finditer(text):
        window = text[match.end(): match.end() + 400]
        literal = _first_complete_literal(window)
        if literal is None:
            continue
        for value in scan_strings(literal, include_unaccented=True):
            if value.strip():
                values.add(value)
            break
    return values


LITERAL_SCAN_RE = re.compile(
    r"'((?:[^'\\\n]|\\.)*)'"
    r"|"
    r'"((?:[^"\\\n]|\\.)*)"'
)


def _unescape_single(inner: str) -> str:
    return inner.replace(r"\'", "'")


def _escape_single(inner: str) -> str:
    return inner.replace(r"\'", "'").replace("'", r"\'")


def _comment_spans(text: str) -> list[tuple[int, int]]:
    """`//` and `/* */` ranges, ignoring comment markers inside literals."""
    spans: list[tuple[int, int]] = []
    starts = {match.start(): match for match in LITERAL_SCAN_RE.finditer(text)}
    index = 0
    length = len(text)
    while index < length:
        literal = starts.get(index)
        if literal is not None:
            index = literal.end()
            continue
        if text.startswith("//", index):
            end = text.find("\n", index)
            end = length if end < 0 else end
            spans.append((index, end))
            index = end
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index)
            end = length if end < 0 else end + 2
            spans.append((index, end))
            index = end
            continue
        index += 1
    return spans


def _strip_comments(text: str) -> str:
    """Blank out comments so doc text never counts as chrome."""
    spans = _comment_spans(text)
    if not spans:
        return text
    chars = list(text)
    for start, end in spans:
        for index in range(start, end):
            if chars[index] != "\n":
                chars[index] = " "
    return "".join(chars)


def _adjacent_literal_chains(text: str) -> list[tuple[list[str], str]]:
    """Dart joins adjacent string literals; one segment alone is just a fragment."""
    chains: list[tuple[list[str], str]] = []
    current: list[str] = []
    quote = "'"
    merged = ""
    previous_end: int | None = None
    comments = _comment_spans(text)
    for match in LITERAL_SCAN_RE.finditer(text):
        if any(start <= match.start() < end for start, end in comments):
            previous_end = None
            continue
        raw = match.group(0)
        single = match.group(1) is not None
        this_quote = "'" if single else '"'
        inner = match.group(1) if single else _unescape_single(match.group(2))
        joined = (
            previous_end is not None
            and not text[previous_end:match.start()].strip()
        )
        if current and joined and this_quote == quote:
            current.append(raw)
            merged += inner
        else:
            if len(current) > 1:
                chains.append((list(current), quote + _escape_single(merged) + quote))
            current = [raw]
            quote = this_quote
            merged = inner
        previous_end = match.end()
    if len(current) > 1:
        chains.append((list(current), quote + _escape_single(merged) + quote))
    return chains


def _first_complete_literal(window: str) -> str | None:
    """First *terminated* Dart string literal (quotes included) in `window`."""
    index = 0
    length = len(window)
    while index < length:
        quote = window[index]
        if quote in "'\"":
            cursor = index + 1
            while cursor < length:
                char = window[cursor]
                if char == "\\":
                    cursor += 2
                    continue
                if char == "\n":
                    break
                if char == quote:
                    return window[index:cursor + 1]
                cursor += 1
        index += 1
    return None


def _append_literal_chain_values(text: str, values: set[str]) -> set[str]:
    """Replace adjacent-literal fragments with the joined string users see."""
    from generate_legacy_ui_fallbacks import scan_strings  # type: ignore

    for segments, merged in _adjacent_literal_chains(text):
        decoded = []
        for segment in segments:
            for value in scan_strings(segment, include_unaccented=True):
                if value.strip():
                    decoded.append((segment, value))
                    break
        # Chains split inside `${...}` interpolation start with a closing
        # bracket; joining them yields garbage, so leave those alone.
        if any(value[:1] in (")", "}", "]") for _raw, value in decoded):
            continue
        if not any(value in values for _raw, value in decoded):
            continue
        for value in scan_strings(merged, include_unaccented=True):
            if value.strip():
                values.add(value)
                break
        for raw, value in decoded:
            if text.count(raw) == 1:
                values.discard(value)
    return values


def _used_as_identifier(text: str, value: str) -> bool:
    """`id: 'triangle'` / `'word_map': ToolItem(` — id công cụ hoặc key map, không
    phải chữ hiện trên màn hình."""
    quoted = re.escape(value)
    return bool(
        re.search(r"id:\s*['\"]" + quoted + r"['\"]", text)
        or re.search(
            r"['\"]" + quoted + r"['\"]\s*:\s*(?:[A-Za-z_]+\.)?ToolItem\(", text
        )
    )


# --- Quét rộng: mọi string literal người dùng có thể đọc -------------------
# Bản quét hẹp ở trên chỉ thấy literal nằm trực tiếp trong `Text(...)` hoặc các
# tham số `label:`/`tooltip:`/`hintText:`. Thực tế còn nhiều kênh khác:
#   • literal gán vào biến rồi mới đưa vào Text(var);
#   • nhãn truyền vào widget tự viết (`_Tile(label: '...')`);
#   • thông điệp tiến trình/`SnackBar` do service/provider sinh ra;
#   • `Text("... ${x}")` (nội suy) — shim cố tình không dịch để tránh khớp nhầm.
# Bỏ sót các kênh này khiến báo cáo "0 leak" trong khi người dùng vẫn thấy tiếng
# Việt. Quét rộng bắt hết, và loại trừ những gì KHÔNG hiển thị (xem
# `tool/lang_ui_scan_exclusions.json`).
SCAN_EXCLUSIONS_JSON = ROOT / "tool" / "lang_ui_scan_exclusions.json"

DEFAULT_SCAN_EXCLUSIONS = {
    "_comment": "Đường dẫn/danh sách loại khỏi phép quét rộng (không hiển thị cho người dùng).",
    "skipPathPrefixes": [
        "core/language/",
        "l10n/",
        "features/translation/data/",
        "features/dictionary/",
        "features/learn_by_heart/data/",
        "features/tipitaka/data/",
        "features/web_reader/js/",
        "knowledge/",
    ],
    "skipValuePatterns": [
        "^assets/",
        "://",
        "^\\[?in4up",
        "^[a-z0-9_.-]+\\.(dart|json|onnx|gguf|txt|wav|mp3|m4a|flac|png|jpg|jpeg|webp|srt|lrc|arb|yaml)$",
        "^[A-Za-z0-9+/=]{24,}$",
        "^[^A-Za-zÀ-ỹ]*$",
    ],
}

# Literal ở ngay trong lời gọi log/throw là thông điệp kỹ thuật, không hiển thị.
NON_DISPLAY_CALL_RE = re.compile(
    r"(?:\b(?:debugPrint|print|log|logger|_log\w*)|\bthrow|\b(?:Exception|StateError|ArgumentError|FormatException|UnsupportedError)\b|\bassert)\s*\(?[^;]*$"
)


def _load_scan_exclusions() -> dict:
    if SCAN_EXCLUSIONS_JSON.exists():
        data = json.loads(SCAN_EXCLUSIONS_JSON.read_text(encoding="utf-8"))
    else:
        data = dict(DEFAULT_SCAN_EXCLUSIONS)
    return data


def _literal_is_technical(
    value: str,
    text: str,
    start: int,
    patterns: list[re.Pattern[str]],
    context_patterns: tuple[re.Pattern[str], ...] = (),
    skip_values: frozenset[str] = frozenset(),
) -> bool:
    stripped = value.strip()
    if not stripped or ESCAPE_ARTIFACT_RE.search(stripped):
        return True
    if IDENTIFIER_RE.match(stripped) or _used_as_identifier(text, stripped):
        return True
    if stripped.upper() in ENGLISH_STOPWORDS or stripped in ENGLISH_STOPWORDS:
        return True
    for pattern in patterns:
        if pattern.search(stripped):
            return True
    if stripped in skip_values:
        return True
    # Bối cảnh 2 dòng phía trước: nếu literal là đối số của log/throw thì bỏ.
    context = text[max(0, start - 200) : start]
    tail = "\n".join(context.split("\n")[-2:])
    if NON_DISPLAY_CALL_RE.search(tail):
        return True
    # Ô của bảng bản địa hoá (`'vi': '…'`, `'en': '…',`): chuỗi này chỉ hiển thị
    # cho chính ngôn ngữ đó nên không thể rò rỉ sang locale khác.
    if context_patterns:
        head = context[max(0, len(context) - 80) :]
        for pattern in context_patterns:
            if pattern.search(head):
                return True
    return False


_INTERP_SPAN_RE = re.compile(r"\$\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}")
_TRANSLATED_CALL_RE = re.compile(r"\b(?:uiText|ui|tr|translate)\s*\(")


def _only_translated_parts(value: str) -> bool:
    """True khi phần chữ tĩnh còn lại sau khi bỏ các `${ui('…')}` không còn nguồn.

    Chuỗi kiểu `'${ui('Lỗi')}: $detail'` đã được dịch ngay bên trong phép nội
    suy, nên không phải rò rỉ dù không có trong pack.
    """
    if "uiText(" not in value and "ui(" not in value and "tr(" not in value:
        return False
    stripped = _INTERP_SPAN_RE.sub(
        lambda m: " " if _TRANSLATED_CALL_RE.search(m.group(0)) else m.group(0),
        value,
    )
    stripped = _INTERP_SPAN_RE.sub(" ", stripped)
    if VIETNAMESE_SOURCE_RE.search(stripped):
        return False
    return not _looks_like_english_chrome(stripped)


def collect_broad_sources() -> dict[str, set[str]]:
    """Mọi literal có khả năng hiển thị, kể cả ngoài `Text(...)`."""
    exclusions = _load_scan_exclusions()
    skip_prefixes = tuple(exclusions.get("skipPathPrefixes", []))
    patterns = [re.compile(p) for p in exclusions.get("skipValuePatterns", [])]
    context_patterns = tuple(
        re.compile(p) for p in exclusions.get("skipValueContextPatterns", [])
    )
    skip_values_by_path = {
        key: frozenset(values)
        for key, values in exclusions.get("skipValuesByPath", {}).items()
    }
    by_file: dict[str, set[str]] = {}
    for path in sorted(LIB.rglob("*.dart")):
        relative = path.relative_to(LIB).as_posix()
        if any(relative.startswith(prefix) for prefix in skip_prefixes):
            continue
        # Thư mục `i18n/` tự chứa bảng bản địa hoá đủ 7 locale (xem
        # `locale_map_gaps()`), nên chuỗi ở đó không thể rò rỉ.
        if "/i18n/" in f"/{relative}":
            continue
        skip_values = skip_values_by_path.get(relative, frozenset())
        text = _strip_comments(path.read_text(encoding="utf-8"))
        strings: set[str] = set()
        # Mảnh của một literal bị ngắt dòng (`'a ' 'b'`) không phải chuỗi runtime:
        # Dart nối chúng ngay khi biên dịch. Chỉ giữ chuỗi đã nối.
        fragments: set[str] = set()
        for segments, merged in _adjacent_literal_chains(text):
            raws = set()
            for segment in segments:
                quoted = segment.strip()
                inner = quoted[1:-1] if quoted[:1] in ("'", '"') else quoted
                raws.add(dart_unescape(inner))
            body = merged[1:-1] if merged[:1] in ("'", '"') else merged
            fragments.update(raws)
            if "${" in body:
                # Template nội suy: chỉ có nghĩa ở nơi gọi `uiText`, không phải
                # một chuỗi nguồn độc lập.
                continue
            if len(body.strip()) >= 2:
                strings.add(dart_unescape(body))
        literals = list(iter_string_literals(text))
        seen_spans = set(literals)
        queue = list(literals)
        while queue:
            start, end = queue.pop()
            for span in _INTERP_SPAN_RE.finditer(text[start:end]):
                inner_start = start + span.start()
                for nested in iter_string_literals(span.group(0)):
                    nested_span = (inner_start + nested[0], inner_start + nested[1])
                    if nested_span in seen_spans:
                        continue
                    seen_spans.add(nested_span)
                    queue.append(nested_span)
                    literals.append(nested_span)
        literals.sort()
        for lit_start, lit_end in literals:
            raw_body = text[lit_start + 1:lit_end - 1]
            static = _INTERP_SPAN_RE.sub(" ", raw_body).strip()
            if not static and "$" in raw_body:
                # Vỏ ghép chuỗi: runtime chỉ toàn nội suy, các mảnh bên trong đã
                # được quét riêng ở trên.
                continue
            value = text[lit_start:lit_end]
            value = value[1:-1]
            value = dart_unescape(value)
            if len(value.strip()) < 2:
                continue
            if value in fragments:
                continue
            if _only_translated_parts(value):
                continue
            if _literal_is_technical(
                value, text, lit_start, patterns, context_patterns, skip_values
            ):
                continue
            strings.add(value)
        if strings:
            by_file[relative] = strings
    return by_file


_STRING_LITERAL_RE = re.compile(r"[rR]?'(?:[^'\\\n]|\\.)*'|[rR]?\"(?:[^\"\\\n]|\\.)*\"")


def dart_string_end(text: str, start: int) -> int | None:
    """Vị trí kết thúc literal Dart, hiểu đúng `${...}` lồng chuỗi con.

    Regex thường cắt sai ở `'${a == 'x' ? 'A' : 'B'}'`; hàm này đi qua phần
    nội suy và bỏ qua chuỗi con bên trong.
    """
    if start >= len(text) or text[start] not in "'\"":
        return None
    quote = text[start]
    index = start + 1
    length = len(text)
    while index < length:
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == quote:
            return index + 1
        if char == "$" and index + 1 < length and text[index + 1] == "{":
            index += 2
            depth = 1
            while index < length and depth:
                inner = text[index]
                if inner in "'\"":
                    nested_end = dart_string_end(text, index)
                    if nested_end is None:
                        index += 1
                    else:
                        index = nested_end
                    continue
                if inner == "{":
                    depth += 1
                elif inner == "}":
                    depth -= 1
                elif inner == "\\":
                    index += 1
                index += 1
            continue
        if char == "\n":
            return None
        index += 1
    return None


def iter_string_literals(text: str):
    """Sinh `(start, end)` của mọi literal Dart, bỏ qua comment."""
    comments = _comment_spans(text)
    index = 0
    length = len(text)
    while index < length:
        if any(start <= index < end for start, end in comments):
            index += 1
            continue
        char = text[index]
        if char in "'\"":
            end = dart_string_end(text, index)
            if end is None:
                index += 1
                continue
            yield index, end
            index = end
            continue
        index += 1


def _chain_fragment_values(text: str) -> set[str]:
    """Giá trị của các mảnh literal đã được Dart nối lại — không phải chuỗi runtime.

    Chỉ loại mảnh xuất hiện đúng một lần trong file (tức là chỉ tồn tại như một
    phần của chuỗi bị ngắt dòng), để không vô tình bỏ một nhãn ngắn có thật.
    """
    fragments: set[str] = set()
    for segments, _merged in _adjacent_literal_chains(text):
        for segment in segments:
            raw = segment.strip()
            if text.count(raw) != 1:
                continue
            body = raw[1:-1] if raw[:1] in ("'", '"') else raw
            decoded = dart_unescape(body)
            if len(decoded.strip()) >= 2:
                fragments.add(decoded)
    return fragments


def collect_sources() -> dict[str, set[str]]:
    sys.path.insert(0, str(ROOT / "tool"))
    from generate_legacy_ui_fallbacks import (  # type: ignore
        TEXT_CALL_RE,
        UI_TEXT_CALL_RE,
        extract_first_argument_strings,
    )

    by_file: dict[str, set[str]] = {}
    for path in sorted(LIB.rglob("*.dart")):
        if LANGUAGE_DIR in path.parents:
            continue
        text = _strip_comments(path.read_text(encoding="utf-8"))
        strings = extract_first_argument_strings(text, TEXT_CALL_RE)
        strings |= extract_first_argument_strings(text, UI_TEXT_CALL_RE)
        if is_presentation_file(path):
            # `label:` / `tooltip:` / `hintText:` values are rendered as chrome
            # too, even when they are not the first argument of Text().
            strings |= _named_chrome_values(text)
        strings = _append_literal_chain_values(text, strings)
        strings -= _chain_fragment_values(text)
        strings = {
            value
            for value in strings
            if value.strip()
            and value.strip() not in ENGLISH_STOPWORDS
            and not ESCAPE_ARTIFACT_RE.search(value)
            and not IDENTIFIER_RE.match(value.strip())
            and not _used_as_identifier(text, value.strip())
        }
        relative = path.relative_to(LIB).as_posix()
        skip_values = _load_scan_exclusions().get("skipValuesByPath", {}).get(relative)
        if skip_values:
            strings -= {value.strip() for value in skip_values}
        if strings:
            by_file[relative] = strings

    # Hợp nhất phép quét rộng. Chỉ nhận literal **có dấu tiếng Việt** hoặc literal
    # English "trông giống chrome" — quét rộng thô sẽ kéo theo mã kỹ thuật
    # (tên package, SQL, mime type…) làm số liệu méo.
    for relative, values in collect_broad_sources().items():
        extra = {
            value
            for value in values
            if VIETNAMESE_SOURCE_RE.search(value) or _looks_like_english_chrome(value)
        }
        if extra:
            by_file.setdefault(relative, set()).update(extra)

    # Bộ lọc cuối: mọi đường quét (hẹp hay rộng) đều phải tôn trọng
    # `skipValuesByPath`, nếu không thì chuỗi kỹ thuật sẽ quay lại báo cáo.
    skip_by_path = _load_scan_exclusions().get("skipValuesByPath", {})
    for relative, values in list(by_file.items()):
        skip = {value.strip() for value in skip_by_path.get(relative, ())}
        if not skip:
            continue
        kept = {value for value in values if value.strip() not in skip}
        if kept:
            by_file[relative] = kept
        else:
            by_file.pop(relative)
    return by_file


def _looks_like_english_chrome(value: str) -> bool:
    """English literal trông giống nhãn UI (không phải mã kỹ thuật)."""
    stripped = value.strip()
    if len(stripped) < 4 or not ENGLISH_CHROME_RE.match(stripped):
        return False
    if " " not in stripped:
        # Một từ đơn: chỉ nhận nếu viết hoa đầu và không phải thuật ngữ mã nguồn.
        return stripped[:1].isupper() and stripped.lower() not in _CODE_TOKENS
    if stripped[0].islower():
        return False
    return True


_CODE_TOKENS = {
    "text", "content", "error", "count", "styles", "texts", "next", "simple",
    "abandon", "against", "judge", "energy", "audio", "video", "image", "file",
    "title", "label", "value", "message", "true", "false", "null", "none",
}


ENGLISH_CHROME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9 ·:→←&/.,!?'’()%+#\-–_]*$")
# Tool id / widget key / JSON field / storage name — không bao giờ hiện trên màn
# hình. Chúng là string literal trong file UI nên lọt vào bộ quét; loại ra để số
# liệu chỉ còn chuỗi người dùng thực thấy.
IDENTIFIER_RE = re.compile(
    r"^(?:[a-z][a-z0-9]*(?:[_-][a-z0-9]+)+"  # word_list, mode-switch-hidden
    r"|[a-z]+[A-Z][A-Za-z0-9]*"  # showLegend
    r"|[a-z]{2})$"  # vi, en
)

ENGLISH_STOPWORDS = {
    "AI",
    "AUTO",
    "URL",
    "PDF",
    "LRC",
    "SRT",
    "IPA",
    "TTS",
    "STT",
    "OCR",
    "SRS",
    "API",
    "CPU",
    "GPU",
    "ID",
    "OK",
    "YouTube",
    "WordList",
    "Playlist",
    "Album",
    "Video",
    "Audio",
    "Captions",
    "LEXA",
    "AB Loop",
    "A",
    "B",
    "A-Z",
    "content",  # JSON field name của lyric_line, không hiện trên màn hình
    "save",
    "MP3, M4A, WAV, FLAC...",  # danh sách định dạng file, giữ English theo chính sách  # giá trị trả về của dialog (Navigator.pop), không hiện trên màn hình
    # Brand / model / file-format identifiers: giữ English ở mọi locale theo
    # chính sách (xem docs/language/PRIORITY_NATIVE_PACK.md — "giữ English").
    "In4Up",
    "In4Up logo",
    "YouGlish",
    "Oxford",
    "TXT · LRC · SRT",
    "web_batch",
    "en_US-lessac-medium",
}


def _looks_like_chrome(value: str) -> bool:
    stripped = value.strip()
    if stripped in ENGLISH_STOPWORDS:
        return False  # brand/technical terms that stay English by policy
    if len(stripped) < 3:
        return False
    return bool(ENGLISH_CHROME_RE.match(stripped))


_DART_INTERP_RE = re.compile(r"\$\{[^{}]*\}|\$[A-Za-z_]\w*")


def _renumber(match: re.Match[str], counter: list[int]) -> str:
    counter[0] += 1
    return "{value%d}" % (counter[0] - 1)


def normalize_placeholders(text: str) -> str:
    """`"$count phút"` → `"{value0} phút"` — dạng mà pack dùng cho template.

    Chuỗi nội suy không bao giờ khớp exact-match, nên chỉ khi được chuẩn hoá về
    dạng `{valueN}` thì mới đo được đúng việc runtime làm (`context.uiText`).
    """
    counter = [0]
    return _DART_INTERP_RE.sub(lambda m: _renumber(m, counter), text)


def resolve(
    source: str,
    locale: str,
    pack: dict[str, dict[str, str]],
    overrides: dict[str, dict[str, str]],
    arb: dict[str, dict[str, str]],
    legacy: dict[str, str],
    templates: list[tuple[re.Pattern[str], dict[str, str]]],
) -> str | None:
    if locale == "vi":
        return source
    for catalog in (pack, overrides, arb):
        entry = catalog.get(source)
        if entry:
            value = entry.get(locale) or entry.get("en")
            if value:
                return value
    if source in legacy:
        return legacy[source]
    if "$" in source:
        source = normalize_placeholders(source)
    for pattern, entry in templates:
        if pattern.match(source):
            value = entry.get(locale) or entry.get("en")
            if value:
                return PLACEHOLDER_RE.sub("…", value)
    return None


def build_templates(*catalogs: dict[str, dict[str, str]]):
    templates: list[tuple[re.Pattern[str], dict[str, str]]] = []
    for catalog in catalogs:
        for source, entry in catalog.items():
            if "{" not in source:
                continue
            parts = PLACEHOLDER_RE.split(source)
            pattern = re.compile("^" + "(.*?)".join(map(re.escape, parts)) + "$", re.S)
            templates.append((pattern, entry))
    templates.sort(key=lambda item: -len(item[0].pattern))
    return templates


LOCALE_MAP_RE = re.compile(r"_get\(\{(.*?)\}\)", re.S)
LOCALE_KEY_RE = re.compile(r"['\"](\w+)['\"]\s*:")


def locale_map_gaps() -> list[tuple[str, str]]:
    """Bảng `_get({'vi': …, 'en': …})` nào còn thiếu locale ưu tiên."""
    gaps: list[tuple[str, str]] = []
    for path in sorted(LIB.rglob("*.dart")):
        if "/i18n/" not in f"/{path.relative_to(LIB).as_posix()}":
            continue
        text = path.read_text(encoding="utf-8")
        for match in LOCALE_MAP_RE.finditer(text):
            keys = set(LOCALE_KEY_RE.findall(match.group(1)))
            missing = [locale for locale in PRIORITY_LOCALES if locale not in keys]
            if missing and "en" in keys:
                gaps.append((path.relative_to(LIB).as_posix(), ",".join(missing)))
    return gaps


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locale", action="append", default=[])
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--write-report", action="store_true")
    parser.add_argument("--fail-on-leak", action="store_true")
    parser.add_argument("--limit", type=int, default=25)
    args = parser.parse_args()

    locales = args.locale or PRIORITY_LOCALES

    pack = json.loads(PACK_JSON.read_text(encoding="utf-8"))
    arb = load_generated_map(LANGUAGE_DIR / "generated_ui_translations.dart")
    overrides = load_priority_overrides()
    legacy = load_legacy_english()
    templates = build_templates(pack, overrides, arb)

    gaps = locale_map_gaps()
    if gaps:
        print(f"⚠️  Bảng i18n thiếu locale: {len(gaps)}")
        for path, missing in gaps[:20]:
            print(f"   {path}: {missing}")

    by_file = collect_sources()
    sources = {value for values in by_file.values() for value in values}
    area_by_source: dict[str, str] = {}
    for file, values in by_file.items():
        area = area_of(Path(file))
        for value in values:
            area_by_source.setdefault(value, area)

    leaks: dict[str, dict[str, list[tuple[str, str, str]]]] = {
        locale: defaultdict(list) for locale in locales
    }
    totals: dict[str, Counter[str]] = {locale: Counter() for locale in locales}

    for source in sorted(sources):
        for locale in locales:
            resolved = resolve(source, locale, pack, overrides, arb, legacy, templates)
            area = area_by_source.get(source, "Other")
            value = source if resolved is None else resolved
            if VIETNAMESE_RE.search(value) or VIETNAMESE_SOURCE_RE.search(value):
                leaks[locale][area].append((source, value, "vietnamese"))
                totals[locale]["vietnamese"] += 1
            elif ENGLISH_CHROME_RE.search(value):
                # Includes "fallback to English": still English on screen.
                leaks[locale][area].append((source, value, "english"))
                totals[locale]["english"] += 1

    print(f"Chrome strings scanned: {len(sources)} (from {len(by_file)} files)\n")
    print(f"{'locale':7s} {'vietnamese':>11s} {'english':>9s}")
    print("-" * 30)
    for locale in locales:
        print(
            f"{locale:7s} {totals[locale]['vietnamese']:11d} "
            f"{totals[locale]['english']:9d}"
        )

    print("\nTop areas per locale:")
    for locale in locales:
        print(f"\n  [{locale}]")
        ranked = sorted(
            leaks[locale].items(), key=lambda item: -(len(item[1]))
        )[: args.limit and 8 or 8]
        for area, rows in ranked:
            if rows:
                print(f"    {area:22s} {len(rows):4d}")

    if args.list:
        for locale in locales:
            print(f"\n=== {locale} ===")
            for area, rows in sorted(leaks[locale].items()):
                if not rows:
                    continue
                print(f"\n[{area}]")
                for source, resolved, kind in rows:
                    print(f"  ({kind}) {source}")
                    if resolved != source:
                        print(f"        → {resolved}")

    if args.write_report:
        write_report(locales, sources, leaks, totals, by_file)
        print(f"\nReport: {REPORT.relative_to(ROOT)}")

    if args.fail_on_leak and any(totals[locale]["vietnamese"] for locale in locales):
        print("\nFAIL: việt ngữ còn rò rỉ ở locale ưu tiên.")
        return 1
    return 0


def write_report(locales, sources, leaks, totals, by_file) -> None:
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Priority-locale chrome leak report",
        "",
        "Sinh tự động bởi `python3 tool/lang_ui_inventory.py --write-report`.",
        "Đừng sửa tay — chạy lại tool sau mỗi wave bản dịch.",
        "",
        f"- Chrome strings quét được: **{len(sources)}** trong "
        f"**{len(by_file)}** file presentation.",
        "- `vietnamese`: chuỗi vẫn hiện tiếng Việt ở locale đó (vi phạm rule #5).",
        "- `english`: chuỗi vẫn hiện English trên màn hình (kể cả khi fallback sang"
        " English) — đây là việc còn lại của các wave bản địa hoá tiếp theo.",
        "",
        "| locale | vietnamese | english |",
        "| --- | ---: | ---: |",
    ]
    for locale in locales:
        lines.append(
            f"| `{locale}` | {totals[locale]['vietnamese']} | "
            f"{totals[locale]['english']} |"
        )
    for locale in locales:
        lines += ["", f"## `{locale}` — theo khu vực", "", "| khu vực | còn lại |", "| --- | ---: |"]
        for area, rows in sorted(leaks[locale].items(), key=lambda i: -len(i[1])):
            if rows:
                lines.append(f"| {area} | {len(rows)} |")
    lines += ["", "## Chi tiết (ưu tiên chuỗi còn tiếng Việt)", ""]
    for locale in locales:
        rows = [
            (area, source, resolved, kind)
            for area, items in leaks[locale].items()
            for source, resolved, kind in items
            if kind == "vietnamese"
        ]
        if not rows:
            continue
        lines += [f"### `{locale}`", ""]
        for area, source, resolved, _kind in sorted(rows)[:400]:
            lines.append(f"- **{area}** — `{source}`")
        lines.append("")
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
