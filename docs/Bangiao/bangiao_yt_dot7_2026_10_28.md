# Bàn giao — YouTube đợt 7 (2026-10-28)

Nhánh `arena/548feb35-in4up`, base `arena/01a0251e-in4up` (đã gồm đợt 6).
Bốn quyết định của owner trong tin nhắn 2026-10-28, và code tương ứng.

---

## 1. "Kênh của tôi" — KHÔNG đăng nhập YouTube  ⇒ `YT-MY-CHANNELS-001`

**Vì sao không đăng nhập:** không có API nào cho app bên thứ ba đọc danh sách
kênh/video của một tài khoản mà không qua OAuth + phê duyệt của Google; nhúng
WebView đăng nhập thì Google chặn ("insecure browser") và vi phạm ToS của
YouTube. Cách dán tay không bao giờ hỏng vì Google đổi chính sách.

**Đã làm**

| File | Việc |
|---|---|
| `models/yt_channel.dart` | `YtChannel`, `parseYtChannelInput()`, `ytChannelIdFromHtml()`, `ytChannelTitleFromHtml()`, `parseYtOpml()` — **hàm thuần**, test được |
| `services/yt_channel_store.dart` | lưu danh sách kênh bằng `shared_preferences`, chống trùng theo ID |
| `services/yt_channel_resolver.dart` | `@handle` / `/c/` / `/user/` / `UC…` → `UC…` + tên kênh (không cần API key) |
| `widgets/yt_my_channels_sheet.dart` | màn "Kênh của tôi": thêm kênh, **import OPML (Takeout)**, bỏ theo dõi, mở danh sách video mới của kênh → mở player |
| `youtube_explorer_screen.dart` | icon "Kênh của tôi" cạnh Lịch sử |

**Chi tiết "thông minh"**
* Dán **link video** vào ô kênh ⇒ báo "đây là link video, không phải kênh",
  không thêm kênh rác.
* Phân giải handle ⇒ **lưu luôn `UC…`** nên lần sau mở không phụ thuộc việc
  đoán handle nữa.
* OPML: chỉ nhận entry có `channel_id=UC…`, giải mã `&amp;`, bỏ trùng.
* Tên kênh trống ⇒ hiện `@handle`, rồi mới tới ID (không hiện chuỗi rỗng).

---

## 2. Duck âm thanh 70/30 — **không làm trên nhánh này** (giải thích)

Âm thanh video YouTube nằm trong **WebView** (`yt_embed.html` + Iframe API),
chạy ở tiến trình/kênh audio riêng của hệ điều hành. `just_audio` (bộ phát của
app) **không** nắm được volume của nó ⇒ không thể "duck" (hạ còn 30%) bằng
`AudioSession` hay bất kỳ API Dart nào.

Ba cách, và lý do chọn cách 3:

1. **Sửa `web/yt_embed.html` gọi `player.setVolume(0.3)`** — đúng kỹ thuật,
   nhưng file đó thuộc phần **web** và nhánh này không được đụng (đã chốt).
2. **Chèn JS vào WebView hiện tại** — WebView đang tải trang wrapper trên
   GitHub Pages ở origin khác, nên `runJavaScript` vẫn chạy được; **nhưng**
   phải biết chắc `player` đã expose ra `window`, và mỗi lần YouTube đổi API
   là hỏng im lặng. Rủi ro cao so với lợi ích.
3. **Bật/tắt tiếng theo bên đọc** (đã làm ở đợt 6, `#9`): đọc câu gốc ⇒ mở
   tiếng video; đọc bản dịch ⇒ tắt tiếng. Người dùng vẫn nghe được cả hai,
   không bị chồng tiếng, và **không phụ thuộc code web**.

⇒ Khuyến nghị: dùng cách 3 (đã có). Nếu owner vẫn muốn 70/30 thật, cần một
phiếu riêng cho nhánh web (`yt_embed.html` + `main_web.dart`), làm cùng lúc
với việc rà Iframe API.

---

## 3. Kho media YouTube  ⇒ `YT-MEDIA-LIB-001`

`widgets/yt_media_library_sheet.dart` (đã có từ đợt 5) được nâng:

* **Dung lượng tách theo loại**: `Âm thanh: 123 MB · Phụ đề: 210 KB` — để biết
  xoá gì trước khi máy đầy (gần như luôn là âm thanh). Số đo **thật trên đĩa**.
* **Gửi sang tab Nghe** (nút tai nghe, chỉ bật khi có file âm thanh): nạp
  `PlayerProvider.loadSong` rồi `ShellNavigationRequest.openListen()`.
* Vẫn giữ: nạp vào tab Đọc, xuất/chia sẻ, xoá từng video, xoá hết, đổi nơi lưu.
* `ShellNavigationTarget` thêm `listen` (+ `openListen()`), `main_shell` xử lý
  bằng `_setListenMode(0)`.

---

## 4. Tab TẢI → "Tải & chuẩn bị"  ⇒ `YT-PREPARE-001`

Owner: *"Không nạp sẵn, mà do người dùng nhấn vô tab tải có lựa chọn tải về,
đồng bộ tab đọc, lưu luôn đám mây hay không. Nói chung bạn làm sao đó cho tinh
tế, thông minh."*

Tab **TẢI** giờ gồm:

1. **Thẻ trạng thái**: "Đã sẵn sàng học offline" / "Chưa đủ…" + ✓/○ cho *Phụ
   đề* và *Âm thanh* + dung lượng + link mở Thư viện đã tải.
2. **Bốn lựa chọn** (mặc định: phụ đề ✓, âm thanh ✓, đồng bộ ✗, đám mây ✗):
   * Tải phụ đề (.lrc)
   * Tải âm thanh
   * Đồng bộ sang tab Đọc
   * Lưu bản sao lên đám mây
3. **Một nút "Tải & chuẩn bị"** chạy đúng những gì được chọn.
4. **Báo cáo từng bước** ngay dưới nút: `Đã tải phụ đề`, `Âm thanh đã có sẵn —
   bỏ qua`, `Chưa đăng nhập — chưa lưu được lên đám mây`, …

"Tinh tế/thông minh" nằm ở bốn điểm, đều nằm trong `services/yt_prepare_plan.dart`
(hàm thuần, có test):

* **Không tải lại thứ đã có** — phụ đề/âm thanh đã nằm trong kho thì bỏ qua,
  chỉ ghi chú "đã có sẵn".
* **Không hứa suông** — lựa chọn không thực hiện được trả mã lý do
  (`sync_needs_captions`, `cloud_needs_captions`, `cloud_up_to_date`) để UI nói
  rõ, không im lặng.
* **Đúng thứ tự** — phụ đề → âm thanh → đồng bộ tab Đọc → đám mây (hai việc
  cuối cần nội dung phụ đề đã nằm trên máy).
* **Không đẩy bản trùng lên Firestore** — `YtCloudCopyService` so **vân tay
  SHA-1** nội dung phụ đề đã lưu (`shared_preferences`), nên bấm lại nhiều lần
  cũng chỉ có một bản.

Thêm: "Đồng bộ sang tab Đọc" nạp bằng `YtReadBridge(openShell: false)` —
**không tự nhảy tab**, vì người dùng có thể chỉ muốn chuẩn bị trước rồi xem
tiếp video này. Nút "Học trong tab Đọc" riêng mới chuyển tab.

Phụ đề lưu lên đám mây được **bỏ mốc thời gian** (`ytPlainTextFromLrc`): thư
viện đọc là văn bản, để `[01:23.45]` trong câu sẽ làm bẩn phân tích từ vựng.

---

## Test

`test/yt_channels_and_prepare_test.dart` (mới, đã thêm vào bước "YouTube audit
tests" của `app_analyze.yml`): 30 test logic thuần

* nhận diện `UC…` / `/channel/` / `@handle` / `/c/` / `/user/` / tên trơn /
  **link video ⇒ null** / domain lạ ⇒ null;
* đọc `channelId` + `og:title` từ HTML (kể cả trường hợp hỏng ⇒ null);
* đọc OPML: chỉ lấy YouTube, giải mã `&amp;`, chống trùng, file rỗng;
* `YtChannel` JSON khứ hồi, thiếu id ⇒ null, tên trống ⇒ handle rồi id;
* kế hoạch "Tải & chuẩn bị": thứ tự bước, bỏ qua việc đã xong, các mã lý do,
  `cloudUpToDate` không đẩy bản trùng;
* `ytPlainTextFromLrc`: bỏ mốc thời gian + metadata, nhiều mốc một dòng, dòng
  trắng.

## i18n

Thêm **55 chuỗi** mới vào `tool/legacy_ui_english_overrides.json` (3911 khoá)
và `lib/core/language/generated_legacy_ui_fallbacks.dart` (2223 khoá). Đã kiểm:
**0 giá trị English chứa ký tự tiếng Việt**, mọi chuỗi UI mới đều có bản tiếng
Anh ⇒ locale ≠ `vi` không rớt tiếng Việt (quy tắc vàng #5).
