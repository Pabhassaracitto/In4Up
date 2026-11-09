# Prompt giao việc — I4U AI Chat: sửa nhãn I2U→I4U + UX "đang suy nghĩ"/nút gửi + Hủy "Đang copy model" (I4U-BRAND-001 + AI-CHAT-UX-001 + MODEL-COPY-CANCEL-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. Gồm 3 mục nhỏ
cùng vùng (I4U AI Chat).

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`
  (`lib/core/language/priority_ui_overrides.dart`); KHÔNG chạy
  `tool/generate_arbs.py`; build release Android `--flavor stable`.
- Cập nhật 3 card `I4U-BRAND-001`, `AI-CHAT-UX-001`, `MODEL-COPY-CANCEL-001`
  trong `docs/project/KANBAN.md`. Commit nhỏ (1 mục 1 commit), push ngay.
  CI: `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (bản 1.10.4)

- **(9) BRAND:** AI Chat vẫn hiện "Hỏi **I2U** về từ vựng, ngữ pháp…" và
  "Trợ lý học tập **I2U**" → phải là **I4U**.
- **(10) CHAT-UX:** chat offline chạy được nhưng (a) **không có biểu tượng
  AI đang suy nghĩ**; (b) **nút gửi chỉ trắng** toàn bộ, không phải loading;
  (c) phản hồi chưa nhất quán (hỏi "xin chào" → nó hỏi lại "bạn cần gì"; hỏi
  về Trump → … *(chưa rõ — cần owner bổ sung)*).
- **(11) COPY-CANCEL:** đổi model → hiện "Đang copy model" nhưng **không có
  nút dừng/hủy** khi đổi ý.

## 2. Những gì đã loại trừ (đừng làm lại)

- Không phải lỗi model offline (chat chạy được). Lỗi ở **UI/trạng thái**
  (thinking indicator, nút gửi, cancel).

## 3. Nơi cần đọc

- `lib/features/ai_chat/` (widget chat: bubble, nút gửi, trạng thái
  streaming/thinking; controller điều khiển gửi câu + nhận streaming).
- Chuỗi I2U: `grep -rn "I2U\|i2u\|I2u" lib/` (UI + l10n `.arb`).
- Luồng copy model: tìm "Đang copy model" / `copyModel` / `copy` trong
  `lib/` (Setting Home + màn chọn model).

## 4. Việc phải làm

1. **BRAND:** thay toàn bộ "I2U" → "I4U" (UI + l18n). Kiểm tra `grep -rn
   "I2U" lib/` về 0. Đăng ký chuỗi đủ 5 locale.
2. **CHAT-UX:**
   - Thêm **trạng thái "đang suy nghĩ"** (spinner/3 chấm động) khi đã gửi câu
     và đang chờ AI trả lời.
   - **Nút gửi** hiện **loading** (spinner) trong lúc xử lý; disable gửi câu
     thứ 2 khi đang chờ.
   - *(Phần (c) phản hồi nhất quán: chờ owner làm rõ câu Trump trước khi sửa —
     ghi chú trong card, không đoán.)*
3. **COPY-CANCEL:** thêm **nút Hủy** khi đang copy model; dừng copy, về model
   cũ, dọn trạng thái dở dang. Dùng cancel token đúng vòng đời.
4. **i18n** + **test** thuần cho phần trạng thái (vd "đang suy nghĩ hiện khi
   isWaiting", "nút Hủy hiện khi isCopying"), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Không còn "I2U" ở bất kỳ đâu; đúng "I4U".
2. Gửi câu → hiện "đang suy nghĩ" + nút gửi loading → trả lời hiện dần; gửi
   lại lúc đang chờ bị chặn.
3. Bấm đổi model → "Đang copy model" → bấm **Hủy** → dừng, về model cũ, không
   kẹt.
4. `flutter analyze` 0 error + CI xanh + test mới pass.
