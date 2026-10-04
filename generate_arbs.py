#!/usr/bin/env python3
"""[ĐÃ VÔ HIỆU HÓA 2026-08-22 — LANG-630-01] Bootstrap ARB một thời.

Script gốc nhúng từ điển 19 locale × ~50 key rồi GHI ĐÈ lib/l10n/app_*.arb.
Kể từ khi catalog lên 26 locale × 376 message, chạy nó sẽ phá toàn bộ ARB
(mất cả template app_en.arb / app_vi.arb — gen-l10n gãy).

Nguồn sự thật hiện nay (ADR-0002):
  * lib/l10n/app_*.arb — catalog dịch, sửa trực tiếp (giữ key parity
    với app_en.arb; rule #5: locale ≠ vi thiếu dịch → giữ English).
  * tool/generate_ui_translation_map.py — dựng map bridge cho legacy shim.
  * tool/lang_rollout_report.py — báo cáo độ phủ + sàn ratchet.
  * flutter gen-l10n (CI chạy khi build/test) — tái sinh app_localizations_*.dart.

Nếu cần bootstrap lại từ đầu, viết tool mới có kiểm chứng key parity —
đừng hồi sinh file này.
"""

import sys

print(__doc__)
print("Từ chối chạy để tránh ghi đè mất catalog ARB. Không có gì bị ghi.")
sys.exit(1)
