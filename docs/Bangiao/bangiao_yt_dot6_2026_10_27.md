# Bàn giao — YouTube đợt 6 (2026-10-27)

Nhánh `arena/35d89772-in4up`, base `arena/01a0251e-in4up`.
Nối tiếp đợt 5 (PR #102) và fix màn trắng `YT-TTS-PROVIDER-001` (PR #109).

Tài liệu này ghi **cái gì đã sửa trong code** và **cái gì chưa làm được /
cần quyết định** — để lần sau không phải đọc lại toàn bộ 10 yêu cầu.

---

## A. ĐÃ SỬA TRONG CODE

### #7 — `YT-DL-PATH-001` · tải file báo lỗi vô nghĩa / crash
`lib/features/youtube/services/yt_downloader.dart`

* Nguyên nhân: `File(path).length()` **ném** `PathNotFoundException` khi file
  chưa tồn tại. Lần tải ĐẦU TIÊN chưa có `.part` ⇒ ném ngay trong vòng tiến
  độ. Trước đây lỗi này bị lỗi `RangeError` khác che mất vì ném sớm hơn.
* Sửa: thêm `static Future<int> _lengthOrZero(File)` (không tồn tại ⇒ `0`) và
  thay **cả 5 chỗ** đọc kích thước.
* `_friendlyError` map `PathNotFoundException` / `Cannot retrieve length of
  file` / `FileSystemException` / `No space left` → “Không ghi được file trên
  máy — kiểm tra dung lượng và nơi lưu (Thư viện → nơi lưu)”. Không đẩy
  path/stack ra UI.

### #4 — `YT-RESUME-AFTER-LOOKUP-001` · tra từ xong video tự chạy
`lib/features/youtube/yt_player_screen.dart`

* `_showWordPopup` nay `async`, hỏi `_isVideoPlaying()` **trước** khi
  `_pauseVideo()`; đóng bảng xong chỉ `_resumeVideo()` khi **chính ta** làm
  dừng và `_readAloudRunning == false`.
* `runJavaScriptReturningResult` trả `bool` (Android) hoặc `"true"` (iOS) ⇒
  nhận cả hai.

### #5 — `YT-BATCH-LINE-001` · “Biết hết” / “Học cả câu” không thấy gì đổi
`yt_player_screen.dart`

Ba nguyên nhân, sửa cả ba:

1. Chỉ đổi từ đang `unknown` ⇒ từ đã `learning` bấm “Biết hết” không đổi.
   Nay `_markWholeLine(line, target)` gom theo chữ thường + bỏ trùng, đếm
   `changed`/`skipped`, và “Học cả câu” **không hạ** từ `known` xuống.
2. `learning` và `unknown` **vẽ giống nhau** (chỉ `known` có gạch chân) ⇒
   `_WordChip` nay: `known` = gạch chân liền xanh, `learning` = gạch chấm tím
   + chữ tím nhạt, `unknown` = bình thường.
3. Không có thông báo ⇒ luôn có snackbar (`_snack`), gồm cả trường hợp
   “không có gì để đổi”, nói rõ `đã đổi/thay đổi bao nhiêu từ`.

### #6 — `YT-PAINT-001` · “khay màu” tô từ hàng loạt
`yt_player_screen.dart`

Nút **Khay màu** trên hàng hành động mở dải chọn màu:

* `Đã biết` (xanh) / `Đang học` (tím) / `Bỏ qua` (xám) — chọn màu rồi **bấm
  vào từ là tô ngay**, KHÔNG mở bảng tra từ (nếu mở bảng thì mỗi từ vẫn tốn
  2 lần bấm).
* `Tô cả dòng` — tô toàn bộ từ của dòng hiện tại bằng màu đang cầm.
* Đóng khay màu ⇒ thoát chế độ tô (bấm từ quay lại mở bảng tra từ).
* Từ chưa đánh dấu có gạch chấm xanh ngọc **khi đang cầm cọ** để thấy vùng
  bấm được, đọc bình thường thì không rối.
* Dùng lại `_setWordState` (đã có `_persistWordStates`, `VocabularyBridge`).

### #8 — `YT-READ-LOOP-LESSON-001` · “đọc mãi mãi”
`models/yt_learning_settings.dart`, `services/yt_read_aloud_sequence.dart`,
`services/yt_read_aloud_controller.dart`, `widgets/yt_read_aloud_sheet.dart`

* Thêm `readAloudPasses`: `0` = **mãi mãi**, `n` = đọc `n` lượt **cả bài** rồi
  tự dừng. `ytPassCount()` đổi sang `int?` (`null` = vô hạn) để không phải
  bịa một trần tuỳ tiện.
* Controller: vòng `while` theo lượt; lượt đầu bắt đầu từ `startIndex`, các
  lượt sau đọc **lại từ đầu bài**; nghỉ giữa hai lượt dài gấp 3 lần nghỉ giữa
  hai dòng; `stop()` reset `_pass`/`_passTotal`.
* Sheet: chip `1 2 3 5 10 ∞ Mãi mãi` + dòng giải thích theo lựa chọn.
* JSON: thiếu khoá (dữ liệu cũ) ⇒ `1` lượt — **không tự lặp**, không phá hành
  vi cũ.

### #9 — `YT-READ-SYNC-VIDEO-001` · chỉ đọc bản dịch nhưng muốn video chạy đúng chỗ
`yt_learning_settings.dart` (+2 cờ), `yt_player_screen.dart`, `sheet`

* `readAloudSyncVideo`: tua video tới đúng dòng đang đọc.
* `readAloudPlayVideoAudio`: phát **tiếng gốc** của video ở câu gốc, tạm dừng
  khi đọc bản dịch ⇒ nghe được giọng thật của video mà TTS không chồng tiếng.
* `_onReadAloudChanged`: chỉ tua khi **đổi dòng/bên** (`_syncedLine`,
  `_syncedSide`) — controller `notifyListeners()` mỗi bước đọc, tua mỗi notify
  sẽ giật video.
* Hai công tắc độc lập; `PlayVideoAudio` chỉ bật được khi `SyncVideo` bật.

### #2 — `YT-ONE-BAR-001` · một ô cho cả tìm kiếm và dán URL
`services/yt_search_service.dart`, `youtube_explorer_screen.dart`

* Ô tìm kiếm duy nhất: nội dung nhận ra là URL/ID YouTube ⇒ mở video; còn lại
  ⇒ tìm theo từ khoá. Không cần chọn chế độ trước.
* Hàm thuần `ytVideoIdFromSearchInput()` (test được): chỉ nhận ID trần 11 ký
  tự **có ít nhất một chữ số**, để `learnenglis`-kiểu từ khoá 11 ký tự không
  bị biến thành lệnh mở video rác.
* Xoá **thanh dán URL thứ hai** và `_urlCtrl`; thêm nút dán clipboard trong
  chính ô đó (dán xong chạy luôn).
* Hint: “Tìm bài, hoặc dán URL/ID YouTube vào đây...”.

### #1 — `YT-LIB-SEARCH-001` · Thư viện đọc → YouTube chỉ cho dán URL
`lib/screens/text_library_drawer.dart`

Nút YouTube mở thẳng `YoutubeExplorerScreen` (có tìm kiếm / kênh / lịch sử)
thay vì `YoutubeSheet` chỉ có ô dán URL. Ô tìm kiếm ở đó nhận cả URL
(`YT-ONE-BAR-001`) nên **không mất** khả năng dán.

### Lỗi layout tìm thấy khi đọc code (chưa ai báo)
`Spacer()` nằm trong `Row` của `SingleChildScrollView` **ngang** ⇒ chiều rộng
vô hạn ⇒ `RenderFlex` ném lỗi layout. Đổi thành `SizedBox(width: 16)`.

---

## B. TEST

`test/yt_one_bar_and_loop_test.dart` (mới), chạy trong bước “YouTube audit
tests” của `.github/workflows/app_analyze.yml`:

* #2: link watch/youtu.be/shorts, ID trần, **từ khoá 11 ký tự toàn chữ**,
  tiếng Việt có dấu, rỗng, link hỏng.
* #8: `0` = mãi mãi, `1` = một lượt, âm kẹp 1, `copyWith` giữ `0` và kẹp
  trần 20, JSON khứ hồi giữ `0`, **dữ liệu cũ thiếu khoá ⇒ 1 lượt**.
* #9: `targetOnly` + tua video là tổ hợp hợp lệ; bật tiếng video không tự bật
  tua; thứ tự đọc không đổi.

---

## C. CHƯA LÀM / CẦN QUYẾT ĐỊNH

### #3 — đăng nhập YouTube + “video của kênh tôi”
Không làm được theo kiểu “đăng nhập”: YouTube không cho app bên thứ ba lấy
danh sách video của kênh bằng tài khoản người dùng mà không qua OAuth +
chính sách API rất chặt; nhúng WebView đăng nhập còn vi phạm ToS và Google
chặn “insecure browser”. **Đề xuất thay thế (đã có sẵn hạ tầng):**

* Người dùng **dán danh sách kênh** (`@handle` / URL kênh) vào một màn “Kênh
  của tôi”, lưu local; Explorer đã có `channelId` + `getUploads` (keyless).
* Thêm “Theo dõi kênh” ⇒ tab riêng liệt kê video mới, không cần tài khoản.
* Nếu cần đồng bộ subscription: nhận file OPML/`subscription_manager` xuất từ
  Google Takeout (người dùng tự xuất) — không cần OAuth.

### #10 — tải về: thư mục hay đồng bộ tab
Hiện `YtMediaStore` đã lưu file + hiện dung lượng (#2 đợt 5). Còn thiếu:
“gửi file đã tải vào Thư viện / Nghe” để dùng chung với các module khác, và
“dọn dung lượng” một chỗ. Đề xuất làm sau thành một màn “Kho media YouTube”
có: tổng dung lượng, xoá từng video, nút “gửi sang Nghe/Đọc”.

### #9 (phần “lồng tiếng 70/30”)
Hạ âm lượng video còn ~30% trong lúc TTS đọc: `yt_embed.html` chạy trong
WebView, âm thanh KHÔNG đi qua `just_audio` của app ⇒ không duck được bằng
AudioSession. Hai cách khả thi: (a) gọi JS `player.setVolume(0.3)` qua
Iframe API — cần sửa `web/yt_embed.html` (**không đụng trên nhánh này**, web
do nhánh khác phụ trách); (b) hiện tại đã có phương án “bật/tắt tiếng video
theo bên đọc” (#9) — thô hơn nhưng chạy được ngay. Chờ quyết định.

### #1 phần “nạp sẵn ref/caption khi chọn video trong Thư viện”
Việc đưa phụ đề của video vừa chọn vào tab **Tài liệu** cần chốt: người dùng
muốn (a) chỉ mở player như hiện nay, hay (b) tự động tải phụ đề và tạo một
“tài liệu” trong Thư viện đọc? (b) tốn dung lượng và dữ liệu mạng nên chưa
làm khi chưa chốt.
