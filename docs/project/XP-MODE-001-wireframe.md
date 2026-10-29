# XP-MODE-001 — Wireframe “Phòng Studio 7 mode + Khám phá công cụ ⚡” (DESIGN GATE, chưa code)

> **Trạng thái:** ✅ **owner ĐÃ CHỐT thiết kế (2026-09-16)** —
> **D1 = B** (KHÔNG thêm tab; mở rộng Phòng Studio ở Home thành 7 thẻ)
> · **D2 = A** (7 thẻ phẳng, lưới 4+3) · **D3 = A** (mặc định: tái dùng
> `_buildQuickActions` — owner có thể phủ quyết) · **D4 = A** (nút “Mở ngay” luôn
> mở được + badge nói thiếu gì) · **D5 = A** (checklist 3–5 bước + “Mở ngay” từng
> bước).
> **Vẫn chưa có dòng code nào của tính năng.** Bước tiếp theo: **PR implementation
> riêng** (WP0–WP3 bên dưới + test navigation) — xem §8 và §11.
>
> **Cập nhật 2026-09-23 — đã bake-in quyết định vào toàn bộ pack:** ảnh wireframe
> `assets/xp-mode-001-wireframe.png`/`.svg` **đã vẽ lại theo D1-B** (bỏ hẳn thiết kế
> tab thứ 6; khối 1 = điểm vào Home với 5 tab giữ nguyên), `XP-MODE-001-review-checklist.md`
> mục A/B đã tick theo quyết định owner, `XP-MODE-001-i18n-keys.csv` ghi rõ `experience`
> là tiêu đề mục trên Home (không phải nhãn tab). PR implementation **bắt buộc theo bản
> D1-B này**, không theo bản tab trước đó.
>
> Card: `XP-MODE-001` (KANBAN, batch 2026-09-16, lane **B8**) · Branch thiết kế:
> `arena/01a0a703-in4up` · Base: `d40f604` · PR thiết kế: #29 (draft)
>
> **Deliverable phase 1 (đã giao, tất cả trong `docs/project/`):**
>
> | Tệp | Nội dung |
> |---|---|
> | `XP-MODE-001-wireframe.md` (file này) | wireframe + đặc tả 7 mode + tool khám phá + quyết định đã chốt |
> | `assets/xp-mode-001-wireframe.png` (+ nguồn `.svg`) | ảnh wireframe 6 khối (đã cập nhật theo D1-B) |
> | `XP-MODE-001-route-inventory.csv` | 28 entry điều hướng (7 MODE + 21 TOOL): route thật, file thật, trạng thái unavailable |
> | `XP-MODE-001-i18n-keys.csv` | 20 key ARB mới + bản dịch vi/en/hi/zh/zh_TW/si |
> | `XP-MODE-001-review-checklist.md` | checklist chốt (đã tick) + bộ AT dùng cho PR implementation |

---

## 1. Hiện trạng — đã verify bằng code (không phải phỏng đoán)

| # | Sự thật | Bằng chứng (file:line) |
|---|---|---|
| 1 | “Chế độ trải nghiệm” hiện là **một mục trong sheet cài đặt Text Studio**, icon `auto_awesome` — không phải màn hình riêng | `lib/screens/read_mode/sheets/read_settings_sheet.dart:90` (`_SectionTitle('Chế độ trải nghiệm')` → `_SubModeSelector`, class ở dòng 1763) |
| 2 | Shell có **5 tab**: `home, listen, read, understand, remember` | `lib/screens/main_shell.dart:52` (`enum _PrimaryTab`) |
| 3 | Sub-mode của Nghe = 0 Nghe / 1 Nói / 2 Xem (Video); của Đọc = 0 Đọc / 1 Viết | `lib/screens/main_shell.dart` `_buildCurrentScreen` (Nghe: `ListenModeScreen`, `SpeakModeScreen`, `VideoLibraryScreen`; Đọc: `ReadModeScreen`, `WriteStudioScreen`) |
| 4 | Icon sấm sét = “Công cụ nhanh” → `showToolsOverlayV2` | `lib/screens/main_shell.dart:1032` (`Icons.bolt_rounded`) → `_openQuickActions` (366) → `lib/screens/tools/tools_overlay_v2.dart:34` |
| 5 | Danh sách ⚡ **khác nhau theo tab**; ở tab Home có **23 mục** ⇒ tool mạnh bị chìm | `lib/screens/main_shell.dart:377` `_buildQuickActions` (switch theo `_currentTab`) |
| 6 | **Tipiṭaka CHỈ xuất hiện ở tab Home** (không có ở Nghe/Đọc/Hiểu/Nhớ) | `_buildQuickActions`, nhánh `_PrimaryTab.home` (`id: 'tipitaka'`) |
| 7 | Tipiṭaka **không thể “mở chết”**: màn hình luôn mở được; thiếu DB thì hiện màn hình khắc phục | `lib/features/tipitaka/screens/library_screen.dart:385` `_MissingDatabaseView` → `TipitakaDownloadScreen`; DB service throw `TipitakaDatabaseException` khi không có DB dùng được (`lib/features/tipitaka/services/db_service.dart:83`, asset là optional: `copyBundledDatabaseIfPresent` trả `null` khi thiếu asset) |
| 8 | Các tool “trống” đều có empty state riêng, không crash | Video: `lib/features/video/widgets/video_library_screen.dart:54` “Chưa có video nào”; Từ điển: `lib/features/dictionary/widgets/dict_manager_screen.dart:117` “Chưa có từ điển nào”; Map/Triangle/Venn: `map_tab.dart:42`, `triangle_tab.dart:95`, `venn_tab.dart:62` “Chưa có từ vựng” |
| 9 | YouGlish là WebView (cần mạng) | `lib/screens/tools/youglish/youglish_widget.dart:11-14` (`webview_flutter` / `webview_win_floating`) |
| 10 | Home hiện có **4 thẻ mode** (gộp “Nghe · Nói”, “Đọc · Viết”, thiếu XEM) trong mục `studioRoom` | `lib/screens/home/home_screen.dart:303` `_buildBentoModesGrid` (grid 4 thẻ, `childAspectRatio` responsive) |
| 11 | Rule #5 có **máy bắt ở tầng source**: generator quét mọi literal tiếng Việt trong `lib/**/*.dart`; test PDF quét cả thư mục feature | `tool/generate_legacy_ui_fallbacks.py:301` (`LIB.rglob("*.dart")`), `test/pdf_reader/pdf_reader_i18n_coverage_test.dart:46` |
| 12 | 3 nhãn mode **chưa có key ARB nào**: NÓI / XEM / VIẾT (chỉ có `listen/read/understand/remember`) | so `lib/l10n/app_vi.arb` (có `listen`, `read`, `understand`, `remember`, `studioRoom`) |

**Kết luận hiện trạng:** **không cần màn hình mode mới** — cả 7 mode đều đã có màn
hình thật, và **không cần tab mới** (D1-B): việc cần làm là (a) **Phòng Studio ở
Home đủ 7 thẻ** với mục tiêu + số bước, (b) **tour dẫn đường** chạy trên màn hình
thật, (c) **mục “Khám phá công cụ ⚡”** ngay trên Home để phơi bày tool ẩn (đặc
biệt Tipiṭaka — hiện chỉ nằm trong ⚡ của tab Home).

---

## 2. Wireframe

Ảnh: `docs/project/assets/xp-mode-001-wireframe.png` (nguồn chỉnh sửa được:
`assets/xp-mode-001-wireframe.svg`). Quy ước: ▣ màn hình đã có · ◻ mới tạo ·
▸ điều hướng thật · ⚡ tool ẩn · ⚠ unavailable · ✅ đã chốt.

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1 · ĐIỂM VÀO — HOME  (✅ D1-B: KHÔNG thêm tab)                       │
│   Home giữ nguyên 5 tab shell; KHÔNG tạo _PrimaryTab mới            │
│   ✦ PHÒNG STUDIO (studioRoom) — ✅ D2-A: 7 thẻ phẳng, lưới 4+3       │
│   ✦ KHÁM PHÁ CÔNG CỤ ⚡ — mục mới ngay dưới Studio                  │
└──────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────┐
│ 2 · PHÒNG STUDIO 7 THẺ  (mỗi thẻ: mục tiêu 1 dòng + “N bước ▸”)      │
│   ┌────────┬────────┬────────┬────────┐                              │
│   │ NGHE   │ NÓI    │ XEM    │ ĐỌC    │  → listen 0/1/2 · read 0/1   │
│   ├────────┼────────┼────────┼────────┤  → understand · remember     │
│   │ VIẾT   │ HIỂU   │ NHỚ    │        │  chạm thẻ = mở mode + tour   │
│   └────────┴────────┴────────┴────────┘                              │
│   KHÁM PHÁ CÔNG CỤ ⚡ (carousel, ≥5 thẻ: Tipiṭaka · Video · Word Map │
│   · Triangle · Venn · Cabin · …)  danh mục Route + ⚠ + [Mở ngay ▸]   │
└──────────────────────────────────────────────────────────────────────┘
┌───────────────────────────────────────┐┌─────────────────────────────┐
│ 3 · TOUR DẪN ĐƯỜNG (ví dụ ĐỌC)  ◻     ││ 4 · KHÁM PHÁ CÔNG CỤ ⚡     │
│   ĐỌC                  bước 1/4 ◻     ││  Tipiṭaka      ⚠ chưa có DB │
│   MỤC TIÊU (1 dòng)                   ││               [Mở ngay ▸]   │
│   1 · Chọn tài liệu để đọc [Mở ngay ▸]││  Video         ⚠ chưa import│
│   2 · Bật chế độ đọc          [ ▸ ]   ││  Word Map      ⚠ cần WordList│
│   3 · Bôi chọn để học         [ ▸ ]   ││  Triangle      ⚠ cần WordList│
│   4 · Nghe lại câu → VIẾT     [ ▸ ]   ││  Venn          ⚠ cần WordList│
│   [Bỏ qua tour] [✓ Hoàn thành]        ││  Cabin live    ⚠ mic + model │
└───────────────────────────────────────┘└─────────────────────────────┘
┌───────────────────────────────────────┐┌─────────────────────────────┐
│ 5 · CHÚ GIẢI (▣ ◻ ▸ ⚡ ⚠ ✅)          ││ 6 · BẤT BIẾN KHÔNG PHÁ      │
└───────────────────────────────────────┘└─────────────────────────────┘
```

**6 khối trong ảnh:** (1) điểm vào = Home + 2 mục mới, (2) lưới **7 thẻ mode** +
carousel ⚡, (3) tour dẫn đường 4 bước của ĐỌC (mỗi bước một route thật), (4) danh
sách tool ⚡ với badge trạng thái, (5) chú giải, (6) bất biến (không thêm tab,
`grammarExperienceMode` cũ giữ nguyên, rule #5, không dep mới, tour là tuỳ chọn,
không tranh file với `HOME-STUDIO-001`).

---

## 3. Quyết định thiết kế — ✅ OWNER ĐÃ CHỐT (2026-09-16)

| ID | Câu hỏi | **Chốt** | Hệ quả kỹ thuật |
|---|---|---|---|
| **D1** | Điểm vào | ✅ **B — KHÔNG thêm tab;** mở rộng **Phòng Studio ở Home** | Không tạo `_PrimaryTab` mới, **không đụng bottom nav**. Sửa `home_screen.dart` + thêm callback ở `main_shell.dart`. **Điểm vào trùng file với card `HOME-STUDIO-001`** → xem §8 “Phối hợp card” |
| **D2** | Hiển thị 7 mode | ✅ **A — 7 thẻ phẳng**, lưới responsive 4+3 (phone nhỏ 2 cột) | Thay `_buildBentoModesGrid` (4 thẻ gộp) bằng 7 thẻ riêng; cần 3 nhãn ARB mới `speak`/`watch`/`write` |
| **D3** | Nguồn danh sách tool | ✅ **A (mặc định)** — tái dùng `_buildQuickActions` (`ToolItem`), tab Home | Một nguồn sự thật; widget mới chỉ *đọc lại* + gọi `_handleTool`; test so khớp id. *Owner phủ quyết được ở PR implementation* |
| **D4** | Tool thiếu dữ liệu | ✅ **A — nút “Mở ngay” luôn mở được**, badge nói **thiếu gì**, màn hình đích tự dẫn cách khắc phục | Đã verify: Tipiṭaka → `_MissingDatabaseView` → `TipitakaDownloadScreen`; Video/Từ điển/Map/Triangle/Venn có empty state. Probe trạng thái fail-soft (§5 quy tắc 4) |
| **D5** | Mức dẫn đường | ✅ **A — checklist 3–5 bước + “Mở ngay” từng bước** trên màn hình thật | 1 widget sheet + store tiến trình theo mode (WP2). Coach-mark/hologram (phương án B) để sau, không làm bây giờ |

Quyết định đã được tick trong `XP-MODE-001-review-checklist.md` mục A.

---

## 4. Đặc tả 7 mode dẫn đường

Nguyên tắc: **tour không dựng bản sao UI** — mỗi bước trỏ tới route thật, chạm là
mở đúng chỗ; khi tour tắt/không dùng, người dùng vẫn thao tác bình thường.

| # | Mode | Thẻ ở Home điều hướng tới (route thật) | Mục tiêu (1 dòng) | Bước dẫn đường (mỗi bước = 1 route thật) |
|---|---|---|---|---|
| 1 | **NGHE** | `_setListenMode(0)` → `ListenModeScreen` (`listen_mode_screen.dart`) | Nghe hiểu audio thật theo câu, có lời khớp và lặp đúng chỗ khó | 1) Chọn audio (drawer Thư viện âm thanh / Thư viện nghe / file trên máy)<br>2) Đưa lời lên: nạp `.lrc` có sẵn hoặc “Tạo lời” (chọn ngôn ngữ, mặc định auto) — đã có lời thì hỏi *dùng bản đã lưu / tạo lại*<br>3) Luyện sâu: AB loop “Theo câu”/“Theo cụm”, tốc độ, số lần lặp<br>4) Chuyển hoá: mở **HIỂU** (đồng bộ) hoặc **Âm mục** khi cần mục lục |
| 2 | **NÓI** | `_setListenMode(1)` → `SpeakModeScreen` | Nói lại đúng câu gốc (shadowing) để luyện phát âm và phản xạ | 1) Vào Nói (từ thẻ NÓI; long-press tab Nghe vẫn hoạt động như cũ)<br>2) Chọn câu/đoạn để luyện (audio đang phát / LRC / AB) — **không bắt buộc AB** (đồng bộ `SHADOW-FILE-001`)<br>3) Nghe mẫu → ghi âm → so với câu gốc (kết quả nhận diện hiện ngay)<br>4) Lưu preset/ghi chú; cần giọng người bản ngữ → mở **YouGlish** |
| 3 | **XEM** | `_setListenMode(2)` → `VideoLibraryScreen` | Xem video có phụ đề để học theo ngữ cảnh | 1) Mở Thư viện video<br>2) Nạp video vào thư viện (nút + → `VideoLibraryService.addVideo`)<br>3) Phát có phụ đề, chạm từ để tra/lưu<br>4) Đưa từ đã lưu sang **NHỚ** (Ôn tập) |
| 4 | **ĐỌC** | `_setReadMode(0)` → `ReadModeScreen` | Đọc hiểu văn bản dài, bôi từ/câu theo ngữ cảnh, nghe được câu đang chọn | 1) Chọn tài liệu: Thư viện đọc (drawer trái) / “Thêm tài liệu” TXT·LRC·SRT·MD·JSON·DOCX / PDF·Web reader<br>2) Cài đặt Text Studio (Grammar Highlight, cỡ chữ, căn lề, chế độ màu) — *“Chế độ trải nghiệm” cũ nằm ở đây, giữ nguyên*<br>3) Bôi từ/cụm/câu → sheet lưu kèm topic + language; bôi nhiều → “lưu hàng loạt” + nhận diện “đã lưu”<br>4) TTS đọc câu đang chọn → nhảy sang **VIẾT** để chép lại |
| 5 | **VIẾT** | `_setReadMode(1)` → `WriteStudioScreen` | Viết lại / chép / điền khuyết để nhớ chủ động nội dung vừa gặp | 1) Vào Viết (từ thẻ VIẾT; chip “Viết” ở tab Đọc vẫn hoạt động)<br>2) Lấy nội dung nguồn: “Dùng dòng đang focus trong tab Đọc (#n)” hoặc đoạn chọn; mở PDF/Web reader ở chế độ viết<br>3) Chọn bài tập: chép chính tả theo audio, điền khuyết (“Đổi ô trống”), viết lại cùng ý, tóm tắt<br>4) Chấm: “Chấm nhanh” (không cần AI) hoặc phân tích bằng model AI local — chưa có model thì badge “Cần model AI local” + lối tắt Quản lý Model AI |
| 6 | **HIỂU** | `_setPrimaryTab(understand)` → `UnderstandWorkspaceScreen` → `UnderstandModeScreen` (2 sub-tab: Đồng bộ · Shadowing) | Ghép audio ↔ text, đồng bộ dòng và hiểu ngữ cảnh trước khi ghi nhớ | 1) Mở tab Hiểu<br>2) Đảm bảo **có cả audio + text** (audio từ Nghe, text từ Đọc/Thư viện text) — thiếu cái nào thì nút mở đúng nguồn đó<br>3) Chỉnh đồng bộ dòng (auto-sync / nudge thời gian) + tuỳ chỉnh karaoke<br>4) Chạy “Đồng bộ” để đọc-theo-dòng, lặp câu<br>5) Nối tiếp: Shadowing (sub-tab) hoặc **Ôn tập** để chuyển thành ghi nhớ |
| 7 | **NHỚ** | `_setPrimaryTab(remember)` → `RememberWorkspaceScreen` | Biến thứ đã gặp thành nhớ dài hạn (SRS/FSRS) và giữ nhịp ôn | 1) Mở tab Nhớ, xem “Đến hạn”<br>2) Ôn thẻ (**Ôn tập** / `ReviewTab`)<br>3) Nạp từ mới vào **Word List** (chưa có từ → hướng dẫn lưu từ khi đọc/nghe)<br>4) Học thuộc lòng cho bài dài (**Thuộc lòng** / Learn by Heart)<br>5) Nhìn tiến độ & lỗ hổng: **Timeline · Thống kê · Word Map · Triangle · Venn** |

**Tour UX (WP2, chạy trên màn hình thật):** sheet đáy, không chặn thao tác:

```
ĐỌC · bước 2/4        [Bỏ qua tour]  [✓ Đánh dấu hoàn thành]
Chọn tài liệu để đọc: mở Thư viện đọc hoặc “Thêm tài liệu”.
[Mở ngay ▸]  → push đúng route thật rồi quay lại đúng bước
```

- Tiến trình lưu **theo từng mode** (đã xem chưa / đang ở bước nào), có nút
  “chạy lại tour”; mode chưa từng dùng → nhãn “Mới” trên thẻ.
- **Điểm vào tour (D1-B + D5-A):** (a) chạm **thẻ mode** ở Phòng Studio (mở mode +
  mở tour lần đầu), (b) tuỳ chọn từ overlay ⚡ (“Xem hướng dẫn mode này”),
  (c) nút `?` trên appbar của mode (nếu bước đó rẻ — quyết định ở PR implementation).
- Không có bước nào yêu cầu model/dữ liệu mới; mọi bước đều là hành động thật.

---

## 5. Mục “Khám phá công cụ ⚡” — ≥5 tool ẩn + trạng thái unavailable

**Vị trí (D1-B):** một **mục trên Home, ngay dưới lưới 7 thẻ Studio** (không phải
tab riêng). Carousel ngang — mỗi thẻ: icon + tên + 1 dòng mô tả + badge trạng thái
+ nút “Mở ngay”; có nút “Xem tất cả ⚡” mở overlay cũ (`showToolsOverlayV2` giữ
nguyên).

Bảng đầy đủ 28 entry: `XP-MODE-001-route-inventory.csv`. Trích 7 thẻ tiêu biểu
(cột “⚡ chỉ có ở tab nào” là **kết quả đọc code**, cho thấy vì sao người dùng
không thấy tool):

| Thẻ | ⚡ chỉ có ở tab | Route khi bấm “Mở ngay” | Trạng thái unavailable + đường khắc phục |
|---|---|---|---|
| **Tipiṭaka** (ưu tiên owner) | **Home** (duy nhất) | `TipitakaLibraryScreen` (`lib/features/tipitaka/screens/library_screen.dart`) | ⚠ “Chưa có dữ liệu” khi không có DB dùng được → **vẫn mở được**, `_MissingDatabaseView` → `TipitakaDownloadScreen` (import DB / gói ngôn ngữ) |
| **Video (local)** | Home | `VideoLibraryScreen` | ⚠ “Trống: chưa import” → empty state + nút thêm video |
| **Word Map** | Home, Nhớ | `MapTab` | ⚠ “Trống: cần WordList” → mở Word List/Đọc để lưu từ |
| **Triangle** | Home, Nhớ | `TriangleTab` | ⚠ “Trống: cần WordList” |
| **Venn** | Home, Nhớ | `VennTab` | ⚠ “Trống: cần WordList” |
| **Cabin dịch live** | Home, Nghe | `LiveCabinScreen` | ⚠ “Cần mic + model STT” → `SttModelSettingsScreen` (`SherpaModelManager`) |
| **YouGlish** | Home | `YouGlishScreen` (WebView) | ⚠ “Cần mạng” |

Quy tắc trạng thái (bắt buộc trong WP1, đã chốt D4-A):

1. **Không có nút chết, không toast câm.** Badge nói **THIẾU GÌ**
   (dữ liệu / model / mạng / quyền) và nút “Mở ngay” **luôn** dẫn tới route thật
   — màn hình đó đã tự có đường khắc phục (đã verify ở §1 mục 7–9).
2. **Không tự tải** model/dữ liệu, không tự mở mạng; chỉ *nói* và *dẫn*.
3. Màu badge là “cần chuẩn bị” (hổ phách), không dùng đỏ lỗi.
4. **Fail-soft:** probe trạng thái chạy async, nhẹ (storage/DB meta), lỗi probe
   ⇒ không hiện badge (không chặn mở Home, không chặn mở tool).
5. Danh sách giữ **1 nguồn sự thật** = `_buildQuickActions` (`ToolItem`) — D3.

---

## 6. Route inventory (CSV) — cột và ghi chú

`docs/project/XP-MODE-001-route-inventory.csv`

`id, nhom, ten, tab_dang_thay_trong_sam_set, entrypoint_hien_tai, route_dich_file, loai_dieu_huong, trang_thai_unavailable_dieu_kien, phat_hien_bang_code, duong_khac_phuc, phu_thuoc, ghi_chu`

- Nhóm `MODE` = 7 màn hình mode gốc (đích của **thẻ mode** ở Home và của tour).
- Nhóm `TOOL` = các id trong ⚡ (kể cả id trùng: `dictionary` ≡ `dict_manager`,
  `video_player` ≡ `video_library` — ghi rõ để WP1 khử trùng lặp hiển thị).
- Cột `entrypoint_hien_tai` ghi đúng hàm trong `main_shell.dart` sẽ được tái
  dùng (`_handleTool('<id>')`, `_setListenMode(n)`, `_setReadMode(n)`,
  `_setPrimaryTab(...)`, và **callback mới cho Home**: `onNavigateToSpeak`,
  `onNavigateToVideo`, `onNavigateToWrite`) — **không tạo cơ chế điều hướng thứ
  hai, không thêm tab**.

---

## 7. i18n plan (rule #5, ADR-0002)

`docs/project/XP-MODE-001-i18n-keys.csv` — **20 key mới**, kèm vi/en/hi/zh/zh_TW/si
(bản dịch là bản nháp chờ owner/người bản ngữ rà).

| key | vi | en | dùng ở đâu (đã cập nhật theo D1-B) |
|---|---|---|---|
| `experience` | Trải nghiệm | Explore | tiêu đề mục dẫn đường/khám phá trên Home (**không còn là nhãn tab**) |
| `experienceSubtitle` | Guided Studio · chọn một mode để được dẫn từng bước | Guided Studio · pick a mode to be guided step by step | phụ đề dưới tiêu đề Phòng Studio |
| `experienceDiscoverTools` | Khám phá công cụ | Discover tools | tiêu đề mục carousel ⚡ trên Home |
| `experienceGoal` | MỤC TIÊU | GOAL | khối mục tiêu trong chi tiết mode |
| `experienceStepCounter` | bước {n}/{m} | step {n} of {m} | header tour |
| `experienceOpenNow` | Mở ngay | Open | nút mở route |
| `experienceSkipTour` | Bỏ qua tour | Skip tour | nút |
| `experienceMarkDone` | Đánh dấu hoàn thành | Mark as done | nút |
| `experienceRestartTour` | Chạy lại tour | Restart tour | nút |
| `speak` | Nói | Speak | thẻ mode NÓI + chip ở tab Nghe |
| `watch` | Xem | Watch | thẻ mode XEM |
| `write` | Viết | Write | thẻ mode VIẾT + chip ở tab Đọc |
| `experienceToolNeedsData` | Chưa có dữ liệu | No data yet | badge Tipiṭaka |
| `experienceToolNeedsImport` | Trống: chưa import | Empty: nothing imported yet | badge Video / Từ điển |
| `experienceToolNeedsWordList` | Trống: cần Word List | Empty: needs Word List | badge Map/Triangle/Venn |
| `experienceToolNeedsMicModel` | Cần mic + model STT | Needs mic + STT model | badge Cabin/Nói |
| `experienceToolNeedsNetwork` | Cần mạng | Needs network | badge YouGlish/YouTube |
| `experienceToolNeedsAiModel` | Cần model AI local | Needs local AI model | badge Viết (đường AI) |
| `experienceNeedsAudioAndText` | Cần cả audio + text | Needs both audio and text | badge HIỂU |
| `experienceNeedsAudio` | Cần audio | Needs audio | badge NGHE / Âm mục |

> Tiêu đề khu vực 7 thẻ **tái dùng key có sẵn `studioRoom`** (vi “PHÒNG STUDIO”) —
> không tạo chuỗi trùng.

Yêu cầu bắt buộc khi implement (đã đọc từ máy bắt trong repo):

1. Key mới thêm vào **ARB** (`lib/l10n/app_*.arb`), **không** hard-code tiếng
   Việt rồi trông vào shim — `tool/generate_legacy_ui_fallbacks.py:301` quét
   toàn bộ `lib/**/*.dart` và fail nếu có literal chưa phân loại.
2. Mọi entry phải có `en`; nhóm T2 (`hi`, `zh`, `zh_TW`, `si`) **phải dịch đủ
   trong cùng PR** (`test/locale_chrome_no_vietnamese_test.dart` — ADR-0002 wave 1).
3. **KHÔNG chạy `generate_arbs.py`** (đã vô hiệu trong AGENTS.md).
4. 3 nhãn mode chưa có key (`NÓI`/`XEM`/`VIẾT`): thêm `speak`/`watch`/`write`
   song song với `listen`/`read`/`understand`/`remember` đã có — **một nguồn**
   cho cả thẻ mode ở Studio lẫn chip ở tab Nghe/Đọc; KHÔNG đụng `commonSpeaking`.
5. Bản dịch trong CSV là **bản nháp** để owner/người bản ngữ rà; máy chỉ kiểm
   tra “không còn ký tự Việt”, không kiểm tra chất lượng dịch.

---

## 8. Kế hoạch file + work package (cho PR implementation sau khi chốt)

| WP | Nội dung | File chạm (dự kiến) | Test |
|---|---|---|---|
| **WP0** | Model 7 mode + tiến trình tour + catalog tool (tái dùng `ToolItem`) | `lib/screens/home/experience/models/experience_mode.dart` (mới), `.../services/tour_progress_store.dart` (mới), `.../services/experience_tool_catalog.dart` (mới), `lib/services/storage_service.dart` (thêm getter/setter tiến trình) | unit: đủ 7 mode + đúng đích điều hướng; id tool ⟷ `_buildQuickActions` khớp |
| **WP1** | Home: lưới 7 thẻ (D2-A) + carousel ⚡ + callback mới từ shell | `lib/screens/home/home_screen.dart` (`_buildBentoModesGrid` → 7 thẻ; thêm mục “Khám phá công cụ ⚡”), `lib/screens/home/widgets/tool_discovery_section.dart` (mới), `lib/screens/main_shell.dart` (thêm `onNavigateToSpeak/Video/Write/…` — **KHÔNG thêm tab**) | widget: 7 thẻ render + bấm từng thẻ gọi đúng callback; bấm “Mở ngay” Tipiṭaka → `TipitakaLibraryScreen` được push |
| **WP2** | Tour dẫn đường (D5-A) + persist tiến trình | `lib/screens/home/experience/widgets/guided_tour_sheet.dart` (mới), nối vào callback thẻ mode | widget: 3–5 bước, “Mở ngay” gọi đúng route, “Bỏ qua/hoàn thành” lưu + đọc lại |
| **WP3** | i18n + checkpoint | `lib/l10n/app_{vi,en,hi,zh,zh_TW,si}.arb` + generated localizations, KANBAN | `flutter test test/locale_chrome_no_vietnamese_test.dart` |

**Test navigation (bắt buộc trong PR implementation):** bấm từng thẻ mode ⇒ đúng
`_PrimaryTab`/sub-mode index; bấm “Mở ngay” của **Tipiṭaka** ⇒
`TipitakaLibraryScreen` được push; bấm “Mở ngay” của 5 tool ⚡ khác ⇒ đúng route.
Không đụng `lib/ffi/`, `UltraTimeStretch`, native C++, workflow.

### Phối hợp card (quan trọng — D1-B làm trùng file với `HOME-STUDIO-001`)

`HOME-STUDIO-001` (lane B5) cũng sửa **đúng** `home_screen.dart`
`_buildBentoModesGrid` để thêm thẻ XEM và **đúng** callback `main_shell.dart`.
Với D1-B, phần “7 thẻ Studio” của hai card là **cùng một việc**. Đề xuất (chờ owner
quyết ở PR implementation, agent không tự hủy/đổi phạm vi card của lane khác):

- **Phương án 1 (khuyến nghị):** PR implementation của `XP-MODE-001` **bao gồm luôn**
  việc 7 thẻ của `HOME-STUDIO-001` (một lần sửa `home_screen.dart`), rồi ghi vào
  lịch sử `HOME-STUDIO-001` là “thực hiện trong PR XP-MODE-001” — tránh hai agent
  chạm cùng file.
- **Phương án 2:** `HOME-STUDIO-001` làm trước (chỉ 7 thẻ), `XP-MODE-001` làm sau
  (mục tiêu + số bước + tour + carousel ⚡) — tuần tự, không song song.

---

## 9. Bất biến — không được phá

1. **KHÔNG thêm tab mới** (D1-B): bottom nav vẫn 5 tab `Home · NGHE · ĐỌC · HIỂU · NHỚ`;
   không thêm giá trị vào `enum _PrimaryTab`.
2. **`grammarExperienceMode` cũ GIỮ NGUYÊN**: key ARB, mục “Chế độ trải nghiệm”
   trong `read_settings_sheet.dart:90` + `_SubModeSelector` (1763) không đổi vị
   trí/hành vi; tính năng mới chỉ là **lớp UX bao trùm trên Home**.
3. **Icon ⚡ + `showToolsOverlayV2` giữ nguyên hành vi**; mục “Khám phá công cụ” chỉ
   *đọc lại* danh sách tool và gọi `_handleTool` (không có cơ chế nav thứ hai).
4. **Rule vàng #5**: chrome locale ≠ vi không còn tiếng Việt; key mới có `en` +
   đủ `hi/zh/zh_TW/si`.
5. Không thêm dependency; không đụng `lib/ffi/`, `UltraTimeStretch`, native C++,
   workflow CI.
6. Tour là **tùy chọn**: tắt tour ⇒ Home và mọi mode hoạt động y như trước.
7. Không tạo danh sách tool thứ hai lệch với `_buildQuickActions` (D3).
8. Không tạo màn hình mode mới — 7 đích điều hướng đều là màn hình đã có.

## 10. Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|---|---|
| **Hai card cùng sửa `home_screen.dart`** (`HOME-STUDIO-001` + `XP-MODE-001`) | §8 “Phối hợp card”: một PR/lane làm cả hai, hoặc tuần tự; ghi rõ trong PR |
| Home dài thêm (7 thẻ + carousel ⚡) làm loãng “Command center” | Thẻ mode gọn (icon + nhãn + mục tiêu 1 dòng); carousel nằm dưới, thu gọn được; kiểm tra 360dp |
| Danh sách ⚡ ở Home quá dài (23 mục) nếu phơi hết | Home chỉ hiển thị **tuyển chọn** ≥5 (Tipiṭaka, Video, Word Map, Triangle, Venn, Cabin) + nút “Xem tất cả ⚡” mở overlay cũ |
| Trạng thái unavailable bị “hứa” mà không phát hiện được | Fail-soft probe (§5 quy tắc 4); badge là *gợi ý chuẩn bị*, không phải điều kiện chặn |
| i18n: literal mới rơi khỏi catalog ⇒ rule #5 đỏ | Dùng ARB ngay từ WP0/WP1; chạy `flutter test test/locale_chrome_no_vietnamese_test.dart` + generator check trước PR |
| Tour bị coi là “hướng dẫn suông” nếu bước không mở được đúng chỗ | Mỗi bước **bắt buộc** có route thật + test navigation (§8) |

## 11. Bước tiếp theo (sau khi owner chốt — đã chốt 2026-09-16)

1. ✅ Owner đã chốt D1-B / D2-A / D3-A / D4-A / D5-A (checklist mục A đã tick).
2. ⏭️ Mở **PR implementation riêng** trên nhánh session, chia commit
   `WP0 model → WP1 Home 7 thẻ + carousel ⚡ → WP2 tour + persist → WP3 i18n/docs`,
   kèm **test navigation**; KHÔNG squash.
3. Card con đề xuất: `XP-MODE-002` (Home 7 thẻ Studio + mục Khám phá công cụ ⚡),
   `XP-MODE-003` (tour dẫn đường + persist tiến trình).
4. Chốt cách phối hợp với `HOME-STUDIO-001` (§8) **trước khi** chạm
   `home_screen.dart`.
5. Cập nhật KANBAN theo governance (status-only + append lịch sử).
