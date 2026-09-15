# XP-MODE-001 — Checklist owner chốt wireframe (DESIGN GATE)

> Dùng file này để **chốt trước khi code**. Owner tick ô `[x]`, ghi ý sửa trực
> tiếp vào dòng, hoặc trả lời theo mã (D1–D5). Sau khi chốt, agent mở PR
> implementation riêng (WP0→WP3) — xem §8 của
> `docs/project/XP-MODE-001-wireframe.md`.
>
> Xem ảnh: `docs/project/assets/xp-mode-001-wireframe.png`

## A. Quyết định UX (bắt buộc — agent không tự quyết)

- [ ] **D1. Điểm vào** — chọn 1:
  - [ ] **D1-A (đề xuất):** thêm **tab thứ 6 “Trải nghiệm”** vào bottom nav,
        5 tab cũ `Home · NGHE · ĐỌC · HIỂU · NHỚ` giữ nguyên.
  - [ ] **D1-B:** không thêm tab — mở rộng thẻ “Phòng Studio” ở Home thành 7 thẻ
        (trùng phạm vi với card `HOME-STUDIO-001`).
  - Ý kiến khác: ...............................................................

- [ ] **D2. Cách hiển thị 7 mode** — chọn 1:
  - [ ] **D2-A (đề xuất):** 7 thẻ phẳng (lưới 4+3), mỗi thẻ có mục tiêu + số bước.
  - [ ] **D2-B:** 4 thẻ theo tab (Nghe/Đọc/Hiểu/Nhớ), chạm thì bung NÓI·XEM·VIẾT.
  - Ý kiến khác: ...............................................................

- [ ] **D3. Nguồn dữ liệu “Khám phá công cụ ⚡”** — chọn 1:
  - [ ] **D3-A (đề xuất):** tái dùng `_buildQuickActions` (nguồn sự thật duy
        nhất) + tab chỉ hiển thị **tuyển chọn** ≥5 tool ưu tiên và nút
        “Xem tất cả ⚡”.
  - [ ] **D3-B:** danh sách riêng tuyển chọn trong tab (chấp nhận hai danh sách).
  - Danh sách ưu tiên đề xuất: `Tipiṭaka · Video · Word Map · Triangle · Venn ·
    Cabin dịch live`  →  owner muốn thêm/bớt: ......................................

- [ ] **D4. Tool thiếu dữ liệu thì nút “Mở ngay”** — chọn 1:
  - [ ] **D4-A (đề xuất):** luôn mở được; badge nói thiếu gì; màn hình đích tự
        dẫn tới chỗ khắc phục (đã verify Tipiṭaka → “Import hoặc tải dữ liệu”).
  - [ ] **D4-B:** disable nút khi thiếu dữ liệu (kèm tooltip lý do).
  - Ý kiến khác: ...............................................................

- [ ] **D5. Mức độ dẫn đường** — chọn 1:
  - [ ] **D5-A (đề xuất):** checklist 3–5 bước + “Mở ngay” từng bước, chạy trên
        màn hình thật (chạm là push route thật rồi quay lại đúng bước).
  - [ ] **D5-B:** thêm lớp coach-mark/hologram đè lên UI mode (làm sau, rủi ro
        vỡ khi UI mode thay đổi).
  - Ý kiến khác: ...............................................................

## B. Rà nội dung 7 mode (mục 4 tài liệu)

- [ ] **NGHE** — mục tiêu + 4 bước đúng ý? .................................
- [ ] **NÓI** — mục tiêu + 4 bước đúng ý? .................................
- [ ] **XEM** — mục tiêu + 4 bước đúng ý? .................................
- [ ] **ĐỌC** — mục tiêu + 4 bước đúng ý? .................................
- [ ] **VIẾT** — mục tiêu + 4 bước đúng ý? .................................
- [ ] **HIỂU** — mục tiêu + 5 bước đúng ý? .................................
- [ ] **NHỚ** — mục tiêu + 5 bước đúng ý? ..................................
- [ ] Thứ tự 7 thẻ đúng mong muốn: `NGHE · NÓI · XEM · ĐỌC · VIẾT · HIỂU · NHỚ`
      (nếu muốn thứ tự khác, ghi rõ): ...........................................

## C. Bất biến (không cần chốt, chỉ xác nhận)

- [ ] “Chế độ trải nghiệm” cũ trong `read_settings_sheet.dart:90` **giữ nguyên**
      (tab mới chỉ là lớp UX bao trùm).
- [ ] 5 tab cũ + icon ⚡ + overlay `showToolsOverlayV2` giữ nguyên hành vi.
- [ ] Rule #5: key mới có `en` + đủ `hi/zh/zh_TW/si`; không hard-code tiếng Việt.
- [ ] Không thêm dependency; không đụng `lib/ffi/`, `UltraTimeStretch`, native C++, workflow CI.
- [ ] Tour là tuỳ chọn — tắt tour thì mọi mode chạy như trước.

## D. Trạng thái “unavailable” — xác nhận cách nói

- [ ] Nhóm “Thiếu dữ liệu” (`experienceToolNeedsData`) — dùng cho Tipiṭaka: OK?
- [ ] Nhóm “Trống: chưa import” (`experienceToolNeedsImport`) — Video/Từ điển: OK?
- [ ] Nhóm “Trống: cần Word List” (`experienceToolNeedsWordList`) — Map/Triangle/Venn: OK?
- [ ] Nhóm “Cần mic + model STT” (`experienceToolNeedsMicModel`) — Cabin/Nói: OK?
- [ ] Nhóm “Cần mạng” (`experienceToolNeedsNetwork`) — YouGlish/YouTube: OK?
- [ ] Nhóm “Cần model AI local” (`experienceToolNeedsAiModel`) — chỉ hiện khi
      người dùng chọn đường AI ở Viết: OK?

## E. i18n (bản nháp dịch trong `XP-MODE-001-i18n-keys.csv`)

- [ ] 20 key đủ dùng (thiếu/thừa key nào: .......................................)
- [ ] Chữ tiếng Việt đúng ý (sửa trực tiếp trong CSV cũng được).
- [ ] Bản `hi/zh/zh_TW/si` dùng được (nguồn: bản dịch nháp, chờ rà ngôn ngữ).

## F. Phạm vi PR implementation sau khi chốt

- [ ] **WP0** model mode + catalog tool (tái dùng `ToolItem`).
- [ ] **WP1** tab + lưới 7 thẻ + carousel ⚡ (+ khử id trùng
      `dictionary`≡`dict_manager`, `video_player`≡`video_library`).
- [ ] **WP2** tour dẫn đường + persist tiến trình theo mode.
- [ ] **WP3** i18n (ARB 6 locale) + test navigation + checkpoint KANBAN.
- [ ] Đồng ý cách chia card con: `XP-MODE-002` (tab + carousel) và
      `XP-MODE-003` (tour).

## G. AT nghiệm thu (dùng lại cho PR implementation)

- [ ] Mở tab Trải nghiệm → thấy đủ **7 thẻ mode** + mục “Khám phá công cụ ⚡”.
- [ ] Chọn **ĐỌC** → làm theo từng bước → tới đúng chỗ từng bước (4/4).
- [ ] Chọn 1 mode khác (ví dụ **NHỚ**) → tour đúng, tiến trình lưu lại sau khi
      thoát/khôi phục app.
- [ ] Carousel hiện **≥5 tool ẩn**, trong đó có **Tipiṭaka**.
- [ ] Bấm **“Mở ngay”** Tipiṭaka → mở `TipitakaLibraryScreen`; máy chưa có DB →
      hiện màn hình “Tipiṭaka chưa có dữ liệu” + nút “Import hoặc tải dữ liệu”
      (không có nút chết).
- [ ] Bấm “Mở ngay” 4 tool khác (Video / Word Map / Triangle / Venn) → đúng màn hình.
- [ ] Tab Đọc → mở Cài đặt Text Studio → **“Chế độ trải nghiệm” cũ vẫn còn
      nguyên** và hoạt động như trước (đối chiếu bản ghi màn hình trước/sau).
- [ ] Icon ⚡ mở overlay cũ đúng như trước (tab Home vẫn thấy Tipiṭaka).
- [ ] Đổi locale EN / JA (chưa dịch hết) → chrome tab Trải nghiệm **không còn
      tiếng Việt**; mở file tiếng Việt thì nội dung vẫn là tiếng Việt.
- [ ] Thiết bị hẹp (≤360dp) → 7 thẻ + bottom nav 6 tab không tràn/cắt chữ.

---

**Chốt:** owner (ký/ngày) ............................ · quyết định D1=.... D2=.... D3=.... D4=.... D5=....
