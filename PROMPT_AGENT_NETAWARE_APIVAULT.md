# Prompt giao việc — Ưu tiên local/online theo mạng (Wi-Fi/4G) + Kho API tự quản lý & đồng bộ đám mây (NETAWARE-001 + APIVAULT-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. 2 mục **tư vấn
kiến trúc trước** (ghi ADR + chốt phương án với owner), rồi mới implement.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: **đổi kiến trúc ⇒ ADR + review**; i18n chuỗi
  mới đủ `en/hi/zh/zh_TW/si`; KHÔNG chạy `tool/generate_arbs.py`; build
  release Android `--flavor stable`.
- Cập nhật card `NETAWARE-001` + `APIVAULT-001` trong `docs/project/KANBAN.md`.
  Commit nhỏ, push ngay. CI: `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng / yêu cầu (bản 1.10.4)

- **(3) NETAWARE:** Hiện ưu tiên **local** (model phải cài, nhiều khi xung
  đột làm tắt app) do lo user tốn 4G/5G. Owner muốn: máy **tự biết** đang
  dùng **Wi-Fi hay mobile data** → Wi-Fi ưu tiên **online**, 4G/5G ưu tiên
  **offline** — **nhưng user vẫn được quyết định cuối** (override).
- **(4) APIVAULT:** Mỗi lần **cài lại app phải nhập lại API key**. 1 nhà
  cung cấp có thể có **N tài khoản ⇒ N API**. Owner muốn **kho API** tự quản
  lý + **đồng bộ đám mây** (không mất khi cài lại). **Cần tư vấn phương án
  hợp lý nhất.**

## 2. Những gì đã có (tái dùng, đừng viết lại)

- `connectivity_plus` (biết Wi-Fi/mobile).
- `AiProviderStore` (WP0 — store provider/API hiện tại, **chưa sync đám mây**).
- Firebase sync **đã có** cho WordList/LHB (mẫu để đồng bộ APIVAULT).
- Routing model/AI hiện tại (xem để thêm lớp "theo mạng").

## 3. Nơi cần đọc

- `lib/features/ai/` — `AiProviderStore` (WP0), routing AI.
- Luồng chọn model local/online (tìm "local"/"online"/"offline" trong
  `lib/features/` AI/model).
- Mẫu sync Firebase: WordList/LHB sync service.
- `connectivity_plus` usage hiện có.

## 4. Việc phải làm

**Bước A — Tư vấn + ADR (TRƯỚC khi code):**
1. **NETAWARE-001:** đề xuất chính sách: `mặc định = theo mạng` (Wi-Fi→online,
   data→offline) + **3 mức override** user ("Tự động theo mạng" / "Luôn
   online" / "Luôn offline"). Ghi **ADR** (hoặc bổ sung ADR routing hiện có)
   + chốt với owner.
2. **APIVAULT-001:** đề xuất **schema kho API**: 1 provider → nhiều "entry"
   (mỗi entry = 1 tài khoản/API key + tên + enabled), **sync Firebase** theo
   tài khoản (mẫu WordList/LHB). Bàn trade-off (privacy: API key nhạy cảm —
   cân nhắc encrypt trước khi lên cloud). Ghi **ADR** + chốt với owner.

**Bước B — Implement (sau khi ADR được chốt):**
3. **NETAWARE:** thêm lớp "theo mạng" vào routing + 3 mức override trong cài
   đặt (persist). Không phá routing hiện có.
4. **APIVAULT:** kho API (thêm/sửa/xoá nhiều entry/provider) + sync Firebase
   + khôi phục khi cài lại. *(Chỉ implement sau khi owner đồng ý ADR.)*
5. **i18n** + **test** thuần (chính sách theo mạng; schema kho API + sync
   round-trip), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. **NETAWARE:** chuyển Wi-Fi↔4G → engine ưu tiên đổi tương ứng; chọn "Luôn
   online"/"Luôn offline" → được tôn trọng dù mạng thế nào.
2. **APIVAULT:** thêm 2 API cùng provider → chọn được cả 2; xoá 1 → cái còn
   lại an toàn; (khi sync sẵn sàng) logout/cài lại → API vẫn còn.
3. ADR đã ghi + owner đồng ý. `flutter analyze` 0 error + CI xanh + test pass.
