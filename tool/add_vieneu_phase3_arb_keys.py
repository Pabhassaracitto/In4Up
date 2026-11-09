#!/usr/bin/env python3
"""Thêm key ARB mới của Giai đoạn 3 (chọn biến thể mô hình VieNeu-TTS) vào
tất cả 26 file app_*.arb, giữ key parity (en == vi) và giá trị English cho
các locale ≠ vi (quy tắc #5). Chỉ thêm key nếu chưa có."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB_DIR = ROOT / "lib" / "l10n"

# key -> (giá trị tiếng Việt, giá trị tiếng Anh). Các locale khác lấy giá trị EN.
NEW_KEYS = {
    "ttsModelVariantHeader": (
        "Phiên bản mô hình",
        "Model variant",
    ),
    "ttsModelVariantInfo": (
        "Q8_0 (~170 MB) là mặc định, cân bằng chất lượng và dung lượng; "
        "bf16 (~292 MB) chất lượng cao hơn, file lớn hơn.",
        "Q8_0 (~170 MB) is the default, balancing quality and size; "
        "bf16 (~292 MB) offers higher quality with a larger file.",
    ),
}

VIETNAMESE_LOCALES = {"vi"}


def load_arb(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    arb_files = sorted(ARB_DIR.glob("app_*.arb"))
    locales = [p.stem.removeprefix("app_") for p in arb_files]
    assert "en" in locales and "vi" in locales, "thiếu template en/vi"

    en = load_arb(ARB_DIR / "app_en.arb")
    vi = load_arb(ARB_DIR / "app_vi.arb")
    assert en.keys() == vi.keys(), "key parity en<->vi phải được giữ trước khi thêm"

    # Các key VieNeu đã có (en/vi/hi/si/zh/zh_TW = 545, còn lại 527). Key mới
    # phải được bổ sung vào TẤT CẢ 26 file để giữ parity.
    for key, (vi_val, en_val) in NEW_KEYS.items():
        if key in en:
            print(f"skip {key}: đã có trong template en")
            continue
        for path in arb_files:
            locale = path.stem.removeprefix("app_")
            data = load_arb(path)
            if key in data:
                continue  # đã có ở file này
            if locale == "vi":
                data[key] = vi_val
            else:
                data[key] = en_val  # locale ≠ vi => English fallback (quy tắc #5)
            # Ghi lại với định dạng gần gũi, UTF-8, không_escape ký tự Việt.
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            print(f"added {key} -> {path.name} ({locale})")

    # Kiểm tra parity sau khi thêm
    keysets = {
        p.stem.removeprefix("app_"): set(
            k for k in load_arb(p).keys() if not k.startswith("@")
        )
        for p in arb_files
    }
    base = keysets["en"]
    bad = [loc for loc, ks in keysets.items() if ks != base]
    if bad:
        print("PARITY NGUON: ", bad)
        raise SystemExit(1)
    print(f"OK: key parity duoc giu ({len(base)} key x {len(arb_files)} locale)")


if __name__ == "__main__":
    main()
