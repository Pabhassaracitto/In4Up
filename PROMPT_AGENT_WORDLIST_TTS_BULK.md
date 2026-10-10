# Prompt giao việc — WordList: phát "từ + nghĩa" (thứ tự tuỳ) + xóa/đổi chủ đề hàng loạt (WORDLIST-TTS-001 + WORDLIST-BULK-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. 2 mục cùng vùng
WordList.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`;
  KHÔNG chạy `tool/generate_arbs.py`; build release Android `--flavor stable`.
- Cập nhật card `WORDLIST-TTS-001` + `WORDLIST-BULK-001` trong
  `docs/project/KANBAN.md`. Commit nhỏ (1 mục 1 commit), push ngay. CI:
  `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (bản 1.10.4)

- **(17)** Chưa có tuỳ chọn phát **từ vựng + ý nghĩa**, và thứ tự phát.
- **(18)** Chọn nhiều từ được nhưng **không xóa hàng loạt** (cũng chưa có
  "thay chủ đề chung").

## 2. Những gì đã loại trừ (đừng làm lại)

- Chọn hàng loạt (multi-select) **đã có** — chỉ thiếu **hành động bulk**
  (xóa, đổi chủ đề) và **tuỳ chọn phát âm**.

## 3. Nơi cần đọc

- `lib/screens/tools/word_list/` — controller (selection + dữ liệu),
  playback service (phát từ), UI danh sách + thanh thao tác.
- TTS dùng chung: `lib/features/tts/tts_service.dart`.

## 4. Việc phải làm

1. **TTS (mục 17):** thêm tuỳ chọn phát:
   - Bật/tắt phát **kèm ý nghĩa** (phát cả từ + nghĩa).
   - Thứ tự: **từ → nghĩa** hoặc **nghĩa → từ** (toggle).
   - Lưu tuỳ chọn (persist).
2. **BULK (mục 18):** khi đang chọn nhiều từ, hiện **thanh thao tác bulk**:
   - **Xóa** (có xác nhận).
   - **Thay chủ đề/common** (chọn 1 chủ đề → gán cho tất cả từ đã chọn).
   - (Mở rộng: gắn tag, đánh dấu đã học — nếu hợp lý).
3. **i18n** (đủ 5 locale) + **test** thuần (logic bulk: xóa N từ, gán chủ đề
   cho N từ; thứ tự phát), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Bật phát "từ + nghĩa" → nghe từ rồi nghĩa (hoặc ngược lại theo chọn).
2. Chọn 5 từ → **Xóa** → cả 5 mất (có xác nhận).
3. Chọn 5 từ → **Thay chủ đề** → cả 5 cùng chủ đề mới.
4. `flutter analyze` 0 error + CI xanh + test mới pass.
