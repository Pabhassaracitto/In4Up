#!/usr/bin/env python3
"""Extract legacy Vietnamese presentation literals and generate English fallbacks.

This is a migration aid, not a runtime machine translator. It emits an exact
lookup (with controlled interpolation placeholders) from presentation files.
Every accented literal in that scope must be classified as ARB-backed UI,
reviewed legacy UI, or explicitly excluded content. Unknown runtime strings
remain untouched by the application.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
OUTPUT = LIB / "core" / "language" / "generated_legacy_ui_fallbacks.dart"
OVERRIDES = ROOT / "tool" / "legacy_ui_english_overrides.json"
CONTENT_EXCLUSIONS = ROOT / "tool" / "legacy_ui_content_exclusions.json"

VIETNAMESE_RE = re.compile(
    r"[ăâđêôơưĂÂĐÊÔƠƯ]|"
    r"[àáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]|"
    r"[ÀÁẢÃẠẰẮẲẴẶẦẤẨẪẬÈÉẺẼẸỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌỒỐỔỖỘỜỚỞỠỢÙÚỦŨỤỪỨỬỮỰỲÝỶỸỴ]"
)
PLACEHOLDER_RE = re.compile(r"\{value\d+\}")


def reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate reviewed catalog key: {key!r}")
        result[key] = value
    return result


CURATED_UI_VALUE_FILES = {
    "models/vocab_context.dart",
    "features/grammar/models/grammar_category.dart",
    "features/grammar/models/grammar_highlight_preset.dart",
    "features/grammar/services/grammar_preset_library_service.dart",
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


def decode_escape(text: str, index: int) -> tuple[str, int]:
    if index + 1 >= len(text):
        return "\\", index + 1
    value = text[index + 1]
    simple = {"n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f"}
    return simple.get(value, value), index + 2


def scan_strings(text: str, *, include_unaccented: bool = False) -> list[str]:
    """Returns runtime-shaped Dart string literals with interpolation markers.

    Accented Vietnamese is the safe default for broad source discovery. The
    all-string mode is used only to verify exact, explicitly reviewed ASCII
    Vietnamese entries from the override catalog (for example, ``Nghe``).
    """
    results: list[str] = []
    length = len(text)

    def should_include(value: str) -> bool:
        return include_unaccented or bool(VIETNAMESE_RE.search(value))

    def scan_string(start: int) -> tuple[str, int]:
        raw = start > 0 and text[start - 1] == "r" and (start < 2 or not text[start - 2].isalnum())
        quote = text[start]
        triple = text.startswith(quote * 3, start)
        delimiter = quote * (3 if triple else 1)
        cursor = start + len(delimiter)
        value: list[str] = []
        placeholder = 0

        while cursor < length:
            if text.startswith(delimiter, cursor):
                return "".join(value), cursor + len(delimiter)
            char = text[cursor]
            if not raw and char == "\\":
                decoded, cursor = decode_escape(text, cursor)
                value.append(decoded)
                continue
            if not raw and char == "$":
                if cursor + 1 < length and text[cursor + 1] == "{":
                    value.append(f"{{value{placeholder}}}")
                    placeholder += 1
                    cursor = skip_interpolation(cursor + 2)
                    continue
                match = re.match(r"\$[A-Za-z_][A-Za-z0-9_]*", text[cursor:])
                if match:
                    value.append(f"{{value{placeholder}}}")
                    placeholder += 1
                    cursor += len(match.group(0))
                    continue
            value.append(char)
            cursor += 1
        return "".join(value), cursor

    def placeholder_count(value: str) -> int:
        indexes = [int(match.group(1)) for match in re.finditer(r"\{value(\d+)\}", value)]
        return max(indexes, default=-1) + 1

    def offset_placeholders(value: str, offset: int) -> str:
        if offset == 0:
            return value
        return re.sub(
            r"\{value(\d+)\}",
            lambda match: f"{{value{int(match.group(1)) + offset}}}",
            value,
        )

    def skip_trivia(start: int) -> int:
        cursor = start
        while cursor < length:
            if text[cursor].isspace():
                cursor += 1
                continue
            if text.startswith("//", cursor):
                end = text.find("\n", cursor + 2)
                cursor = length if end < 0 else end + 1
                continue
            if text.startswith("/*", cursor):
                end = text.find("*/", cursor + 2)
                cursor = length if end < 0 else end + 2
                continue
            break
        return cursor

    def scan_adjacent_strings(start: int) -> tuple[str, int]:
        value, cursor = scan_string(start)
        next_placeholder = placeholder_count(value)
        while cursor < length:
            next_start = skip_trivia(cursor)
            quote_start = next_start
            if (
                next_start + 1 < length
                and text[next_start] == "r"
                and text[next_start + 1] in "'\""
            ):
                quote_start += 1
            if quote_start >= length or text[quote_start] not in "'\"":
                break
            part, cursor = scan_string(quote_start)
            value += offset_placeholders(part, next_placeholder)
            next_placeholder += placeholder_count(part)
        return value, cursor

    def skip_interpolation(start: int) -> int:
        cursor = start
        depth = 1
        while cursor < length and depth:
            if text.startswith("//", cursor):
                end = text.find("\n", cursor + 2)
                cursor = length if end < 0 else end + 1
                continue
            if text.startswith("/*", cursor):
                end = text.find("*/", cursor + 2)
                cursor = length if end < 0 else end + 2
                continue
            if text[cursor] in "'\"":
                nested, cursor = scan_string(cursor)
                if should_include(nested):
                    results.append(nested)
                continue
            if text[cursor] == "{":
                depth += 1
            elif text[cursor] == "}":
                depth -= 1
            cursor += 1
        return cursor

    cursor = 0
    while cursor < length:
        if text.startswith("//", cursor):
            end = text.find("\n", cursor + 2)
            cursor = length if end < 0 else end + 1
            continue
        if text.startswith("/*", cursor):
            end = text.find("*/", cursor + 2)
            cursor = length if end < 0 else end + 2
            continue
        if text[cursor] in "'\"":
            value, cursor = scan_adjacent_strings(cursor)
            if should_include(value):
                results.append(value)
            continue
        cursor += 1
    return results


def extract_first_argument_strings(
    text: str,
    call_pattern: re.Pattern[str],
    *,
    include_unaccented: bool = False,
) -> set[str]:
    """Extract strings from the first argument of selected presentation calls.

    Restricting the fallback catalog to values that are visibly rendered avoids
    translating document text, vocabulary examples, JavaScript, prompts, and
    other domain content that happens to live in a screen file.
    """
    results: set[str] = set()
    length = len(text)

    def skip_string(start: int) -> int:
        raw = start > 0 and text[start - 1] == "r" and (
            start < 2 or not (text[start - 2].isalnum() or text[start - 2] == "_")
        )
        quote = text[start]
        delimiter = quote * (3 if text.startswith(quote * 3, start) else 1)
        cursor = start + len(delimiter)
        while cursor < length:
            if text.startswith(delimiter, cursor):
                return cursor + len(delimiter)
            if not raw and text[cursor] == "\\":
                cursor += 2
            else:
                cursor += 1
        return length

    for match in call_pattern.finditer(text):
        start = match.end()
        cursor = start
        parens = brackets = braces = 0
        while cursor < length:
            if text.startswith("//", cursor):
                end = text.find("\n", cursor + 2)
                cursor = length if end < 0 else end + 1
                continue
            if text.startswith("/*", cursor):
                end = text.find("*/", cursor + 2)
                cursor = length if end < 0 else end + 2
                continue
            char = text[cursor]
            if char in "'\"":
                cursor = skip_string(cursor)
                continue
            if char == "(":
                parens += 1
            elif char == ")":
                if parens == brackets == braces == 0:
                    break
                parens -= 1
            elif char == "[":
                brackets += 1
            elif char == "]":
                brackets -= 1
            elif char == "{":
                braces += 1
            elif char == "}":
                braces -= 1
            elif char == "," and parens == brackets == braces == 0:
                break
            cursor += 1
        results.update(
            scan_strings(text[start:cursor], include_unaccented=include_unaccented)
        )
    return results


TEXT_CALL_RE = re.compile(r"(?<![A-Za-z0-9_.])Text\s*\(")
UI_TEXT_CALL_RE = re.compile(r"\buiText\s*\(")


def load_arb_pairs() -> dict[str, str]:
    vi = json.loads((LIB / "l10n" / "app_vi.arb").read_text())
    en = json.loads((LIB / "l10n" / "app_en.arb").read_text())
    return {value: en[key] for key, value in vi.items()
            if not key.startswith("@") and isinstance(value, str)}


def dart_string(value: str) -> str:
    return "'" + (value.replace("\\", "\\\\")
                       .replace("'", "\\'")
                       .replace("$", "\\$")
                       .replace("\n", "\\n")
                       .replace("\r", "\\r")) + "'"


def main() -> None:
    direct_sources: set[str] = set()
    direct_candidates: set[str] = set()
    presentation_literals: set[str] = set()
    presentation_candidates: set[str] = set()
    for path in LIB.rglob("*.dart"):
        text = path.read_text()

        # uiText is an explicit presentation boundary, regardless of a file's
        # naming/location convention.
        ui_text_sources = extract_first_argument_strings(text, UI_TEXT_CALL_RE)
        ui_text_candidates = extract_first_argument_strings(
            text, UI_TEXT_CALL_RE, include_unaccented=True
        )
        direct_sources.update(ui_text_sources)
        direct_candidates.update(ui_text_candidates)
        presentation_literals.update(ui_text_sources)
        presentation_candidates.update(ui_text_candidates)

        if is_presentation_file(path):
            direct_sources.update(extract_first_argument_strings(text, TEXT_CALL_RE))
            direct_candidates.update(
                extract_first_argument_strings(
                    text, TEXT_CALL_RE, include_unaccented=True
                )
            )
            # Some reviewed labels live in presets/models and only reach Text as
            # runtime values. Keep this broad set solely for stale-key checking;
            # a literal is translated only after it is explicitly reviewed and
            # added to the override catalog below.
            presentation_literals.update(scan_strings(text))
            presentation_candidates.update(
                scan_strings(text, include_unaccented=True)
            )

    arb_pairs = load_arb_pairs()
    # Generated ARB-backed values live in generated_ui_translations.dart.
    direct_sources.difference_update(arb_pairs)
    direct_candidates.difference_update(arb_pairs)
    presentation_literals.difference_update(arb_pairs)
    presentation_candidates.difference_update(arb_pairs)
    # These are language-learning data tokens rather than application chrome.
    # They must remain untouched when rendered as vocabulary/document content.
    direct_sources = {
        source for source in direct_sources
        if not (len(source.strip()) == 1 and source.strip().isalpha())
    }
    presentation_literals = {
        source for source in presentation_literals
        if not (len(source.strip()) == 1 and source.strip().isalpha())
    }
    direct_candidates = {
        source for source in direct_candidates
        if not (len(source.strip()) == 1 and source.strip().isalpha())
    }
    presentation_candidates = {
        source for source in presentation_candidates
        if not (len(source.strip()) == 1 and source.strip().isalpha())
    }

    overrides = json.loads(
        OVERRIDES.read_text(),
        object_pairs_hook=reject_duplicate_keys,
    )
    if not isinstance(overrides, dict) or not all(
        isinstance(source, str) and isinstance(english, str)
        for source, english in overrides.items()
    ):
        raise ValueError(f"{OVERRIDES.relative_to(ROOT)} must contain a JSON string map")

    # ASCII-only Vietnamese cannot be identified safely with a broad language
    # heuristic. Admit it only when the exact source was deliberately added to
    # the reviewed override catalog and still exists in presentation code.
    reviewed_unaccented = {
        source for source in overrides if not VIETNAMESE_RE.search(source)
    }
    direct_sources.update(direct_candidates.intersection(reviewed_unaccented))
    presentation_literals.update(
        presentation_candidates.intersection(reviewed_unaccented)
    )

    content_exclusions = json.loads(
        CONTENT_EXCLUSIONS.read_text(),
        object_pairs_hook=reject_duplicate_keys,
    )
    if not isinstance(content_exclusions, dict) or not all(
        isinstance(source, str) and isinstance(reason, str) and reason.strip()
        for source, reason in content_exclusions.items()
    ):
        raise ValueError(
            f"{CONTENT_EXCLUSIONS.relative_to(ROOT)} must contain a JSON string map "
            "with a non-empty review reason for every source"
        )

    conflicting_classifications = set(overrides).intersection(content_exclusions)
    if conflicting_classifications:
        examples = ", ".join(
            repr(value) for value in sorted(conflicting_classifications)[:5]
        )
        raise ValueError(
            f"{len(conflicting_classifications)} sources are classified as both UI and "
            f"content: {examples}"
        )

    unused_overrides = set(overrides).difference(
        presentation_literals | direct_sources,
    )
    if unused_overrides:
        examples = ", ".join(repr(value) for value in sorted(unused_overrides)[:5])
        raise ValueError(
            f"{len(unused_overrides)} reviewed overrides no longer match extracted "
            f"presentation sources: {examples}"
        )

    unused_exclusions = set(content_exclusions).difference(presentation_literals)
    if unused_exclusions:
        examples = ", ".join(repr(value) for value in sorted(unused_exclusions)[:5])
        raise ValueError(
            f"{len(unused_exclusions)} reviewed content exclusions no longer match "
            f"extracted presentation sources: {examples}"
        )

    unclassified_sources = presentation_literals.difference(
        overrides,
        content_exclusions,
    )
    if unclassified_sources:
        examples = ", ".join(repr(value) for value in sorted(unclassified_sources)[:5])
        raise ValueError(
            f"{len(unclassified_sources)} accented presentation literals need UI/content "
            f"classification: {examples}"
        )

    for source, english in overrides.items():
        source_placeholders = sorted(PLACEHOLDER_RE.findall(source))
        english_placeholders = sorted(PLACEHOLDER_RE.findall(english))
        if source_placeholders != english_placeholders:
            raise ValueError(
                f"Override placeholders do not match for {source!r}: "
                f"expected {source_placeholders}, got {english_placeholders}"
            )

    missing_overrides = direct_sources.difference(overrides)
    if missing_overrides:
        examples = ", ".join(repr(value) for value in sorted(missing_overrides)[:5])
        raise ValueError(
            f"{len(missing_overrides)} extracted presentation sources need reviewed "
            f"English overrides: {examples}"
        )

    translations = {source: overrides[source] for source in sorted(overrides)}
    residual = {
        source: english
        for source, english in translations.items()
        if VIETNAMESE_RE.search(english)
    }
    report = ROOT / ".dart_tool" / "legacy_ui_translation_residuals.txt"
    report.parent.mkdir(exist_ok=True)
    report.write_text("\n".join(f"{s!r} => {e!r}" for s, e in residual.items()))
    if residual:
        raise ValueError(
            f"{len(residual)} reviewed English overrides still contain Vietnamese "
            f"characters; see {report}"
        )

    lines = [
        "// GENERATED CODE - DO NOT EDIT BY HAND.",
        "// Run: python3 tool/generate_legacy_ui_fallbacks.py",
        "// Exact presentation-source fallbacks only; unknown runtime text is untouched.",
        "",
        "const Map<String, String> generatedLegacyUiEnglishFallbacks = {",
    ]
    for source, english in translations.items():
        lines.append(f"  {dart_string(source)}: {dart_string(english)},")
    lines.extend(["};", ""])
    OUTPUT.write_text("\n".join(lines))

    print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(translations)} English fallbacks")
    print(f"Residual accented translations: {len(residual)} ({report})")


if __name__ == "__main__":
    main()
