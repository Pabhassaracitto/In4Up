# Audit v1.30.1 — nội dung cập nhật issue (#212–#219)

GitHub App token trong phiên này **tạo issue được nhưng không sửa/đóng/comment được**
(`Resource not accessible by integration` — thiếu scope `issues: write`).

Vì vậy 8 issue đã được tạo (#212 … #219) với nội dung "đang mở"; dưới đây là nội dung
**đóng** chính thức. Hai cách áp:

- **Cách A (khuyến nghị):** merge PR của nhánh `arena/395208ef-in4up` — body PR có
  `Closes #212 … #219` nên GitHub tự đóng cả 8 khi merge.
- **Cách B:** dán từng khối vào issue tương ứng rồi bấm Close (hoặc chạy script ở cuối).

Nhánh: `arena/395208ef-in4up` · commit cuối: `a30d6954` · CI **5/5 🟢**:
`App Analyze + Locale` **46101020098** (4/4 job con) · `Read translation` **46101020104** ·
`Listen queue` **46101020067** · `Deploy web` **46101020045**.
Nhánh **0 merge commit** (yêu cầu "tuyến tính" của owner).

---

## Closes #212 — Audit v1.30.1 #1: ngôn ngữ đọc chỉ có English + Tiếng Việt

**Nguyên nhân** — `lib/features/pdf_reader/widgets/pdf_toolbar.dart`,
`_TtsLanguageSelector` khai báo cứng:

```dart
final options = <(String, String)>[
  ('auto', 'Tự động'), ('en-US', '🇺🇸 English'), ('vi-VN', '🇻🇳 Tiếng Việt'),
  if (controller.isBilingualTtsAvailable) ('bilingual', '🔀 Song ngữ'), // = false
];
```

và `PdfReaderController._init()` chỉ khôi phục lựa chọn đã lưu khi
`saved == 'en-US' || saved == 'vi-VN'` ⇒ mọi mã khác bị nuốt khi mở lại tài liệu.
Trong khi đó `EdgeTtsEngine` đã có sẵn **35 giọng / 17 ngôn ngữ**.

**Đã sửa**
- `lib/features/pdf_reader/services/pdf_tts_language.dart` (mới, thuần Dart):
  `normalizePdfTtsLanguage`, `pdfTtsLanguageLabel`, `pdfTtsLanguageOptions()` — 26 ngôn ngữ
  lấy từ `AppLanguageCatalog`, xếp theo mức phổ biến với người học Việt Nam.
- `_TtsLanguageSelector` viết lại: chip «Tự động» + chip ngôn ngữ đang dùng + «Ngôn ngữ khác…»
  → `_TtsLanguageSheet` có tìm kiếm và **đếm số giọng thật** của engine.
- `_init()` dùng `normalizePdfTtsLanguage` (nhận mọi mã catalog + `auto`).

**Test** — `test/pdf_reader/pdf_tts_language_test.dart` (chuẩn hoá 26 mã, idempotent,
thứ tự ưu tiên phủ đúng catalog, nhãn cờ + tên bản ngữ).

---

## Closes #213 — Audit v1.30.1 #2: nút dịch chưa chọn được ngôn ngữ đích

**Nguyên nhân** — `_TranslatePageButton` chỉ `controller.togglePageTranslatePanel()`;
ngôn ngữ đích luôn là `TranslationService.targetLang` (mặc định `VI`) và không có lối đổi
tại chỗ đọc. `PdfSentenceTranslator` cũng chỉ nhận `String text`.

**Đã sửa**
- Nút thành một cụm `[icon + cờ + mã đích] [mũi tên]`; mũi tên mở
  `showTranslationLanguagePicker` (bảng chọn đích dùng chung của tab Đọc, có tìm kiếm).
- Chọn xong: `TranslationService().configure(targetLang:)` + lưu bền
  `StorageService.saveTranslationTargetLanguage` (trước đây chỉ đổi RAM).
- `PdfReaderController.retranslateCurrentPage()`: xoá cache trang + dịch lại ngay nếu panel
  đang mở, để bản dịch khớp ngôn ngữ vừa chọn.

---

## Closes #214 — Audit v1.30.1 #3: đổi giọng đọc phải chuyển liền

**Nguyên nhân** — `setTtsLanguage` chỉ gán field + `prefs.setString('pdf_tts_locale', lang)`;
phiên TTS đang chạy giữ voice cũ tới **hết câu hiện tại** (câu dài = vài chục giây) ⇒ thử
nhanh nhiều giọng gần như không làm được. Đường đổi tốc độ thì đã có restart
(`_speedRestart` Timer 100 ms → `_restartAtCurrentRate()`).

**Đã sửa** — `setTtsLanguage` chuẩn hoá mã; nếu giá trị **đổi** và `_ttsMachine.isPlaying`
thì dùng đúng cơ chế của thanh tốc độ: debounce 100 ms → `_restartAtCurrentRate()` (dừng
phiên, mở lại từ đúng câu đang đọc với voice mới). Đang **Pause** thì không restart (giữ
trạng thái dừng).

---

## Closes #215 — Audit v1.30.1 #4: thanh kéo giãn dòng trong Text Studio

**Nguyên nhân** — `height` hard-code `1.6` ở hai chỗ: `TextLineWidget._buildTextContent`
(`baseStyle`) và `_ColoredWord` (`TextStyle`); không có control nào trong Cài đặt đọc.

**Đã sửa**
- `TextProvider.readerLineHeight` (1.2 – 2.6; mặc định **1.6 = giá trị cũ**), lưu bền qua
  `StorageService` khoá `reader_line_height`; `setReaderLineHeight` notify ngay (ghi đĩa nền).
- Chảy xuống: `TextLineWidget` (`_LineData.lineHeight`) → `ColoredTextWidget.lineHeight` →
  `_ColoredWord` (thay cả hai chỗ hard-code).
- `_LineHeightControl` trong nhóm «Chữ & bố cục» của `ReadSettingsSheet`: slider 14 bước +
  khung chữ mẫu 3 dòng để thấy ngay độ giãn.

**Test** — `test/read_mode/line_height_test.dart` (mặc định, clamp, notify ngay, không
notify khi trùng giá trị).

---

## Closes #216 — Audit v1.30.1 #5: danh sách giọng Edge chiếm nhiều chỗ

**Nguyên nhân** — `ReaderVoiceTile` đổ toàn bộ `readerVoiceCatalog` vào một `SimpleDialog`
phẳng: Edge 35 giọng / 17 ngôn ngữ chưa tính danh sách live tải từ `voices/list` ⇒ hộp
thoại cao hơn màn hình, không thấy đang dùng giọng nào.

**Đã sửa**
- `lib/features/tts/voice_catalog_grouping.dart` (mới, thuần Dart): gom nhóm theo ngôn ngữ,
  giữ thứ tự engine, `defaultExpandedVoiceGroups` (mở nhóm đang dùng + tối đa 2 nhóm nhỏ).
- `lib/features/tts/widgets/voice_picker_sheet.dart` (mới): bottom sheet có **tìm kiếm**,
  nhóm **thu gọn/bung** (1 dòng/ngôn ngữ khi chưa tìm), dấu chọn ở cả nhóm lẫn giọng, dòng
  «kế thừa», đếm `N giọng · M ngôn ngữ`.
- `ReaderVoiceTile` gọi `showVoicePickerSheet`.

**Test** — `test/tts/voice_catalog_grouping_test.dart` (gom nhóm, không mất giọng, nhóm
rỗng/lẻ, nhóm mở sẵn).

---

## Closes #217 — Audit v1.30.1 #6: góc trên phải 2 lựa chọn → mở thẳng cài đặt

**Nguyên nhân** — `main_shell` dùng `PopupMenuButton` 2 mục «Tùy biến / Cài đặt»; panel
«Tùy biến» của dock lại có thêm 2 `ActionChip` «Bố cục đọc / Cài đặt» ⇒ **4 tầng cùng
một đích**, mất 2 chạm mới tới cài đặt.

**Đã sửa**
- Một icon ⚙ mở **thẳng** `ReadSettingsSheet` (bỏ menu 2 mục).
- `_DisplayPanel`: bỏ 2 chip trùng; «Cài đặt» chỉ còn **một** lối vào.
- `_ReadLayoutQuickChips` đặt **ngoài** panel, thường trực trong vùng đọc: «Đọc song ngữ /
  Luyện nghe / Một dòng / Bố cục đọc» — nội dung bố cục đọc trực quan, không ẩn sau tab.

**Test** — cập nhật pin `test/read_mode/psrc_235_read_settings_dedup_test.dart` và
`test/read_ui_121_contract_test.dart` theo hành vi mới.

---

## Closes #218 — Audit v1.30.1 #7: ô «khoảng lặng» không đổi chữ theo giá trị

**Nguyên nhân** — slider 0 – 10 s chia **20 bước** (0,5 s/bước) nhưng chip preset và badge
đều in `toInt()`: 1,5 s hiện «1s» (trùng 1,0 s), 0,5 s hiện «0s»/«Tắt». Hai giá trị lẻ liền
nhau ra cùng một nhãn ⇒ cảm giác "chọn xong chữ không đổi".

**Đã sửa** — `lib/widgets/loop_gap_label.dart` (mới): `formatGapDurationLabel` giữ phần lẻ
(`0.5s`, `1.5s`), `formatGapDurationBadge`; chip preset + badge dùng chung một hàm; so sánh
preset bằng dung sai 0,001 thay `==` trên double (chip sáng đúng khi kéo slider).

**Test** — `test/widgets/loop_gap_label_test.dart`: 21 bước slider phải ra **21 nhãn khác
nhau** (đây chính là lỗi cũ), NaN/Infinity không vỡ UI.

---

## Closes #219 — Audit v1.30.1 #8: SRS chưa có âm thanh từ vựng

**Nguyên nhân** — `lib/screens/memory_mode/**` không import `TtsService` ở bất kỳ file nào
(grep = 0) ⇒ vườn nhớ hoàn toàn im lặng.

**Đã sửa**
- `lib/screens/memory_mode/services/memory_vocab_audio.dart` (mới): `MemoryVocabAudio`
  (ValueNotifier + prefs `memory_vocab_auto_read`), `speakMemoryVocab` qua
  `TtsService().speak(language: 'auto', matchVoiceLanguage: true)`.
- `_MemoryVocabSpeaker` trên thẻ (vườn + danh sách): chạm = **bật tự đọc + đọc ngay** từ đó;
  chạm lần nữa = **tắt + `TtsService().stop()`**. Icon đổi theo trạng thái.
- Tự đọc khi chạm thẻ (vườn + danh sách) và khi `MemoryController.flipCard()` lật sang mặt
  đáp án.

---

## Script đóng nhanh (cần token có scope `issues: write`)

```bash
for n in 212 213 214 215 216 217 218 219; do
  gh issue close "$n" --reason completed \
    --comment "Đã sửa trên nhánh arena/395208ef-in4up (a30d6954), CI 5/5 🟢 — chi tiết trong docs/project/ISSUE-UPDATE-AUDIT-1.30.1.md và card AUDIT-1.30.1 trong docs/project/KANBAN.md."
done
```
