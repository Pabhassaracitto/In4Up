# Prompt giao việc — Dịch offline: thêm ngôn ngữ ML Kit + kiểm tra mâu thuẫn "offline" vs Server/API + PDF dịch đa ngôn ngữ (XLAT-OFFLINE-LANG-001 + XLAT-OFFLINE-SYNC-001 + PDF-XLAT-MULTI-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. 3 mục cùng chủ
đề "ngôn ngữ dịch".

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`;
  KHÔNG chạy `tool/generate_arbs.py`; build release Android `--flavor stable`.
- Cập nhật 3 card `XLAT-OFFLINE-LANG-001`, `XLAT-OFFLINE-SYNC-001`,
  `PDF-XLAT-MULTI-001` trong `docs/project/KANBAN.md`. Commit nhỏ (1 mục 1
  commit), push ngay. CI: `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (bản 1.10.4)

- **(6) ML-KIT-LANG:** Gói dịch **offline (ML Kit)** hiện chỉ **3 ngôn ngữ**
  → cần thêm, dạng **ẩn** (sổ ra khi cần).
- **(7) SYNC-CHECK:** Chỗ Engine dịch có "Chỉ dùng dịch **offline**" — chưa
  rõ có **đồng bộ/mâu thuẫn** với phần "Server & API cho AI" không.
- **(16) PDF-MULTI:** Dịch trong **PDF** cố định **EN→VN** → cần đa ngôn
  ngữ, tối thiểu **26** (phổ thông + "thêm" sổ ra).

## 2. Những gì đã loại trừ (đừng làm lại)

- Engine dịch (online ML Kit/DeepLX/LLM + offline) **đã có** và chạy. Việc
  này là **bổ sung ngôn ngữ + nhất quán routing + UI**, không phải viết
  engine mới.

## 3. Nơi cần đọc

- `lib/features/translation/` — `translation_service.dart` (routing online/
  offline), engine ML Kit, danh sách ngôn ngữ hỗ trợ.
- `lib/features/ai/` (provider store) — phần "Server & API cho AI" (để so
  sánh routing ở mục 7).
- Luồng dịch PDF (tìm "dịch" trong `lib/features/pdf_reader/` / read).

## 4. Việc phải làm

1. **Mục 6 (ML-KIT-LANG):** liệt kê thêm ngôn ngữ ML Kit hỗ trợ; UI chỉ hiện
   vài ngôn ngữ **phổ biến** + nút **"Thêm ngôn ngữ"** sổ ra (bottom-sheet/
   dropdown) danh sách đầy đủ.
2. **Mục 7 (SYNC-CHECK):** rà routing dịch — đảm bảo **1 nguồn sự thật** cho
   "dùng offline/online". Nếu "Chỉ dùng dịch offline" (engine dịch) và
   "Server & API" (AI) là 2 toggle độc lập dễ mâu thuẫn ⇒ gộp/harmonize thành
   1 chính sách rõ (ghi ADR ngắn nếu đổi kiến trúc).
3. **Mục 16 (PDF-MULTI):** cho dịch PDF chọn **nguồn + mục tiêu** (không
   cố định EN→VN); danh sách **≥26** ngôn ngữ (phổ biến ở trên + "thêm" sổ ra).
4. **i18n** (đủ 5 locale) + **test** thuần (danh sách ngôn ngữ ≥26; routing
   offline/online nhất quán), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Dịch offline: thấy ngôn ngữ phổ biến + "Thêm ngôn ngữ" sổ ra thêm.
2. "Chỉ dùng dịch offline" và "Server & API" không mâu thuẫn (1 chính sách).
3. Dịch PDF: chọn nguồn/mục tiêu khác EN/VN → dịch đúng; danh sách ≥26.
4. `flutter analyze` 0 error + CI xanh + test mới pass.
