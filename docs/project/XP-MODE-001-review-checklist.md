# XP-MODE-001 — Checklist owner chốt wireframe (**✅ owner đã chốt — hết design gate**)

> Dùng file này để **chốt trước khi code**. Owner tick ô `[x]`, ghi ý sửa trực
> tiếp vào dòng, hoặc trả lời theo mã (D1–D5). Sau khi chốt, agent mở PR
> implementation riêng (WP0→WP3) — xem §8 của
> `docs/project/XP-MODE-001-wireframe.md`.
>
> Xem ảnh: `docs/project/assets/xp-mode-001-wireframe.png`
>
> **Trạng thái 2026-09-23:** mục **A (D1–D5)**, **B (nội dung 7 mode)** và
> **F (phạm vi WP)** đã tick theo quyết định owner (Q&A 2026-09-16); bản thiết kế
> chốt là **D1-B** (không thêm tab) và ảnh wireframe đã vẽ lại theo D1-B.
> Mục **C–E, G** giữ nguyên để **xác nhận khi PR implementation** (không chặn).
> Hai việc còn chờ owner: (a) bật đèn xanh mở PR implementation; (b) chọn PA1/PA2
> ở dòng cuối mục F (phối hợp `HOME-STUDIO-001`).

## A. Quyết định UX — ✅ OWNER ĐÃ CHỐT 2026-09-16 (agent không tự quyết)

- [x] **D1. Điểm vào** → **D1-B: KHÔNG thêm tab — mở rộng “Phòng Studio” ở Home
      thành 7 thẻ.** 5 tab shell `Home · NGHE · ĐỌC · HIỂU · NHỚ` giữ nguyên.
      *Hệ quả đã ghi nhận:* điểm vào trùng file `home_screen.dart` +
      callback `main_shell.dart` với card `HOME-STUDIO-001` → phải phối hợp
      (WP §8 tài liệu: làm chung một PR, hoặc tuần tự, KHÔNG song song).
- [x] **D2. Cách hiển thị 7 mode** → **D2-A: 7 thẻ phẳng** (lưới responsive
      4+3; phone nhỏ 2 cột), mỗi thẻ có mục tiêu 1 dòng + “N bước ▸”.
- [x] **D3. Nguồn “Khám phá công cụ ⚡”** → **D3-A (mặc định):** tái dùng
      `_buildQuickActions` (`ToolItem`) làm nguồn sự thật duy nhất; Home chỉ
      hiển thị tuyển chọn ≥5 (`Tipiṭaka · Video · Word Map · Triangle · Venn ·
      Cabin dịch live`) + nút “Xem tất cả ⚡”.
      *Owner có thể phủ quyết ở PR implementation (D3-B = danh sách riêng).*
- [x] **D4. Tool thiếu dữ liệu** → **D4-A: nút “Mở ngay” luôn mở được**; badge
      nói thiếu gì; màn hình đích tự dẫn tới chỗ khắc phục (Tipiṭaka →
      “Import hoặc tải dữ liệu”).
- [x] **D5. Mức độ dẫn đường** → **D5-A: checklist 3–5 bước + “Mở ngay” từng
      bước**, chạy trên màn hình thật. Coach-mark/hologram (D5-B) hoãn, không
      làm ở PR này.

## B. Rà nội dung 7 mode (mục 4 tài liệu) — ✅ chốt theo thiết kế đã trình

- [x] **NGHE** — mục tiêu + 4 bước (giữ nguyên như bản trình).
- [x] **NÓI** — mục tiêu + 4 bước.
- [x] **XEM** — mục tiêu + 4 bước.
- [x] **ĐỌC** — mục tiêu + 4 bước.
- [x] **VIẾT** — mục tiêu + 4 bước.
- [x] **HIỂU** — mục tiêu + 5 bước.
- [x] **NHỚ** — mục tiêu + 5 bước.
- [x] Thứ tự 7 thẻ: `NGHE · NÓI · XEM · ĐỌC · VIẾT · HIỂU · NHỚ` (lưới 4+3).
- [ ] *Nếu owner muốn sửa chữ/mục tiêu/bước cụ thể nào → ghi tại đây, PR
      implementation sẽ chỉnh:* ...............................................

## C. Bất biến (không cần chốt, chỉ xác nhận)

- [ ] “Chế độ trải nghiệm” cũ trong `read_settings_sheet.dart:90` **giữ nguyên**
      (lớp UX mới trên Home chỉ là vỏ dẫn đường).
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

- [x] **WP0** model mode + catalog tool (tái dùng `ToolItem`).
- [x] **WP1** Home: lưới 7 thẻ Studio + carousel ⚡ (+ khử id trùng
      `dictionary`≡`dict_manager`, `video_player`≡`video_library`).
- [x] **WP2** tour dẫn đường + persist tiến trình theo mode.
- [x] **WP3** i18n (ARB 6 locale) + test navigation + checkpoint KANBAN.
- [x] Đồng ý cách chia card con: `XP-MODE-002` (Home 7 thẻ + carousel) và
      `XP-MODE-003` (tour).
- [ ] **Phối hợp `HOME-STUDIO-001`** (D1-B làm trùng file): chọn 1 —
      [ ] PA1: PR của XP-MODE-001 làm luôn phần 7 thẻ (một lần sửa
      `home_screen.dart`), ghi vào lịch sử HOME-STUDIO-001;
      [ ] PA2: HOME-STUDIO-001 làm trước, XP-MODE-001 làm sau (tuần tự).

## G. AT nghiệm thu (dùng lại cho PR implementation)

- [ ] Home → **Phòng Studio** thấy đủ **7 thẻ mode** (lưới 4+3) + mục
      **“Khám phá công cụ ⚡”** (D1-B: KHÔNG có tab thứ 6).
- [ ] Chạm thẻ **ĐỌC** → làm theo từng bước → tới đúng chỗ từng bước (4/4),
      quay lại đúng bước đang dở.
- [ ] Chạm 1 thẻ mode khác (ví dụ **NHỚ**) → tour đúng, tiến trình lưu lại sau
      khi thoát/khôi phục app.
- [ ] Carousel hiện **≥5 tool ẩn**, trong đó có **Tipiṭaka**.
- [ ] Bấm **“Mở ngay”** Tipiṭaka → mở `TipitakaLibraryScreen`; máy chưa có DB →
      hiện màn hình “Tipiṭaka chưa có dữ liệu” + nút “Import hoặc tải dữ liệu”
      (không có nút chết).
- [ ] Bấm “Mở ngay” 4 tool khác (Video / Word Map / Triangle / Venn) → đúng màn hình.
- [ ] Tab Đọc → mở Cài đặt Text Studio → **“Chế độ trải nghiệm” cũ vẫn còn
      nguyên** và hoạt động như trước (đối chiếu bản ghi màn hình trước/sau).
- [ ] Icon ⚡ mở overlay cũ đúng như trước (tab Home vẫn thấy Tipiṭaka).
- [ ] Đổi locale EN / JA (chưa dịch hết) → chrome phần mới trên Home **không còn
      tiếng Việt**; mở file tiếng Việt thì nội dung vẫn là tiếng Việt.
- [ ] Thiết bị hẹp (≤360dp) → 7 thẻ + carousel ⚡ không tràn/cắt chữ; **bottom
      nav vẫn đúng 5 tab** như trước (đối chiếu ảnh chụp trước/sau).

---

**Chốt:** owner (ký/ngày) ............................ · quyết định
**D1 = B · D2 = A · D3 = A (mặc định, phủ quyết được ở PR code) · D4 = A · D5 = A**
(chốt qua Q&A 2026-09-16, bake-in vào tài liệu/ảnh ngày 2026-09-23).
