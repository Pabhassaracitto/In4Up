# Bàn giao — Tipiṭaka (OpenTipitaka Pa-Auk)

> File bàn giao DUY NHẤT cho module kinh điển Tipiṭaka. Khi mở nhánh mới để giao
> việc, đọc toàn bộ file này trước — nó ghi rõ **đã làm gì, phải làm gì, sẽ làm gì**
> và các ràng buộc phải tuân thủ.

## Chỉ mục nhanh (đọc bắt buộc)

- `docs/GOVERNANCE.md` — luật quản trị (status-only + append, không xóa).
- `docs/project/PLAN.md` — **PLAN-021** (bản chuẩn đã làm/phải làm/sẽ làm).
- `docs/project/KANBAN.md` — **TIPITAKA-001** (trạng thái + commit + CI chính thức).
- `lib/features/tipitaka/models/README.md` — schema DB chuẩn hóa.
- `docs/skills/i18n-localization/SKILL.md` + `docs/skills/ci-red-debugging/SKILL.md`
  — bắt buộc khi thêm/sửa UI hoặc khi CI đỏ.

## 1. Tóm tắt

- **Nguồn:** owner (2026-09-03), triển khai trên session `arena/019ff2f6-in4up`
  (workspace Linux + worktree Windows `E:\PROJECTS\in4up.worktree\DEV`).
- **Trạng thái:** doing — **DEMO đã nằm trong DEV** (commit `18813d6`); các bước
  production làm trên **nhánh mới từ tip DEV** (`arena/01a0251e-in4up`), KHÔNG copy
  lại từ workspace `019ff2f6`.
- **KANBAN:** `TIPITAKA-001` — module Library/Reader song ngữ/Search + 26 language
  pack + import script + quick-action bolt.

## 2. Đã làm (DEMO đang chạy trong DEV — commit `18813d6`)

- **Module** `lib/features/tipitaka/`:
  - `models/` — Collection / Book / Segment (Equatable).
  - `services/db_service.dart` — sqflite helper, schema chuẩn, tìm kiếm `LIKE` + index.
  - `screens/` — Library (2 cột theo Piṭaka → sách); Reader song ngữ Pāli/Việt/Anh
    + bookmark/ghi chú + nút trước/sau đoạn; Search toàn văn; Download; Language
    Pack (26 ngôn ngữ).
  - `tipitaka.dart` — barrel export.
- **Tích hợp app:** `main_shell.dart` — quick-action bolt "tipitaka"
  (Home → ⚡ → Tipiṭaka → Library → Reader).
- **pubspec.yaml:** thêm `sqflite`, `path`.
- **Dữ liệu DEMO:** `assets/db/tipitaka.sqlite` (~1.69MB, ~10k đoạn, import từ 3 file
  nguồn Pali-roman + Việt + Anh) + `scripts/import_tipitaka.py` (Windows/Linux,
  dynamic repo_root).
- **i18n:** `language_pack_screen.dart` fallback vi/en; 26 gói tải từ nguồn Pa-Auk
  **chỉ khi user bấm** (quy tắc model — không auto tải lúc mở app).

## 3. Phải làm (production — MỖI NHÁNH MỚI chọn 1 bước, đừng làm tất cả)

- **Bước F — Full DB import:** cập nhật `scripts/import_tipitaka.py` nhập TẤT CẢ
  bảng nguồn (`vin01t_tik`, `e0101n_mul`, …) thay vì chỉ `e0703n_nrf` + LIMIT 10000
  (hoặc adapter đọc trực tiếp 2 file `.db` nguồn). Kết quả: `tipitaka.sqlite`
  ~500MB đầy đủ sách/chương/đoạn.
- **Bước D — Production/Offline/Citation:** DB **KHÔNG** bundle vào `assets/`
  production — download về `getApplicationDocumentsDirectory` khi user mở lần đầu
  (hoặc ADB/file manager với bản test); hoàn thiện bookmark/note persistence qua
  restart (`tipitaka_user_notes`); nút "Copy Citation" (format `DN 1.1` /
  `Dīgha Nikāya 1.1`).
- **Bước B — Spaced repetition/học thuộc:** bảng `tipitaka_learning_items` (đã có
  trong schema, chưa dùng) ↔ `memory_mode`; nút "Thêm vào bộ nhớ" trên đoạn kinh;
  SM-2 hoặc `next_review_at` + `memory_strength`.
- **Bước C — AI-RAG với citation:** `TipitakaRAGService` (đặt trong `in4up_ai` hoặc
  module tipitaka): câu hỏi → tìm đoạn kinh qua `tipitaka_fts`/`LIKE` → trả lời
  **duy nhất** từ đoạn đã lấy + citation chuẩn (`Dīgha Nikāya 1.1, paragraph N` +
  link `read/:segmentId`). **Không có citation từ DB → KHÔNG trả lời như kinh điển.**

## 4. Sẽ làm (sau F/D/B/C)

- FTS5 thay `LIKE` (typo-tolerant, nhanh) — yêu cầu SQLite build có FTS5.
- Ngôn ngữ nguồn thêm: Miến, Thái (schema đã để chỗ đa ngôn ngữ).
- Nối Reader tipitaka với tab Đọc (mở đoạn kinh trong TextProvider).

## 5. Cấm / ràng buộc

- Không trả lời giáo pháp tùy tiện — AI layer phải có trích dẫn đoạn kinh.
- Tôn trọng giấy phép OpenTipiṭaka / Pa-Auk khi đóng gói data.
- Không commit DB 500MB vào `assets/` (production) — chỉ bản DEMO 1.69MB được phép
  bundle; file nguồn tải từ `dhamma.paauksociety.org` (server chỉ cho trình duyệt —
  sandbox TLS bị chặn, tải bằng trình duyệt).

## 6. Cách mở nhánh mới để giao việc

1. **Branch mới từ tip DEV** (`arena/01a0251e-in4up`). Module đã có sẵn trong DEV
   (`18813d6`) — KHÔNG copy lại từ workspace `019ff2f6`.
2. **Prompt topic** trỏ `docs/Bangiao/bangiao_tipitaka.md` + "chọn bước F/D/B/C
   **duy nhất**" + quy trình harvest/CI như PLAN-020 mục 5.
3. **Chuẩn bị dữ liệu nếu cần (bước F):** tải bằng trình duyệt (Windows 11):
   - Pali (Roman): `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-roman-pali.db.zip`
   - Tiếng Việt: `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/vietnamese_tipitaka_translation_data-2026-04-29.db.zip`
   - Tiếng Anh (tuỳ chọn): `https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/english_tipitaka_translation_data-2026-04-28.db.zip`
   Giải nén → chỉnh `SOURCE_DIR` nếu cần → `python scripts/import_tipitaka.py`
   (Windows: `python scripts\import_tipitaka.py`) → kết quả `assets/db/tipitaka.sqlite`.
4. **Nghiệm thu:** Home → ⚡ bolt → Tipiṭaka → Library → Reader; DB thiếu →
   chạy import script. Báo cáo trạng thái CI trung thực (skill ci-red-debugging).

## 7. Nguồn tham khảo

- OpenTipitaka: https://www.opentipitaka.org/
- Source DB: https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/
- Root data: https://dhamma.paauksociety.org/index.php?dir=Root
- Repo: https://github.com/Pabhassaracitto/In4Up

## Lịch sử bàn giao

- 2026-09-03 | created | owner via session `arena/019ff2f6-in4up` | module + DB DEMO
  + quick-action bolt; code nằm trong DEV từ `18813d6`.
- 2026-09-03 | doing | agent `arena/01a0251e-in4up` | card `TIPITAKA-001` + PLAN-021
  ghi rõ đã làm/phải làm/sẽ làm.
- 2026-09-03 | restructure | agent `arena/01a06915-in4up` | gom các file dồn trước
  đây (INTEGRATION_GUIDE + README module + AGENT_PROMPT_TIPITAKA + TIPITAKA_HANDOFF)
  thành 1 bàn giao chuẩn mục đã/phải/sẽ để nhánh mới đọc là hiểu.
