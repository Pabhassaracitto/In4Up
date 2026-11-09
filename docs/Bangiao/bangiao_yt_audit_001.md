> **📄 Để nghiệm thu, dùng file này thay vì đọc từng đợt:**
> [`bangiao_yt_nghiem_thu_chung.md`](./bangiao_yt_nghiem_thu_chung.md) — một
> checklist duy nhất cho toàn bộ (YT-LR-002/003/004 + cả 4 đợt).
> File bên dưới là **lịch sử bàn giao theo đợt**, giữ lại để tra nguyên nhân.
>
> **⚠️ Số commit đã đổi 2 lần — lần cuối 2026-10-22:** 19 commit rời rạc
> → gom thành 6 → nay **gom còn 3** và **rebase lên tip mới của
> `arena/01a0251e-in4up` (`a1a0eeb`)** (branch 251e đã tự làm phần web nên
> toàn bộ việc deploy web đã bỏ khỏi branch này). Mọi số commit ghi trong các
> phần dưới là số **cũ** — chỉ còn tra được qua lịch sử force-push. Bảng đối
> chiếu hiện tại → cũ:
>
> | Commit hiện tại | Nội dung | Gồm những commit cũ |
> |---|---|---|
> | `6547772` | YT-LR-002/003/004 — 3 nhóm lõi + bỏ tầng 1 | `c65cbac` ← `61dd388`…`98bfc64` (8) |
> | `5f98233` | YT-AUDIT-001 — cả 4 đợt (10 mục) | `6941457` + `6e1dd73` + `b6958ef` + `511f2ae` |
> | *(commit docs, cuối branch)* | Bản audit nghiệm thu chung + ghi chú | `da3064c` + `904b51e` |

# Bàn giao YT-AUDIT-001 — Đợt 1/4: 6 lỗi audit YouTube (2026-10-20)

**Epic:** IN4-85 · **Issue:** IN4-97, IN4-98, IN4-99, IN4-100, IN4-101, IN4-102
**Commit:** `eadf793` · **CI:** 🟢 `39432459448`
**Branch:** `arena/9498c207-in4up` (đã rebase lên tip `arena/01a0251e-in4up` = `2d0ef30`)

Audit 11 mục của owner ngày 2026-10-20, chia 4 đợt. **Đợt 1** dọn 6 lỗi nhỏ
(triệu chứng rõ, sửa gọn, nghiệm thu nhanh). Đợt sau:

| Đợt | Mục | Issue |
|---|---|---|
| 2 | #4 ngôn ngữ đích · #6 routing wifi/4G | IN4-103, IN4-104 |
| 3 | #11 chia câu + viết hoa + bù trễ | IN4-106 |
| 4 | #5 tab GIẢI THÍCH đầy đủ | IN4-105 |

> #9 (chế độ “Có bản dịch” bấm 1 dòng ⇒ nhiều dòng dịch bị ẩn) owner xác nhận
> **đã fix ở YT-LR-003**, không làm lại.

---

## 1. #1 — Tải audio chỉ được một đoạn rồi dừng (IN4-97)

### Nguyên nhân gốc
`YtDownloader._doDownload()` **không hề kiểm tra `downloaded == totalBytes`**:

```dart
await for (final chunk in yt.videos.streamsClient.get(streamInfo)) { … }
…
final finalSize = await file.length();
if (finalSize < 1000) { fail('File tải về quá nhỏ, thử lại'); }
emit(YtDownloadDone(filePath, quality: '${kbps}kbps'));   // ← vẫn báo XONG
```

YouTube hay **đóng kết nối giữa chừng mà không ném lỗi** ⇒ vòng `await for`
kết thúc sớm. File còn cụt nhưng vẫn > 1000 byte ⇒ app báo **thành công** với
file bị cắt. Đúng triệu chứng “chỉ tải một xíu xong dừng”.

### Đã sửa
`lib/features/youtube/services/yt_downloader.dart` — viết lại bước tải bằng
HTTP thường **có `Range`** (bỏ `streamsClient.get`):

| Cơ chế | Chi tiết |
|---|---|
| Resume | `_downloadResumable()`: gửi `Range: bytes=<offset>-` từ `part.length()` |
| File tạm | ghi ra `<tên>.part`, chỉ `rename` thành file thật **khi đủ byte** |
| Watchdog | `resp.stream.timeout(_stallTimeout=20s)` — `Stream.timeout` reset đồng hồ sau **mỗi** chunk ⇒ đúng nghĩa “không nhận byte nào” |
| Retry | 8 lần, backoff 400 ms → 4 s |
| URL hết hạn | gặp `403` ⇒ gọi `refreshUrl()` xin URL mới (URL stream YouTube có hạn ~6 giờ), khớp theo `itag` |
| Verify | `if (knownSize && received >= totalBytes)` mới `return true` |
| Không che giấu | thiếu byte ⇒ `fail('Tải chưa xong (X / Y MB)…')` **và giữ `.part`** để lần tải sau nối tiếp thật sự |
| Huỷ | vẫn tôn trọng `YtDownloader.cancel()`; huỷ ⇒ xoá `.part` |

Logcat mới: `in4up-yt` · `tải chưa hoàn tất` · `không nhận byte nào` ·
`stream URL hết hạn (403)` · `resume: đã đủ`.

---

## 2. #2 — “Làm mờ bản dịch” không thấy hiệu ứng gì (IN4-98)

### Nguyên nhân gốc — **hai** cách trước đều hỏng, mỗi cách một kiểu
1. `ImageFiltered(ImageFilter.blur(sigmaX: 6, sigmaY: 6))` ⇒ **render TRỐNG**
   trên máy thật.
2. Đổi sang `MaskFilter.blur(BlurStyle.normal, 4)` gắn trên
   `foreground: Paint()` của `TextStyle` ⇒ trên **Impeller** (mặc định từ
   Flutter 3.27+), mask-blur áp lên **text** bị bỏ qua ⇒ chữ hiện bình thường.

### Đã sửa
Bỏ cả hai, gỡ luôn `import 'dart:ui'`. Làm mờ bằng **`TextStyle.shadows`**:

```dart
const TextStyle(
  fontSize: 16, fontWeight: FontWeight.w500, height: 1.4,
  color: Color(0x4DFFC107),                       // nét thật gần trong suốt
  shadows: <Shadow>[
    Shadow(color: Color(0xFFFFC107), blurRadius: 7),
    Shadow(color: Color(0xFFFFC107), blurRadius: 7),
  ],
)
```

Text-shadow blur được **Skia lẫn Impeller hỗ trợ đầy đủ** ⇒ luôn vẽ ra một vệt
mờ, **không bao giờ trống**. Giữ nguyên hành vi bấm để hiện tạm / mờ lại.

---

## 3. #3 — Dịch đôi khi ra tiếng Anh (IN4-101)

### Nguyên nhân gốc
`TranslationService._runEngineChain()` nhận **mọi** kết quả có
`isSuccess && translatedText.isNotEmpty`, **không soi ngôn ngữ đầu ra**. Khi
MyMemory / Libre / Google Free hết quota, bị rate-limit hoặc không hỗ trợ cặp
`en|vi`, chúng **trả nguyên văn bản nguồn** (tiếng Anh) và vẫn báo success —
app còn **lưu luôn vào cache**.

### Đã sửa
Thêm `_looksUntranslated(source, output, sourceCode, targetCode)` → `true` ⇒
coi engine đó **thất bại**, đi tiếp engine kế:

* output ≡ input (bỏ qua hoa/thường, dấu câu, khoảng trắng) ⇒ engine chưa làm gì;
* output ≥ 4 từ mà `detectSourceLanguage(output) == sourceCode` ⇒ vẫn là ngôn
  ngữ nguồn;
* bỏ qua các trường hợp vô hại: chuỗi không có chữ cái (số / placeholder
  glossary `__G1__`), chuỗi quá ngắn (< 12 ký tự cả hai phía), `source == target`.

Áp dụng tại **4 điểm**: online engines · Hy-MT · ML Kit · LLM API.
Log: `⏭️ <engine>: trả về NGÔN NGỮ NGUỒN (EN→VI) ⇒ bỏ qua`.

---

## 4. #7 — Lịch sử hoạt động không ghi nhận (IN4-99)

### Nguyên nhân gốc
`YtHistory.add()` **chỉ** được gọi ở `youtube_sheet.dart:126` — tức **tầng 1**
(bottom sheet “Dán URL YouTube…”). Ở IN4-95 chúng ta đã **bỏ tầng 1**: nhấn
icon YouTube đi thẳng vào `YoutubeExplorerScreen`, mà Explorer chỉ gọi
`ensureOpen()` / `load()` / `remove()` ⇒ **luồng mới không bao giờ ghi**.

### Đã sửa
Ghi ở **màn player** (`_recordHistory`) — một chỗ, phủ mọi đường vào
(search / dán URL / lịch sử / kênh):

* `initState` ⇒ ghi khi mở player;
* `didUpdateWidget` (đổi video trong cùng player) ⇒ ghi video mới;
* `await YtHistory.ensureOpen()` trước — Hive box có thể chưa mở ở luồng này;
* convert `YtExVideo` → `YtVideo`; `unawaited(...)` để không chặn player.

Explorer: `await Navigator.push(...)` rồi `await _loadHistory()` ⇒ danh sách
Lịch sử luôn tươi sau khi quay lại.

---

## 5. #8 — Bảng tra từ không hiện từ loại (IN4-100)

### Nguyên nhân gốc
`SyntaxHighlighterService._classifyWordBasic()` có đủ nhánh pronoun /
determiner / preposition / conjunction / commonVerbs + quy tắc hậu tố, nhưng
**thiếu nhánh `_adverbs`** — nhánh đó chỉ tồn tại trong `_classifyStopWord()`.

`"very"` **không nằm trong `_stopWords`** ⇒ đi vào `_classifyWordBasic` ⇒
không khớp nhánh nào, không khớp hậu tố nào ⇒ `WordType.unknown` ⇒
`_parseWords()` map sang `'other'` ⇒ hiện **“từ”**.

### Đã sửa
1. `_classifyWordBasic()`: thêm `if (_adverbs.contains(w)) return WordType.adverb;`
   (đặt **trước** `_commonVerbs` để không bị động từ đa nghĩa nuốt).
2. `_parseWords()`: map **đầy đủ** `WordType` —
   `pronoun→'pron'`, `determiner→'det'`, `number→'num'`, `interjection→'intj'`.
3. `_typeLabel()`: nhãn “đại từ / từ hạn định / số từ / thán từ”.
4. `LrWord.typeColor`: màu riêng cho 4 loại mới để chip không rớt về trắng.

> Ảnh hưởng ngoài YouTube: việc bổ sung nhánh trạng từ cũng làm đúng hơn việc
> tô màu từ ở tab Đọc / PDF (các trạng từ thông dụng như `very`, `often`,
> `just` giờ được nhận là trạng từ thay vì “không rõ”).

---

## 6. #10 — Tab VĂN BẢN không theo dòng đang phát (IN4-102)

### Nguyên nhân gốc
`_buildTranscriptTab()` là **`ListView.builder` trần, không có
`ScrollController`** ⇒ thực ra **không theo dõi gì cả** (không phải “đang nhảy
tự do”).

### Đã sửa
* `YtLearningSettings.transcriptAutoFollow` — **mặc định `true`**, persist; dữ
  liệu cũ thiếu khoá ⇒ vẫn mặc định BẬT.
* `GlobalKey _activeLineKey` gắn **chỉ cho dòng active** (không tạo key cho
  hàng nghìn dòng) ⇒ `Scrollable.ensureVisible(alignment: 0.35)` cuộn chính xác
  bất kể chiều cao các dòng khác nhau.
* Cuộn khi `_currentLineIdx` đổi và khi vừa chuyển sang tab VĂN BẢN.
* Công tắc **“Tự động theo dòng hiện tại”** ngay đầu tab + một mục cùng tên
  trong *Cài đặt phụ đề*. Tắt ⇒ đổi nhãn thành “Cuộn tự do” và **không bao giờ
  giật lại** vị trí đang đọc.

---

## 7. Rủi ro / giới hạn đã biết

1. **Chưa chạy được `flutter test` / `flutter analyze` trong sandbox** (không có
   Flutter SDK) — chỉ đối chiếu nguồn bằng script + CI. CI đã bắt và mình đã
   sửa 1 lỗi thật (`await client.close()` — `http.Client.close()` trả `void`).
2. **Download**: resume phụ thuộc server YouTube trả `206`. Nếu trả `200`
   (không hỗ trợ Range) code tự ghi lại từ đầu — đúng nhưng mất công đã tải.
3. **#2 blur**: mức mờ là `blurRadius: 7` × 2 lớp trên chữ 16 px. Nếu owner
   thấy chưa đủ mờ / quá mờ, chỉ cần đổi hằng số này ở
   `_buildTranslationLine` — không động kiến trúc.
4. **#3**: bộ soi đầu ra có thể **bắt nhầm** khi bản dịch đúng mà ngắn (đã chặn
   < 12 ký tự) hoặc khi tên riêng giữ nguyên. Có log `⏭️` để soi.
5. Chuỗi báo lỗi mới trong `yt_downloader.dart` (`'Tải chưa xong…'`) là tiếng
   Việt **chưa có English fallback** — đúng như các chuỗi lỗi vốn có sẵn trong
   file này (`services/` không thuộc vùng quét gate i18n). Nên dọn trong một
   đợt i18n riêng, không làm chung đợt này.

## 8. Test

* **`test/yt_audit_2026_10_20_batch1_test.dart`** (mới) — **50 assertion**,
  chia 6 group theo đúng 6 mục. Pin cả nguyên nhân (cấm `MaskFilter`,
  `ImageFilter`, `dart:ui`; bắt buộc `Range`, verify `totalBytes`, `.part`,
  watchdog, `_adverbs`, `YtHistory.add` trong player, `_activeLineKey`…).
* **`test/yt_lr_002_fixes_test.dart`** — cập nhật group “Lỗi 2”: bỏ pin
  `MaskFilter.blur(...)`, thay bằng pin `TextStyle.shadows`.

## 9. i18n

* 8 English fallback mới trong `tool/legacy_ui_english_overrides.json`
  (`Cuộn tự do`, `Tự động theo dòng hiện tại`, `Theo dòng đang phát`,
  `Tab VĂN BẢN tự cuộn…`, `đại từ`, `từ hạn định`, `số từ`, `thán từ`).
* Tái sinh `lib/core/language/generated_legacy_ui_fallbacks.dart` → **1975** mục.
* Gate i18n so với baseline `2d0ef30`: **+0** ở cả 4 hạng mục
  (75 / 0 / 864 / 644).

---

## 10. Checklist nghiệm thu máy thật

> Sandbox không có thiết bị ⇒ owner tự bấm. Mỗi mục ghi rõ “thấy gì là đạt”.

### #1 Tải audio (IN4-97)
1. Mở 1 video **dài** (> 15 phút), tab **TẢI**, chọn chất lượng, bấm tải.
2. **Đạt:** thanh tiến trình chạy đến 100 % hoặc hiện lỗi
   *“Tải chưa xong (X / Y MB)”* — **không bao giờ** dừng im lặng ở giữa rồi
   báo “xong”.
3. Khi đang tải, **tắt mạng 5 giây rồi bật lại** ⇒ **Đạt:** log có
   `không nhận byte nào trong 20s` hoặc `tải chưa hoàn tất`, tiến trình **nối
   tiếp** (số MB không về 0), không kẹt mãi.
4. Bấm **Dừng** giữa chừng ⇒ **Đạt:** dừng ngay, không có file `.part` sót lại
   trong thư mục `youtube_downloads`.
5. Tải xong ⇒ phát thử ⇒ **Đạt:** nghe trọn bài, **không bị cắt** ở giữa.

### #2 Làm mờ bản dịch (IN4-98)
1. Mở video có phụ đề + bản dịch ⇒ Cài đặt phụ đề ⇒ **Làm mờ bản dịch**.
2. **Đạt:** thấy một **vệt chữ mờ màu vàng** (không đọc được, nhưng biết có
   chữ) + dòng nhỏ “Bấm để hiện bản dịch.”
3. Bấm vào vệt mờ ⇒ **Đạt:** hiện rõ bản dịch + “Bấm để làm mờ bản dịch.”
4. Bấm lần nữa ⇒ mờ lại. Đổi sang “Có bản dịch” ⇒ rõ ngay.

### #3 Dịch ra tiếng Việt (IN4-101)
1. Mở vài video khác nhau, để ý phần bản dịch.
2. **Đạt:** không còn dòng nào là nguyên văn tiếng Anh.
3. Mở logcat lọc `⏭️` ⇒ **Đạt:** thấy dòng nào bị bỏ qua ghi rõ
   `trả về NGÔN NGỮ NGUỒN (EN→VI)`.

### #7 Lịch sử (IN4-99)
1. Tìm một video bất kỳ ⇒ mở ⇒ xem vài giây ⇒ **thoát ra** lại Explorer.
2. Bấm nút **Lịch sử** ⇒ **Đạt:** video vừa xem nằm ở **đầu danh sách**.
3. Mở thêm 2–3 video ⇒ **Đạt:** danh sách đầy đủ, thứ tự mới nhất lên trên.
4. Xoá 1 mục ⇒ đóng ⇒ mở lại ⇒ **Đạt:** mục đó biến mất.
5. Đổi video ngay trong player (nếu có đường vào) ⇒ **Đạt:** video mới cũng
   được ghi.

### #8 Từ loại (IN4-100)
1. Bấm vào từ **`very`** trong phụ đề ⇒ **Đạt:** chip hiện **“trạng từ”**.
2. Thử lần lượt: `beautiful` → tính từ · `quickly` → trạng từ · `because` →
   liên từ · `she` → đại từ · `the` → từ hạn định.
3. **Đạt:** mỗi từ có đúng một chip từ loại, kèm phiên âm + nghĩa Việt.

### #10 Tab VĂN BẢN (IN4-102)
1. Mở tab **VĂN BẢN** ⇒ **Đạt:** đầu tab có hàng
   **“Tự động theo dòng hiện tại”** với công tắc **đang BẬT**.
2. Phát video ⇒ **Đạt:** danh sách **tự cuộn** theo câu đang nói, dòng active
   nằm khoảng 1/3 từ trên xuống.
3. Tắt công tắc ⇒ nhãn đổi thành **“Cuộn tự do”** ⇒ kéo tay lên đầu danh sách
   ⇒ **Đạt:** danh sách **không bị giật lại** theo video.
4. Bật lại ⇒ **Đạt:** lập tức cuộn về dòng đang nói.
5. Thoát hẳn rồi mở lại video ⇒ **Đạt:** trạng thái công tắc được nhớ.

---

# Bàn giao YT-AUDIT-001 — Đợt 2/4: #4 ngôn ngữ đích + #6 định tuyến AI theo mạng

Branch: `arena/9498c207-in4up` · HEAD `0da1f21` · CI 🟢 `39496675963`
(commit chính `358d940`, 2 commit sửa theo CI `32c400b` + `0da1f21`).

## 11. #4 — Ngôn ngữ đích: English hay ngôn ngữ trong Cài đặt Home? (IN4-103)

### Góp ý thẳng thắng (theo yêu cầu của owner)

> **Nên là ngôn ngữ trong Cài đặt Home, không phải English.** Lý do: người dùng
> chọn ngôn ngữ ở Home là chọn **ngôn ngữ mẹ đẻ** của mình — đó đúng là thứ họ
> muốn ĐỌC. Bắt mặc định là English sẽ biến app thành "dịch Anh → Anh" với đa số
> người Việt (phụ đề YouTube phần lớn là tiếng Anh). English vẫn phải **có trong
> menu** vì người học tiếng Nhật/Trung có thể muốn dịch sang Anh.

Đã chốt với owner: **mặc định = Cài đặt Home + override từng video.**

### Nguyên nhân gốc

`_loadRealSubtitles()` (`yt_player_screen.dart`):

```dart
final target = TranslationService().targetLang.toLowerCase();
final lang2 = target.isEmpty || target == 'en' ? 'vi' : target;
```

Đoạn này tự đoán **trong im lặng**: Home đang để EN thì **lén** đổi sang VI,
người dùng không hề biết. Không có chỗ nào để chọn ngôn ngữ phụ đề gốc hay
ngôn ngữ dịch, và `sourceLang` đưa vào AI dịch luôn hard-code `'en'`.

### Đã sửa

| File | Thay đổi |
| -- | -- |
| `yt_learning_settings.dart` | `subtitleLang` (mặc định `'en'`) + `String? targetLang` (`null` = theo Home); `static resolveTargetLang(...) → ({lang, fellBack})`; `copyWith` sentinel `_kNoChange`; JSON có default cho dữ liệu cũ |
| `yt_player_screen.dart` | Phụ đề gốc theo `subtitleLang`; `lang2` từ `resolveTargetLang`; `sourceLang` = `subLang` (bỏ `a.`); `_loadAvailableLangs()`; đổi ngôn ngữ ⇒ clear + tải lại; `_buildLanguageFallbackNotice()` |
| `yt_subtitle_settings_sheet.dart` | Section **Ngôn ngữ**: ô *Phụ đề gốc* (track thật của video) + ô *Ngôn ngữ dịch* (có *Theo Cài đặt Home*) + `_buildLanguageHint()` |

**Điểm cốt lõi:** vẫn rớt về `vi` khi đích trùng phụ đề gốc (đừng làm mất bản
dịch) nhưng trả kèm `fellBack: true` ⇒ UI **nói rõ lý do** thay vì lén.

**Bug thật do test mới bắt được:** `resolveTargetLang()` so `lang == sub` mà
không bỏ tiền tố `a.` ⇒ phụ đề auto-generated `a.en` bị coi là khác `en` ⇒ app
dịch Anh→Anh. Đã sửa (commit `0da1f21`).

## 12. #6 — Định tuyến AI theo loại mạng (IN4-104)

| File | Thay đổi |
| -- | -- |
| `packages/in4up_ai/lib/src/engine/ai_connectivity_routing.dart` | **MỚI** — `AiNetworkKind`, `resolveRouteMode()`, `classifyConnectivity()`, `AiConnectivityRouter` |
| `ai_provider_config.dart` | `AiRouteMode.auto` + mặc định `modeOf()` đổi `offlineFirst` → `auto` |
| `ai_service_facade.dart` | `_chatRoutePlan()` resolve qua router; `_refreshRouteMode()`; `initializeAsync()` → `ensureStarted()` |
| `ai_provider_store.dart` | `resolveProvider()` so mode THẬT ⇒ không mạng trả `null` |
| `ai_route_planner.dart` | Nhận nhánh `auto` (phòng caller quên resolve) |
| `llm_mt_engine.dart` | `_StoreEnv.routeMode()` trả mode đã resolve |
| `ai_providers_screen.dart` | Nhãn *Tự động (theo mạng)* + `_autoModeHint()` |

| Cấu hình | Wifi | 4G | Không mạng |
| -- | -- | -- | -- |
| **`auto` (mặc định mới)** | `[remote, local]` | `[local, remote]` | `[local]` |
| 3 mode rõ ràng | giữ nguyên | giữ nguyên | giữ nguyên |

Planner vẫn **thuần** — resolve ở người gọi, test cũ của WP1 không vỡ.
Serialization dùng **tên** ⇒ dữ liệu đã lưu không lệch dù enum thêm `auto`.

## 13. Test (Đợt 2)

* `test/yt_lang_resolution_test.dart` — 18 test thuần.
* `test/ai_connectivity_routing_test.dart` — 15 test thuần.
* `test/ai_provider_wp0_test.dart` — 3 assertion pin đổi theo mặc định `auto`.
* `test/yt_progressive_loading_test.dart` — pin cũ `lang: 'en'` đổi thành
  `lang: subLang` + pin phủ định hard-code + pin `sourceLang: subLang.startsWith`.
* **`app_analyze.yml`** — bước mới *YouTube audit tests* chạy 7 file test logic
  thuần (Đợt 1 trước đó chưa được cắm vào CI). Bước này có
  `if: always() && steps.analyze.outcome != 'cancelled'` + đẩy tên test fail lên
  annotation `::error::` vì không phải môi trường nào cũng tải được log blob.

## 14. i18n (quy tắc vàng #5)

10 chuỗi chrome mới đi qua `context.uiText()` + 10 English fallback trong
`tool/legacy_ui_english_overrides.json` và bản sinh
`lib/core/language/generated_legacy_ui_fallbacks.dart` (giữ đúng thứ tự sort).
`tool/generate_legacy_ui_fallbacks.py` **không chạy được** trên cây này (75
override stale ở baseline) ⇒ đồng bộ tay bằng
`~/…/.yt_tools/sync_legacy_fallbacks.py` — chỉ chèn đúng 10 dòng, không reformat.

## 15. Checklist nghiệm thu máy thật (Đợt 2)

### #4 Ngôn ngữ đích (IN4-103)
1. Mở video tiếng Nhật ⇒ **Cài đặt phụ đề → Ngôn ngữ** ⇒ ô *Phụ đề gốc* liệt kê
   đúng track thật của video (không phải danh sách cứng).
2. Cài đặt Home = **English**, phụ đề gốc `en` ⇒ **Đạt:** dưới bản dịch hiện dòng
   amber *“Ngôn ngữ dịch trùng với phụ đề gốc — đang tạm dùng tiếng Việt.”*
3. Chọn *Ngôn ngữ dịch* = **English** với video tiếng Nhật ⇒ **Đạt:** dịch sang
   English, **không bị ép về Việt**.
4. Đổi ngôn ngữ xong bấm **Xong** ⇒ **Đạt:** phụ đề + bản dịch đổi ngay (không
   còn giữ bản dịch ngôn ngữ cũ).
5. Chọn *Theo Cài đặt Home* ⇒ **Đạt:** dòng xám hiện *“Cài đặt Home đang để: …”*.

### #6 Định tuyến theo mạng (IN4-104)
1. **Wifi** ⇒ *Cài đặt → Server & API* ⇒ chip **Tự động (theo mạng)** kèm dòng
   *“Đang dùng Wifi ⇒ ưu tiên trả lời từ mạng, hỏng mới chạy trên máy.”*
2. **Tắt Wifi, bật 4G**, mở lại ⇒ *“Đang dùng mạng di động ⇒ ưu tiên chạy trên
   máy, không được mới qua mạng.”*
3. **Chế độ máy bay** ⇒ *“Không có mạng ⇒ chỉ chạy trên máy.”* và tra từ **không**
   sinh request (kiểm bằng logcat).
4. Chọn rõ **Chỉ trên máy** ⇒ **Đạt:** dòng giải thích biến mất và không có
   request remote kể cả khi đang wifi.

---

# Bàn giao YT-AUDIT-001 — Đợt 3/4: #11 chia câu + bù trễ âm thanh/chữ

**Epic:** IN4-85 · **Issue:** IN4-108 · **Commit:** `2d12f0d` · **CI:** 🟢 `39507761643`
**Branch:** `arena/9498c207-in4up`

## 16. #11 — “Xuống dòng vô tội vạ, không chia câu rõ ràng” + “âm thanh nhanh hơn chữ ~2,5 giây”

### Gợi ý VAD của owner — bị bác, và vì sao

Owner gợi ý dùng VAD (dò tiếng nói) để tự khớp chữ với âm thanh. **Không làm được**:
màn player là **iframe WebView** của YouTube ⇒ không lấy được **PCM** của luồng
audio. Không có PCM thì không có VAD. Đây không phải giới hạn cài đặt mà là giới
hạn nền tảng — mọi cách “tự động” kiểu VAD đều không thể.

### Tách đôi vấn đề: hai phần lệch KHÁC NHAU

Sai lầm dễ mắc là gộp hai thứ thành một “offset”. Chúng khác bản chất:

| | Đo được? | Cách xử lý |
|---|---|---|
| **(A) Độ trễ KÊNH** WebView → Flutter | **Có** | JS gửi kèm `Date.now()` theo từng tin `t:`; Dart lấy hiệu với lúc nhận ⇒ **trung vị** 40 mẫu gần nhất, tự bù tối đa **1,5 s** |
| **(B) Track phụ đề lệch so với audio** | **Không** (cần PCM) | **Tay người dùng** — nút +− / thanh trượt |

Tự bù quá 1,5 s thường là **đồng hồ lệch** hoặc **thiết bị quá tải**, không phải
độ trễ kênh thật — bù theo sẽ làm chữ **nhảy lộn xộn**. Phần còn lại (B) để người
dùng tự chỉnh, vì ở đó họ **có chủ đích**.

### Chia câu — `services/yt_sentence_segmenter.dart` (MỚI, thuần logic)

Nguyên nhân gốc: track phụ đề của YouTube là các **cue ngắn** cắt theo nhịp nói
(1–2 giây / 20–40 ký tự), cắt ở bất kỳ chỗ nào kể cả giữa câu. App cũ hiện nguyên
từng cue ⇒ mẩu câu vụn, không dấu chấm, không viết hoa.

* Gộp cue thành **câu hoàn chỉnh**: dấu đầy đủ (thiếu chấm thì thêm; chấm chồng
  dấu phẩy ⇒ **thay** bằng chấm chứ không thành `,.`), **viết hoa đầu câu**
  (bỏ qua ngoặc kép mở đầu), **1 dấu cách** (hết xuống dòng vô tội vạ).
* Nhận track **rolling window** (auto-caption / nhiều track dịch) ⇒ chỉ lấy
  **phần chữ MỚI** của mỗi cue, không còn hiện lặp lại cả đoạn.
* **Không cắt nhầm** viết tắt / số thập phân: `Dr.` `U.S.` `e.g.` `3.5` `J.`
* Đóng câu khi: gặp dấu kết thúc · vượt **180** ký tự · vượt **9 giây** · khoảng
  lặng > **1,5 giây**.
* Kẹp mốc: câu này không lấn sang mốc bắt đầu câu sau (track gốc có cue đè nhau).
* Chạy **TRƯỚC** `_applyCaptionLines` ⇒ dịch **nguyên câu** (ML Kit/glossary cho
  kết quả tốt hơn hẳn so với dịch từng mẩu).

### Bù trễ — luồng đấu nối

```
JS (iframe)                    Dart
─────────────────────────────  ────────────────────────────────────────
v.currentTime + Date.now()  →   ytParseTimeMessage() → vị trí phát
   't:12.3|1700000000123'       ytParseSentAt()      → mốc gửi
                                _trackChannelLag()   → _autoLagMs
                                syncMs = ms + audioLeadMs + _autoLagMs
                                         ↑ tay người dùng   ↑ tự đo
```

* Định dạng tin **CŨ** (`t:<giây>` không mốc) vẫn đọc được ⇒ máy đang chạy
  phiên bản cũ không gãy; chỉ mất phần tự đo (rớt về bù tay).
* **Bù trễ chỉ đổi chỗ CHỌN DÒNG PHỤ ĐỀ.** Vị trí phát thật (`ms`) giữ nguyên
  ⇒ **seek / lặp A-B không lệch**. Đây là điểm dễ sai nhất.
* `_trackChannelLag` nuốt mẫu rác: `< 0` hoặc `> 10 s` (10 s không phải độ trễ
  kênh, là đồng hồ lệch), cửa sổ 40 mẫu, cần ≥ 8 mẫu mới tin, chỉ đổi khi lệch
  ≥ 100 ms để chữ không giật từng 100 ms một.
* **Nút +/− đặt ngay tại tab VĂN BẢN**: người dùng phải **vừa nghe vừa bấm**.
  Đẩy vào sheet thì lúc mở sheet họ không còn nghe gì để mà chỉnh — vô dụng.
  Thanh trượt trong CÀI ĐẶT PHỤ ĐỀ vẫn có (chỉnh thô, nhìn được con số).
* Chiều dương đúng như owner mô tả: `> 0` = **âm thanh nhanh hơn chữ** ⇒ chữ
  đổi sớm hơn.

### Hai lỗi CI/test bắt được (đáng ghi lại)

1. **`incrementalTexts` so sai bản**: bản đầu so phần chữ mới **vừa tách ở bước
   trước** thay vì so **cue trước ở dạng đầy đủ**. Hệ quả: từ cue thứ 3 trở đi
   không còn khớp tiền tố (`'Bye.'` không bắt đầu bằng `'world.'`) ⇒ rớt về
   nguyên cue ⇒ **chữ bị lặp lại**. Chỉ phát hiện được nhờ mô phỏng Python
   (`~/.yt_tools/sim_segmenter.py` — sandbox không có Dart).
2. **`drift` phải dùng `ms`, không phải `syncMs`.** Đổi sang `syncMs` làm gãy pin
   IN4-81 (“ĐO drift thay vì đoán”) **và** làm mất tác dụng chẩn đoán: với
   `syncMs` thì `drift ≈ 0` mãi. Dùng `ms` (vị trí phát thật, chưa bù) mới nói
   lên **lệch gốc**; khi đã bù đúng, `drift ≈ -(lead+lag)` ⇒ đọc con số đó biết
   ngay bù còn dư/thiếu bao nhiêu. Thông tin bù trễ ghi riêng ở
   `sync=/lead=/lag=`. Đã thêm pin nguồn để không ai “sửa” lại.

### Lỗi dấu phẩy động của Slider

Slider có `divisions` vẫn trả **`100.00000000000001`** và **`-1.4e-14`**
(chia 60 rồi nhân 6000). Hệ quả: UI hiện **“-0.0s”** và `lead == 0` **sai**
(⇒ nhãn “Đang khớp” không bao giờ hiện). `snapAudioLead()` chốt về đúng bước
100 ms và ép `-0.0 → 0.0`.

## 17. File đổi (Đợt 3)

| File | Thay đổi |
|---|---|
| `services/yt_sentence_segmenter.dart` | **MỚI** — gộp cue thành câu, thuần logic |
| `models/yt_learning_settings.dart` | `audioLeadMs` ±  hằng số ±  `clampAudioLead` / `snapAudioLead` / `audioLeadSeconds` ±  copyWith / JSON |
| `yt_player_screen.dart` | `ytParseSentAt`, `_trackChannelLag`, `measuredLagMs`, `syncMs`, gọi segmenter, hàng +− tại tab VĂN BẢN |
| `widgets/yt_subtitle_settings_sheet.dart` | `measuredLagMs`, thanh trượt, gợi ý “Đo được chữ đến trễ …” + *Áp dụng* |
| `.github/workflows/app_analyze.yml` | thêm 2 file test vào step YouTube audit |

## 18. Test (Đợt 3)

* `test/yt_sentence_segment_test.dart` — **29 test / 65 assertion**: chuẩn hoá
  khoảng trắng, dấu kết thúc câu, viết tắt, viết hoa, tidy, rolling window,
  phần chữ mới, 9 kịch bản gộp câu (khoảng lặng / maxChars / maxDuration /
  viết tắt / rolling window / kẹp mốc / nối bản dịch / rỗng / đã hoàn chỉnh).
* `test/yt_sync_offset_test.dart` — **24 test / 52 assertion**: định dạng tin
  cũ & mới, `ytParseSentAt`, kẹp biên ±3000, snap 100 ms, `-0.0`, JSON
  round-trip, dữ liệu cũ ⇒ 0; + 6 pin nguồn đấu nối.
* Cả hai **thuần** (không thiết bị / mạng / WebView) và đã thêm vào step
  *YouTube audit tests*.

## 19. i18n (quy tắc vàng #5)

9 chuỗi chrome mới đều qua `context.uiText()`: `Đang khớp` · `Âm thanh nhanh hơn
chữ` · `Chữ nhanh hơn âm thanh` · `Đặt về 0` · `Căn chỉnh âm thanh & chữ` ·
`Dương: chữ đổi sớm hơn…` · `Chưa đủ mẫu để đo…` · `Đo được chữ đến trễ ` ·
`Áp dụng`. English fallback 1985 → **1994**.

## 20. Checklist nghiệm thu máy thật (Đợt 3)

1. Mở video có phụ đề tiếng Anh → tab **VĂN BẢN**: mỗi dòng là **một câu hoàn
   chỉnh** (viết hoa đầu câu, có dấu chấm), không còn mẩu câu 2–3 từ.
2. Video có **auto-caption** (rolling window): chữ **không bị lặp lại** từ đầu
   đoạn; mỗi dòng chỉ hiện phần đang được đọc.
3. Câu có `Dr.` / `3.5` / `U.S.` ⇒ **không bị cắt** làm hai dòng.
4. Nghe thấy chữ đổi trễ ⇒ bấm **+** ở góc trên tab VĂN BẢN cho tới khi khớp
   (mỗi lần 0,1 s). Nhãn hiện *“Âm thanh nhanh hơn chữ +0.4s”*. Bấm **+**/**−**
   **trong lúc đang nghe** ⇒ vẫn nghe được (đây là lý do nút nằm ở tab này).
5. Nút **↺** (đặt về 0) chỉ hiện khi đã lệch 0.
6. Mở **CÀI ĐẶT PHỤ ĐỀ → Căn chỉnh âm thanh & chữ**: xem vài giây rồi mở lại ⇒
   thấy *“Đo được chữ đến trễ Xs”* (amber) + nút *Áp dụng*; chưa đủ mẫu thì hiện
   *“Chưa đủ mẫu để đo…”* (xám).
7. Thanh trượt kéo hết cỡ hai đầu ⇒ đậu ở **±3,0s**, không vượt.
8. **Seek** và **lặp A-B** vẫn đúng — bù trễ không làm lệch vị trí phát thật.
9. Thoát hẳn rồi mở lại video ⇒ bù trễ **được giữ nguyên** (đã lưu).
10. Đổi locale Cài đặt Home sang **English** ⇒ 9 chuỗi trên hiện tiếng Anh,
    không còn tiếng Việt.

## 21. Còn lại — Đợt 4

**#5 tab GIẢI THÍCH** (IN4-105): tóm tắt AI, mẹo nhớ, ngữ pháp (cấu trúc/chủ
ngữ/động từ/tân ngữ), ví dụ trong ngữ cảnh, hình ảnh gợi nhớ, câu chuyện ghi
nhớ. 19 pin đã sẵn sàng trong `test/yt_lr_002_fixes_test.dart`.

---

# Bàn giao YT-AUDIT-001 — Đợt 4/4: #5 tab GIẢI THÍCH có nội dung thật

**Epic:** IN4-85 · **Issue:** IN4-105 · **Commit:** `5e877bc` · **CI:** 🟢 `39542337818`
**Branch:** `arena/9498c207-in4up`

## 22. #5 — Tab GIẢI THÍCH chỉ hiện “AI chưa phân tích được”

Yêu cầu của owner: tóm tắt AI, mẹo nhớ, **ngữ pháp** (cấu trúc/chủ ngữ/động
từ/tân ngữ/giải thích), ví dụ trong ngữ cảnh, hình ảnh gợi nhớ, câu chuyện ghi
nhớ. Thực tế: một dòng lỗi tiếng Anh thô và **không có gì khác**.

Ba nguyên nhân gốc, mỗi cái nằm ở một tầng khác nhau.

### (1) Prompt không bao giờ xin `grammar` ← lỗi chính của “không có ngữ pháp”

`packages/in4up_ai/lib/src/prompts/ai_prompts_library.dart`:

```dart
static String _wordLookupPrompt(String word, String? context) => '''…
{
  "summary": "<Vietnamese meaning 2-5 words>",
  "word_detail": { … },
  "pao_suggestions": […],
  …
}''';
```

Không có khoá `grammar`. Trong khi đó `AiAnalysis.fromJson` **đã đọc được**
`grammar` từ lâu (dòng 183/212 của `ai_analysis.dart`). Hệ quả: `AiAnalysis.grammar`
luôn `null` ⇒ ô Ngữ pháp không bao giờ hiện, **kể cả khi AI chạy hoàn hảo**.

Sửa:
- Xin đủ `grammar` (`subject`/`verb`/`object`/`complement`/`adverbial`/`pattern`/
  `explanation_vi`) khi **có** câu ngữ cảnh, đặt **ngay sau `word_detail`** —
  model nhỏ hay cắt ngang ở cuối, nên thứ owner đòi rõ ràng phải nằm sớm hơn
  `pao`/`visual`.
- **Bỏ hẳn** khoá này khi không có câu: ngữ pháp là của câu, bắt model bịa
  subject/verb cho một từ đơn là vô nghĩa + phình JSON.
- `summary` đổi từ “2–5 từ” (chỉ là gloss) thành 2–3 câu giải thích theo ngữ cảnh.

### (2) Bảng tra từ tự ném đi dữ liệu mình đang có

```dart
localDictEntry: _localMeaning == null ? null : {'meaning': _localMeaning!}
```

Từ điển nhanh không có từ ⇒ gửi `null` ⇒ facade rớt thẳng vào
`buildFromLocalDict(word, null)` ⇒ `AiAnalysis.fallback('No local dict entry and
engine not ready')` — **dù lúc đó ta vẫn còn nghĩa từ MDX và câu phụ đề đang
phát**. Đây chính là dòng owner nhìn thấy trên máy.

Sửa:
- Gửi đầy đủ: nghĩa (tuyến offline → MDX) + phiên âm + **câu phụ đề đang phát
  làm ví dụ**.
- Nghĩa + phiên âm offline phải xong **TRƯỚC** rồi mới gọi AI (bản cũ gọi
  `_prepareAi()` ngay trong postframe ⇒ `_mdxEntries`/`_ipa` vẫn trống).
- Không có nghĩa ⇒ trả `null` (báo lỗi) thay vì gửi bản đồ rỗng: bản đồ rỗng
  làm facade trả `success: true` với nội dung trống ⇒ UI tưởng AI đã xong ⇒
  **tệ hơn** báo lỗi.

### (3) Chuỗi tiếng Anh thô của engine bị hiện lên màn hình

`errorReason` = `'No local dict entry and engine not ready'` ⇒ hiện nguyên văn.
Không ai hiểu, và **không dịch được** (vi phạm quy tắc vàng #5 theo cả hai
chiều: locale ≠ vi thì chrome không được tiếng Việt, nhưng đây lại là tiếng Anh
cứng).

Sửa: facade giờ phát **mã máy** (`local_dict_missing`, `engine_not_ready`,
`timeout`, `network`, `empty_word`, `unknown`); `aiErrorCode()` vẫn map được cả
câu tiếng Anh cũ ⇒ máy đang chạy bản cũ không gãy. Bảng dịch mã → tiếng Việt +
gợi ý hành động.

Sửa luôn chỗ `example` bị nhét vào `memoryHook` ⇒ câu ví dụ hiện dưới nhãn
“Mẹo nhớ”. Đưa về `contextExamples`.

### Có chủ đích: KHÔNG đoán ngữ pháp / mẹo nhớ bằng regex

Khi AI không có, ta **vẫn hiện nội dung thật**: nghĩa + “Câu đang phát” (chính
câu phụ đề vừa bấm) + một ô nêu **đúng** những phần còn thiếu kèm nút gọi AI.

Nhưng **không** tự bịa ngữ pháp/mẹo nhớ/hình ảnh. Đoán SVO bằng regex trên một
câu bất kỳ sẽ sai phần lớn các trường hợp, và **dạy sai còn tệ hơn không có**.
Ô “cần AI” nói thẳng điều đó — trung thực hơn một câu trả lời sai.

### Có chủ đích: KHÔNG gửi `wordType` vào `localDictEntry`

Bảng đã biết từ loại nhờ phân tích của player (`_typeLabel`). Gửi vào sẽ làm
`_isDictionaryOnly` (đo “độ sâu AI” bằng `wordDetail.wordType`) trả `false`
⇒ **mất luôn cảnh báo “thực ra chỉ là nghĩa từ điển”** đã làm ở Đợt 2.

## 23. File đổi (Đợt 4)

| File | Thay đổi |
|---|---|
| `packages/…/ai_prompts_library.dart` | prompt `wordLookup` xin đủ 7 phần + `grammar` theo ngữ cảnh |
| `packages/…/error/ai_error_codes.dart` | **MỚI** — mã lỗi máy + `aiErrorCode()` |
| `packages/…/facade/ai_service_facade.dart` | phát mã máy; `example` → `contextExamples` |
| `packages/…/in4up_ai.dart` | export mã lỗi + thư viện prompt (để test pin được) |
| `lib/…/services/yt_word_analysis_fallback.dart` | **MỚI** — dựng `localDictEntry`, chọn nghĩa, báo phần thiếu, map mã lỗi |
| `lib/…/widgets/yt_word_panel.dart` | chờ nghĩa offline rồi mới gọi AI; lỗi đã dịch; ô “có sẵn trên máy”; ô “cần AI” |
| `.github/workflows/app_analyze.yml` | +2 file test vào step YouTube audit |

## 24. Test (Đợt 4)

* `test/yt_ai_word_prompt_test.dart` — prompt xin đủ 7 phần khi có câu; **bỏ**
  `grammar` khi không có câu; JSON mẫu không lệch ngoặc / không dấu phẩy thừa;
  `sentenceParse` không bị ảnh hưởng.
* `test/yt_word_analysis_fallback_test.dart` — dựng `localDictEntry` (đủ/thiếu
  nghĩa/rỗng), chọn nghĩa (offline → MDX → cắt dài), báo phần thiếu (đủ 7 / chỉ
  từ điển / lỗi), map mã lỗi (câu cũ + mới + timeout + mạng + unknown), + 6 pin
  nguồn đấu nối.
* Cả hai **thuần** (không thiết bị / mạng / model AI) và đã vào step
  *YouTube audit tests*.

## 25. i18n

12 chuỗi chrome mới có English fallback (1994 → **2006**), gồm cả 2 chuỗi thiếu
từ trước của tab NGHĨA (`Ngữ pháp`, `Từ đồng nghĩa`).

## 26. Checklist nghiệm thu máy thật (Đợt 4)

**Có model AI (hoặc API remote đã cấu hình):**
1. Bấm 1 từ trong phụ đề ⇒ tab **GIẢI THÍCH** có ô **Ngữ pháp** với đủ Cấu
   trúc / Chủ ngữ / Động từ / Tân ngữ + Giải thích tiếng Việt. ← phần chưa bao
   giờ có trước đây.
2. Có **Tóm tắt** dài 2–3 câu (không còn chỉ 2–5 từ).
3. Có **Mẹo nhớ**, **Ví dụ trong ngữ cảnh**, **Hình ảnh gợi nhớ**, **Câu chuyện
   ghi nhớ** (PAO).
4. Bấm 1 từ **không có** trong từ điển offline ⇒ vẫn có kết quả AI (không còn
   “No local dict entry”).

**Chưa cài model AI:**
5. Tab hiện banner + nút **Cài AI**, và **vẫn có nội dung**: nghĩa offline (từ
   điển nhanh hoặc MDX) + **Câu đang phát** = chính câu phụ đề vừa bấm.
6. Nếu AI gọi được nhưng thất bại ⇒ ô lỗi hiện **tiếng Việt**, không còn câu
   tiếng Anh thô.

**Chung:**
7. Ô “Cần AI cho phần còn lại” liệt kê **đúng** những phần còn trống (vd
   “Ngữ pháp · Hình ảnh gợi nhớ · Câu chuyện ghi nhớ”).
8. Đổi sang một từ khác ⇒ kết quả đổi theo, không bị kẹt kết quả cũ.
9. Đổi locale Cài đặt Home sang **English** ⇒ 12 chuỗi trên hiện tiếng Anh.

## 27. Tổng kết cả 4 đợt

| Đợt | Mục | Issue | CI |
|---|---|---|---|
| 1 | #1 #2 #3 #7 #8 #10 | IN4-97…102 | 🟢 `39432459448` → `6941457` |
| 2 | #4 #6 | IN4-103, IN4-104 | 🟢 `39496675963` → `6e1dd73` |
| 3 | #11 | IN4-108 | 🟢 `39507761643` → `b6958ef` |
| 4 | #5 | IN4-105 | 🟢 `39542337818` → `511f2ae` |

*(Cột phải = commit sau khi gom lần 1 ngày 2026-10-21. Sau lần gom 2
(2026-10-22) cả 4 đợt nằm chung commit `5f98233`, đã rebase lên `a1a0eeb`;
`6547772` = YT-LR-002/003/004, commit cuối = bản audit nghiệm thu chung.)*

#9 owner xác nhận đã fix ở YT-LR-003, không làm lại.
