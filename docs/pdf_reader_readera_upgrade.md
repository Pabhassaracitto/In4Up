# PDF Reader — phân tích hiện trạng & đề xuất nâng cấp (tham chiếu ReadEra)

> Bản thảo luận (chưa phải kế hoạch đã chốt). Mọi nhận định đều kèm `file:dòng`
> để kiểm chứng. Ngày phân tích: 05-09-2026, branch `arena/01a07250-in4up`.
> Đối chiếu: ReadEra (Play Store `org.readera`, iOS `id1669188337`, changelog
> 1.1.0 → 1.2.2 + Android 26.05.20) và tài liệu `pdfrx` (pub.dev, 2.6.1).

---

## 0. TL;DR — 12 dòng

1. **Phần "não" của tool này đã ở mức rất tốt** (tap từ → CEFR/từ loại/ghi nhớ,
   recall markers, lưu theo topic+language, mở lại đúng ngữ cảnh, nguồn cho Viết).
   Đó là thứ ReadEra **không có**. Đừng từ bỏ để đuổi theo ReadEra.
2. **Phần "cơ thể" (reader mechanics) thì chưa đạt mức chuyên nghiệp**: thiếu
   search trong tài liệu, thiếu TOC/outline, thiếu thumbnail, thiếu bookmark thật,
   thiếu theme ngày/đêm/sepia, thiếu layout hai trang/cắt lề, thiếu progress %
   ở thư viện.
3. Có **3 lỗi làm hỏng đúng tính năng đinh**, và chúng cheap to fix:
   (a) **không bôi đen được chữ ở chế độ PDF** → toàn bộ SelectionBar (6 hành động)
   không bao giờ hiện; (b) **nút prev/next trên thanh TTS là nút giả** (no-op);
   (c) **TTS trong PDF không highlight từ/câu** dù overlay đã có sẵn tham số.
4. ReadEra dạy ta một nguyên tắc thiết kế: **chrome tối giản + một nút chạm ở góc
   trên-phải để bookmark**, mọi thứ khác ẩn vào "About document". Hiện tại
   toolbar PDF của ta có 5 chip chữ + FAB + bottom bar → quá tải khi đọc.
5. ReadEra **không copy file vào app** và **giữ bookmark/progress ngay cả khi file
   bị xoá/di chuyển**. Ta thì khoá toàn bộ ghi chú theo `pdfPath.hashCode`
   (32-bit, va chạm được, mất sạch khi file đổi đường dẫn) — đây là lỗ hổng
   niềm tin lớn nhất của một tool đọc tài liệu.
6. Kiến trúc overlay hiện tại (GestureDetector phủ kín từng trang + `setState`
   toàn màn hình mỗi khi viewer báo hiệu) vừa **chống lại gesture của pdfrx**
   (pan/zoom/selection) vừa **tốn frame** khi cuộn. pdfrx 2.4.0 thêm
   `PdfOverlayInteractionRegion` đúng vì issue #376 này.
7. Ràng buộc nâng cấp pdfrx: repo pin `pdfrx: ^2.2.24` (pubspec.yaml:96), CI
   Flutter **3.44.1 / Dart 3.11.5**. pdfrx **2.5.0 trở lên yêu cầu Flutter 3.47**
   → trần khả dụng ngay bây giờ là **2.4.8** (vẫn có `PdfOverlayInteractionRegion`,
   fix selection/tiến trình tải trang, fix `PdfPageView` rò ảnh). Muốn 2.6.x thì
   phải nâng toolchain — quyết định riêng, tầm ảnh hưởng lớn hơn PDF.
8. Text extraction đang **bỏ qua cấu trúc fragment/block/line** → PDF 2 cột đọc
   nhầm thứ tự, TTS đọc lẫn chân trang/số trang. Cần `PdfLayoutEngine` nếu muốn
   "chuyên nghiệp" thật sự.
9. Text Mode extract **cả tài liệu trong một vòng lặp trên UI isolate**
   (pdf_text_extractor.dart:53-60) → treo với file vài trăm trang, không % tiến độ.
10. `Song ngữ EN → VN` hiện **chỉ đọc tiếng Anh** (controller:452-470, code comment
    nhận "bỏ qua phần dịch"). UI đang hứa một thứ không tồn tại.
11. **Chưa có test nào** cho `pdf_reader` (`grep -rl PdfReader test/` = 0) + **vi phạm
    quy tắc vàng #5** ở ~12 chuỗi chrome hardcode tiếng Việt (không có trong ARB,
    overrides lẫn generated catalog).
12. Đề xuất: **Wave 0 sửa đúng-đã (2–3 ngày) → Wave 1 reader fundamentals
    (ReadEra parity) → Wave 2 thư viện/continuity → Wave 3 chất riêng
    (learning brain) → Wave 4 perf/a11y/keyboard**. Chi tiết mục 4.

---

## 1. Hiện trạng

### 1.1 Bản đồ code (`lib/features/pdf_reader/`, 5.605 dòng)

| File | Dòng | Vai trò |
|---|---|---|
| `pdf_reader_screen.dart` | 1402 | Scaffold, chrome auto-hide, PdfViewer + overlays, Text Mode, SelectionBar, AnnotationManager, tap→word sheet |
| `pdf_reader_controller.dart` | 715 | Document, ColorMode, grammar presets, words cache, TTS, annotations, VocabContext |
| `widgets/pdf_word_tap_sheet.dart` | 1037 | Sheet tra từ/lưu từ/hồ sơ tri thức |
| `widgets/pdf_toolbar.dart` | 598 | Top chrome + Options sheet |
| `widgets/pdf_annotation_sheet.dart` | 429 | Xem/sửa/xoá ghi chú |
| `widgets/pdf_wordlist_panel.dart` | 345 | Panel từ đã lưu (split view) |
| `widgets/pdf_word_overlay.dart` | 311 | CustomPaint highlight từ / focus cue / recall |
| `widgets/pdf_tts_bar.dart` | 256 | Bottom chrome TTS |
| `services/pdf_text_extractor.dart` | 200 | `loadText()` → fullText + charRects, cache |
| `services/pdf_annotation_storage.dart` | 103 | Hive JSON, key theo path |
| `models/*`, `pdf_annotation_layer.dart` | 213 | PdfWordInfo, PdfAnnotation, layer |

### 1.2 Điểm mạnh thật sự (giữ nguyên, đừng đụng)

- **Ba chế độ tô màu** (`ColorMode`: wordType / cefrLevel / difficulty) + grammar
  preset/palette dùng chung với Web Reader → đây là "đặc sản" không reader phổ thông nào có.
- **Mỗi từ mang theo ngữ cảnh** (`PdfWordInfo.contextSnippet`, `startOffset/endOffset`,
  `rectHint`, `pageIndexHint`) → reopened đúng chỗ theo quy tắc vàng #3.
- **Ba ngả lưu** (WordList + Vườn Nhớ/SM-2 + Unified Knowledge) và **batch save từ trang**
  (`SelectionSaveSheet`) → flow học từ liền mạch, không rời màn hình đọc.
- **Text Mode** → đẩy toàn bộ chữ vào Read Mode / Writing Studio (rewrite/summary).
- **Đã có 8 điểm vào** (`PdfReaderScreen(` tại main_shell:716, empty_state:194, library:228/293/392, quick_library:85, text_library_drawer:355, unified_knowledge_sheet:724) (main_shell tool, library, quick library, empty state,
  text_library_drawer, unified_knowledge_sheet…) → không phải tool mồ côi.

### 1.3 Những gìReadEra có mà ta chưa có (mục 3 chi tiết)

Search trong file · TOC/outline + tiến chương · thumbnail/page grid · bookmark ·
theme (day/night/sepia/console) · fit width/page + crop margin + hai trang ·
single-column cho trang scan · progress line kéo được · % tiến độ + cover trong
thư viện · multi-document · keyboard shortcuts · TTS chạy nền có notification ·
**và điểm mấu chốt: toàn bộ trạng thái đọc sống sót khi file bị di chuyển/xoá.**

---

## 2. Lỗi & đứt gãy trải nghiệm (P0) — có bằng chứng

| # | Vấn đề | Bằng chứng | Hệ quả với người dùng |
|---|---|---|---|
| P0-1 | **Chế độ PDF không bôi đen được text.** `setSelection()` chỉ được gọi từ `SelectableText` của Text Mode. Không có dòng nào nối `PdfViewerController` selection → controller, dù comment ở `pdf_reader_screen.dart:73` nói "Đồng bộ vùng chọn từ PDF Viewer vào controller" | `pdf_reader_screen.dart:549` (chỗ duy nhất gọi), `:73-78` | SelectionBar với 6 hành động (note, save wordlist, Text Studio, TTS, Vườn Nhớ, reopen-recall) **vô dụng ở chế độ PDF** — tính năng đinh bị chôn |
| P0-2 | **Nút prev/next trang trên thanh TTS là no-op**: `onTap` chỉ gọi callback + haptic, comment thừa nhận "Signal via a callback if needed" | `pdf_tts_bar.dart:64-75`, `:122-137` | Nút hiện ra, bấm không có gì → mất niềm tin vào cả app |
| P0-3 | **TTS không highlight khi đọc trong PDF**: `_currentSpeakingWord` không bao giờ được gán (chỉ bị reset) → `PdfWordOverlay.speakingWord` luôn null | `pdf_reader_controller.dart:96-97, 425, 478` | "Karaoke reading" — lý do tồn tại của nút Play — không hoạt động |
| P0-4 | `Song ngữ EN → VN` **chỉ đọc EN**, phần dịch bị stub | `pdf_reader_controller.dart:452-470`; label ở `pdf_tts_bar.dart:180-186`, `pdf_toolbar.dart:539` | tuỳ chọn gây hiểu lầm; nên ẩn hoặc làm thật |
| P0-5 | **Ghi chú khoá theo `pdfPath.hashCode` (32-bit)**; `last_page_` cũng vậy. RecentFile thì lại định danh bằng `md5(path)[0:12]` → hai hệ thống khác nhau cho cùng một file | `pdf_annotation_storage.dart:31-32, 96, 100` vs `read_mode/models/recent_file.dart:160` | Đổi tên/di chuyển file = mất highlight, mất trang đọc, **và** có nguy cơ va chạm key giữa 2 file |
| P0-6 | **Toạ độ highlight không đáng tin ở Text Mode**: `setSelection(text, Rect.zero)` → annotation lưu `Rect.zero` | `pdf_reader_screen.dart:549` → `pdf_reader_controller.dart:528-536` | Mở lại ghi chú không nhảy đúng chỗ → **vi phạm quy tắc vàng #3** |
| P0-7 | `id` annotation = `millisecondsSinceEpoch` → trùng khi lưu 2 cái liền | `pdf_reader_controller.dart:528` | Xoá/sửa nhằm (`indexWhere((a) => a.id == id)`) |
| P0-8 | **Overlay chặn gesture của viewer**: `GestureDetector(behavior: translucent)` phủ `SizedBox.expand` trên **mọi** trang + `_pdfViewerController.addListener(() => setState(...))` rebuild cả màn hình theo mỗi tick pan/zoom/scroll | `pdf_reader_screen.dart:830-905` (đặc biệt `:899 child: const SizedBox.expand()`), `:76-79` | Cuộn/zoom bị "nặng tay", selection khó, jank trên máy yếu. pdfrx sinh `PdfOverlayInteractionRegion` (2.4.0) đúng cho ca này (issue #376) |
| P0-9 | Hit-test từ theo **bán kính 20 đơn vị PDF** + `Rect.contains`, không theo scale, không có magnifier; `dist < 20` tính bằng khoảng cách tâm | `pdf_reader_screen.dart:872-890` | Chạm hụt khi zoom xa / chữ nhỏ; trên scan (charRects rỗng) thì **không tap được từ nào** |
| P0-10 | **Chrome tự ẩn sau 3 s**, kể cả khi đang đọc; vị trí SelectionBar hard-code `92 : 20` | `pdf_reader_screen.dart:52, 96, 114` | Mất toolbar lúc đang cần; selection bar đè/không khớp bottom bar ở một số màn hình |
| P0-11 | **Text Mode extract toàn bộ file, đồng bộ, trên UI isolate, không tiến độ** | `pdf_reader/services/pdf_text_extractor.dart:53-60`; gọi ở `pdf_reader_controller.dart:380` | File 200–800 trang: app đứng hình, Android ANR risk |
| P0-12 | **Thứ tự đọc sai với PDF đa cột**: extractor lấy `fullText` tuyến tính, bỏ qua `fragments` (code còn để nguyên block comment thử fragments) | `pdf_text_extractor.dart:26-42` | TTS đọc lẫn nhau giữa 2 cột, đọc cả số trang/chân trang; snippet ngữ cảnh lộn xộn |
| P0-13 | `refreshVocabularySignals()` **clear toàn bộ cache trang** mỗi lần lưu 1 từ rồi re-extract | `pdf_reader_controller.dart:701-706` | Giật mỗi lần bấm "Lưu" khi đang bật ColorMode |
| P0-14 | TTS đọc **cả trang một khối**: không câu, không chunk, không auto-advance page, không resume/pause, không notification nền (Read Mode có sẵn `tts_notification_service`), không cache theo trang | `pdf_reader_controller.dart:392-431` | Chờ lâu, không kiểm soát, không nghe lúc tắt màn hình; chuỗi dài có thể bị engine cắt |
| P0-15 | **i18n quy tắc vàng #5**: hàng loạt chuỗi chrome hardcode tiếng Việt, không có trong `tool/legacy_ui_english_overrides.json` **và** không có trong `generated_legacy_ui_fallbacks.dart` (đã kiểm tra từng chuỗi): `Đang mở PDF...`, `Không thể mở PDF`, `Đang trích xuất văn bản...`, `Giọng đọc`, `Tốc độ đọc`, `Lưu ghi chú`, `Thêm ghi chú`, `Đánh dấu: BẬT/TẮT`, `Không thể trích xuất text từ PDF này…`, `Mở trong Read Mode →`, `Chế độ văn bản — toàn bộ tính năng highlight & TTS`; cộng chuỗi template `✅ Đã load "$_title" vào Text Studio` mà shim exact-match không bao giờ bắt được | `pdf_reader_screen.dart:318, 465, 473, 841, 528-532, 783-789`; `pdf_toolbar.dart:437, 447, 496`; `pdf_word_tap_sheet.dart:380, 528` | Locale EN/hi/zh/si **vẫn hiện tiếng Việt** — bug đã bị "cấm" bằng văn bản ở AGENTS.md |
| P0-16 | **Không có test** cho pdf_reader; không có golden test cho coordinate mapping | `test/` không file nào import `pdf_reader` | Mọi refactor reader (Wave 1) sẽ không có lưới an toàn |
| P0-17 | Tựa file cắt 30 ký tự theo `Platform.pathSeparator`; controller thì lại `split('/')` | `pdf_reader_screen.dart:153, 290, 733` (dùng `Platform.pathSeparator`) vs `pdf_reader_controller.dart:571, 586, 606, 618, 651` (hard-code `split('/')`) | Trên Windows, `fileName` trong `VocabContext` **sai** → panel "từ đã lưu của file này" lọc theo `sourceName == pdfFileName` (`pdf_wordlist_panel.dart:30-35`) **liệt** |

> **Đọc bảng trên, có một mẫu số chung:** tính năng đã được *xây*, nhưng *đường nối*
> (viewer ↔ controller ↔ storage) thì hở. Wave 0 chỉ vá chỗ nối, không viết tính
> năng mới.

---

## 3. Benchmark ReadEra — học gì, không học gì

### 3.1 ReadEra: các quyết định UX đáng học (nguồn: mô tả Play Store / App Store + changelog 1.1.0–1.2.2 + review của CodeYarns)

| Cơ chế ReadEra | Mô tả | Áp dụng cho In4Up |
|---|---|---|
| **Không copy file vào app** | App chỉ đánh dấu metadata + trạng thái; nhận diện file trùng | Giữ "mở từ thiết bị" nhưng tách *định danh file* khỏi *đường dẫn* (md5 + size + mtime, và fallback theo tên+size khi di chuyển) |
| **Progress + bookmark sống sót khi file bị xoá/tải lại** | Lưu vị trí theo file identity | Chìa khoá để người dùng dám dùng app làm thư viện chính |
| **Tap góc trên-phải = bookmark** | Một gesture, không menu | Cho In4Up: tap góc trên-trái = đổi ColorMode (đặc sản), góc trên-phải = đánh dấu trang/từ |
| **Progress line + page pointer ở đáy** | Kéo để tua, hiển thị cả % chương | Thay `LinearProgressIndicator` vô dụng hiện tại (`pdf_tts_bar.dart:47-57`) bằng thanh kéo được |
| **About document** gom toàn bộ: TOC, bookmarks, quotes, notes, abstract, review | Một bảng, mở từ ⋮ | In4Up đã có AnnotationManager + Wordlist panel — nên **gom thành một "Hồ sơ tài liệu"** (notes + quotes + từ đã lưu + ôn tập đến hạn + tiến độ) |
| **Smart TOC đa cấp, gập/mở; đếm số trang của chương** | | Bắt buộc với sách giáo khoa/tài liệu học thuật — nguồn chính của người học ngoại ngữ |
| **Search trong tài liệu + next/prev + lịch sử search** | | Ta **chưa có gì**; đây là lỗ hổng số 1 về "chuyên nghiệp" |
| **Color modes: day / night / sepia / console; margin; brightness; orientation** | | Ta **chỉ có nền tối #0D1117**; nền PDF gốc vẫn trắng → loá mắt ban đêm |
| **Reflow font/size/spacing/hyphenation cho EPUB/DOCX/TXT; với PDF chỉ zoom + crop margin + single-column cho trang scan** | | In4Up Text Mode chính là "reflow thô" — nâng cấp nó (font, size, line-height, theme) rẻ hơn làm lại PDF layer |
| **Highlight ↔ từ điển: từ đã tra được gạch chân, và mọi từ đã tra vào mục Dictionary để ôn** | | **Gần như chính xác thứ In4Up đang làm** (recall markers) → xác nhận hướng đi, và ta có SM-2, ReadEra không có |
| **TTS: chọn giọng, tốc độ, lặp lại đoạn/từ/câu đã chọn; thao tác khi đang đọc không dừng TTS** | changelog 1.2.1 |In4Up cần đúng hai thứ: (1) highlight đồng bộ, (2) cho phép tap/lưu từ **mà không ngắt** dòng đọc |
| **Multi-document / split-screen** | | Ta **đã có split view** PDF + Wordlist panel (`pdf_reader_screen.dart:287-305`) → chỉ cần thêm "mở 2 file" nếu cần |
| **Keyboard shortcuts** (mũi tên, PageUp/Down, Space ẩn/hiện chrome, Home/End, Esc) | changelog 1.1.0 | Windows/Linux là target thật của repo (build.yml) → thêm `Shortcuts/Actions`, rẻ, "chuyên nghiệp" thấy ngay |
| **Không ads, không account** | | In4Up đã không ads — nhấn mạnh trong UI "dữ liệu của bạn nằm trên máy bạn" |

### 3.2 ReadEra **không** có — chính là hào của In4Up (đừng trade away)

- Không có CEFR/word-type grammar highlighting, không preset palette.
- Không có SRS/SM-2, không "đến kỳ ôn", không hồ sơ tri thức hợp nhất.
- Không có batch-save từ trang theo topic + ngôn ngữ.
- Không có "đoạn văn này thành bài tập Viết lại ý / tóm tắt".
- Không có luyện phát âm/STT, UltraTimeStretch, shadowing.
- TTS của họ là TTS hệ thống, không có chọn engine/cache/piper/zalo/fpt như `tts_service.dart` của ta.

> **Kết luận chiến lược:** "ReadEra-class *mechanics* + In4Up *brain*". Mục tiêu
> không phải trở thành PDF viewer tốt nhất, mà là **công cụ đọc-để-học-ngoại-ngữ
> có cơ chế đọc đạt chuẩn ngành**. ReadEra là *thước đo UX*, không phải *sản phẩm mẫu*.

---

## 4. Lộ trình đề xuất (5 wave, mỗi wave tự đóng gói & có nghiệm thu)

### WAVE 0 — "Sửa cho đúng cái đã có" (2–3 ngày dev) — **P0**
Không thêm tính năng mới. Đây là wave rẻ nhất và tác động UX lớn nhất.

| ID | Việc | Chốt |
|---|---|---|
| 0.1 | Nối selection của pdfrx vào controller: bật `textSelectionParams`, custom `buildContextMenu` để **chính menu đó** chứa Ghi chú / Lưu WordList / TTS / Text Studio / Vườn Nhớ; xoá `_SelectionBar` floating cũ (hoặc giữ làm fallback desktop) | Bỏ được 1 class + selection hoạt động ở PDF mode |
| 0.2 | Thay `_WordTapDetector` full-page bằng `PdfOverlayInteractionRegion` (yêu cầu pdfrx ≥ 2.4.0 — xem mục 5) | Gesture viewer mượt, tap vẫn ra sheet |
| 0.3 | Hit-test từ theo **screen px** (nhân scale + clamp theo `MediaQuery.textScaleFactor`), thêm fallback "từ gần nhất trong 1.2× chiều cao dòng" | Không còn tap hụt; sửa được cho trang chữ nhỏ |
| 0.4 | TTS bar: prev/next thật (`PdfViewerController.goToPage`), pause/resume, tự lật trang khi đọc xong trang, highlight **theo câu** bằng `speakLines(...)` đã có sẵn trong `tts_service.dart:673-701` + set `_currentSpeakingWord`/`focusRectCue` | Karaoke hoạt động thật; 2 nút giả biến mất |
| 0.5 | Song ngữ: hoặc làm thật (dịch từng câu qua `TranslationService`/ML Kit đã có trong app) hoặc **ẩn tuỳ chọn** cho tới khi làm | Không hứa suông |
| 0.6 | `FileIdentity`: `md5(lowercasedPath)` → **md5(path + size + first 64KB)**?; migration đọc key cũ theo hashCode rồi rekey một lần; dùng chung 1 helper cho `RecentFile` + `PdfAnnotationStorage` | Ghi chú sống sót khi file di chuyển; không va chạm key |
| 0.7 | `id`: dùng `uuid` (đã có trong pubspec); rect Text-Mode → suy rect thật từ charRects theo `startOffset/endOffset` (extractor đã có `_rectFromCharRects`) | Reopen đúng vị trí (quy tắc vàng #3) |
| 0.8 | Chrome: bỏ auto-hide 3 s; hide bằng tap; `AnimatedSize` cho SelectionBar theo `padding.bottom` thật; không `setState` toàn màn hình theo viewer listener (chuyển sang `ValueListenableBuilder` quanh phần cần) | Ẩn/hiện dự đoán được, bớt jank |
| 0.9 | i18n: chuyển 12+ chuỗi vào `app_*.arb` (đủ `en/hi/zh/zh_TW/si` trong cùng PR) + chạy generator legacy overrides; chuỗi template → ARB có placeholder | Pass QA rule #5 (`test/locale_chrome_no_vietnamese_test.dart`) |
| 0.10 | Test sàn: `test/pdf_reader/` — extractor (de-hyphen, reading order), `FileIdentity` migration, annotation CRUD + id unique, `VocabContext` rect khi selection ở Text Mode | Lưới an toàn cho Wave 1 |

**Nghiệm thu Wave 0:** mở 1 PDF 300 trang: chọn được chữ → menu 5 hành động chạy;
bấm Play thấy sáng theo câu + tự lật trang; copy file sang tên khác rồi mở lại vẫn
còn highlight + đúng trang; UI locale `en` không còn một chữ Việt nào.

### WAVE 1 — Reader fundamentals (bằng tầm ReadEra) — 1,5–2 tuần
| ID | Việc | Ghi chú kỹ thuật |
|---|---|---|
| 1.1 | **TOC / outline** drawer: cây đa cấp, gập/mở, nhảy tới trang, **tiến độ % trong chương hiện tại** | pdfrx có doc "Document Outline (a.k.a Bookmarks)"; với file không có outline → suy ra từ font-size/bold (heuristic, chạy trong isolate, cache vào file identity) |
| 1.2 | **Tìm kiếm trong tài liệu**: input ở top chrome, kết quả theo trang, prev/next, highlight match, lịch sử search | Doc "Text Search" của pdfrx; nếu API 2.4.8 chưa đủ nhanh cho 800 trang → tự build index trong isolate + cache |
| 1.3 | **Lược đồ trang** (thumbnail strip / grid) dùng `PdfDocumentViewBuilder` + `PdfPageView` (example `thumbnails_view.dart`), mở bằng cách vuốt từ cạnh dưới | `PdfViewerController.goToPage` đã dùng ở `screen:348`; `startPageNumber` chỉ có trên pdfrx mới → kiểm chứng khi nâng; nhớ `RepaintBoundary` |
| 1.4 | **Layout & zoom**: Fit width / Fit page / Actual; single ↔ continuous ↔ facing-pages; 2 trang cho ngang; **crop margins**; rotate; **single-column split** cho scan đôi | `PdfViewerParams.layoutPages` + `PdfPageLayout` (ta đang override thủ công ở `pdf_reader_screen.dart:428-447` → thay bằng builder chọn được) |
| 1.5 | **Theme đọc**: Day / Night(invert) / Sepia / Paper + brightness slider per-file; night qua doc "Dark/Night Mode Support" (colour map trong `pagePaintCallbacks`) | Không còn nền trắng loá ban đêm; lưu theo `ReaderDisplaySettings` (file đã có 2 khoá — mở rộng thêm) |
| 1.6 | **Bookmark** thật + "tap góc trên-phải = bookmark" + ★ trên toolbar khi trang đã bookmark | `AnnotationType.bookmark` **đã tồn tại trong enum** (`models/pdf_annotation.dart:3`) nhưng chưa ai dùng — rẻ |
| 1.7 | **Progress line kéo được** ở đáy (thay `LinearProgressIndicator`), % + "trang x/y · chương Z · còn N phút" | tính WPM theo cấu hình người dùng |
| 1.8 | **Gesture zones** cấu hình được: trái/phải/giữa (tap để lật/tắt chrome); vuốt để lật khi ở chế độ single page | Tuân thủ "chrome tối giản" của ReadEra |
| 1.9 | **Keyboard (Windows/Linux)**: ←→↑↓ PageUp/Down, Space toggle chrome, F tìm, T TOC, B bookmark, Esc đóng, +/- zoom | `CallbackShortcuts` |

### WAVE 2 — Thư viện & liên-tục-đọc — 1–1,5 tuần
| ID | Việc | Ghi chú |
|---|---|---|
| 2.1 | **Shelf cho PDF**: cover render từ trang 1 (`PdfPageView` → ảnh), % tiến độ, "đọc 12 phút trước", số highlight/từ đã lưu, ngôn ngữ tài liệu | Nối vào `library_screen.dart` (đã có `RecentFileType.localPdf` ở `:219-228` nhưng hiện chỉ là một dòng text) |
| 2.2 | **Collections**: Đang đọc / Muốn đọc / Đã đọc / ★ Yêu thích + collections tuỳ ý, **dùng được cho cả text/cloud/pdf** | ReadEra: 1 file nằm được ở nhiều collection |
| 2.3 | **Auto-scan thư mục** để PDF tự xuất hiện (Android đã có `TextDeviceChannel.scanTree` — `lib/services/text_device_channel.dart:16`; cần iOS/Windows/Linux path hoặc dùng `file_picker` + persist URI) | ReadEra "auto-detection" |
| 2.4 | **Đa tài liệu**: hàng đợi "đang mở" (tab/trình chuyển đổi nhanh) + tiếp tục đúng nơi rời đi | pdfrx dùng lại `PdfDocumentRef` để không nhân đôi bộ nhớ |
| 2.5 | **Hồ sơ tài liệu** (bản "About document" của ta): TOC + bookmark + quotes + notes + từ đã lưu + **đến kỳ ôn của riêng file này** + xuất | Gom `AnnotationManager` + `PdfWordlistPanel` về 1 chỗ |
| 2.6 | **Xuất**: Markdown/CSV (quotes+notes+words), in, chia sẻ; cân nhắc **stamp highlight thành PDF** (pdfrx có editing/`encodePdf`) hoặc xuất file `.annotations.json` cạnh file để không khoá dữ liệu trong Hive | "Không sở hữu dữ liệu của user" là lý do người ta chọn ReadEra |

### WAVE 3 — Hào ngôn ngữ (khác biệt hoá, không phải parity) — 2 tuần
| ID | Việc |
|---|---|
| 3.1 | Đọc **theo câu** với lặp lại câu (×1/×3), speed giảm dần, shadowing mode (dùng engine UltraTimeStretch sẵn có — *không đụng FFI*, gọi qua API hiện tại) |
| 3.2 | Tap từ **không ngắt dòng đọc** (ReadEra đã làm ở 1.2.1) — tách TTS session khỏi word sheet |
| 3.3 | "Chỉ tô những từ **≥ B1 chưa lưu**" (lọc theo threshold, thay vì tô hết) + **tự động gợi ý** 5–12 từ nên học của trang đang đọc → 1 chạm lưu cả cụm |
| 3.4 | Phrase-book: highlight → thẻ Anki/CSV (mặt trước cụm, mặt sau nghĩa + IPA + audio TTS đã cache + link về `page/rect`) |
| 3.5 | OCR cho PDF scan (Android ML Kit Text Recognition; desktop: tuỳ chọn) → bật tap-từ/TTS/search cho file ảnh; hiện "trang này là ảnh, bật OCR?" |
| 3.6 | Song ngữ thật: EN câu → VN nghĩa câu (ML Kit translation đang có trong app), đọc xen kẽ, và **cả hai bản hiện song song trong Text Mode** |

### WAVE 4 — Perf & chất lượng (làm song song, đừng để nợ)
- **Vẽ highlight bằng `pagePaintCallbacks` thay widget overlay**: 1 canvas/trang,
  không widget tree, không `LayoutBuilder` per page; giữ widget overlay cho phần tương tác.
- Text extraction vào **isolate riêng + stream tiến độ** (`compute`/`Isolate.run`, cache theo trang vào file cache).
- Cache từ theo trang có **LRU + invalidation theo trang** (bỏ `_pageWords.clear()` toàn phần — `controller:701-706`).
- `Semantics` cho từ (label = word + nghĩa + trạng thái đã lưu) → TalkBack/VoiceOver.
- Test: unit (extractor, identity, controller), golden (coordinate mapping ở 3 mức zoom), widget (selection→menu), 1 harness mở 3 file chuẩn: `hello.pdf` / 500-trang / 2-cột / scan.
- Đo và ghi vào docs: time-to-first-page, page/second khi scroll nhanh, tỉ lệ tap trúng từ, độ trễ Play→có tiếng, % reopen đúng trang.

---

## 5. Năm quyết định cần chốt trước khi code

**Q1 — Nâng pdfrx tới đâu?** (ảnh hưởng mọi thứ khác)
- Hiện tại: `pdfrx: ^2.2.24` (pubspec.yaml:96) + `dependency_overrides: pdfium_flutter → third_party/pdfium_flutter 0.1.9`.
- Trần **không nâng Flutter**: `2.4.8` (2.5.0+ yêu cầu Flutter 3.47; CI đang 3.44.1 / Dart 3.11.5). 2.4.x cho: `PdfOverlayInteractionRegion` (2.4.0), fix selection khi tải tiến trình + `selectAllText` crash + free-drag selection (2.4.4/2.4.5), fix `PdfPageView` rò ảnh (2.4.8) — **đúng các vùng ta đang đau**.
- Cái giá: phải bump `third_party/pdfium_flutter` (0.1.9 → 0.2.2/0.2.3), Windows cần Developer Mode (README pdfrx), kích thước binary, và `flutter analyze` CI có thể lòi lint mới.
- Phương án B: nâng toolchain 3.47 → lấy 2.6.1 (WASM web, progressive load, `startPageNumber`, text-search fix) nhưng **blast radius cả app** (llama.cpp/webview/CI 4 file workflow).

**Q2 — Ai sở hữu việc vẽ highlight?** overlay-widget (linh hoạt, tốn frame) ↔ `pagePaintCallbacks` (nhanh, khó tương tác). Đề xuất: **paint cho vẽ, `PdfOverlayInteractionRegion` cho chạm, bỏ full-page GestureDetector**.

**Q3 — Annotation sống ở đâu?** (a) Hive như hiện tại (nhanh, khoá theo path); (b) file JSON cạnh PDF (portable, dùng được với app khác — ReadEra-philosophy); (c) trở thành **`Evidence` trong `lib/knowledge/`** theo schema MVA (nhất quán kiến trúc, có merge/split, có reopen-locator — **đúng quy tắc vàng #2/#3**, nhưng cần **ADR**). Đề xuất: (c) + export (b).

**Q4 — "Chuyên nghiệp" tới mức nào về chỉnh sửa file?** Ta chỉ *siêu dữ liệu ghi chú trong app* (như ReadEra) hay in/stamp highlight ra file PDF mới (pdfrx có editing + `encodePdf`)? Câu hỏi này quyết định có cần `PdfEditing` + tests binary.

**Q5 — Ưu tiên nền tảng nào?** Android-first (đa số), hay Windows-first (vì người dùng học chủ yếu trên máy tính, và keyboard/split-screen toả sáng)? Quyết định thứ tự Wave 1 (touch gestures vs shortcuts) và có làm Web/WASM hay không.

---

## 6. Câu hỏi mở cho bạn (owner)

1. Người dùng chính của PDF Reader là ai: (a) người học từ sách báo nước ngoài, (b) người luyện đề/thi, (c) đọc tài liệu kỹ thuật/truyện? → quyết định TOC/search có phải ưu tiên số 1 hay OCR mới là số 1.
2. Trong 3 lỗ hổng P0 (selection / TTS-sync / file-identity), bạn muốn **vá cả Wave 0** trước hay **chọn 1** để đo phản ứng người dùng?
3. Có cho phép nâng pdfrx → 2.4.8 (+ bump `third_party/pdfium_flutter`) trong PR này không? Nếu đồng ý, cho phép đụng `pubspec.yaml`/CI không?
4. Annotation: di sản Hive hiện có **bao nhiêu người dùng thật**? Nếu ≈0 thì làm lại sạch theo `Evidence` (không cần migration); nếu >0 thì tôi viết migrator + test.
5. Thiết kế thị giác: giữ **một theme tối kỹ thuật** (`#0D1117`) như hiện tại, hay đầu tư 4 theme đọc (day/night/sepia/paper) ngay từ Wave 1? Điều này quyết định có cần `pagePaintCallbacks` colour-map (hơi art-y) không.

---

## 7. Phụ lục A — checklist QA thủ công (mỗi wave chạy lại)

- [ ] Mở PDF 500 trang: thời gian tới trang 1 < 1,5 s; không ANR; cuộn nhanh không trang trắng.
- [ ] PDF 2 cột (2-column article): TTS đọc đúng thứ tự từng cột; snippet ngữ cảnh không lẫn cột.
- [ ] PDF scan (chỉ ảnh): app nói rõ "trang này không có lớp chữ" + (Wave 3) gợi ý OCR — **không** im lặng trả về rỗng.
- [ ] PDF có outline: nhảy 5 chương, % chương đúng; PDF không outline: heuristic sinh TOC, không crash.
- [ ] Chọn 1 cụm 3 dòng → menu: Ghi chú / WordList / TTS / Text Studio / Vườn Nhớ **chạy hết**, mỗi cái reopen đúng trang+rect.
- [ ] Tắt màn hình khi đang TTS: vẫn phát + có notification; mở lại resume đúng câu.
- [ ] Copy file sang `/sdcard/Download/x2.pdf`, mở lại: còn highlight, còn trang, còn bookmark (Wave 0.6).
- [ ] Xoá file, mở lại từ danh bạ thư viện: trạng thái đọc còn (ReadEra parity).
- [ ] Locale `en` và `hi`: không còn một chuỗi Việt nào ở chrome PDF; nội dung file Việt vẫn Việt.
- [ ] Zoom 400% rồi tap 20 từ ngẫu nhiên: ≥ 19/20 ra đúng từ.
- [ ] Windows: phím ←→/PageUp/PageDown/Space/F/T/B/Esc hoạt động.
- [ ] TalkBack: mỗi từ đọc được nhãn "word — nghĩa — đã lưu".

## 8. Phụ lục B — những thứ nên *bỏ* (đừng bảo tồn đồ hỏng)

| Bỏ | Lý do |
|---|---|
| `_WordTapDetector` full-page translucent | Chống gesture (P0-8). Thay bằng overlay-region |
| `_SelectionBar` nổi đặt theo số đo cứng | pdfrx context menu + bottom sheet tự đẩy lên an toàn hơn |
| `PdfViewMode.textMode` dùng `SelectableText` cho cả file | O(n) memory, mất layout, Rect.zero. Thay = pipeline text có tiến độ trong isolate, render theo trang/thoại |
| Chip trạng thái dạng chữ trong toolbar (`Đánh dấu: BẬT`, `ColorMode.label`) | Chiếm 60% ngang toolbar trên phone; đổi thành icon + tooltip + 1 label ngắn |
| `LinearProgressIndicator` vô nghĩa trong TTS bar | Thay bằng progress line kéo được (1.7) |
| `_pageWords.clear()` toàn cục | Invalidation theo trang |

---

## 9. Phụ lục C — nguồn tham chiếu đã đối chiếu

- **pdfrx** (engine đang dùng): README + changelog pub.dev —
  https://pub.dev/packages/pdfrx , https://pub.dev/packages/pdfrx/changelog
  → các mục xác nhận dùng được cho Wave 0/1: *Text Selection* (mặc định bật,
  custom qua `PdfViewerParams.buildContextMenu` + `PdfTextSelectionParams.magnifier`),
  *PDF Link Handling*, *Document Outline (a.k.a Bookmarks)*, *Text Search*,
  *Page Layout (Horizontal Scroll/Facing Pages)*, *Showing Scroll Thumbs*,
  *Dark/Night Mode Support*, *pagePaintCallbacks*, `PdfOverlayInteractionRegion`
  (thêm ở **2.4.0**, giải đúng issue #376 "overlay chặn gesture"),
  `underflowAnchor`, `scrollPhysics`, *PasswordProvider*,
  `PdfDocumentViewBuilder` + `PdfPageView` (example `thumbnails_view.dart`),
  `startPageNumber` + progressive loading (2.6.0, PR #706).
  Yêu cầu bản mới: **2.6.0 BREAKING — Dart 3.13 / Flutter 3.47**; 2.5.0 cũng đã
  nâng min Flutter 3.47 → trên CI 3.44.1 thì **trần là 2.4.8**.
- **ReadEra**: mô tả Google Play (`org.readera`) — không copy file vào app, giữ
  bookmark/trang đọc ngay khi file bị xoá hoặc tải lại, colour modes day/night/
  sepia/console, crop margin, single-column cho trang scan đôi, multi-document,
  footnote, TOC. App Store (`id1669188337`) changelog 1.1.0→1.2.2 — keyboard
  shortcuts, tap góc trên-phải để bookmark, Quotes/Notes gom vào "About document",
  TTS chọn giọng + lặp lại đoạn/từ/câu đã chọn, thao tác khi đang TTS không ngắt
  đọc, search nhanh + next/prev + lịch sử, Smart TOC đa cấp. Review kỹ trên
  CodeYarns (2023-01-12) — từ đã tra được gạch chân + mọi từ đã tra vào mục
  Dictionary để ôn (≈ recall markers + Vườn Nhớ của ta).
- **Trong repo**: `AGENTS.md` (quy tắc vàng #2 #3 #5), `docs/project/KANBAN.md`
  (READ-630-01…05 đã done → Wave 0/3 không được làm hỏng), `docs/HANDOFF_MVA_v2.md`
  (schema Evidence — lựa chọn Q3), `docs/adr/` (cần ADR nếu đổi storage).
