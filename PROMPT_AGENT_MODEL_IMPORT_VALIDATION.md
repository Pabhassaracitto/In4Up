# Prompt giao việc — Import model báo "thiếu file" SAI: TTS (thư mục) + STT offline (cả 2) (MODELIMPORT-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`
  (`lib/core/language/priority_ui_overrides.dart`); KHÔNG chạy
  `tool/generate_arbs.py`; build release Android `--flavor stable`.
- Cập nhật card `MODELIMPORT-001` trong `docs/project/KANBAN.md`. Commit
  nhỏ, push ngay. CI: `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (Setting Home, bản 1.10.4)

- **(3) TTS (Piper):** nạp **thư mục** → báo **thiếu file**; nạp **file** → OK.
- **(5) STT Offline (Zipformer):** cả **import thư mục lẫn import file** đều
  báo **thiếu**, trong khi thực tế file **đủ**.

## 2. Những gì đã loại trừ (đừng làm lại)

- Không phải do thiếu file thật (owner xác nhận file đủ). ⇒ Lỗi ở **validator**
  (so sánh danh sách file mong đợi vs file thực tế) hoặc **đọc thư mục**
  (lựa chọn thư mục trả về path sai / không đệ quy / lệch tên).

## 3. Nơi cần đọc

- `packages/in4up_stt/lib/sherpa_model_manager.dart` — logic scan/validate
  model (danh sách file mong đợi cho TTS Piper vs STT Zipformer).
- Luồng import: tìm bằng `grep -rn "thiếu\|missing\|importModel\|validate"
  packages/in4up_stt/ lib/` (nơi báo "thiếu file").
- So sánh cách import **file** (đang OK với TTS) vs **thư mục** (lỗi).

## 4. Việc phải làm

1. **Tái hiện + in log** danh sách file mong đợi vs file tìm được (đúng tên,
   đúng thư mục) cho cả 3 trường hợp: TTS-file (OK), TTS-thư mục (lỗi),
   STT-file (lỗi), STT-thư mục (lỗi).
2. **Sửa validator** cho đúng: nhận đủ file hợp lệ; chỉ báo thiếu khi THẬT
   SỰ thiếu, **kèm tên file cụ thể** thiếu.
3. Nếu do **đọc thư mục**: sửa cách liệt kê (đệ quy, path chuẩn, không bỏ
   file con).
4. **i18n** cho thông báo thiếu-file (đủ 5 locale). **Test** thuần: cho 1 bộ
   file đủ → "OK"; bỏ đúng 1 file → báo đúng tên file đó thiếu. Nối
   `app_analyze.yml`.

## 5. Nghiệm thu

1. Import 1 bộ model **TTS** đủ file (cả file lẫn thư mục) → "OK", dùng được.
2. Import 1 bộ model **STT offline** đủ file (cả file lẫn thư mục) → "OK".
3. Bỏ 1 file → báo **đúng tên** file thiếu (không báo sai).
4. `flutter analyze` 0 error + CI xanh + test mới pass.
