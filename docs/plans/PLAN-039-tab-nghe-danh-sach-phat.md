# PLAN-039 — Tab Nghe: phát nhiều bài và chuyển bài

- **Trạng thái:** doing — owner đã duyệt mặc định, code/test đang viết; chưa qua CI hay nghiệm thu thiết bị. Nội dung khảo sát dưới đây ghi nhận thời điểm trước khi triển khai.
- **Nguồn:** yêu cầu của chủ dự án, 2026-10-27.
- **Nền khảo sát:** `arena/01a0251e-in4up` tại `0556f82` (đã fetch và rebase ngày 2026-10-27).
- **Phạm vi đề xuất:** audio trên thiết bị và các playlist thư viện đang có. Giữ nguyên luồng nghe một bài; không mở rộng sang hàng đợi YouTube/Drive, media session hệ điều hành hay phát nền mới trong bản đầu.

## 1. Khảo sát hiện trạng

| Nơi | Đã có | Còn thiếu đối với yêu cầu |
|---|---|---|
| [`audio_library_drawer.dart`](../../lib/screens/listen_mode/widgets/audio_library_drawer.dart) | Chọn nhiều file, nhập file tạm vào nơi lưu bền, hiện danh sách và phát được từng bài. | Danh sách `_playlist` nằm trong state của drawer; đóng/hủy widget có thể mất danh sách. Không có hàng đợi dùng chung hoặc tự phát bài kế. |
| [`AudioPlaylist`](../../lib/models/audio_playlist.dart), [`AudioLibraryProvider`](../../lib/providers/audio_library_provider.dart) | Playlist có tên được lưu Hive bằng `libraryId`, thêm/xóa/sắp xếp; bộ lọc yêu thích, gần đây, chưa nghe. | `playlistTracks()` bỏ qua ID không còn trong chỉ mục; chạm một dòng ở [`PlaylistDetailScreen`](../../lib/screens/listen_mode/widgets/audio_playlists_sheet.dart) chỉ gọi phát **một** bài. Playlist lưu trữ chưa phải hàng đợi đang phát. |
| [`AudioLibraryView`](../../lib/screens/listen_mode/widgets/audio_library_view.dart) | Danh sách lọc theo album, tác giả, thư mục và tìm kiếm. | Chạm bài chỉ mở bài đó; chưa truyền thứ tự danh sách đang thấy cho player. |
| [`PlayerProvider`](../../lib/providers/player_provider.dart), [`AudioPlayerService`](../../lib/audio/audio_player_service.dart) | Một player `just_audio`, nhận sự kiện kết thúc, lặp bài, A–B, vị trí nghe và LRC/STT. | Chưa có trạng thái bài trước/bài sau của một hàng đợi. `playNextSegment()`/`playPreviousSegment()` là chuyển **đoạn học**, không phải chuyển bài. |
| [`listen_mode_screen.dart`](../../lib/screens/listen_mode/listen_mode_screen.dart) | Hàng điều khiển thực tế có lùi 10 giây, phát/tạm dừng, tiến 10 giây. | Chưa có hai nút chuyển bài. [`PlayerControls`](../../lib/widgets/player_controls.dart) có icon skip cũ nhưng không được gọi từ màn này; skip trước chỉ về đầu file, skip sau chưa làm gì. |
| [`MiniPlayer`](../../lib/screens/listen_mode/widgets/mini_player.dart) | Bộ điều khiển nhỏ ở shell có ±10 giây và phát/tạm dừng. | Chưa điều khiển bài trước/bài sau; kích thước cố định cần kiểm tra khi bổ sung nút. |

**Những điểm kỹ thuật cần xử lý trước khi nối hàng đợi:**

1. `AudioPlayerService.play()` hiện `await _audioPlayer.play()` rồi tự ghi trạng thái `playing`. Theo hợp đồng `just_audio`, future của `play()` có thể chờ đến khi việc phát kết thúc; vì thế `loadSong(autoPlay: true)` và công việc phía sau nó có thể chờ quá lâu, đồng thời cập nhật trạng thái muộn. Không được coi future này là tín hiệu “đã bắt đầu phát”.
2. `loadSong()` đổi `currentSongPath` trước khi kiểm tra/nạp xong file; lưu vị trí cũ chỉ có theo timer hoặc pause, không được gọi ngay trước mọi lần chuyển bài. Cần tránh sai tên/bài đang phát khi nạp thất bại và lưu vị trí **trước** khi đổi nguồn.
3. Nguồn `content://` hiện được copy sang cache. Android đặt tên cache theo tên hiển thị (`in4up_$name`), nên hai nguồn khác nhau cùng tên có thể đè/chung đường dẫn. Các dữ liệu Âm mục, LRC và vị trí đang gắn với path: đổi quy tắc đường dẫn mà không có tương thích sẽ làm khó mở lại dữ liệu cũ.
4. Chọn nhiều file trong drawer hiện không đồng nghĩa đã đăng ký các file đó thành `AudioLibraryEntry`; playlist có tên lại chỉ lưu `libraryId`. Không giả định hai loại danh sách đã là một hoặc âm thầm ghi playlist mới khi chọn file.
5. Có nhiều điểm khác cũng gọi `loadSong()` (Gần đây, Âm mục, YouTube đã tải, Drive, Hiểu, Web Reader). Nếu chỉ nối nút vào drawer, bài đang phát và chỉ số hàng đợi có thể lệch nhau.

## 2. Trải nghiệm đề xuất

### 2.1 Điểm vào

1. **Chọn nhiều file:** giữ thao tác hiện có. Sau khi import thành công, tạo hàng đợi theo thứ tự file picker trả về, phát bài đầu; nếu một số file lỗi, báo số file lỗi và chỉ đưa file đã import vào hàng đợi. Không hứa thứ tự tên file do mỗi hệ điều hành có thể trả khác nhau.
2. **Playlist có tên:** thêm **Phát tất cả**; chạm bài bất kỳ bắt đầu tại bài đó trong bản chụp thứ tự của playlist. Playlist rỗng thì nút vô hiệu và có hướng dẫn thêm bài.
3. **Thư viện đang lọc/tìm:** chạm một bài tạo hàng đợi từ kết quả đang hiển thị, đúng thứ tự lúc chạm, bắt đầu từ bài được chọn. Thay bộ lọc sau đó không âm thầm thay đổi hàng đợi đang nghe.
4. **Chọn file đơn hoặc mở bài từ Gần đây/Âm mục/các luồng khác:** nguồn mới ngoài hàng đợi thay hàng đợi bằng bài đơn, để hai nút không chuyển về một danh sách cũ ngoài ý muốn. Đi tới đoạn/dấu của **cùng nguồn** không phá hàng đợi.

Hàng đợi sống tại tầng player, tồn tại khi đóng drawer hoặc chuyển tab. Playlist có tên vẫn lưu như hiện tại. **Bản đầu không hứa khôi phục hàng đợi tạm sau khi hệ điều hành đóng tiến trình**; khôi phục sau restart là bước mở rộng riêng. Không tự phát lại khi mở app.

### 2.2 Thanh điều khiển

```text
  Đang phát: Pháp thoại 02                 Danh sách  2/8
  03:12 ━━━━━━━━━●━━━━━━━━━━━━━━━━━━━━━━  45:30

       ⏮         ↶10       ▶ / ❚❚       10↷         ⏭
   Bài trước   Lùi 10s    Phát/dừng    Tiến 10s     Bài sau

  Các điều khiển tốc độ, lặp và A–B hiện có giữ nguyên.
```

- Nút **bài trước/bài sau** đặt cạnh các nút ±10 giây ở `_SeekAndPlayRow` thật, dùng biểu tượng khác hẳn để không nhầm chuyển bài với tua thời gian.
- Một nút **Danh sách** mở sheet “Đang phát”, tô bài hiện tại, hiển thị `2/8`, cho chạm bài để chuyển; lỗi của bài phải nhìn thấy được. Bản đầu có thể chỉ đọc/chọn bài; chỉnh thứ tự playlist có tên tiếp tục dùng màn kéo-thả hiện có.
- Bộ phát thu nhỏ dùng cùng trạng thái hàng đợi. Khi đủ rộng có hai nút chuyển bài; ở màn hẹp ưu tiên không tràn hoặc che tiêu đề, vẫn có đường mở danh sách/điều khiển đầy đủ và giữ khả năng tua ±10 giây.
- Nút disabled có tương phản phân biệt, tooltip và semantic label; vùng chạm mục tiêu 48×48 dp khi bố cục cho phép. Kiểm tra màn hẹp, chữ lớn, xoay ngang, rèm LRC và panel A–B để không tái phát overflow.

### 2.3 Quy tắc hoạt động mặc định — đề xuất để chủ dự án chốt

| Tình huống | Hành vi đề xuất |
|---|---|
| Hết bài tự nhiên, còn bài kế | Tự chuyển **một lần** sang bài kế và phát từ đầu. |
| Hết bài cuối / danh sách chỉ một bài | Dừng ở trạng thái kết thúc; không tự quay về đầu danh sách. Nút bài sau vô hiệu. |
| Bấm bài trước / bài sau | Chuyển đúng một bài liền kề và bắt đầu bài đó từ đầu. Đầu danh sách: bài trước vô hiệu; cuối danh sách: bài sau vô hiệu. Không dùng “bài trước” để tua đầu bài hiện tại. |
| Bấm chuyển bài khi đang tạm dừng | Nạp bài đích nhưng vẫn tạm dừng; đang phát thì tiếp tục phát. |
| Chạm trực tiếp một bài trong thư viện/playlist | Mở từ bài đó; giữ quy tắc tiếp tục vị trí đã lưu như cách mở bài hiện nay, trừ khi người dùng chọn phát từ đầu. Tự chuyển và hai nút chuyển bài không tự nhảy tới vị trí cũ. |
| Mở bài mới ngoài hàng đợi | Thay bằng hàng đợi một bài; thao tác đi đến dấu/đoạn cùng bài không thay danh sách. |
| Lặp bài / A–B / lặp đoạn | Các chế độ học có ưu tiên khi đang hoạt động. Lặp bài hữu hạn chỉ chuyển kế sau lần lặp cuối; A–B và tự chuyển đoạn tiếp tục vận hành như cũ. Bấm chuyển bài thủ công kết thúc vòng lặp của bài cũ. |
| File kế bị mất, lỗi giải mã hoặc mất quyền | Đánh dấu lỗi rõ ràng, thử các bài kế còn lại tối đa một lượt, rồi dừng nếu không có bài phát được; không xóa file hoặc playlist. Khi chọn thủ công bài lỗi, báo lỗi và cho thử lại/chọn bài khác. |
| Hẹn giờ ngủ / nhấn dừng khi đang chuyển | Lệnh mới nhất thắng; không được tự phát lại do kết quả tải hay sự kiện kết thúc cũ về muộn. |

Các lựa chọn trên được đề xuất khi khảo sát; owner đã duyệt để triển khai, bao gồm quy tắc tiếp tục vị trí và giữ trạng thái tạm dừng khi chuyển bài. Việc kiểm chứng đang theo dõi trong [hồ sơ review](../project/PLAN-039-review.md).

## 3. Phương án kỹ thuật

### 3.1 Một nguồn sự thật cho hàng đợi

- Bổ sung một controller/model hàng đợi test độc lập, do `PlayerProvider` sở hữu hoặc điều phối ở cùng vòng đời; không để danh sách phát thật trong widget. Mỗi item giữ định danh nguồn ổn định, tên, `libraryId` nếu có, URI/path gốc; tách khỏi đường dẫn cache tạm để phát. Nếu có item lặp trong hàng đợi, dùng ID của **lần xuất hiện**, không chỉ dùng `libraryId` làm chỉ số.
- Tách **playlist lưu bền** (`AudioPlaylist.trackIds`) khỏi **queue của phiên phát** (bản chụp có thứ tự + item hiện tại). Sửa playlist có tên không âm thầm sửa queue đang chạy; tạo lại queue khi bấm Phát tất cả lần sau. Với playlist chứa ID bị thiếu, giữ ID trong dữ liệu gốc và thể hiện mục không khả dụng thay vì xóa hoặc trộn sai thứ tự.
- API ở tầng player theo ý định, ví dụ `startQueue(items, startIndex)`, `playQueueItem(index)`, `nextTrack()`, `previousTrack()`, cùng `canGoNext/canGoPrevious`. Tên cuối cùng tùy thiết kế khi code. Xác định rõ hành vi `stop` (giữ queue) và `clearCurrentSong` (dừng, xóa queue phiên, vô hiệu các tác vụ cũ).
- Thống nhất mọi điểm vào phát qua một gateway chung: yêu cầu phát danh sách tạo queue; lời gọi `loadSong` cũ với nguồn khác phải tách khỏi queue cũ, còn thao tác trên cùng nguồn phải giữ queue. Kiểm thử các luồng Âm mục, Gần đây, YouTube đã tải, Hiểu và Web Reader; không lưu URL/token tạm của Drive vào queue lưu bền.
- Tiếp tục sử dụng player/service đang có và nạp từng bài qua luồng có kiểm soát thay vì giao ngay playlist native cho `just_audio`: chuyển index native trực tiếp có thể bỏ qua các bước reset LRC, ghi Recent, lặp và lưu vị trí của `loadSong`. Chấp nhận có khoảng chờ tải giữa bài; **không cam kết gapless**.

### 3.2 Chuyển bài an toàn

1. Chụp queue và item đích; lưu vị trí bài cũ **trước** khi đổi `currentSongPath`. Chọn rõ `resume` cho mở trực tiếp và `startAtZero` cho chuyển bài, không xóa lịch sử vị trí chỉ để phát từ đầu.
2. Đánh dấu đang tải, vô hiệu kết quả bất đồng bộ của lượt cũ; resolve nguồn đích theo loại nguồn, chỉ nạp bài cần phát, không copy toàn bộ MediaStore vào RAM/cache. Nếu resolve `content://` thất bại, báo lỗi thay vì coi URI chưa resolve là file cục bộ đã sẵn sàng.
3. Tích hợp `resetLrcStateForAudioChange()` và guard định danh đã có; LRC/STT, waveform, dấu/đoạn, duration và tên phải thuộc đúng bài. Không phá các key/path dữ liệu cũ. Chỉ commit item/index là đang phát sau khi tải thành công; nếu nạp thất bại, giữ trạng thái lỗi nhất quán, không hiển thị metadata mới trong khi âm thanh cũ vẫn chạy.
4. Chỉ cập nhật `lastPlayed`/Recent khi nạp thành công, tránh tạo mục recent đôi giữa URI gốc và path cache. Kiểm tra cả `loadSong` lẫn các helper UI hiện đang ghi Recent; bảo toàn khả năng đọc các mục đã lưu.
5. Đổi hợp đồng “bắt đầu phát” để không chờ future phát đến hết bài; trạng thái do stream player xác nhận, lỗi future vẫn được thu nhận, không tự ghi `playing` muộn sau pause/completed. Mỗi lần chuyển có generation/guard và một luồng điều phối; sự kiện cũ hoặc tác vụ bị hủy không được commit/đổi index/phát lại. Phải kiểm thử cả sự kiện `completed` lặp và thao tác liên tiếp trong lúc resolve/load.
6. Điều phối `completed` cùng `repeatTrack`, A–B, tự chuyển đoạn và sleep timer. Đặc biệt `handleRepeatTrack()` có thời gian chờ bất đồng bộ và trường hợp đủ số lần lặp trả về mà không có một sự kiện completed mới: cần chốt chuyển bài sau vòng lặp cuối, đồng thời chặn callback của bài cũ sau khi người dùng chuyển hoặc dừng.

### 3.3 Nguồn và dữ liệu cũ

- File picker tạm: tái dùng `AudioImportService.ensurePersistent()` và dedup hiện có; import theo luồng, có trạng thái tiến trình/lỗi, không đọc toàn file vào RAM. Không xóa file gốc hoặc bản import khi xóa queue.
- MediaStore `content://`: resolve khi đến lượt, xử lý quyền bị thu hồi. Cần sửa/thiết kế đường dẫn cache phân biệt **nguồn**, không chỉ tên hiển thị; xử lý I/O file lớn để không làm nghẽn UI. Trước khi đổi path dùng làm key, thiết kế ánh xạ tương thích cho LRC, Âm mục, Recent và vị trí cũ; chỉ tự liên kết khi chứng minh được đúng nguồn. Nếu bản ghi cũ mơ hồ do trùng tên, giữ dữ liệu và báo để người dùng quyết định, không đoán hoặc ghi đè.
- File đã chọn nhiều lần, file trùng tên ở hai thư mục, tên Unicode, đường dẫn Windows và `content://` đều phải được thử riêng. Không bổ sung package âm thanh mới nếu nền hiện tại đáp ứng.
- Đăng ký file import thành `AudioLibraryEntry` để lưu **queue tạm** thành playlist có tên là việc riêng: cần thiết kế `libraryId` bền + dedup + migration, không coi như đã có. Bản đầu vẫn phát được danh sách file đã chọn mà không phụ thuộc việc đó.

## 4. Các bước thực hiện khi được duyệt

| Bước | Việc | Đầu ra/điều kiện qua bước |
|---|---|---|
| 0 | Chốt hành vi ở §2.3, rà soát tất cả caller `loadSong`, spike cache/identity. Lập ADR mới cho thay đổi kiến trúc theo `AGENTS.md`. | Không làm mất reopen/LRC cũ; quyết định chuyển nguồn và cách tương thích được review. |
| 1 | Queue/controller thuần + seam fake player; sửa hợp đồng start/completion, lưu vị trí, xử lý lặp và hủy theo generation. | Unit test chuyển bài và race xanh trước khi gắn UI. |
| 2 | Nối chọn nhiều file, playlist có tên và kết quả thư viện; nối các điểm mở bài đơn vào gateway; thêm hàng nút và sheet danh sách. | Đóng drawer/chuyển tab vẫn nghe đúng queue; UI không tràn; các luồng mở cũ không lệch queue. |
| 3 | i18n, test hồi quy/CI, nghiệm thu thiết bị thật. | Đạt ma trận §5; không tuyên bố hỗ trợ nền/tai nghe ngoài những gì đã kiểm thử. |
| Sau bản đầu | Tùy chủ dự án: khôi phục queue sau restart, chỉnh queue độc lập, lưu queue thành playlist, shuffle/lặp cả danh sách, media controls/phát nền chính thức. | Scope/ADR và QA riêng; không trộn vào MVP khi chưa duyệt. |

## 5. Kiểm thử và nghiệm thu dự kiến

- **Unit (fake engine):** queue rỗng/1/n bài, đầu/cuối, bấm trước/sau khi đang phát và đang pause; chọn bài giữa danh sách; kết quả lọc/playlist là snapshot; nguồn khác thay queue; stop/clear; không ghi `lastPlayed` khi load lỗi.
- **Completion/race:** sự kiện completed lặp; lặp bài vô hạn/hữu hạn; A–B và lặp đoạn; thao tác chuyển liên tiếp; dừng/hẹn giờ ngủ trong khi đang load; kết quả cũ trả sau bài mới; future `play()` chưa hoàn tất nhưng `loadSong` vẫn trả điều khiển kịp thời.
- **Dữ liệu:** lưu vị trí trước chuyển, mở lại theo đúng chính sách; file mất/permission denied/lỗi decode, danh sách toàn file lỗi dừng hữu hạn; hai `content://` trùng tên; LRC/STT callback cũ không dính vào bài mới; marks/đoạn/recent/vị trí cũ còn mở đúng; không xóa dữ liệu người dùng.
- **Widget/i18n:** icon chuyển bài/tua 10 giây có nhãn truy cập khác nhau; disabled ở biên; queue sheet hiển thị đúng bài và lỗi; điện thoại hẹp, chữ lớn, tablet/xoay ngang, LRC/A–B mở. Chuỗi chrome mới có fallback English và đủ `vi`, `en`, `hi`, `zh`, `zh_TW`, `si` theo `AGENTS.md`; nội dung/ngôn ngữ tên file của người dùng không bị dịch.
- **Thiết bị:** Android với MediaStore và picker nhiều file (kể cả thu hồi quyền/cache bị dọn), tai nghe, chuyển tab, màn hình khóa nếu hành vi sẵn có hỗ trợ; kiểm tra picker và đường dẫn trên Windows/iOS theo nền tảng thực sự hỗ trợ. Không coi test giả lập là bằng chứng cho phát nền sau khi tiến trình bị hệ điều hành kết thúc.
- **CI sau khi code:** `flutter analyze` cho phạm vi đổi; thêm test queue/widget mới vào bước CI thực thi thật, chạy cùng `test/audio_playlist_test.dart`, `test/audio_library_filters_test.dart`, `test/audio_import_service_test.dart`, `test/listen_lifecycle_guards_test.dart` và test i18n liên quan. Sandbox khảo sát này không có Flutter/Dart SDK; kế hoạch chưa được chạy test hay nghiệm thu máy.
