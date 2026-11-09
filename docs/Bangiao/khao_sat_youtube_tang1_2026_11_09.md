# Khảo sát YouTube — trọng tâm **tầng 1** (2026-11-09)

> **Chỉ thảo luận — KHÔNG sửa code trong đợt này.**
> Nhánh: `arena/478b8f3a-in4up`. Đã `git fetch` + so với `origin/arena/01a0251e-in4up`:
> cả hai đang ở **cùng một commit `f8be18c`** (`test(video): run A-B loop tests in CI`),
> `git rev-list --left-right --count HEAD...origin/arena/01a0251e-in4up` = `0 0`
> ⇒ **không còn commit mới để rebase**, nhánh đã đứng đúng nền.
> Lưu ý phối hợp: PR **#142** (Audit v1.23.0 — khay màu transcript, tạm dừng khi tra từ,
> màu YouTube → độ khó dùng chung) đang ở nhánh `arena/64e98f20-in4up`, **chưa gộp** vào 251e.
> Vì vậy một số nhận xét dưới đây về `yt_player_screen.dart` là trên bản **nền 251e hiện tại**
> (chưa có 3 tính năng của PR #142).

## 0. Phương pháp & giới hạn

- Đọc trực tiếp mã nguồn: `lib/features/youtube/**` (16.142 dòng), 20 file test `test/yt_*.dart`,
  và catalog i18n (`priority_ui_overrides.dart`, `generated_ui_translations.dart`).
- **Máy này không có Flutter SDK** ⇒ không chạy được `flutter analyze`/`flutter test`/máy thật.
  Mọi kết luận là **đọc mã**, không phải quan sát hành vi runtime. Những chỗ cần xác nhận trên
  máy thật được đánh dấu *(cần máy thật)*.
- Không đụng `web/yt_embed.html` (thuộc nhánh khác) và không sửa `lib/ffi/`.

## 1. Tầng 1 hiện nay là gì

“Tầng 1” theo lịch sử = **cửa vào YouTube**: trước là bottom sheet `YoutubeSheet` (dán URL),
nay (từ IN4-95 / YT-LR-004) là **`YoutubeExplorerScreen`** — màn “Khám phá”: tìm kiếm + kênh +
danh sách video. Kích thước: **1.319 dòng**, cùng các service:

| Thành phần | File | Vai trò |
|---|---|---|
| Explorer (tầng 1) | `youtube_explorer_screen.dart` (1.319) | ô tìm kiếm duy nhất, sidebar lọc, danh sách video, lịch sử, “Kênh của tôi” |
| Tìm kiếm/kênh keyless | `services/yt_search_service.dart` (185) | tầng 1 `youtube_explode_dart`, tầng 2 parse `ytInitialData` |
| Parser HTML | `services/yt_initial_data_parser.dart` (294) | đọc `ytInitialData` thuần Dart |
| Kênh đã theo dõi | `services/yt_channel_store.dart` (122) + `widgets/yt_my_channels_sheet.dart` (553) | `@handle`/URL + OPML, `shared_preferences` |
| Chi tiết video/phụ đề | `services/yt_service.dart` (515) | oEmbed, captions 4 tầng, danh sách ngôn ngữ |
| Player (tầng 2) | `yt_player_screen.dart` (3.780) | WebView + phụ đề + tra từ + TTS + tải |

**Điểm mạnh đáng giữ** (đừng “làm lại từ đầu”): chạy **không cần Data API key**; hai tầng
(explode → parse HTML) để YouTube đổi client vẫn còn đường; một ô vừa dán URL vừa tìm
(`ytVideoIdFromSearchInput` có chặn bẫy “11 ký tự là từ khoá”); responsive 560dp; giữ Lịch sử;
watchdog + overlay lỗi player khá kỹ.

## 2. Chuẩn “chuyên nghiệp” đề nghị dùng để chấm

Một màn khám phá nội dung được coi là chuyên nghiệp khi đạt 7 điều. Cột “hiện nay” là kết quả khảo sát.

| # | Chuẩn | Hiện nay |
|---|---|---|
| 1 | **Không có điều khiển giả** — thao tác nào cũng có tác dụng thật | ❌ thanh “Cấp độ từ vựng” không lọc gì |
| 2 | **Một nguồn sự thật** — dữ liệu người dùng nhập hiện ở mọi nơi liên quan | ❌ “Kênh của tôi” không xuất hiện ở Explorer |
| 3 | **Trạng thái rõ** — phân biệt “đang tải / rỗng / lỗi mạng / bị chặn / hết trang” và có nút thử lại | ❌ tất cả rơi vào một empty state |
| 4 | **Không mất thao tác** — bấm lúc đang tải vẫn có kết quả đúng, không bị nuốt | ❌ truy vấn mới bị `return` khi đang tải |
| 5 | **Nhanh & nhẹ** — cache, phân trang, ảnh decode đúng cỡ | ❌ không cache, không phân trang, ảnh decode full-size |
| 6 | **Bản địa hoá & tiếp cận** — chrome không tiếng Việt khi locale ≠ vi; vùng chạm ≥ 48dp | ❌ ~10 nhãn hard-code; chữ 8–10px; icon chạm 12px |
| 7 | **Đo được** — có test hành vi, có log/metric | ⚠️ 17 assertion nhưng **toàn quét chuỗi mã nguồn**, không test hành vi |

## 3. Phát hiện cụ thể ở tầng 1

Mức: **P0** = nói dối/không dùng được, sửa ngay; **P1** = chuyên nghiệp hoá; **P2** = bóng bẩy.

### P0 — người dùng bị “lừa” hoặc mất thao tác

**YT1-01 · Thanh “Cấp độ từ vựng” là điều khiển giả** (P0)
`_rankMin/_rankMax` khai báo ở `:121` và **chỉ** được dùng để vẽ `RangeSlider` (`:801-809`).
`_loadVideos()` không hề đọc hai biến này; `YtExVideo.langRank` (`:53`) **không bao giờ được gán**
(`_hitToEx` `:273-282` không truyền `langRank`, mà keyless cũng không có dữ liệu này).
⇒ Người dùng kéo thanh, danh sách không đổi. Đây là kiểu lỗi tệ nhất về niềm tin.
*Đề xuất:* hoặc (a) **ẩn** thanh này khi không có nguồn rank (keyless), hoặc (b) làm thật: tính
rank trung bình của phụ đề — nhưng phải phân tích phụ đề từng video, quá đắt cho danh sách.
Khuyến nghị **(a) ẩn + ghi chú “cần API key”**, và chỉ hiện khi có dữ liệu thật.

**YT1-02 · “Kênh của tôi” không nối với Explorer** (P0)
`YtChannelStore` chỉ được dùng trong `yt_my_channels_sheet.dart` (`:60,100,155,185`); Explorer
nạp cứng `_kDefaultChannels` (`:91-99` → `:172-186`). ⇒ Người dùng import 50 kênh OPML, đóng
sheet ra thì sidebar **vẫn 7 kênh tiếng Anh mặc định**. Hai hệ song song.
*Đề xuất:* sidebar = **hợp** `YtChannelStore` (nhóm “Kênh của tôi”, có ghim) + danh sách gợi ý;
kênh đã theo dõi hiện trước, kênh mặc định sau. Đây là việc nối dây, không phải viết mới.

**YT1-03 · Truy vấn mới bị nuốt khi đang tải** (P0)
`_loadVideos` mở đầu bằng `if (_loading) return;` (`:221`). Người dùng đổi kênh rồi gõ tìm kiếm
trong 1–3 giây đầu ⇒ lệnh thứ hai **mất im lặng**, danh sách hiện kết quả của lệnh cũ.
*Đề xuất:* sinh số thứ tự yêu cầu (`_reqId++`), bỏ kết quả về muộn; hoặc `CancelableOperation`.
Đây là mẫu kinh điển, sửa ~15 dòng.

**YT1-04 · ~10 nhãn hard-code tiếng Việt** (P0 — vi phạm quy tắc vàng #5)
`Text('Cấp độ từ vựng')` `:795`, `'Sắp xếp theo'` `:822`, `'Kênh'` `:839`, `Text(label)` trong
`_sortBtn` (`'Ngày'`, `'Lượt xem'`), `'Thêm kênh'` `:1233`, `'Huỷ'` `:1252`, `'Thêm'` `:1267`,
`'Tất cả các kênh'` `:855`. Catalog **đã có** bản dịch cho các khoá này (kiểm `generated_ui_translations`
= 3 locale mỗi khoá) — chỉ là mã không gọi `uiText`.
Thêm: `viewLabel`/`dateLabel` (`:67-84`) **dựng câu tiếng Việt có nội suy** (`'1.2M lượt xem'`,
`'3 ngày trước'`) rồi mới bọc `uiText` ⇒ không bao giờ khớp template, locale ≠ vi vẫn ra tiếng Việt.
*Đề xuất:* bọc `context.uiText`, và đổi hai getter thành **template** `{value0} lượt xem` /
`{value0} {value1}` với đơn vị rời (ngày/tháng/năm) để dịch được.

### P1 — chuyên nghiệp hoá nội dung & trạng thái

**YT1-05 · Không phân biệt lỗi với rỗng** (P1)
`fetchChannelVideos` trả `[]` cho cả “kênh không có video”, “HTTP 403”, “trang consent/bot-check”,
“parser gãy” (chỉ `debugPrint`, `yt_search_service.dart:99-140`). Explorer hiển thị một empty
state duy nhất (`:1195-1220`) ⇒ người dùng tưởng kênh trống.
*Đề xuất:* service trả kết quả có kiểu: `ok(list) | empty | blocked | networkError | parseFailed`;
Explorer hiện câu tương ứng + nút **Thử lại** / **Mở trên YouTube**.

**YT1-06 · Không cache, không offline** (P1)
Mỗi lần mở Explorer gọi mạng (kênh + lịch sử không cache danh sách video). Mất mạng = màn trống.
*Đề xuất:* cache theo khoá `(kind, id/query)` vào Hive, TTL 30 phút, **stale-while-revalidate**:
hiện cache ngay + làm mới ngầm. Đúng tinh thần local-first; chi phí ~1 file service.

**YT1-07 · Không phân trang ở chế độ keyless** (P1)
`_hasMore = false` (`:255`, `:279`). Kết quả kẹt ở 20–30 video, không có “tải thêm”.
*Đề xuất:* `ytInitialData` có `continuationCommand` → gọi `youtubei/v1/search` (POST, keyless,
cùng UA) để lấy trang sau. Nếu ngại endpoint nội bộ, tối thiểu: nút “Xem thêm trên YouTube”.

**YT1-08 · Thẻ video thiếu thông tin quyết định** (P1)
`_videoTile` (`:1096-1180`) chỉ có: tiêu đề, `viewLabel`, `dateLabel`, thanh rank.
Thiếu: **tên kênh** (bắt buộc khi tìm kiếm xuyên kênh), nhãn **LIVE**, nhãn **Shorts**,
nhãn **“đã tải”/“có phụ đề tiếng X”/“đã đưa vào tab Đọc”**, % đã nghe.
*Đề xuất:* thêm hàng phụ “kênh · thời lượng · trạng thái”; đọc trạng thái từ `YtMediaStore`
(đã có API dung lượng) + `YtReadBridge`. Người dùng nhìn danh sách là biết cái nào dùng được offline.

**YT1-09 · Ảnh thumbnail decode full-size** (P1)
`Image.network(v.thumb!)` trong khung 130×73 nhưng không `cacheWidth` ⇒ mỗi ảnh decode ở cỡ gốc
(vd 1280×720 = gấp ~90 lần số pixel cần). Danh sách 20–30 dòng ⇒ áp lực bộ nhớ, giật khi cuộn.
*Đề xuất:* `cacheWidth: (130 * devicePixelRatio).round()`, thêm `frameBuilder` fade-in,
`filterQuality: FilterQuality.low`. Sửa 2 chỗ (`_videoTile`, `_chanTile`).

**YT1-10 · Bộ lọc/nhãn không được nhớ** (P1)
`_selChannelId`, `_sortMode`, `_rankMin/_rankMax`, `isPinned` chỉ nằm trong RAM
(`:890` ghim kênh bằng `setState`, thoát màn là mất). `_searchQuery` cũng mất.
*Đề xuất:* lưu `YtExplorerPrefs` (shared_preferences) — nhỏ, ảnh hưởng lớn tới cảm giác “app nhớ mình”.

**YT1-11 · Danh sách kênh “gợi ý” cứng 7 kênh tiếng Anh** (P1)
`_kDefaultChannels` (`:91-99`) + nhãn `'ĐƯỢC KHUYẾN NGHỊ: 1 - 7'` (`:869`).
Người học tiếng Trung/Nhật mở app thấy 7 kênh tiếng Anh — sai đối tượng.
*Đề xuất:* chọn bộ gợi ý theo **ngôn ngữ đích ở Cài đặt Home** (đã có `TranslationService().targetLang`),
mỗi ngôn ngữ 5–8 kênh; nếu chưa có bộ cho ngôn ngữ đó thì **ẩn cả khối gợi ý** thay vì hiện sai.

**YT1-12 · Ô tìm kiếm: gợi ý có thể về sai thứ tự; Enter không có trạng thái** (P2)
`_onSearchChanged` (`:600-621`) debounce 350ms nhưng không kiểm “phản hồi này còn ứng với chữ đang gõ
không” ⇒ gõ nhanh có thể thấy gợi ý cũ đè lên. Ngoài ra `_searchCtrl` không có
`textInputAction: TextInputAction.search` (bàn phím hiện nút “xong” thay vì “tìm”).
*Đề xuất:* đếm phiên bản như YT1-03; thêm `textInputAction` + `onSubmitted`.

### P2 — tiếp cận & chi tiết

**YT1-13 · Vùng chạm và cỡ chữ quá nhỏ** (P2)
Icon ghim kênh 12px (`:997`), nút ghim/sắp xếp cao 24–32px, nhãn 8–10px
(`:795-840`, `_tag` 10px, `_rankBar` 9px). Trên điện thoại, chạm 12px là gần như không thể.
*Đề xuất:* tối thiểu 44–48dp cho mọi vùng chạm (dùng `IconButton` có `constraints`), chữ sàn 11px,
tăng tương phản (grey[600]/[700] trên `#161B22` dưới ngưỡng đọc).

**YT1-14 · Không có “kéo để làm mới”, không có nút thử lại ở cấp màn** (P2)
`_loadVideos` chỉ chạy khi đổi bộ lọc/kênh/tìm kiếm. Danh sách cũ, không có cách làm mới nhanh.

**YT1-15 · Test chưa bảo vệ hành vi** (P2 nhưng ảnh hưởng dài hạn)
`test/yt_explorer_entry_test.dart` 17 assertion **đều là `source.contains(...)`**.
Không test nào chạy thật `_loadVideos`, race, hay filter. Nghĩa là: sửa hỏng hành vi mà test vẫn xanh.
*Đề xuất:* tách phần logic ra service thuần (như `buildYtPreparePlan`) rồi test hành vi:
`YtExplorerController` (state machine: query → loading → ok/blocked/empty) test được không cần mạng
bằng cách tiêm hàm `search`/`fetchChannel` giả.

## 4. “Làm sao cho chuyên nghiệp” — 3 đợt đề nghị

| Đợt | Nội dung | Mục tiêu cảm nhận | Ước lượng |
|---|---|---|---|
| **A — “Không nói dối”** | YT1-01 (ẩn/bỏ filter giả) · YT1-02 (nối Kênh của tôi) · YT1-03 (race) · YT1-04 (i18n) | Mở lên thấy đúng, bấm gì cũng có tác dụng, tiếng Anh ra tiếng Anh | 1–1,5 ngày |
| **B — “Nhanh và biết chuyện gì đang xảy ra”** | YT1-05 (trạng thái lỗi) · YT1-06 (cache) · YT1-08 (nhãn trạng thái thẻ) · YT1-09 (ảnh) · YT1-10 (nhớ bộ lọc) | Mở tức thì, mất mạng vẫn dùng, hiểu ngay video nào đã tải | 2 ngày |
| **C — “Đủ để học cả kênh”** | YT1-07 (phân trang) · YT1-11 (gợi ý theo ngôn ngữ) · YT1-12 · YT1-13/14 · YT1-15 (test hành vi) | Cuộn được sâu, đúng ngôn ngữ đang học, thao tác một tay | 2–3 ngày |

Nguyên tắc xuyên suốt để “trông chuyên nghiệp” mà không cần làm lại giao diện:
1. **Mỗi điều khiển phải có dữ liệu thật đứng sau** (nếu chưa có thì ẩn, đừng giả).
2. **Bốn trạng thái tách bạch**: đang tải / rỗng / lỗi-có-thể-thử-lại / bị-chặn-không-thể.
3. **Danh sách là nơi quyết định**: người dùng phải biết video đó *có phụ đề gì, đã tải chưa,
   đã học chưa* **trước khi** bấm vào.
4. **Nhớ người dùng**: kênh, bộ lọc, vị trí cuộn, từ khoá gần nhất.
5. **Đo bằng test hành vi**, không phải test chuỗi.

## 5. Góp ý các mảng YouTube khác (ngoài tầng 1)

### 5.1 Player (`yt_player_screen.dart`, 3.780 dòng)
- **Không nhớ vị trí đang xem** — đóng video mở lại là từ đầu. Với video học 40 phút đây là lỗi
  cảm nhận nặng nhất. Đề xuất: lưu `(videoId → ms)` trong Hive mỗi 5s + khi `dispose`, khi mở lại
  hỏi “Xem tiếp từ 12:34?”.
- **Không có “video kế tiếp”/playlist** — học theo kênh phải back ra Explorer mỗi lần.
- **Không có tốc độ phát video** (0,75×/1×/1,25×). Hiện chỉ có tốc độ TTS. Người học cần cả hai.
- **Không xử lý lỗi mạng của WebView**: `NavigationDelegate` chỉ có `onPageFinished`
  (`:510-536`); thiếu `onWebResourceError` ⇒ mất mạng giữa chừng thì màn hình đen im lặng,
  watchdog chỉ bắt được vài trường hợp *(cần máy thật để xác nhận)*.
- **Chưa có “chương” (chapters)**: video học thường có chapter trong mô tả; đưa chapters thành
  mốc nhảy + thành “mục lục” cho `YtReadBridge` ở tab Đọc (rất hợp với hướng “1 video = 1 bài đọc”).
- **Fullscreen/PiP**: hiện chỉ có layout ngang/dọc, chưa có toàn màn hình thật.

### 5.2 Tải về & thư viện media
- `YtDownloader` là **singleton có cờ `_cancelled` dùng chung** (`yt_downloader.dart:61,63,490`)
  ⇒ không thể tải **2 video song song**, và “Tải cả kênh” sẽ phải tuần tự + không huỷ riêng từng cái.
  Nếu định làm batch (rất nên), cần hàng đợi: `(jobId, videoId, loại, trạng thái)`, huỷ theo job.
- Nên có **“Tải tất cả phụ đề của kênh đang xem”** (chỉ caption — rất nhẹ, vài chục KB/video)
  kèm báo dung lượng trước khi tải. Hợp yêu cầu “người dùng phải biết file chiếm bao nhiêu dung lượng”.
- `YtMediaStore` đã có API dung lượng — chỉ cần đưa lên **thẻ video** (YT1-08) là thành tính năng.

### 5.3 Từ vựng / tra từ
- PR #142 vừa nối màu YouTube → `userDifficulty` (một chiều). Bước tự nhiên tiếp theo:
  **“từ vựng của kênh này”** — gom các từ `learning` theo `channelId` để mở lại đúng kênh mà ôn.
- Cân nhắc **gộp tab TỪ của player** với màn Từ vựng chung để không có hai danh sách “đang học”.

### 5.4 Kênh của tôi
- Import OPML nên hỗ trợ **nhập lại để cập nhật** (hiện `addAll` chỉ thêm mới — cần dedupe theo
  `handle/url` đã có, nhưng nên báo “đã có 12 kênh, thêm 8, bỏ qua 4”).
- Cho **nhóm kênh** (Thầy A / Tin tức / Phim) — chỉ là thêm 1 trường, giúp sidebar Explorer gọn.

### 5.5 i18n & test
- Gate hiện tại (`test/locale_chrome_no_vietnamese_test.dart`) **chỉ so ARB**, còn
  `test/i18n/dict_pack_and_word_pop_i18n_test.dart` chỉ quét **4 file**. Đó là lý do YT1-04 lọt.
  Đề xuất: mở rộng danh sách quét sang `lib/features/youtube/**` (ít nhất 2 màn chính).
- Thêm **test hành vi** cho service (thuần Dart, không cần WebView): parser HTML với fixture thật
  (kết quả tìm kiếm, trang kênh, trang bị consent) — hiện parser chỉ được test gián tiếp.

## 6. Thứ tự đề nghị (chờ user chốt)

1. **Đợt A** (4 việc, 1–1,5 ngày): YT1-01, YT1-02, YT1-03, YT1-04.
   → Đây là nhóm “sửa cái sai”, không thêm tính năng, rủi ro thấp, cảm nhận rõ.
2. **Đợt B** (5 việc, 2 ngày): YT1-05, 06, 08, 09, 10.
3. **Đợt C** (5 việc, 2–3 ngày): YT1-07, 11, 12, 13+14, 15.
4. **Player**: “nhớ vị trí đang xem” nên làm **sớm**, tách đợt riêng vì chạm vào player
   (đang có PR #142 chưa gộp ⇒ nên chờ gộp để tránh xung đột `yt_player_screen.dart`).

### 6.1 Chốt của owner (2026-11-09)

- **(b) “Kênh của tôi” ĐỨNG SAU danh sách gợi ý.** Thứ tự sidebar: gợi ý (theo ngôn ngữ đích)
  → **Kênh của tôi** → “Tất cả các kênh”. Nghĩa là YT1-02 vẫn là *nối dây*, không phải thay thế.
- **(c) Cache CÓ tính dung lượng, mặc định hiện, được ẩn trong Cài đặt YouTube.** Nghĩa là:
  cache phải đi qua `YtMediaStore`-style (thư mục hiện, cộng vào “dung lượng đã dùng”),
  và có công tắc “Hiện dung lượng cache” trong `YtLearningSettings`/sheet cài đặt.
  TTL: **có** (đề xuất dưới).
- **(a) chưa chốt** — đang chờ trả lời chi phí (mục 6.2).

### 6.2 Chi phí nếu làm “Cấp độ từ vựng” cho thật

Ba mức, chọn theo chi phí:

| Mức | Cách làm | Băng thông | Thời gian | Công code |
|---|---|---|---|---|
| **0 — Ẩn** | Bỏ slider khỏi sidebar | **0** | 0 | ~10 phút (xoá UI + test) |
| **1 — Rẻ (đề xuất)** | Chỉ tính cho video **đã có phụ đề trên máy** (`YtMediaStore.list()` → `lrcPath != null`); video chưa có thì vào nhóm “chưa rõ cấp độ”, có nút “Tính cấp độ” từng video | **0** (đọc file cục bộ) | < 50 ms cho 30 video (tokenize ~30k từ) | ~0,5 ngày |
| **2 — Đầy đủ** | Tải manifest/player response của **từng** video trong trang để lấy phụ đề rồi tính | **≈ 4–10 MB / 20 video** (mỗi video phải mở 1 trang ~0,5–1 MB mới biết có phụ đề gì) | 10–40 s trên Wi-Fi, lâu hơn nhiều trên 4G; 20 request ⇒ dễ bị YouTube chặn tạm | ~1,5–2 ngày + rủi ro |

Ghi chú kỹ thuật cho mức 1/2: “cấp độ của video” = **rank trung bình của các từ nội dung**
(bỏ stopword), tra trong bảng tần suất đã có sẵn trong app — phần tính toán không tốn gì;
tốn là **lấy được chữ**. Bản thân file phụ đề rất nhẹ (~20–60 KB/video), nên *nếu phải tải*
thì nên tải **cả phụ đề và giữ lại** (hợp với quyết định (c): cache có dung lượng, có thể ẩn) thay
vì tải để tính rank rồi vứt.

**Khuyến nghị:** mức **1** — thanh trượt có tác dụng thật với video đã tải (nhóm người dùng quan
tâm nhất), không tốn 1 byte mạng, và khi chưa có dữ liệu thì **ẩn số, hiện nhãn “chưa rõ”** chứ
không hiện thanh giả. Mức 2 chỉ nên làm sau, dưới dạng nút **“Phân tích cả trang”** có hộp thoại
báo trước “~6 MB, ~20 giây” — người dùng tự quyết.

### 6.3 TTL cache (theo quyết định (c))

| Loại | TTL | Lý do |
|---|---|---|
| Kết quả tìm kiếm theo từ khoá | 24 giờ | Nội dung mới xuất hiện nhanh, nhưng lặp lại trong ngày rất nhiều |
| Danh sách video của kênh | 3 ngày | Kênh học ít đăng; 3 ngày vẫn đủ tươi |
| Thông tin kênh (tên/ảnh/mô tả) | 30 ngày | Gần như tĩnh |
| Phụ đề đã tải | **không hết hạn** | Là dữ liệu người dùng chủ động tải, xoá tay như hiện nay |

Stale-while-revalidate: hiện cache **ngay**, làm mới ngầm, có nhãn nhỏ “cập nhật 2 giờ trước”.
Nút “Làm mới” trong menu = bỏ qua TTL. Dung lượng cache đi vào màn dung lượng chung và có
công tắc ẩn/hiện.
