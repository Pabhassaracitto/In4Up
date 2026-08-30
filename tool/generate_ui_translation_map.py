#!/usr/bin/env python3
"""Generate the legacy UI-string lookup from Flutter ARB files.

The app still contains presentation text written directly in Vietnamese. New code
should use AppLocalizations keys. This lookup is a migration bridge that lets the
LocalizedText shim route those known strings through the same reviewed ARBs.
English is deliberately the source of truth for missing non-Vietnamese values.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB_DIR = ROOT / "lib" / "l10n"
OUTPUT = ROOT / "lib" / "core" / "language" / "generated_ui_translations.dart"


def dart_string(value: str) -> str:
    return "'" + (value.replace("\\", "\\\\")
                       .replace("'", "\\'")
                       .replace("$", "\\$")
                       .replace("\n", "\\n")
                       .replace("\r", "\\r")) + "'"


def load_arb(locale: str) -> dict[str, str]:
    data = json.loads((ARB_DIR / f"app_{locale}.arb").read_text(encoding="utf-8"))
    return {key: value for key, value in data.items()
            if not key.startswith("@") and isinstance(value, str)}


def main() -> None:
    locale_files = sorted(ARB_DIR.glob("app_*.arb"))
    locales = [path.stem.removeprefix("app_") for path in locale_files]
    assert "en" in locales and "vi" in locales

    catalogs = {locale: load_arb(locale) for locale in locales}
    english = catalogs["en"]
    vietnamese = catalogs["vi"]
    assert english.keys() == vietnamese.keys()

    lines = [
        "// GENERATED CODE - DO NOT EDIT BY HAND.",
        "// Run: python3 tool/generate_ui_translation_map.py",
        "// English values are the canonical fallback for every non-Vietnamese locale.",
        "",
        "const Map<String, Map<String, String>> generatedUiTranslations = {",
    ]

    # A Vietnamese phrase may be shared by multiple semantic keys. Keep the first
    # key in template order; ARBs intentionally put common actions before feature
    # specific aliases.
    seen_sources: set[str] = set()

    def emit_source(source: str, key: str, *, vietnamese_source: str | None = None) -> None:
        if not source or source in seen_sources:
            return
        seen_sources.add(source)
        lines.append(f"  {dart_string(source)}: {{")
        lines.append(f"    'en': {dart_string(english[key])},")
        for locale in locales:
            if locale in {"en", "vi"}:
                continue
            # ARBs already use English for untranslated entries. Enforce it here
            # too so an absent/malformed catalog value can never leak Vietnamese.
            value = catalogs[locale].get(key) or english[key]
            if value == vietnamese_source:
                value = english[key]
            lines.append(f"    {dart_string(locale)}: {dart_string(value)},")
        # For a Vietnamese source alias, vi remains Vietnamese. For an English
        # source alias, vi must remain English: this lets legacy English Text
        # widgets be localized when they use the reviewed material shim.
        lines.append(f"    'vi': {dart_string(vietnamese_source or source)},")
        lines.append("  },")

    for key, source in vietnamese.items():
        emit_source(source, key, vietnamese_source=source)

    # The application still contains reviewed English chrome in older screens.
    # Emit English aliases for the same catalog entries so Text('Settings') is
    # localized just like Text('Cài đặt'), without translating arbitrary content.
    for key, source in vietnamese.items():
        emit_source(english[key], key, vietnamese_source=source)

    lines.extend(["};", ""])
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(seen_sources)} source messages")


if __name__ == "__main__":
    main()
