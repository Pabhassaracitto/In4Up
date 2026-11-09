# Prompt giao việc — Tab Đọc: nút Focus ẩn khi dùng (trên title) + 2 cụm chức năng "dính nền" khi cuộn (READ-FOCUS-002 + READ-SCROLL-CLUSTER-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. 2 mục cùng vùng
tab Đọc.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`;
  KHÔNG chạy `tool/generate_arbs.py`; build release Android `--flavor stable`.
- Cập nhật card `READ-FOCUS-002` + `READ-SCROLL-CLUSTER-001` trong
  `docs/project/KANBAN.md`. Commit nhỏ (1 mục 1 commit), push ngay. CI:
  `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (bản 1.10.4)

- **(13) FOCUS:** Nút/chế độ Focus ở vị trí chưa hợp lý khi đang dùng.
- **(14) SCROLL:** Kéo **lên** → **2 cụm chức năng vẫn còn (nền)**; kéo
  **xuống** mới hiện lại — hành vi chưa hợp lý.

## 2. Những gì đã loại trừ (đừng làm lại)

- Chế độ Focus + smart-hide khi cuộn **đã có** (cross-ref `READ-FOCUS-001`,
  `READ-TOOLBAR-001`). Việc này là **điều chỉnh vị trí/hành vi ẩn-hiện**,
  không phải viết lại.

## 3. Nơi cần đọc

- `lib/screens/read_mode/read_mode_screen.dart` — `isFocusMode`, nút Focus,
  smart-hide khi cuộn, 2 cụm chức năng (thanh trên + thanh dưới).
- `lib/screens/read_mode/widgets/` (collapsible controls).

## 4. Việc phải làm

1. **Mục 13 (FOCUS):** khi đang **trong** chế độ Focus → **ẩn** nút Focus
   hiện tại; chỉ để lại **nút thoát Focus trên title Đọc**, dưới tab chính.
   Thoát Focus → nút hiện lại vị trí cũ.
2. **Mục 14 (SCROLL):** điều chỉnh hành vi **2 cụm chức năng** theo cuộn cho
   hợp lý: cuộn lên → ẩn cả 2 cụm (không "dính" nền); cuộn xuống → hiện lại.
   Đảm bảo không còn trạng thái "vẫn còn nền" khi cuộn lên.
3. **i18n** (nếu thêm chuỗi) + **test** thuần cho logic ẩn/hiện (trạng thái
   Focus ⇒ nút ẩn; cuộn lên ⇒ 2 cụm ẩn), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Vào Focus → nút Focus ẩn, còn nút thoát trên title; thoát → hiện lại.
2. Cuộn lên → 2 cụm chức năng ẩn (không dính nền); cuộn xuống → hiện lại.
3. Không còn hành vi "kéo lên vẫn còn nền".
4. `flutter analyze` 0 error + CI xanh + test mới pass.
