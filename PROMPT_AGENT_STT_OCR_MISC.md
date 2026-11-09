# Prompt giao việc — (MISC) Gộp 1 thông báo pin + OCR tinh chỉnh bằng AI + Thêm engine Parakeet (BATTERY-PROMPT-001 + OCR-AI-REFINE-001 + PARAKEET-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. 3 mục nhỏ, tách
commit riêng.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`;
  KHÔNG chạy `tool/generate_arbs.py`; build release Android `--flavor stable`;
  CẤM tải model HTTP lúc bootstrap.
- Cập nhật 3 card `BATTERY-PROMPT-001`, `OCR-AI-REFINE-001`, `PARAKEET-001`
  trong `docs/project/KANBAN.md`. **1 mục 1 commit**, push ngay. CI:
  `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng / yêu cầu (bản 1.10.4)

- **(2) BATTERY:** Vừa cài app → hiện thông báo pin (1) → xong ra thông báo
  chính thức (2) xin tắt giới hạn pin. → **gộp thành 1**.
- **(15) OCR-AI:** Kết quả OCR thường còn lỗi → cho user **chọn** tinh chỉnh
  bằng **AI** (tuỳ chọn, không mặc định).
- **(19) PARAKEET:** Thêm engine **Parakeet** (STT) đầy đủ như Whisper:
  **hoạt động + import thư mục + import file + xóa + tải**.

## 2. Những gì đã loại trừ / đã có (tái dùng)

- **BATTERY:** xin quyền pin (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) đã có
  ở 2 nơi — chỉ cần **gộp** thành 1 luồng duy nhất.
- **OCR-AI:** lane OCR + AI engine **đã có** — chỉ thêm **nút tuỳ chọn**
  "tinh chỉnh bằng AI" gọi AI engine.
- **PARAKEET:** mẫu **Whisper strategy** (import thư mục/file, xóa, tải,
  chạy) **đã có** — nhân bản pattern cho Parakeet.

## 3. Nơi cần đọc

- **BATTERY:** `grep -rn "battery\|BATTERY\|ignoreBattery\|REQUEST_IGNORE"
  lib/` (2 nơi xin quyền pin).
- **OCR-AI:** `lib/features/ocr/` (kết quả OCR + UI) + AI engine.
- **PARAKEET:** `lib/features/.../stt` (Whisper strategy),
  `packages/in4up_stt/` (model manager).

## 4. Việc phải làm

1. **BATTERY:** gộp 2 nơi xin quyền pin thành **1 luồng** → user chỉ thấy
   **1** thông báo xin quyền pin (rõ, gọn). Không xin 2 lần.
2. **OCR-AI:** sau khi có kết quả OCR → hiện **nút tuỳ chọn** "Tinh chỉnh
   bằng AI" (không mặc định). Bấm → gọi AI engine sửa chính tả/cấu trúc →
   hiện bản đã chỉnh (user so sánh/lưu). Có loading + báo lỗi lịch sự.
3. **PARAKEET:** thêm engine Parakeet theo **mẫu Whisper**: import thư mục,
   import file, xóa, tải, chọn + chạy STT. Đăng ký vào danh sách engine.
4. **i18n** (đủ 5 locale) + **test** thuần (gộp quyền pin; nút OCR-AI hiện
   điều kiện; Parakeet có trong danh sách engine), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Cài mới → **chỉ 1** lần xin quyền pin (không 2 thông báo dồn).
2. Sau OCR → có nút "Tinh chỉnh bằng AI" → bấm → văn bản sạch hơn.
3. Parakeet: tải/import (thư mục + file) → chạy STT được → xóa được; hiện
   đúng trong danh sách engine.
4. `flutter analyze` 0 error + CI xanh + test mới pass.
