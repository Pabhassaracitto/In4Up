# XP-MODE-001 — Wireframe tab “Trải nghiệm” + Route inventory (DESIGN GATE, chưa code)

> **Trạng thái:** 📋 chờ owner chốt — Phase 1 (B8 trong
> `docs/project/AGENT_ASSIGNMENTS_2026-09-16.md`). **Chưa có dòng code nào của
> tính năng này.** Sau khi owner chốt §3 (D1–D5), mở **PR implementation riêng**
> với card con + test navigation (§8).
>
> Card: `XP-MODE-001` (KANBAN, batch 2026-09-16) · Branch thiết kế:
> `arena/01a0a703-in4up` · Base: `d40f604`
>
> **Deliverable của phase này (4 tệp, tất cả trong `docs/project/`):**
>
> | Tệp | Nội dung |
> |---|---|
> | `XP-MODE-001-wireframe.md` (file này) | wireframe + đặc tả 7 mode + tool khám phá + quyết định chờ chốt |
> | `assets/xp-mode-001-wireframe.png` (+ nguồn `.svg`) | ảnh wireframe 6 khối |
> | `XP-MODE-001-route-inventory.csv` | 28 entry điều hướng (7 MODE + 21 TOOL): route thật, file thật, trạng thái unavailable |
> | `XP-MODE-001-i18n-keys.csv` | key ARB mới + bản dịch vi/en/hi/zh/zh_TW/si |
> | `XP-MODE-001-review-checklist.md` | checklist owner dùng để chốt + AT sau này |

---

## 1. Hiện trạng — đã verify bằng code (không phải phỏng đoán)

| # | Sự thật | Bằng chứng (file:line) |
|---|---|---|
| 1 | “Chế độ trải nghiệm” hiện là **một mục trong sheet cài đặt Text Studio**, icon `auto_awesome` — chưa phải tab | `lib/screens/read_mode/sheets/read_settings_sheet.dart:90` (`_SectionTitle('Chế độ trải nghiệm')` → `_SubModeSelector`, class ở dòng 1763) |
| 2 | Shell có **5 tab**: `home, listen, read, understand, remember` | `lib/screens/main_shell.dart:52` (`enum _PrimaryTab`) |
| 3 | Sub-mode của Nghe = 0 Nghe / 1 Nói / 2 Xem (Video); của Đọc = 0 Đọc / 1 Viết | `lib/screens/main_shell.dart` `_buildCurrentScreen` (Nghe: `ListenModeScreen`, `SpeakModeScreen`, `VideoLibraryScreen`; Đọc: `ReadModeScreen`, `WriteStudioScreen`) |
| 4 | Icon sấm sét = “Công cụ nhanh” → `showToolsOverlayV2` | `lib/screens/main_shell.dart:1032` (`Icons.bolt_rounded`) → `_openQuickActions` (366) → `lib/screens/tools/tools_overlay_v2.dart:34` |
| 5 | Danh sách ⚡ **khác nhau theo tab**; ở tab Home có **23 mục** ⇒ tool mạnh bị chìm | `lib/screens/main_shell.dart:377` `_buildQuickActions` (switch theo `_currentTab`) |
| 6 | **Tipiṭaka CHỈ xuất hiện ở tab Home** (không có ở Nghe/Đọc/Hiểu/Nhớ) | `_buildQuickActions`, nhánh `_PrimaryTab.home` (`id: 'tipitaka'`) |
| 7 | Tipiṭaka **không thể “mở chết”**: màn hình luôn mở được; thiếu DB thì hiện màn hình khắc phục | `lib/features/tipitaka/screens/library_screen.dart:385` `_MissingDatabaseView` → `TipitakaDownloadScreen`; DB service throw `TipitakaDatabaseException` khi không có DB dùng được (`lib/features/tipitaka/services/db_service.dart:83`, asset là optional: `copyBundledDatabaseIfPresent` trả `null` khi thiếu asset) |
| 8 | Các tool “trống” đều có empty state riêng, không crash | Video: `lib/features/video/widgets/video_library_screen.dart:54` “Chưa có video nào”; Từ điển: `lib/features/dictionary/widgets/dict_manager_screen.dart:117` “Chưa có từ điển nào”; Map/Triangle/Venn: `map_tab.dart:42`, `triangle_tab.dart:95`, `venn_tab.dart:62` “Chưa có từ vựng” |
| 9 | YouGlish là WebView (cần mạng) | `lib/screens/tools/youglish/youglish_widget.dart:11-14` (`webview_flutter` / `webview_win_floating`) |
| 10 | Home hiện có 4 thẻ mode (thiếu XEM) → đang trùng việc với card `HOME-STUDIO-001` | `lib/screens/home/home_screen.dart:303` `_buildBentoModesGrid` |
| 11 | Rule #5 có **máy bắt ở tầng source**: generator quét mọi literal tiếng Việt trong `lib/**/*.dart`; test PDF quét cả thư mục feature | `tool/generate_legacy_ui_fallbacks.py:301` (`LIB.rglob("*.dart")`), `test/pdf_reader/pdf_reader_i18n_coverage_test.dart:46` |
| 12 | 3 nhãn mode **chưa có key ARB nào**: NÓI / XEM / VIẾT (chỉ có `listen/read/understand/remember`) | so `lib/l10n/app_vi.arb` (có `listen`, `read`, `understand`, `remember`, `studioRoom`) |

**Kết luận hiện trạng:** tab Trải nghiệm **không cần màn hình mode mới** — cả 7 mode
đều đã có màn hình thật. Việc cần làm là **lớp UX bao trùm** (điểm vào + dẫn
đường) và **phơi bày tool ẩn** (đặc biệt Tipiṭaka, hiện chỉ ở tab Home).

---

## 2. Wireframe

Ảnh: `docs/project/assets/xp-mode-001-wireframe.png` (nguồn chỉnh sửa được:
`assets/xp-mode-001-wireframe.svg`). Quy ước: ▣ màn hình đã có · ◻ mới tạo ·
▸ điều hướng thật · ⚡ tool ẩn · ⚠ unavailable · ! điểm chờ chốt.

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1 · ĐIỂM VÀO  (chờ chốt D1)                                          │
│   ● thêm tab thứ 6 “TRẢI NGHIỆM” vào bottom nav (5 tab cũ giữ nguyên)│
│   ○ hoặc: mở rộng thẻ “Phòng Studio” ở Home thành 7 thẻ              │
└──────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────┐
│ 2 · TAB TRẢI NGHIỆM                                                  │
│   ✦ TRẢI NGHIỆM            Guided Studio · chọn 1 mode để dẫn bước   │
│   ┌────────┬────────┬────────┬────────┐                              │
│   │ NGHE   │ NÓI    │ XEM    │ ĐỌC    │  4+3, responsive 2↔4 cột     │
│   ├────────┼────────┼────────┼────────┤  mỗi thẻ: mục tiêu 1 dòng +  │
│   │ VIẾT   │ HIỂU   │ NHỚ    │        │  “tab … · 4 bước ▸”          │
│   └────────┴────────┴────────┴────────┘                              │
│   KHÁM PHÁ CÔNG CỤ ⚡  (carousel, ≥5 thẻ: Tipiṭaka · Video · Word Map │
│   · Triangle · Venn · Cabin dịch live · …)  mỗi thẻ: danh mục Route  │
│   trạng thái ⚠ + nút [Mở ngay ▸]                                     │
└──────────────────────────────────────────────────────────────────────┘
┌───────────────────────────────────────┐┌─────────────────────────────┐
│ 3 · CHI TIẾT MODE (ví dụ ĐỌC)         ││ 4 · KHÁM PHÁ CÔNG CỤ ⚡     │
│   ‹ ĐỌC                  bước 1/4 ◻   ││  Tipiṭaka      ⚠ chưa có DB │
│   MỤC TIÊU (1 dòng)                   ││               [Mở ngay ▸]   │
│   1 · Chọn tài liệu để đọc [Mở ngay ▸]││  Video         ⚠ chưa import│
│   2 · Bật chế độ đọc          [ ▸ ]   ││  Word Map      ⚠ cần WordList│
│   3 · Bôi chọn để học         [ ▸ ]   ││  Triangle      ⚠ cần WordList│
│   4 · Nghe lại câu → VIẾT     [ ▸ ]   ││  Venn          ⚠ cần WordList│
│   [Bỏ qua tour] [✓ Hoàn thành]        ││  Cabin live    ⚠ mic + model │
└───────────────────────────────────────┘└─────────────────────────────┘
┌───────────────────────────────────────┐┌─────────────────────────────┐
│ 5 · CHÚ GIẢI (▣ ◻ ▸ ⚡ ⚠ !)           ││ 6 · BẤT BIẾN KHÔNG PHÁ      │
└───────────────────────────────────────┘└─────────────────────────────┘
```

**6 khối trong ảnh:** (1) điểm vào, (2) tab mặc định 7 thẻ + 3 thẻ carousel,
(3) chi tiết mode ĐỌC với 4 bước điều hướng thật, (4) danh sách tool ⚡ với
badge trạng thái, (5) chú giải, (6) bất biến (garammarExperienceMode cũ, rule #5,
không dep mới, không đổi hành vi 5 tab).

---

## 3. Điểm chờ owner chốt (agent KHÔNG tự quyết UX lớn)

| ID | Câu hỏi | Phương án | Đề xuất của agent | Hệ quả kỹ thuật |
|---|---|---|---|---|
| **D1** | Tab mới hay mở rộng Home? | **A.** Tab thứ 6 “Trải nghiệm” trong bottom nav<br>**B.** Không thêm tab; mở rộng thẻ “Phòng Studio” ở Home thành 7 thẻ | **A** — đúng câu owner (“cho nó ra màn hình tab”), tách khỏi `home_screen.dart` đang có `HOME-STUDIO-001` chờ làm, 5 tab cũ không đổi ⇒ rủi ro hồi quy nav thấp | A: `main_shell.dart` (+1 enum, +1 tab, 1 nhánh screen) — 1 file nav duy nhất. B: tranh chấp file với `HOME-STUDIO-001` |
| **D2** | 7 mode hiển thị thế nào? | **A.** 7 thẻ phẳng 4+3<br>**B.** 4 thẻ (theo tab) + bung sub-mode | **A** — owner yêu cầu đủ 7; tránh trùng lặp với mô hình 2 tầng của shell | Nhãn NÓI/XEM/VIẾT chưa có key ARB ⇒ cần 3 key + bản dịch T2 (§7) |
| **D3** | Nguồn dữ liệu “Khám phá công cụ”? | **A.** Tái dùng `_buildQuickActions` (`ToolItem`) — 1 nguồn sự thật<br>**B.** Danh sách riêng tuyển chọn trong tab | **A**, kèm test so khớp id (không để hai danh sách lệch) | A: giữ `main_shell.dart` ownership; tab mới chỉ *đọc lại* + gọi `_handleTool` |
| **D4** | Tool thiếu dữ liệu thì nút “Mở ngay”? | **A.** Luôn mở được + badge nói thiếu gì + màn hình khắc phục<br>**B.** Disable nút khi unavailable | **A** — đã verify các tool đều tự xử lý (Tipiṭaka → `_MissingDatabaseView`; Video/Từ điển → empty state + nút import) | Cần hàm probe trạng thái nhẹ, fail-soft (§5) |
| **D5** | Mức độ “dẫn đường”? | **A.** Checklist 3–5 bước + nút “Mở ngay” từng bước (chạy trên màn hình thật)<br>**B.** Thêm coach-mark/overlay hologram đè lên UI mode | **A** (WP2). B để sau như nâng cấp, vì overlay dễ vỡ khi UI mode đổi | A: 1 widget sheet + model tiến trình; B: cần API định vị widget trong mọi mode |

> Mọi câu D1–D5 đều ghi rõ trong `XP-MODE-001-review-checklist.md` để owner tick.

---

## 4. Đặc tả 7 mode dẫn đường

Nguyên tắc: **tour không dựng bản sao UI** — mỗi bước trỏ tới route thật, chạm
là mở đúng chỗ; khi tour tắt/không dùng, người dùng vẫn thao tác bình thường.

| # | Mode | Màn hình đích (route thật) | Mục tiêu (1 dòng) | Bước dẫn đường (route cho từng bước) |
|---|---|---|---|---|
| 1 | **NGHE** | Tab Nghe — `ListenModeScreen` (`listen_mode_screen.dart`) | Nghe hiểu audio thật theo câu, có lời khớp và lặp đúng chỗ khó | 1) Chọn audio (drawer Thư viện âm thanh / Thư viện nghe / file trên máy)<br>2) Đưa lời lên: nạp `.lrc` có sẵn hoặc “Tạo lời” (chọn ngôn ngữ, mặc định auto) — đã có lời thì hỏi *dùng bản đã lưu / tạo lại*<br>3) Luyện sâu: AB loop “Theo câu”/“Theo cụm”, tốc độ, số lần lặp<br>4) Chuyển hoá: mở **HIỂU** (đồng bộ) hoặc **Âm mục** khi cần mục lục |
| 2 | **NÓI** | Tab Nói — `SpeakModeScreen` (listen mode 1) | Nói lại đúng câu gốc (shadowing) để luyện phát âm và phản xạ | 1) Mở Nói (chip “Nói” ở tab Nghe; long-press tab Nghe nếu bật cài đặt shell)<br>2) Chọn câu/đoạn để luyện (từ audio đang phát / LRC / AB) — **không bắt buộc AB** (đồng bộ với `SHADOW-FILE-001`)<br>3) Nghe mẫu → ghi âm → so với câu gốc (kết quả nhận diện hiện ngay)<br>4) Lưu preset/ghi chú luyện tập; cần giọng người bản ngữ → mở **YouGlish** |
| 3 | **XEM** | Tab Nghe › Xem — `VideoLibraryScreen` (listen mode 2) | Xem video có phụ đề để học theo ngữ cảnh | 1) Mở Thư viện video<br>2) Nạp video vào thư viện (nút + → `VideoLibraryService.addVideo`)<br>3) Phát có phụ đề, chạm từ để tra/lưu<br>4) Đưa từ đã lưu sang **NHỚ** (Ôn tập) |
| 4 | **ĐỌC** | Tab Đọc — `ReadModeScreen` (read mode 0) | Đọc hiểu văn bản dài, bôi từ/câu theo ngữ cảnh, nghe được câu đang chọn | 1) Chọn tài liệu: Thư viện đọc (drawer trái) / “Thêm tài liệu” TXT·LRC·SRT·MD·JSON·DOCX / PDF·Web reader<br>2) Cài đặt Text Studio (Grammar Highlight, cỡ chữ, căn lề, chế độ màu) — *“Chế độ trải nghiệm” cũ nằm ở đây, giữ nguyên*<br>3) Bôi từ/cụm/câu → sheet lưu kèm topic + language; bôi nhiều → “lưu hàng loạt” + nhận diện “đã lưu”<br>4) TTS đọc câu đang chọn → nhảy sang **VIẾT** để chép lại |
| 5 | **VIẾT** | Tab Đọc › Viết — `WriteStudioScreen` (read mode 1) | Viết lại / chép / điền khuyết để nhớ chủ động nội dung vừa gặp | 1) Mở Viết (chip “Viết” ở tab Đọc)<br>2) Lấy nội dung nguồn: “Dùng dòng đang focus trong tab Đọc (#n)” hoặc đoạn chọn; mở PDF/Web reader ở chế độ viết<br>3) Chọn bài tập: chép chính tả theo audio, điền khuyết (“Đổi ô trống”), viết lại cùng ý, tóm tắt<br>4) Chấm: “Chấm nhanh” (không cần AI) hoặc phân tích bằng model AI local — chưa có model thì badge “Cần model AI local” + lối tắt tới Quản lý Model AI |
| 6 | **HIỂU** | Tab Hiểu — `UnderstandWorkspaceScreen` → `UnderstandModeScreen` (2 sub-tab: Đồng bộ · Shadowing) | Ghép audio ↔ text, đồng bộ dòng và hiểu ngữ cảnh trước khi ghi nhớ | 1) Mở tab Hiểu<br>2) Đảm bảo **có cả audio + text** (audio từ Nghe, text từ Đọc/Thư viện text) — thiếu cái nào thì nút mở đúng nguồn đó<br>3) Chỉnh đồng bộ dòng (auto-sync / nudge thời gian) + tuỳ chỉnh karaoke<br>4) Chạy “Đồng bộ” để đọc-theo-dòng, lặp câu<br>5) Nối tiếp: Shadowing (sub-tab) hoặc **Ôn tập** để chuyển thành ghi nhớ |
| 7 | **NHỚ** | Tab Nhớ — `RememberWorkspaceScreen` | Biến thứ đã gặp thành nhớ dài hạn (SRS/FSRS) và giữ nhịp ôn | 1) Mở tab Nhớ, xem “Đến hạn”<br>2) Ôn thẻ (**Ôn tập** / `ReviewTab`)<br>3) Nạp từ mới vào **Word List** (chưa có từ → hướng dẫn lưu từ khi đọc/nghe)<br>4) Học thuộc lòng cho bài dài (**Thuộc lòng** / Learn by Heart)<br>5) Nhìn tiến độ & lỗ hổng: **Timeline · Thống kê · Word Map · Triangle · Venn** |

**Tour UX (WP2, chạy trên màn hình thật):** sheet đáy, không chặn thao tác:

```
ĐỌC · bước 2/4        [Bỏ qua tour]  [✓ Đánh dấu hoàn thành]
Chọn tài liệu để đọc: mở Thư viện đọc hoặc “Thêm tài liệu”.
[Mở ngay ▸]  → push đúng route thật rồi quay lại đúng bước
```

- Tiến trình lưu **theo từng mode** (đã xem chưa / đang ở bước nào), có nút
  “chạy lại tour”; lần đầu vào mode chưa từng dùng → nhãn “Mới”.
- 3 điểm vào tour (tùy chọn D5): (a) chạm thẻ mode ở tab Trải nghiệm,
  (b) từ overlay ⚡ (“Xem hướng dẫn mode này”), (c) nút `?` trên appbar mode.
- Không có bước nào yêu cầu model/dữ liệu mới; mọi bước đều là hành động thật.

---

## 5. Mục “Khám phá công cụ ⚡” — ≥5 tool ẩn + trạng thái unavailable

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

Quy tắc trạng thái (bắt buộc trong WP1):

1. **Không có nút chết, không toast câm.** Badge nói **THIẾU GÌ**
   (dữ liệu / model / mạng / quyền) và nút “Mở ngay” **luôn** dẫn tới route thật
   — màn hình đó đã tự có đường khắc phục (đã verify ở §1 mục 7–9).
2. **Không tự tải** model/dữ liệu, không tự mở mạng; chỉ *nói* và *dẫn*.
3. Màu badge là “cần chuẩn bị” (hổ phách), không dùng đỏ lỗi.
4. **Fail-soft:** probe trạng thái chạy async, nhẹ (storage/DB meta), lỗi probe
   ⇒ không hiện badge (không chặn mở tab, không chặn mở tool).
5. Danh sách giữ **1 nguồn sự thật** = `_buildQuickActions` (`ToolItem`) — D3.

---

## 6. Route inventory (CSV) — cột và ghi chú

`docs/project/XP-MODE-001-route-inventory.csv`

`id, nhom, ten, tab_dang_thay_trong_sam_set, entrypoint_hien_tai, route_dich_file, loai_dieu_huong, trang_thai_unavailable_dieu_kien, phat_hien_bang_code, duong_khac_phuc, phu_thuoc, ghi_chu`

- Nhóm `MODE` = 7 màn hình mode gốc (đích của tour).
- Nhóm `TOOL` = các id trong ⚡ (kể cả id trùng: `dictionary` ≡ `dict_manager`,
  `video_player` ≡ `video_library` — ghi rõ để WP1 khử trùng lặp hiển thị).
- Cột `entrypoint_hien_tai` ghi đúng hàm trong `main_shell.dart` sẽ được tái
  dùng (`_handleTool('<id>')`, `_setListenMode(n)`, `_setReadMode(n)`,
  `_setPrimaryTab(...)`) — **không tạo cơ chế điều hướng thứ hai.**

---

## 7. i18n plan (rule #5, ADR-0002)

`docs/project/XP-MODE-001-i18n-keys.csv` — **20 key mới**, kèm vi/en/hi/zh/zh_TW/si
(bản dịch là bản nháp chờ owner/người bản ngữ rà).

| key | vi | en | dùng ở đâu |
|---|---|---|---|
| `experience` | Trải nghiệm | Explore | nhãn tab |
| `experienceSubtitle` | Guided Studio · chọn một mode để được dẫn từng bước | Guided Studio · pick a mode to be guided step by step | header tab |
| `experienceDiscoverTools` | Khám phá công cụ | Discover tools | tiêu đề mục carousel |
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
| `experienceToolNeedsImport` | Trống: chưa import | Empty: nothing imported yet | badge Video/Từ điển |
| `experienceToolNeedsWordList` | Trống: cần Word List | Empty: needs Word List | badge Map/Triangle/Venn |
| `experienceToolNeedsMicModel` | Cần mic + model STT | Needs mic + STT model | badge Cabin/Nói/Tạo lời |
| `experienceToolNeedsNetwork` | Cần mạng | Needs network | badge YouGlish/YouTube |
| `experienceToolNeedsAiModel` | Cần model AI local | Needs local AI model | badge Viết (phân tích AI) |
| `experienceNeedsAudioAndText` | Cần cả audio + text | Needs both audio and text | badge Hiểu |
| `experienceNeedsAudio` | Cần audio | Needs audio | badge Nghe/Âm mục |

Yêu cầu bắt buộc khi implement (đã đọc từ máy bắt trong repo):

1. Key mới thêm vào **ARB** (`lib/l10n/app_*.arb`), **không** hard-code tiếng
   Việt rồi trông vào shim — `tool/generate_legacy_ui_fallbacks.py:301` quét
   toàn bộ `lib/**/*.dart` và fail nếu có literal chưa phân loại.
2. Mọi entry phải có `en`; nhóm T2 (`hi`, `zh`, `zh_TW`, `si`) **phải dịch đủ
   trong cùng PR** (`test/locale_chrome_no_vietnamese_test.dart` — ADR-0002 wave 1).
3. **KHÔNG chạy `generate_arbs.py`** (đã vô hiệu trong AGENTS.md).
4. 3 nhãn mode chưa có key (`NÓI`/`XEM`/`VIẾT`): thêm `speak`/`watch`/`write`
   song song với `listen`/`read`/`understand`/`remember` đã có — **một nguồn**
   cho cả thẻ mode ở tab Trải nghiệm lẫn chip ở tab Nghe/Đọc; KHÔNG đụng key
   `commonSpeaking` đang dùng ở chỗ khác.
5. Bản dịch trong CSV là **bản nháp** để owner/người bản ngữ rà; máy chỉ kiểm
   tra “không còn ký tự Việt”, không kiểm tra chất lượng dịch.

---

## 8. Kế hoạch file + work package (cho PR implementation sau khi chốt)

| WP | Nội dung | File chạm (dự kiến) | Test |
|---|---|---|---|
| **WP0** | Model/đăng ký mode + tái dùng nguồn tool | `lib/screens/experience/models/experience_mode.dart` (mới), `lib/screens/experience/services/experience_tool_catalog.dart` (mới — đọc lại `ToolItem`) | unit: 7 mode đủ; id tool ⟷ `_buildQuickActions` khớp |
| **WP1** | Tab + lưới 7 thẻ + carousel ⚡ | `lib/screens/main_shell.dart` (+1 enum/tab/nhánh), `lib/screens/experience/experience_tab_screen.dart` (mới), `lib/screens/experience/widgets/mode_card.dart`, `.../tool_carousel_card.dart` (mới) | widget: 7 thẻ render; chạm thẻ → callback đúng |
| **WP2** | Tour dẫn đường + persist tiến trình | `lib/screens/experience/widgets/guided_tour_sheet.dart` (mới), `lib/screens/experience/services/tour_progress_store.dart` (mới; qua `StorageService`) | widget: 3–5 bước, “Mở ngay” gọi đúng route, “Bỏ qua/hoàn thành” lưu |
| **WP3** | i18n + checkpoint | `lib/l10n/app_{vi,en,hi,zh,zh_TW,si}.arb` + generated localizations, KANBAN | `flutter test test/locale_chrome_no_vietnamese_test.dart` |

**Test navigation (bắt buộc trong PR implementation):** test bấm từng thẻ mode
⇒ xác nhận đúng `_PrimaryTab`/sub-mode index được đặt; bấm “Mở ngay” của
**Tipiṭaka** ⇒ `TipitakaLibraryScreen` được push; bấm “Mở ngay” của 5 tool ⚡
khác ⇒ đúng route. Không đụng `lib/ffi/`, `UltraTimeStretch`, native C++, workflow.

---

## 9. Bất biến — không được phá

1. **`grammarExperienceMode` cũ GIỮ NGUYÊN**: key ARB, mục “Chế độ trải nghiệm”
   trong `read_settings_sheet.dart:90` + `_SubModeSelector` (1763) không đổi vị
   trí/hành vi; tab mới chỉ là **lớp UX bao trùm**.
2. **5 tab cũ + icon ⚡ + `showToolsOverlayV2` giữ nguyên hành vi**; tab mới chỉ
   *đọc lại* danh sách tool và gọi `_handleTool` (không có cơ chế nav thứ hai).
3. **Rule vàng #5**: chrome locale ≠ vi không còn tiếng Việt; key mới có `en` +
   đủ `hi/zh/zh_TW/si`.
4. Không thêm dependency; không đụng `lib/ffi/`, `UltraTimeStretch`, native C++,
   workflow CI.
5. Tour là **tùy chọn**: tắt tour ⇒ mọi mode hoạt động y như trước.
6. Không tạo danh sách tool thứ hai lệch với `_buildQuickActions` (D3).

## 10. Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|---|---|
| Thêm tab thứ 6 làm chật bottom nav trên máy nhỏ | Tab mới icon + nhãn ngắn; kiểm tra 360dp; phương án B (D1-B) vẫn giữ trong tài liệu |
| Danh sách ⚡ ở Home quá dài (23 mục) khi tab mới đọc lại toàn bộ | Tab chỉ hiển thị **tuyển chọn** (≥5 ưu tiên: Tipiṭaka, Video, Word Map, Triangle, Venn, Cabin) + nút “Xem tất cả ⚡” mở overlay cũ |
| Trạng thái unavailable bị “hứa” mà không phát hiện được | Fail-soft probe (D4 quy tắc 4); không hiện badge khi không chắc — badge là *gợi ý chuẩn bị*, không phải điều kiện chặn |
| Trùng việc với `HOME-STUDIO-001` (7 thẻ ở Home) | Nếu owner chốt D1-A: `HOME-STUDIO-001` vẫn làm ở Home (thẻ mode), hai nơi dùng chung model/đích điều hướng; ghi rõ trong PR để không tranh chấp `home_screen.dart` |
| i18n: literal mới rơi khỏi catalog ⇒ rule #5 đỏ | Dùng ARB ngay từ WP0/WP1; chạy `flutter test test/locale_chrome_no_vietnamese_test.dart` + generator check trước PR |

## 11. Bước tiếp theo (sau khi owner chốt)

1. Owner tick `XP-MODE-001-review-checklist.md` (chốt D1–D5, sửa chữ/mục tiêu).
2. Agent mở **PR implementation riêng** trên nhánh session, chia commit
   `model → tab+carousel → tour → i18n/docs`, kèm test navigation; KHÔNG squash.
3. Card con đề xuất: `XP-MODE-002` (tab + 7 thẻ + carousel),
   `XP-MODE-003` (tour dẫn đường + persist).
4. Cập nhật KANBAN theo governance (status-only + append lịch sử).
