#!/usr/bin/env python3
"""Báo cáo độ phủ ngôn ngữ (ADR-0002) — lộ trình vi → en → hi/zh/si → …

Usage:
    python3 tool/lang_rollout_report.py                 # báo cáo + chặn sàn
    python3 tool/lang_rollout_report.py --update-floors # viết lại sàn = độ phủ
                                                        # hiện tại (chỉ ra lên)

Độ phủ của một locale = số message ARB có giá trị khác English /
tổng message (trừ key giữ English theo tool/lang_keep_english.json).
English là chuẩn fallback (rule #5 AGENTS.md) nên giá trị == English
được tính là "chưa phủ". Tiếng Việt là nguồn — không đo.

Exit code 1 nếu có locale dưới sàn (dùng được trong CI).
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB_DIR = ROOT / "lib" / "l10n"
KEEP = ROOT / "tool" / "lang_keep_english.json"
FLOORS = ROOT / "tool" / "lang_rollout_floors.json"

PRIORITY = ["hi", "zh", "zh_TW", "si"]
LEGACY_DIR = ROOT / "tool" / "legacy_ui_translations"


def load_messages(locale: str) -> dict[str, str]:
    data = json.loads((ARB_DIR / f"app_{locale}.arb").read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}


def main() -> int:
    update_floors = "--update-floors" in sys.argv

    keep = json.loads(KEEP.read_text(encoding="utf-8"))
    keep_global = set(keep.get("keepEnglish", []))
    keep_by_locale = keep.get("keepEnglishByLocale", {})

    floors_data = json.loads(FLOORS.read_text(encoding="utf-8"))
    floors = dict(floors_data.get("floors", {}))

    en = load_messages("en")
    locales = sorted(
        p.stem.removeprefix("app_")
        for p in ARB_DIR.glob("app_*.arb")
        if p.stem.removeprefix("app_") not in {"en", "vi"}
    )

    violations: list[str] = []
    print(f"{'locale':7s} {'tier':5s} {'cov':>7s} {'floor':>6s}  {'n/t':>9s}")
    print("-" * 44)
    new_floors: dict[str, float] = {}
    for loc in locales:
        msgs = load_messages(loc)
        keep = keep_global | set(keep_by_locale.get(loc, []))
        total = len(en) - len(keep)
        translated = sum(
            1
            for k, v in en.items()
            if k not in keep and msgs.get(k, v) != v
        )
        cov = translated / total if total else 0.0
        tier = "T2" if loc in PRIORITY else "T3"
        floor = floors.get(loc, 0.0)
        new_floors[loc] = math.floor(cov * 100) / 100 if not update_floors else max(floor, cov)
        flag = ""
        if cov + 1e-9 < floor:
            flag = "  <<< DƯỚI SÀN"
            violations.append(f"{loc}: coverage {cov:.4f} < floor {floor}")
        print(f"{loc:7s} {tier:5s} {cov:7.1%} {floor:6.2f}  {translated:4d}/{total}{flag}")

    if update_floors:
        merged = {**floors, **{k: round(v, 4) for k, v in new_floors.items()}}
        merged = dict(sorted(merged.items()))
        FLOORS.write_text(
            json.dumps(
                {"_comment": floors_data.get("_comment", ""), "floors": merged},
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"\nĐã cập nhật sàn ({FLOORS.relative_to(ROOT)}) — chỉ tăng, không hạ.")

    # ADR-0003 — legacy catalog coverage (chuỗi hard-code chưa migrate ARB).
    legacy_floors = dict(floors_data.get("legacyFloors", {}))
    overrides = json.loads((ROOT / "tool" / "legacy_ui_english_overrides.json").read_text(encoding="utf-8"))
    overrides = {k: v for k, v in overrides.items() if not k.startswith("_")}
    print(f"\nLegacy catalog (ADR-0003): {len(overrides)} chuỗi hard-code")
    print(f"{'locale':7s} {'tier':5s} {'cov':>7s} {'floor':>6s}  {'n/t':>9s}")
    print("-" * 44)
    for loc in PRIORITY:
        path = LEGACY_DIR / f"{loc}.json"
        table = {}
        if path.exists():
            table = {
                k: v
                for k, v in json.loads(path.read_text(encoding="utf-8")).items()
                if not k.startswith("_")
            }
        cov = len(table) / len(overrides) if overrides else 0.0
        floor = legacy_floors.get(loc, 0.0)
        flag = ""
        if cov + 1e-9 < floor:
            flag = "  <<< DƯỚI SÀN"
            violations.append(
                f"legacy {loc}: coverage {cov:.4f} < floor {floor}"
            )
        print(f"{loc:7s} {'T2':5s} {cov:7.1%} {floor:6.2f}  {len(table):4d}/{len(overrides)}{flag}")

    if violations:
        print("\nVI PHẠM SÀN RATCHET:")
        for v in violations:
            print(f"  - {v}")
        print("Hạ độ phủ là lùi lộ trình — phục hồi bản dịch hoặc điều chỉnh sàn bằng ADR.")
        return 1
    print("\nOK — mọi locale đạt sàn. Nhớ đồng bộ lib/core/language/language_roadmap.dart.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
