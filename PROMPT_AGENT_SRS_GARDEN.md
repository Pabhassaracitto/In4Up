# Prompt giao việc — Vườn nhớ SRS: chạm từ không phản ứng → long-press chấm điểm nhanh (kéo 4 hướng) + onboarding (SRS-GARDEN-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`;
  KHÔNG chạy `tool/generate_arbs.py`; build release Android `--flavor stable`.
  KHÔNG gộp 3 skill SM-2.
- Cập nhật card `SRS-GARDEN-001` trong `docs/project/KANBAN.md`. Commit nhỏ,
  push ngay. CI: `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (bản 1.10.4)

Mở **vườn nhớ (SRS)** → các từ chỉ **hiện**, **chạm vô không phản ứng** gì.
User không biết làm gì thêm. Chức năng SRS rất hay nhưng **tiếp cận chưa
tốt**.

## 2. Những gì đã loại trừ (đừng làm lại)

- Engine SRS (SM-2) **đã có** và hoạt động (lịch ôn). Lỗi ở **UI tương tác**:
  từ trong vườn nhớ chưa có gesture chấm điểm.

## 3. Nơi cần đọc

- `lib/features/.../srs` (hoặc tìm "vườn nhớ" / `memory` / `srs` / `review`
  trong `lib/`) — widget vườn nhớ, engine SM-2, cách từ được render.
- Xem SRS đang được dùng ở đâu khác (flashcard review) để **tái dùng** gesture
  chấm điểm nếu có.

## 4. Việc phải làm

1. **Long-press 1 từ** trong vườn nhớ → hiện **thao tác chấm điểm nhanh**
   kiểu **kéo 4 hướng** (vd: Lại / Quên / Ổn / Giỏi — 4 góc/màu). Kéo theo
   hướng → áp dụng điểm SRS (cập nhật lịch ôn) + haptic.
   - Nếu làm kéo 4 hướng khó/tốn thời gian: phương án dự phòng = long-press
     mở **bộ 4 nút** chấm điểm rõ ràng (vẫn đạt mục tiêu "chấm nhanh").
2. **Onboarding/gợi ý:** lần đầu vào vườn nhớ → 1 dòng hướng dẫn ngắn
   ("Nhấn giữ một từ để chấm điểm ôn tập") + highlight 1 từ. Lưu đã hiện.
3. **i18n** (đủ 5 locale) + **test** thuần (chấm điểm → cập nhật đúng lịch ôn
   SM-2; flag đã-onboard), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Long-press 1 từ → hiện 4 lựa chọn chấm (kéo 4 hướng hoặc 4 nút).
2. Chấm "Giỏi" → từ chuyển sang ngày ôn xa hơn; chấm "Lại" → ôn sớm lại.
3. Lần đầu vào vườn nhớ → có gợi ý dùng; lần sau không lặp lại.
4. `flutter analyze` 0 error + CI xanh + test mới pass.
