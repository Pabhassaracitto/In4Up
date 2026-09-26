#!/usr/bin/env python3
# tool/wp0_arb_inject.py — WP0 (API-001): chèn 37 key ARB mới vào 26 file
# app_*.arb + regenerate getter vào lib/l10n/app_localizations*.dart
# (thay cho `flutter gen-l10n` — sandbox không có Flutter SDK; CI sẽ regenerate
# lại đúng chuẩn khi pub get, file này chỉ để repo nhất quán).
#
# Chạy: python3 tool/wp0_arb_inject.py   (idempotent — chạy lại không nhân đôi)

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from wp0_arb_inject_data import TRANSLATIONS  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"

# locale arb → (class suffix, generated dart file)
IMPL_FILES = {
    "ar": "Ar", "bn": "Bn", "bo": "Bo", "de": "De", "en": "En", "es": "Es",
    "fr": "Fr", "hi": "Hi", "id": "Id", "it": "It", "ja": "Ja", "km": "Km",
    "ko": "Ko", "lo": "Lo", "mn": "Mn", "mr": "Mr", "my": "My", "pt": "Pt",
    "ru": "Ru", "si": "Si", "ta": "Ta", "te": "Te", "th": "Th", "vi": "Vi",
    "zh": "Zh",
}


def dart_escape(s: str) -> str:
    return (s.replace("\\", "\\\\").replace("'", "\\'")
             .replace("$", "\\$").replace("\n", "\\n"))


def value_for(key: str, locale: str) -> str:
    t = TRANSLATIONS[key]
    return t.get(locale, t["en"])


def inject_arb() -> None:
    for locale in list(IMPL_FILES) + ["zh_TW"]:
        path = L10N / f"app_{locale}.arb"
        data = json.loads(path.read_text(encoding="utf-8"))
        existing = {k for k in data if not k.startswith("@")}
        missing = [k for k in TRANSLATIONS if k not in existing]
        if not missing:
            print(f"  arb {locale}: no missing keys")
            continue
        # Text-level insert trước '}' cuối cùng để giữ nguyên format file.
        text = path.read_text(encoding="utf-8").rstrip()
        assert text.endswith("}"), f"{path} does not end with }}"
        body = text[:-1].rstrip()
        assert body.endswith('"') or body.endswith(","), body[-40:]
        add = "".join(
            f',\n  "{k}": {json.dumps(value_for(k, locale), ensure_ascii=False)}'
            for k in missing
        )
        path.write_text(body + add + "\n}\n", encoding="utf-8")
        print(f"  arb {locale}: +{len(missing)} keys")


def getter_impl(key: str, locale: str) -> str:
    return (
        f"\n  @override\n"
        f"  String get {key} => '{dart_escape(value_for(key, locale))}';\n"
    )


def abstract_decl(key: str) -> str:
    en = dart_escape(value_for(key, "en"))
    return (
        f"\n  /// No description provided for @{key}.\n"
        f"  ///\n"
        f"  /// In en, this message translates to:\n"
        f"  /// **'{en}'**\n"
        f"  String get {key};\n"
    )


def inject_abstract() -> None:
    path = L10N / "app_localizations.dart"
    text = path.read_text(encoding="utf-8")
    start = text.index("abstract class AppLocalizations {")
    close = text.index("\n}\n", start)
    block = "".join(abstract_decl(k) for k in TRANSLATIONS
                    if f"String get {k};" not in text)
    if not block:
        print("  abstract: no missing keys")
        return
    text = text[:close] + "\n" + block + text[close + 1:]
    path.write_text(text, encoding="utf-8")
    print(f"  abstract: +{len(TRANSLATIONS)} declarations")


def inject_impl_files() -> None:
    for locale, _suffix in IMPL_FILES.items():
        path = L10N / f"app_localizations_{locale}.dart"
        text = path.read_text(encoding="utf-8")
        block = "".join(getter_impl(k, locale) for k in TRANSLATIONS
                        if f"String get {k} " not in text)
        if not block:
            print(f"  impl {locale}: no missing keys")
            continue
        if locale == "zh":
            # File chứa 2 class: AppLocalizationsZh + AppLocalizationsZhTw
            # (zh_TW kế thừa Zh nhưng override đủ key). Giữa 2 class có
            # doc comment — chèn theo VỊ TRÍ dấu '}' thay vì cắt theo marker.
            marker = text.index("class AppLocalizationsZhTw")
            zh_close = text.rindex("}", 0, marker)  # '}' đóng class Zh
            zh_block = "".join(getter_impl(k, "zh") for k in TRANSLATIONS
                               if f"String get {k} " not in text[:zh_close])
            text = (text[:zh_close] + "\n" + zh_block.rstrip() + "\n"
                    + text[zh_close:])
            # Class ZhTw đóng bằng '}' cuối cùng của file.
            tw_close = text.rstrip().rfind("}")
            marker2 = text.index("class AppLocalizationsZhTw")
            tw_block = "".join(getter_impl(k, "zh_TW") for k in TRANSLATIONS
                               if f"String get {k} "
                               not in text[marker2:tw_close])
            text = (text[:tw_close].rstrip()[:-1] + "\n"
                    + tw_block.rstrip() + "\n}\n")
            path.write_text(text, encoding="utf-8")
            print("  impl zh: +keys (Zh & ZhTw)")
            continue
        body = text.rstrip()
        assert body.endswith("}"), path
        text = body[:-1] + "\n" + block + "}\n"
        path.write_text(text, encoding="utf-8")
        print(f"  impl {locale}: +{len(TRANSLATIONS)} getters")


def main() -> None:
    print("WP0 ARB inject")
    inject_arb()
    inject_abstract()
    inject_impl_files()
    # Sanity: JSON hợp lệ + đủ key mọi locale.
    for locale in list(IMPL_FILES) + ["zh_TW"]:
        data = json.loads((L10N / f"app_{locale}.arb").read_text(encoding="utf-8"))
        missing = [k for k in TRANSLATIONS if k not in data]
        assert not missing, f"{locale} missing {missing}"
    print("OK — all 26 arb files valid & complete")


if __name__ == "__main__":
    main()
