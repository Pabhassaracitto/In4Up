# AGENTS.md — Chỉ mục cho AI agent làm việc trong repo này

> File này để agent (Arena/Claude Code/Cursor/...) định hướng nhanh.
> Người đọc mới: bắt đầu từ đây, đừng dò code mù.

## Skills (tải trước khi làm việc liên quan)

- **`docs/skills/ci-red-debugging/SKILL.md`** — bắt buộc đọc khi CI GitHub Actions đỏ
  mà không tải được log (`gh run view --log` EOF) hoặc không có Flutter SDK local.
  Kèm script 1-lệnh `scripts/ci_check.sh` trong cùng folder.
- **`docs/skills/i18n-localization/SKILL.md`** — bắt buộc đọc khi thêm hoặc sửa UI,
  đặc biệt các chức năng mới. Phải kiểm tra chrome, ARB parity và đủ bản dịch
  `hi`/`zh`/`zh_TW`/`si` trước khi coi task hoàn tất.

## Tài liệu kiến trúc (không code mù — đọc trước khi đổi kiến trúc)

- `docs/HANDOFF_MVA_v2.md` — hợp đồng bàn giao MATRIX KNOWLEDGE MVA (schema mục 2,
  isolate boundary mục 4, 8 task, 8 acceptance test).
- `docs/adr/` — mọi quyết định kiến trúc sau bàn giao đi qua ADR tại đây
  (xem 0001: chuẩn hóa SM-2 về một hàm duy nhất + postmortem).

## Quản trị thông tin dự án (BẮT BUỘC đọc `docs/GOVERNANCE.md`)

- `docs/project/KANBAN.md` — bảng việc, nguồn sự thật duy nhất về trạng thái.
  Luật: CHỈ đổi trạng thái + append lịch sử, KHÔNG xóa.
- `docs/project/PLAN.md` — milestone + nơi tiếp nhận kế hoạch mới từ người sở hữu.
- Đầu session: `git fetch` rồi đọc bản trên `origin/main` trước khi cập nhật.

## Quy tắc vàng (vi phạm = dừng lại hỏi người, không tự quyết)

1. KHÔNG đụng `UltraTimeStretch` C++ FFI / `lib/ffi/` — audio realtime là vùng bảo vệ.
2. KHÔNG gộp 3 skill SM-2 (Hiểu–Nghe–Đọc) thành 1 điểm số — đang tách biệt có chủ đích.
3. KHÔNG làm mất khả năng reopen đúng vị trí nguồn (PDF page/rect, Web url/scroll,
   Audio timestamp) — xem schema Evidence mục 2.2.
   - PDF: rect được **lưu** theo quy ước PDF y-up (`top > bottom`, tức `Rect.height`
     âm và `contains()` luôn false). Mọi quy đổi phải đi qua
     `lib/features/pdf_reader/services/pdf_geometry.dart`; KHÔNG "sửa" chiều rect ở
     chỗ lưu (dữ liệu đã về máy người dùng — ADR-0003). Khoá dữ liệu đọc của một
     file là `PdfFileIdentity` (md5(size|mtime)), không phải chuỗi đường dẫn.
4. Mọi thay đổi kiến trúc: ADR + code review, không "hội đồng AI".
5. **Locale ≠ tiếng Việt → chrome UI không được còn tiếng Việt. Thiếu bản dịch
   ngôn ngữ đó thì hiện English. Không bao giờ fallback về `vi`.**
   - Áp dụng: nút, tooltip, title, snackbar, empty state, chip, dialog hệ thống.
   - **Không** áp dụng (giữ nguyên nguồn): nội dung user (văn bản, lyric, PDF/Web,
     ghi chú), từ vựng/nghĩa user nhập, output AI, transcript STT, tiêu đề chương
     auto-TOC.
   - **Lộ trình phủ theo bậc (ADR-0002):** vi (nguồn) → en (chuẩn fallback) →
     T2 ưu tiên hi/zh/zh_TW/si (đã 100% wave 1 — key ARB mới phải dịch đủ
     4 locale ngay trong cùng PR) → T3 (sàn ratchet, chỉ tăng). Xem
     `lib/core/language/language_roadmap.dart` + `tool/lang_rollout_report.py`
     + group ADR-0002 trong `test/locale_chrome_no_vietnamese_test.dart`;
     nhãn mới của Tab Đọc bị quét thêm bởi `test/pdf_reader/pdf_reader_i18n_coverage_test.dart`.
     KHÔNG chạy `generate_arbs.py` (đã vô hiệu — ghi đè mất catalog).
   - Thứ tự: `locale có sẵn` → `en` → không đoán, không để `vi`.
   - Chuỗi UI mới: ARB **hoặc** `uiText('…')` + English trong
     `tool/legacy_ui_english_overrides.json`. KHÔNG hard-code tiếng Việt ra `Text`
     rồi hy vọng shim bắt hết (shim chỉ exact, không template).
   - **Đừng chỉ có chữ trên giấy** — cần máy bắt (rule văn xuôi agent vẫn quên):
     1. Generator `tool/generate_legacy_ui_fallbacks.py` (`unused_overrides` /
        unclassified — fail nếu có literal chrome chưa phân loại) — giữ nguyên.
     2. Test `test/locale_chrome_no_vietnamese_test.dart`: catalog đã review —
        dịch `ja`/`en` (và mọi locale ≠ vi) **không còn ký tự Việt**; mọi entry
        phải có giá trị `en` (canonical fallback).
     3. QA tay: EN + 1 locale chưa dịch hết (JA/BN) — chrome không `vi`; mở file
        tiếng Việt vẫn thấy tiếng Việt.
   - KHÔNG bật dịch máy runtime cho mọi chuỗi lạ.

## Vận hành CI / môi trường (đúc kết từ thực chiến)

- CI test module Knowledge: `.github/workflows/knowledge_tests.yml` (flutter 3.44.1,
  chỉ chạy khi chạm `lib/knowledge/**` hoặc `test/knowledge/**`).
- `flutter analyze` trong CI coi info-lint là lỗi — nhưng flutter_lints 6.0 đã giảm
  mạnh rule set; kiểm rule thật trước khi "đoán lint" (mục 3 của skill ci-red-debugging).
- Bẫy đã biết + quy trình hồi phục sandbox: mục 5 của skill ci-red-debugging.
- Sandbox clone mới có thể **chỉ fetch `main`** (`remote.origin.fetch = +refs/heads/main:...`),
  khiến `git branch -r` / `git show origin/arena/*:...` không thấy nhánh lineage.
  Xem **GOVERNANCE mục 2a** để fetch đúng ref — ĐỪNG kết luận "nhánh gốc bị mất".
- Commit nhỏ, push ngay — push là backup (sandbox có thể tái bản giữa phiên).

## Module mới (đang trên branch `arena/01a019bb-in4up`, chờ merge)

`lib/knowledge/` — 5 model schema MVA + merge/split hoàn tác + migrator WordEntry cũ.
Test: `test/knowledge/` (58 test xanh). Lịch sử bisect trong commit message — đọc
postmortem trong `lib/knowledge/migration/word_entry_migrator.dart` trước khi đụng
import giữa `lib/models` và `lib/knowledge`.
