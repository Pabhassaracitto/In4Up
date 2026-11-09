#!/usr/bin/env python3
"""Generate the priority-locale native UI pack (ADR-0002, rule #5).

Source of truth: `tool/priority_native_pack.json`
Output:          `lib/core/language/generated_priority_native_pack.dart`

Why a second catalog next to the ARBs
-------------------------------------
The ARB catalog is the long-term home of UI copy, but every ARB key must exist
in all 26 locale files, and the ratchet in `tool/lang_rollout_floors.json`
counts "value == English" as untranslated. Adding a few hundred legacy chrome
messages to the ARBs would therefore drop 20+ T3 locales below their floor and
force a full 26-language translation wave.

This pack keeps the *reviewed native translations for the priority locales*
(`zh`, `zh_TW`, `hi`, `si`, `my`, `th`, `ja`) next to `en` as the canonical
fallback, so legacy hard-coded chrome renders natively instead of falling back
to English. Coverage floors are untouched because these are not ARB keys.

Run: python3 tool/generate_priority_native_pack.py [--check]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tool" / "priority_native_pack.json"
OUTPUT = ROOT / "lib" / "core" / "language" / "generated_priority_native_pack.dart"

# Priority locales: the six the owner named (zh, my, si, hi, th, ja) plus the
# Traditional Chinese sibling of zh. `en` is the canonical fallback for every
# other locale and must always be present.
PRIORITY_LOCALES = ["zh", "zh_TW", "hi", "si", "my", "th", "ja"]
REQUIRED_LOCALES = ["en", *PRIORITY_LOCALES]
ALLOWED_LOCALES = set(REQUIRED_LOCALES)

VIETNAMESE_RE = re.compile(r"[đĐơƠưƯảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]")
PLACEHOLDER_RE = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")


def load_pack() -> dict[str, dict[str, str]]:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("priority_native_pack.json must be an object")
    return data


def validate(pack: dict[str, dict[str, str]]) -> list[str]:
    problems: list[str] = []
    for source, entry in pack.items():
        if not source.strip():
            problems.append("empty source key")
            continue
        if not isinstance(entry, dict):
            problems.append(f"{source!r}: entry must be an object")
            continue
        unknown = set(entry) - ALLOWED_LOCALES
        if unknown:
            problems.append(f"{source!r}: unknown locales {sorted(unknown)}")
        for locale in REQUIRED_LOCALES:
            value = (entry.get(locale) or "").strip()
            if not value:
                problems.append(f"{source!r}: missing {locale}")
                continue
            if locale != "en" and VIETNAMESE_RE.search(value):
                problems.append(
                    f"{source!r}: {locale} still contains Vietnamese "
                    f"({VIETNAMESE_RE.search(value).group(0)!r})"
                )
        # Placeholders must survive translation: a value that drops {value0}
        # silently deletes user data from the rendered string.
        expected = set(PLACEHOLDER_RE.findall(source))
        if expected:
            for locale in ["en", *PRIORITY_LOCALES]:
                value = entry.get(locale) or ""
                missing = expected - set(PLACEHOLDER_RE.findall(value))
                if missing:
                    problems.append(
                        f"{source!r}: {locale} lost placeholders {sorted(missing)}"
                    )
    return problems


def dart_string(value: str) -> str:
    return (
        "'"
        + value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        + "'"
    )


def render(pack: dict[str, dict[str, str]]) -> str:
    lines = [
        "// GENERATED CODE - DO NOT EDIT BY HAND.",
        "// Run: python3 tool/generate_priority_native_pack.py",
        "// Source: tool/priority_native_pack.json (reviewed native translations).",
        "//",
        "// Priority locales only: zh, zh_TW, hi, si, my, th, ja + canonical en.",
        "// Every other locale falls back to `en` through _valueForLocale.",
        "",
        "const Map<String, Map<String, String>> generatedPriorityNativePack = {",
    ]
    for source in sorted(pack):
        entry = pack[source]
        lines.append(f"  {dart_string(source)}: {{")
        for locale in REQUIRED_LOCALES:
            lines.append(f"    {dart_string(locale)}: {dart_string(entry[locale])},")
        lines.append("  },")
    lines.extend(["?};", ""])
    return "\n".join(lines).replace("?};", "};")


def main() -> int:
    pack = load_pack()
    problems = validate(pack)
    if problems:
        print("priority_native_pack.json lỗi:")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    rendered = render(pack)
    if "--check" in sys.argv:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != rendered:
            print(f"{OUTPUT.relative_to(ROOT)} lệch với pack — chạy lại generator.")
            return 1
        print(f"OK — {len(pack)} entry, khớp {OUTPUT.relative_to(ROOT)}")
        return 0

    OUTPUT.write_text(rendered, encoding="utf-8")
    print(
        f"Wrote {OUTPUT.relative_to(ROOT)} — {len(pack)} entry × "
        f"{len(REQUIRED_LOCALES)} locale"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
