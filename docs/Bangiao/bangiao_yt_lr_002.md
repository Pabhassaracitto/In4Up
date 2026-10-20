# Bàn giao YT-LR-002 — Chế độ YouTube: bộ tính năng học kiểu Language Reactor

**Ngày:** 2026-10-19 · **Branch:** `arena/9498c207-in4up` · **Commit:** `75601e0`
**Epic Linear:** [IN4-85](https://linear.app/in4up/issue/IN4-85/yt-lr-002-che-djo-youtube-bo-tinh-nang-hoc-kieu-language-reactor-phu)
**Trạng thái:** lõi code xong → **In Review**, chờ nghiệm thu máy thật.

---

## 1. Câu hỏi ban đầu: YouTube đã có code chưa?

**Đã có**, và không hề trống — `lib/features/youtube/**` có 12 file ~6.800 dòng:

- Player iframe (wrapper GitHub Pages chống lỗi 153) + phụ đề timestamp + dịch 3 pha
- Click từ → `WordAnalysisSheet`; `WordState known/learning/ignored` lưu Hive
- Tab **VĂN BẢN** / **TỪ** / **TẢI**; nút Biết hết / Học cả câu / Lặp câu
- Tải audio → mở trong tab Nghe kèm LRC

**Nhưng thiếu đúng 7 nhóm** so với bản mô tả giao diện (menu `Subtitle Settings`,
bảng `Word Dictionary & Analysis`, tab `Lexa AI Chat` + 4 đề xuất nêu cao).
Epic IN4-85 có bảng đối chiếu từng nhóm.

---

## 2. Đã làm gì (lõi — theo chốt phạm vi với chủ dự án)

### IN4-88 · Menu `Subtitle Settings`

| Nhóm | Giá trị |
| --- | --- |
| Chế độ bản dịch | `Có bản dịch` · `Ẩn bản dịch` · `Làm mờ bản dịch` (bấm hiện tạm, bấm lại mờ) · `Ẩn phụ đề` (giữ ô trống 44px, không giật player) |
| Bố cục danh sách | `Đơn giản` (1 cột) · `Song song` (2 cột) · `Trên và dưới` |
| Ngưỡng tần suất | Thanh trượt rank 100–2000, bước 50 |

- Nút `subtitles_outlined` trên thanh tiêu đề (cả dọc lẫn ngang) mở menu.
- Cài đặt lưu Hive **toàn cục** (box `yt_learning_settings`) — nhớ lại khi mở video khác.

### IN4-86 · Bảng `Word Dictionary & Analysis`

Click vào từ trong phụ đề (vẫn pause video như cũ) → bảng hiện:

- Từ + **phiên âm IPA** (CMU dict, fallback `OfflineDictionary.phonetic`) + chip từ loại / rank / CEFR
- Nghĩa Việt (offline → MDX → AI trên máy) + **câu đang phát** làm ngữ cảnh
- **Thanh trượt tần suất** (kéo đổi ngưỡng "từ đã quen")
- **3 nút ✓ Đã biết / 📖 Đang học / 🚫 Bỏ qua** — bấm lại nút đang chọn để bỏ đánh dấu
- Tab **GIẢI THÍCH**: tóm tắt AI, mẹo nhớ, **ngữ pháp** (cấu trúc / chủ ngữ / động từ /
  tân ngữ / giải thích), ví dụ trong ngữ cảnh, hình ảnh gợi nhớ, câu chuyện ghi nhớ

### IN4-87 · Tab `Lexa AI Chat`

- Tab thứ 4 **LEXA** (`TabController` 3 → 4, `TabBar` cuộn ngang cho màn hẹp).
- Ngữ cảnh tự động: tiêu đề video + **câu phụ đề đang phát** + **từ vừa bấm**.
- 3 gợi ý câu hỏi bám vào câu đang phát ( đổi theo từ đang chọn ).
- Chưa cài model → banner + nút **Cài AI**, không crash, không gọi mạng.
- Local-first, không RAG / embedding / vector DB.

---

## 3. File

**MỚI**

| File | Vai trò |
| --- | --- |
| `lib/features/youtube/models/yt_subtitle.dart` | `WordState` · `LrWord` · `SubtitleLine` (tách khỏi màn hình) |
| `lib/features/youtube/models/yt_learning_settings.dart` | `YtTranslationMode` · `YtSubtitleLayout` · `YtLearningSettings` |
| `lib/features/youtube/services/yt_learning_settings_service.dart` | persist Hive |
| `lib/features/youtube/services/cmu_phonetics_service.dart` | lấy IPA, bọc `CMUDictionaryService` |
| `lib/features/youtube/widgets/yt_subtitle_settings_sheet.dart` | menu cài đặt phụ đề |
| `lib/features/youtube/widgets/yt_word_panel.dart` | bảng tra cứu từ vựng |
| `lib/features/youtube/widgets/yt_lexa_chat_tab.dart` | tab AI chat |
| `test/yt_learning_settings_test.dart` | test thuần |

**SỬA**

- `lib/features/youtube/yt_player_screen.dart` — 4 tab, 4 chế độ phụ đề, 3 bố cục, wiring
- `tool/legacy_ui_english_overrides.json` — **+40** English fallback
- `lib/core/language/generated_legacy_ui_fallbacks.dart` — tái sinh 1822 → 1932 mục
- `docs/project/KANBAN.md` — card `YT-LR-002` + lịch sử (append, không xoá)

**KHÔNG đụng:** `lib/ffi/` / UltraTimeStretch · không gộp 3 skill SM-2 ·
không server `yt-dlp` · không thêm package · không gọi mạng.

---

## 4. Checklist nghiệm thu trên máy thật

1. Mở 1 video YouTube **có CC** → phụ đề + dịch hiện, không che player.
2. Bấm nút `subtitles_outlined` → lần lượt chọn 4 chế độ:
   - `Có bản dịch`: dịch hiện bình thường
   - `Ẩn bản dịch`: chỉ còn phụ đề gốc
   - `Làm mờ bản dịch`: dịch bị mờ → bấm vào dịch → rõ → bấm lại → mờ
   - `Ẩn phụ đề`: cả gốc lẫn dịch biến mất, **player không bị giật**; prev/next/lặp câu vẫn bấm được
3. Tab **VĂN BẢN** → đổi 3 bố cục → render đúng (1 cột / 2 cột / trên-dưới).
4. Tắt app, mở lại → chế độ + bố cục + ngưỡng đã chọn **còn nguyên**.
5. Click 1 từ (vd `very`) → bảng hiện từ loại `trạng từ`, phiên âm, nghĩa Việt.
6. Kéo thanh tần suất → số ngưỡng đổi; bấm ✓ / 📖 / 🚫 → trạng thái đổi; tắt app mở lại còn nguyên.
7. Tab **LEXA** → bấm 1 gợi ý hoặc gõ câu hỏi → có câu trả lời bám ngữ cảnh video.
8. Xoay ngang / dọc → 4 tab không vỡ layout.
9. Đổi sang video khác → phụ đề đổi đúng, không lẫn dòng của video cũ.
10. Chuyển locale sang **EN** → toàn bộ nhãn mới (menu, nút, tab, chat) **không còn tiếng Việt**;
    nội dung video/phụ đề vẫn giữ nguyên ngôn ngữ gốc.

---

## 5. Giới hạn cần biết

- **Chưa chạy được `flutter analyze` / `flutter test`** — sandbox không có Flutter SDK.
  Đã kiểm thay bằng: parser cân bằng ngoặc (8 file OK) + đối chiếu 16/16 assertion của
  `test/yt_progressive_loading_test.dart` (IN4-81) + gate i18n (0 vi phạm mới so `025cd4b`).
- Tab Lexa dùng chung lịch sử `AiServiceFacade`; tab chỉ lưu **chỉ số** câu trả lời nên
  "Cuộc trò chuyện mới" đổi góc nhìn cục bộ, **không** xoá lịch sử AI chung.
- Prompt gửi model viết bằng tiếng Anh (để không đưa literal có dấu vào file presentation —
  gate i18n bắt mọi literal phải phân loại); model được yêu cầu trả lời cùng ngôn ngữ câu hỏi.
- **Chưa có nguồn ví dụ Tatoeba offline** trong repo ⇒ tab GIẢI THÍCH hiện
  `contextExamples` do AI sinh + mục từ điển MDX, chưa có câu mẫu Tatoeba.
- `tool/generate_legacy_ui_fallbacks.py` **đang đỏ sẵn từ trước** trên nhánh này
  (73 stale overrides / 866 unclassified) — không do thay đổi này, và không nằm trong CI.

---

## 6. Chưa làm (Backlog trên Linear)

| Issue | Tên |
| --- | --- |
| [IN4-89](https://linear.app/in4up/issue/IN4-89) | Preset Quick-Switch — nhấn giữ Play hiện radial menu |
| [IN4-90](https://linear.app/in4up/issue/IN4-90) | Nối từ đã lưu vào Vườn Trí Nhớ (Memory Garden) với SM-2 |
| [IN4-91](https://linear.app/in4up/issue/IN4-91) | Shadowing theo câu + chấm điểm phát âm mức âm vị |
| [IN4-92](https://linear.app/in4up/issue/IN4-92) | Luồng lưu từ 2 cấp (1 chạm + inline mini-form) |

---

## 7. Đợt sửa lỗi sau nghiệm thu máy thật (2026-10-20)

Owner test trên máy thật và báo **5 lỗi**. Đã sửa hết bằng code thật trong
`lib/features/youtube/**`, có test pin để không tái phát.

| # | Triệu chứng owner báo | Nguyên nhân gốc (đọc code xác minh) | Cách sửa | File |
|---|---|---|---|---|
| 1 | Chế độ `Có bản dịch`: bấm 1 dòng ⇒ **nhiều dòng dịch bị ẩn**, chỉ còn các dòng dịch CUỐI | Phase C dịch theo lô 6 dòng; mỗi lô dựng lại `merged = List.from(base)` — `base` là bản gốc **chưa có dịch** ⇒ ghi đè xoá sạch dịch của các lô trước | Bảng dịch **tích luỹ** `List<String?>.filled(total, null)`; mỗi lô ghi THÊM `translations[offset+i]`, rồi áp lại **toàn bộ** `base[i].copyWith(translation: translations[i])` | `yt_player_screen.dart` (phase C) |
| 2 | Chế độ `Làm mờ bản dịch`: dịch **bị ẩn hẳn** thay vì mờ | `ImageFiltered(ImageFilter.blur)` tạo **lớp blur riêng**; trên một số GPU Android lớp đó render **trống** ⇒ không còn chữ | Dùng `MaskFilter.blur(BlurStyle.normal, 4)` ngay trên `Paint` của `Text` (không cần layer) + dòng gợi ý "Bấm để hiện bản dịch." | `yt_player_screen.dart` `_buildTranslationLine` |
| 3 | Tab Tải audio: không có nút dừng/huỷ, kẹt "Đang tải…" mãi | `_downloadAudio()` dùng `await for` ⇒ **không có cách nào ngắt luồng từ UI**; `YtDownloader.cancel()` đã có sẵn nhưng không bao giờ được gọi | `listen()` giữ `StreamSubscription` + **nút Dừng** gọi `YtDownloader.instance.cancel()`; thêm bộ canh: 45 giây không tiến triển ⇒ hiện cảnh báo cam + vẫn có nút Dừng | `yt_player_screen.dart` (`_downloadAudio`, `_cancelDownloadAudio`, `_buildDownloadTab`) |
| 4 | **Âm thanh nhanh hơn chữ ~1 dòng** (lệch đồng bộ) | Vị trí phát được hỏi bằng `setInterval(tick, 250)` trong WebView ⇒ **cộng thêm tới 250 ms độ trễ** trước khi Dart biết thời gian mới ⇒ chữ đổi trễ hơn tiếng nói (đúng bằng "nhanh hơn một dòng") | Đẩy theo **sự kiện**: `video.addEventListener('timeupdate', tick)` (+ `seeked`/`ratechange`/`play` để đồng bộ lại ngay sau tua/đổi tốc độ), chỉ giữ `setInterval(tick, 1000)` làm dự phòng khi trình duyệt throttles timer. Nhịp hỏi từ Dart giảm 400 ms → 1000 ms. Thêm log `drift=` và `driftTB=` (độ lệch `t − start` của dòng, trung bình 60 mẫu gần nhất) để **ĐO** thay vì đoán — không áp offset cố định cho mọi video | `yt_player_screen.dart` (`_injectSyncScript`, `_updateTime`) |
| 5 | Tab GIẢI THÍCH: **không có phản ứng** + crash `'!_debugDoingThisLayout': is not true` / `RenderBox was not laid out` | (a) `TabBarView` là `PageView` (viewport cần layout) trong khi `analyzeWord()` gọi `notifyListeners()` **giữa các `await`** ⇒ rebuild đúng lúc build/layout; (b) `lookupWord` có thể mất **30 s (local) + 45 s (remote)** rồi mới rớt về nghĩa từ điển ⇒ im lặng; (c) `buildFromLocalDict()` trả `success: true, isPartial: false` nên UI không phân biệt được "AI trả lời" và "chỉ là từ điển" ⇒ owner thấy "hình như nó chỉ đang dịch" | Bỏ `TabBarView` → `IndexedStack` (cùng một约束 tĩnh, không viewport); bỏ `context.select` provider, panel **tự gọi `lookupWord`** và tự giữ kết quả (`_aiResult`/`_aiWaiting`/`_aiError`) + timeout 90 s; hiện rõ 4 trạng thái: đang chờ (có số giây + nút "Bỏ chờ") / lỗi / **chỉ có nghĩa từ điển** (+ Thử lại) / có phân tích AI | `widgets/yt_word_panel.dart` |

### Cách đọc log cho lỗi 4 (quan trọng)

Sau khi phát video, lọc logcat theo `in4up-yt`:

```
[in4up-yt] line 12 start=45210ms end=47480ms | t=45260ms | drift=50ms | driftTB=120ms | gapBefore=0ms | …
```

- `drift` **dương và lớn** ⇒ chữ đổi TRỄ so với tiếng nói (đúng triệu chứng).
- `driftTB` là trung bình 60 lần đổi dòng gần nhất — dùng số này để quyết định,
  **không** áp một offset cố định cho mọi video (IN4-81 đã ghi rõ).

### Test pin

`test/yt_lr_002_fixes_test.dart` (thuần, không cần máy): **32 assertion** phủ
cả 5 lỗi — cấm `List.from(base)` trong vòng lặp, cấm `ImageFilter.blur(`,
cấm `TabBarView(` và `context.select<AiServiceFacade,`, bắt buộc có
`YtDownloader.instance.cancel()`, `timeupdate`, `drift=`, timeout 90 s…

### Checklist nghiệm thu lại (máy thật)

1. `Có bản dịch` → dịch hiện **đầy đủ mọi dòng**, kể cả dòng đầu (lỗi 1).
2. `Làm mờ bản dịch` → chữ **vẫn nhìn thấy** nhưng mờ; bấm vào hiện rõ, bấm nữa mờ lại (lỗi 2).
3. Tab Tải → bấm "Tải audio" có **nút Dừng**; bấm Dừng thì dừng ngay, không kẹt (lỗi 3).
4. Phát video → so `driftTB` trong logcat với cảm nhận tai; gửi lại số liệu nếu vẫn lệch (lỗi 4).
5. Bấm 1 từ → tab GIẢI THÍCH **không crash**, hiện "Đang nhờ AI phân tích… (Đã chờ Ns)",
   có nút "Bỏ chờ"; nếu AI quá 30 giây sẽ hiện rõ "chỉ là nghĩa từ điển" + "Thử lại bằng AI" (lỗi 5).

---

## 8. YT-LR-004 (IN4-95) — Bỏ tầng 1 cũ, icon YouTube vào thẳng tầng 2

### Yêu cầu

> "Hãy đảm bảo ở youtube không còn ở tầng 1 cũ (sau khi nhấn vào icon youtube)
> (chỉ điền url mà không cho điền để search) => Nhấn icon youtube vào thẳng tầng 2
> (nơi có thể search) thay vì tầng 1 cũ."

### Trước / Sau

| | Trước | Sau |
| --- | --- | --- |
| Nhấn icon YouTube | Bottom sheet **tầng 1** (`YoutubeSheet`): đầu trang là ô **"Dán URL YouTube..."** + 3 tab Audio / Captions / Lịch sử. **Không có ô tìm kiếm** — muốn tìm phải bấm thêm nút "Khám phá kênh" để sang tầng 2 | Mở thẳng **tầng 2** (`YoutubeExplorerScreen`): ô **tìm kiếm** ngay trên cùng (con trỏ nhảy vào ô sẵn — IN4-77) + danh sách kênh + kết quả |

### Thay đổi code

| File | Thay đổi |
| --- | --- |
| `lib/screens/main_shell.dart` | `case 'youtube_downloader'`: `YoutubeSheet.show(context)` → `nav.push(MaterialPageRoute(builder: (_) => const YoutubeExplorerScreen()))`. Đổi import tương ứng (gỡ `youtube_sheet.dart`) |
| `lib/features/youtube/youtube_explorer_screen.dart` | (a) `LayoutBuilder`: `isWide = maxWidth >= 560`; sidebar 195px **chỉ** render khi rộng; màn hẹp thêm nút **Bộ lọc** (`tune`) mở bottom sheet chứa cùng nội dung (`_sidebar()` tách thành `_sidebarContent()`). (b) Thêm nút **Lịch sử** + `_showHistory()` dùng lại `YtHistoryItem`, nạp qua `YtHistory` |

### Vì sao phải sửa thêm 2 chỗ (không chỉ đổi đích)

Tầng 2 vốn được thiết kế cho màn rộng (sidebar cố định 195px + vùng kết quả). Khi nó trở thành
**cửa vào duy nhất** thì trên điện thoại đứng (360 dp) vùng kết quả chỉ còn ~165 px, thẻ video
(ảnh nhỏ + tiêu đề) sẽ vỡ. Vì vậy bắt buộc phải làm responsive trước khi bỏ tầng 1.

### Không mất tính năng so với tầng 1 cũ

| Tính năng tầng 1 cũ | Ở đâu bây giờ |
| --- | --- |
| Dán URL YouTube | Ngay trong tầng 2 (ô "Dán URL YouTube..." + nút paste) → mở thẳng player |
| Tab Audio (tải audio) | Tab **TẢI** trong màn player (tầng 3) — vừa được thêm nút **Dừng** ở mục 7 |
| Tab Captions (tải phụ đề) | Tab **TẢI** trong màn player |
| Tab Lịch sử | Nút **Lịch sử** trên thanh trên cùng của tầng 2 (bottom sheet, xoá từng mục được) |

> `YoutubeSheet` (tầng 1) **vẫn còn trong repo** vì 2 luồng nhập nội dung không phải "icon YouTube"
> vẫn dùng: `audio_library_drawer` (thêm audio vào tab Nghe) và `text_library_drawer`
> (`captionsFirst: true` — lấy phụ đề vào tab Đọc). Hai luồng này chủ đích là "chọn đúng video rồi
> tải", không phải "tìm kiếm", nên giữ nguyên.

### Kiểm chứng

- Test mới `test/yt_explorer_entry_test.dart` — **17 assertion**: cấm `YoutubeSheet.show(` và
  import `youtube_sheet.dart` trong `main_shell.dart`; bắt buộc push `YoutubeExplorerScreen`;
  bắt buộc tầng 2 có cả `_searchCtrl` (tìm kiếm) lẫn `_urlCtrl` (dán URL); bắt buộc
  `isWide = c.maxWidth >= 560` + `if (isWide) _sidebar(),` + `_sidebarContent()`;
  bắt buộc nút Bộ lọc + Lịch sử.
- Các test cũ vẫn xanh: **20/20** IN4-81 + **32/32** YT-LR-003.
- Gate i18n: **+0** so với `5c72bd8` ở cả 4 hạng mục. Chỉ thêm 1 English fallback (`Bộ lọc` →
  `Filters`) — `Lịch sử` / `Chưa có lịch sử` **không** đưa vào catalog vì đã có trong
  `app_vi.arb` (ARB tự dịch; đưa vào sẽ thành stale key).

### Nghiệm thu (máy thật)

1. Nhấn icon YouTube (công cụ nhanh / header tab Nghe) → **mở thẳng màn có ô tìm kiếm**, con trỏ
   đã ở trong ô; **không còn** bottom sheet "Dán URL YouTube...".
2. Gõ từ khoá (vd. "english listening") → có kết quả **không cần Data API key**.
3. Dán một URL YouTube vào ô dưới → mở thẳng màn player.
4. Điện thoại **đứng**: không thấy sidebar trái; bấm nút **Bộ lọc** → sheet hiện đủ cấp độ từ
   vựng / sắp xếp / kênh; đổi kênh thì danh sách lọc lại.
5. Xoay **ngang** (hoặc máy tính bảng) → sidebar hiện lại như cũ.
6. Bấm nút **Lịch sử** → hiện danh sách đã xem, bấm 1 mục mở lại video, nút xoá hoạt động.

---

## 9. Rebase lên `arena/01a0251e-in4up` (2026-10-20)

Theo yêu cầu owner: *"Hãy rebase từ branch 251e mới nhất. Để sau này không bị xung đột nếu có
rebase & merge."*

### Kết quả

| | Trước | Sau |
| --- | --- | --- |
| Gốc (merge-base) | `fe715ae` | `81512d8` (tip `arena/01a0251e-in4up` lúc đó) |
| Commit riêng của branch | 6 | 6 (nội dung giữ nguyên, SHA đổi) |
| Có thể fast-forward / rebase & merge? | Không (lệch 14 commit) | **Có** — branch đã nằm ngay trên tip `251e` |

SHA mới: `31f1351` `ff09b91` `20c10ab` `9734fae` `b0cec88` `abaae51`
(SHA cũ tương ứng: `3301467` `cd92f66` `4253b76` `5c72bd8` `90cae0f` `22b5257`).

### Lần 2 — rebase tiếp lên `ab0e82b` (cùng ngày 2026-10-20)

`251e` lại có **12 commit mới** (`81512d8` → `ab0e82b`): bản 1.12.2/1.12.3 và audit giao diện
**UI-COMPACT-001** (5 mục: Focus fix, thanh 2 tầng, bỏ tự ẩn ở Nhớ, pop nhỏ ô chữ, header chung
gọn, icon loa thông minh). Đã rebase lại branch lên tip mới.

| | Kết quả |
| --- | --- |
| Gốc mới | **`ab0e82b`** (tip `arena/01a0251e-in4up`) |
| File giao nhau | **4** (thêm `lib/screens/main_shell.dart` so với lần 1) |
| Xung đột thật | **1** commit (`de98130`, commit đầu) — vẫn chỉ 2 file catalog i18n |

`lib/screens/main_shell.dart` **không** xung đột dù cả hai cùng sửa: hunk của `251e` nằm ở line
~53/1559/1615/1708/2075/2127, hunk của branch này nằm ở line ~18 (import) và ~1040
(`case 'youtube_downloader'`) ⇒ git tự merge. Đã kiểm riêng: nút **YouTube** trong
`_WorkspaceHeaderAction` (line ~1556, vừa bị refactor bởi UI-COMPACT-001) **vẫn còn nguyên**.

Kiểm chứng lần 2:

- **69/69 assertion** (20 IN4-81 + 32 YT-LR-003 + 17 YT-LR-004) vẫn OK.
- Gate i18n **+0** so với **tip mới `ab0e82b`** ở cả 4 hạng mục (75 / 0 / 864 / 644 — không đổi).
- Không mất việc của `251e`: 19/20 file của họ **giống hệt** tip
  (`app_analyze.yml`, `priority_ui_overrides.dart`, `text_provider.dart`, toàn bộ màn/widget
  read_mode + memory_mode, `collapsible_action_bar.dart`, `pulsing_icon.dart`,
  `workspace_action_button.dart`, `pubspec.yaml`, test audit…); riêng `main_shell.dart` khác đúng
  2 hunk của YT-LR-004.
- 18 entry catalog mới của họ (UI-COMPACT: "Box từng từ", "Đồng bộ tự động", "Đọc dòng hiện tại",
  "Đang phát — chạm để dừng"…) đều còn — tổng catalog **1967** entry.
- `git diff ab0e82b..HEAD` đúng 17 file của branch này.
- CI 🟢 run `39417337577`.

### Xung đột

Chỉ **1** commit bị xung đột (`31f1351`, commit đầu tiên), ở đúng 2 file catalog i18n — cả hai bên
cùng sửa:

| File | Cách giải |
| --- | --- |
| `tool/legacy_ui_english_overrides.json` | Lấy bản `251e` làm nền (trong rebase là `--ours`), rồi gồi thêm **đúng** các entry mà commit đó thêm (`keys(commit) − keys(commit^)`) |
| `lib/core/language/generated_legacy_ui_fallbacks.dart` | Tái sinh từ JSON đã gộp (file này là GENERATED CODE) |

`docs/project/KANBAN.md` **không** xung đột: hunk của `251e` nằm ở line ~2585, hunk của branch này
nằm ở line ~91 và cuối file ⇒ git tự merge.

> Lưu ý kỹ thuật: trong `git rebase` chiều **ngược** với `git merge` —
> `--ours` = cây đang đứng (251e + commit đã replay), `--theirs` = commit đang được replay (của mình).

### Kiểm chứng sau rebase

- **69/69 assertion**: 20 (IN4-81) + 32 (YT-LR-003) + 17 (YT-LR-004) — tất cả vẫn OK.
- Gate i18n **+0** so với **tip mới** `81512d8` ở cả 4 hạng mục
  (73 / 0 / 867 / 645 — không đổi).
- Không mất việc của `251e`: `priority_ui_overrides.dart`, `builtin_ai_providers.dart`,
  `ai_provider_builtin_and_read_align_test.dart`, 2 script CI, 2 workflow — tất cả **giống hệt**
  tip `251e`; entry OpenRouter trong catalog vẫn còn.
- `git diff 81512d8..HEAD` đúng 17 file, toàn bộ là việc của branch này.
- CI 🟢 run `39390435203`.

### Đẩy lên

Rebase viết lại lịch sử ⇒ bắt buộc force-push. Đã dùng
`git push --force-with-lease=refs/heads/arena/9498c207-in4up:22b5257…` (chỉ ghi đè nếu remote vẫn
đúng ở `22b5257` — tránh vô tình xóa commit của người khác).
