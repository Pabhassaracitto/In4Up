# Bàn giao — Đợt 5: 4 lỗi nghiệm thu máy thật (2026-10-24)

Owner báo sau khi dùng máy thật (sau PR #100). Bốn triệu chứng, bốn nguyên nhân
gốc khác nhau — không phải bốn "tính năng thiếu" mà là bốn **lỗi im lặng**:
app vẫn chạy, nhưng người dùng không biết chuyện gì đang xảy ra.

| # | Triệu chứng owner báo | Nguyên nhân gốc | Sửa ở đâu |
|---|---|---|---|
| 1 | `Tải thất bại: Lỗi: RangeError (end): Invalid value: Not in inclusive range 0..70: 74` | `_sanitize()` cắt chuỗi theo `name.length` của tên **GỐC** trong khi `replaceAll` đã làm chuỗi NGẮN đi (74 → 71) ⇒ `substring(0, 74)` | `services/yt_downloader.dart` |
| 2 | Phụ đề tải xong "mất tích" trong `app_flutter/youtube_captions/`, không biết nạp lại; không biết chiếm bao nhiêu dung lượng | Không có kho chung, không có UI liệt kê/xoá/nạp; âm thanh nằm thư mục khác, đặt tên theo TỰA ĐỀ nên không ghép được cặp | `services/yt_media_store.dart` (mới), `services/yt_read_bridge.dart` (mới), `widgets/yt_media_library_sheet.dart` (mới) |
| 3 | "Chỉ dịch ra chữ" — muốn phát luôn âm thanh đã dịch, chọn online/offline, ưu tiên online khi WiFi / offline khi 4G, đọc lặp / xen kẽ / bên nhiều bên ít | `TtsPriority` không có chế độ theo loại mạng; chế độ YouTube chưa có bộ đọc nào | `features/tts/*` (`TtsPriority.auto`, `_effectivePriority()`), `services/yt_read_aloud_controller.dart`, `services/yt_read_aloud_sequence.dart`, `widgets/yt_read_aloud_sheet.dart` (mới) |
| 4 | Ô "Cần AI cho phần còn lại" bấm **không có phản hồi** | `lookupWord` trả cache TRƯỚC khi xét route, và cache cả kết quả thất bại/chỉ-từ-điển ⇒ bấm nút luôn ra đúng kết quả cũ trong vài ms ⇒ UI không đổi | `packages/in4up_ai/.../ai_service_facade.dart`, `widgets/yt_word_panel.dart` |

---

## 1. YT-DL-RANGE-001 — `RangeError` khi dựng tên file

```dart
// TRƯỚC (sai): cắt theo độ dài tên GỐC
name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .substring(0, name.length.clamp(0, 80));

// SAU (đúng): cắt trên chuỗi ĐÃ chuẩn hoá, có tự bảo vệ
final cleaned = ...;
if (cleaned.length <= 80) return cleaned;
return cleaned.substring(0, 80);
```

**Vì sao khó đoán:** lỗi ném ra ở bước *dựng tên file*, giữa luồng tải, nên
người dùng chỉ thấy `Tải thất bại` — trông y như lỗi mạng. Không liên quan gì
tới HTTP Range.

**Hệ quả kèm theo:** tên file âm thanh nay **không còn dùng tựa đề** (xem mục
2) ⇒ lớp lỗi này biến mất hẳn khỏi đường tải chính; `sanitizeFileName` vẫn
được giữ (đã chuyển thành `static`, có test) cho đường sidecar.

## 2. YT-MEDIA-STORE-001 — một kho, thấy được dung lượng, nạp lại được

**Trước:** hai nơi, hai quy tắc đặt tên, không có gì liên kết:

```
<app>/youtube_captions/yt_<videoId>.lrc
<app>/youtube_downloads/<tựa đề>.<ext>      ← theo TỰA ĐỀ
```

**Sau:** một kho, khoá là **video ID**:

```
<kho>/yt_<videoId>.lrc
<kho>/yt_<videoId>.<ext>
```

* `<kho>` = `app_flutter/youtube_media` (mặc định) **hoặc** `Download/In4Up`
  nếu người dùng chọn "thư mục công khai".
* Android 11+ có thể **từ chối ghi** dù manifest có quyền ⇒ `folder()` ghi thử
  `.write_probe`, thất bại thì lùi về bộ nhớ riêng và đặt
  `lastFallbackReason` để UI **báo thật**, không hứa suông.
* File của bản cũ được **di trú một lần** (không mất dữ liệu đã tải); file cũ
  đặt tên theo tựa đề vẫn hiện trong danh sách (khoá nhóm = phần stem).

**"Thư viện đã tải"** (`showYtMediaLibrarySheet`) — mở được từ 3 chỗ: thanh
tiêu đề player (dọc + ngang), tab VĂN BẢN, tab TẢI:

1. Tổng dung lượng + đường dẫn đầy đủ.
2. Chọn nơi lưu (2 chip).
3. Danh sách từng video: dung lượng, có phụ đề / có âm thanh.
4. Mỗi dòng: **nạp vào tab Đọc** · xuất/chia sẻ · xoá. Có "xoá hết" (hỏi lại).

**Nạp vào tab Đọc** (`YtReadBridge.openInRead`) đi đúng luồng sẵn có:
`TextProvider.loadTextFile` → `PlayerProvider.loadSong` →
`RecentFilesService.addOrUpdate` → `ShellNavigationRequest.openRead()`. Nhờ vậy
**phụ đề + âm thanh vào cùng lúc**, đồng bộ theo mốc thời gian, và lần sau mở
lại được từ "Gần đây".

## 3. YT-TTS-READ-001 — phát bản dịch thành tiếng

**`TtsPriority.auto`** — chế độ owner yêu cầu (ưu tiên online khi WiFi, offline
khi 4G, vẫn fallback):

| Loại mạng | Resolve thành | Đường lùi |
|---|---|---|
| WiFi / Ethernet / VPN | `onlineFirst` | online lỗi → offline |
| Mạng di động | `offlineFirst` | offline lỗi → online |
| Không có mạng | `offlineOnly` | chỉ offline (khỏi chờ timeout 15s/câu) |
| Không đọc được loại mạng | `offlineFirst` | vẫn giữ online ở cuối chuỗi |

Resolve **một lần cho mỗi câu** (cache 5 giây) tại `TtsService._effectivePriority()`
rồi mới dựng chuỗi engine — nếu quên resolve, `orderTtsCandidates` coi `auto`
như `offlineFirst` (nhánh an toàn). Chế độ `auto` cũng đã có trong Cài đặt TTS
(`TtsPriority.values` ⇒ chip "Tự động theo mạng").

**Bộ đọc** (`YtReadAloudController`) chạy **độc lập với video**: âm thanh YouTube
là iframe WebView, không lấy được PCM, nên không tái dùng `PlaybackController`
của tab Đọc. Nó đọc tuần tự từng dòng bằng TTS, `await waitForCompletion()`
giữa các dòng (không thì các dòng chồng lên nhau), nghỉ giữa hai lượt theo
thiết lập, và dừng ngay khi bấm dừng (kiểm tra epoch mỗi 100 ms).

**Cài đặt** (bảng "Đọc bản dịch thành tiếng", lưu vào `YtLearningSettings`):

| Nhóm | Giá trị |
|---|---|
| Đọc gì | chỉ gốc · **chỉ bản dịch** · xen kẽ gốc → dịch |
| Số lần lặp | bản gốc 0–5 · bản dịch 0–5 ⇒ **bên nhiều bên ít** (vd gốc 2 · dịch 1) |
| Khoảng nghỉ | 0 / 500 / 1500 / 3000 ms |
| Tốc độ | 0.5×–2.0× |
| Bắt đầu | từ dòng đang phát · hoặc từ đầu |

Thứ tự đọc được dựng bằng hàm **thuần** `buildYtReadAloudSequence()` để test
được (xem `test/yt_read_aloud_sequence_test.dart`) — đây là chỗ dễ sai nhất:

* dòng **không có bản dịch** ở chế độ "chỉ bản dịch" ⇒ đọc bản gốc, **không im
  lặng** (im lặng trông như tính năng bị treo);
* đặt 0 lần cả hai bên ⇒ không đọc gì (sheet có cảnh báo);
* `startIndex` ngoài phạm vi được kẹp, không ném lỗi.

## 4. AI-WORD-RETRY-001 — bấm "Cần AI cho phần còn lại" phải có phản hồi

Ba nguyên nhân, sửa cả ba:

1. **Cache trả trước khi xét route.** Cache `word_<lower>` được kiểm tra trước
   cả `_chatRoutePlan()` ⇒ kể cả đã cấu hình API vẫn trả kết quả offline cũ.
2. **Cache giữ cả kết quả thất bại và kết quả chỉ-từ-điển** ⇒ lần bấm sau trả
   đúng kết quả cũ trong vài ms ⇒ UI không đổi ⇒ "nút không có tác dụng".
   Nay **chỉ cache kết quả thành công**.
3. **Không có đường "lần này hỏi mạng đi".** Thêm `preferRemote` +
   `forceRefresh` cho thao tác người dùng chủ động; `preferRemote` **không vượt
   mặt** `offlineOnly` (người dùng đã chọn rõ ràng) và không thử khi chưa cấu
   hình provider.

UI nay **nói rõ** kết quả của một lần bấm (`_reportManualResult`) — ba trường
hợp, ba câu khác nhau:

| Tình huống | Câu báo |
|---|---|
| Có nội dung AI thật, nguồn `remote` | "Đã phân tích bằng AI online" |
| Có nội dung AI thật, nguồn local | "Đã phân tích bằng AI trên máy" |
| Chưa cấu hình provider online | "Chưa cấu hình nhà cung cấp AI online — vào Cài đặt AI để thêm" |
| Đang để "chỉ offline" | "Đang để *chỉ offline* nên không gọi mạng — bật Online trong cài đặt AI để dùng API" |
| Đã gọi API nhưng lỗi | "API không trả về kết quả — kiểm tra kết nối hoặc khoá API" |

Nguồn thật được facade ghi vào `lastWordSource` (`remote`, `local_model`,
`local_dict`, `remote_failed`, `error`), reset ở đầu **mỗi** lần tra.

---

## Checklist nghiệm thu máy thật (Đợt 5)

**#1 Tải âm thanh**
1. Tải một video có tựa đề **dài và có dấu `:` `/` `?`** ⇒ không còn
   `RangeError`; file nằm trong kho với tên `yt_<videoId>.<ext>`.

**#2 Kho + dung lượng**
2. Tải phụ đề ⇒ snackbar hiện **đường dẫn thật** ("Đã lưu phụ đề vào: …").
3. Mở **Thư viện đã tải** ⇒ thấy tổng dung lượng, đường dẫn, từng video.
4. Đổi nơi lưu sang "thư mục công khai" ⇒ nếu máy chặn, có câu báo **thật**
   ("Hệ thống không cho ghi ra thư mục công khai…") và vẫn lưu được trong app.
5. Tải cả phụ đề + âm thanh ⇒ bấm **nạp vào tab Đọc** ⇒ sang tab Đọc có **chữ
   và tiếng**, đồng bộ theo mốc thời gian; mở lại từ "Gần đây" vẫn được.
6. Xoá từng video / xoá hết ⇒ tổng dung lượng giảm đúng.

**#3 Đọc bản dịch**
7. Cài đặt TTS chọn **Tự động theo mạng**; bật WiFi ⇒ giọng online; tắt WiFi
   dùng 4G ⇒ giọng offline (xem log `🔊 [in4up-tts] auto → …`).
8. Bấm nút **đọc** ở player ⇒ đọc lần lượt gốc → dịch theo thiết lập; video tự
   dừng; bấm lần nữa ⇒ dừng ngay (không đọc hết câu đang dở + cả danh sách).
9. Đặt gốc 2 · dịch 1 ⇒ nghe rõ **bên nhiều bên ít**.
10. Đặt nghỉ 3000 ms ⇒ có khoảng lặng thật giữa hai lượt.
11. Video **chưa có bản dịch** ⇒ sheet khoá mục "chỉ bản dịch"/"xen kẽ" và nói
    rõ vì sao.
12. Thoát màn khi đang đọc ⇒ không có lỗi
    `A YtReadAloudController was used after being disposed`.

**#4 AI tab Giải thích**
13. Đã cấu hình API online ⇒ bấm "Cần AI cho phần còn lại" ⇒ có kết quả **và**
    snackbar "Đã phân tích bằng AI online".
14. Bấm lại lần nữa ⇒ vẫn là một lần thử mới (không trả cache cũ trong vài ms).
15. Chưa cấu hình API ⇒ bấm ⇒ snackbar nói rõ **chưa cấu hình**, không im lặng.
16. Đặt AI về "chỉ offline" ⇒ bấm ⇒ snackbar nói rõ **vì chế độ**, không đổ lỗi
    mạng.

**Chung**
17. Đổi locale Home sang **English** ⇒ mọi chuỗi mới hiện tiếng Anh (đã thêm
    fallback cho toàn bộ literal mới + template `{value0}`).

## Test tự động đi kèm

| File | Khoá điều gì |
|---|---|
| `test/yt_download_filename_test.dart` | tên 74 ký tự có 3 ký tự bị loại (đúng ca owner báo) không còn ném `RangeError`; cắt 80; chuỗi rỗng |
| `test/yt_media_store_test.dart` | `fileBaseFor` (kể cả ID rỗng ⇒ `yt_clip`); `YtLearningSettings` mặc định, khứ hồi JSON, **dữ liệu cũ thiếu khoá**, giá trị rác, kẹp 0..5 / 0.5..2.0 |
| `test/yt_read_aloud_sequence_test.dart` | 12 ca: xen kẽ, bên nhiều bên ít, chỉ gốc, chỉ dịch, dòng thiếu bản dịch, 0/0, dòng rỗng, `startIndex` âm / vượt phạm vi |

Cả ba đã được thêm vào bước `YouTube audit tests` của
`.github/workflows/app_analyze.yml` nên chạy trong CI.

## Ghi chú kỹ thuật để lần sau không vấp lại

* `.clamp()` trả `num` ⇒ phải `.toInt()` / `.toDouble()` trước khi gán vào
  field `int`/`double` (đã sửa ở `copyWith`).
* `TextStyle(color: color.shade100)` **không** biên dịch được khi `color` là
  `Color` — chỉ `MaterialColor` mới có `shade*`.
* `notifyListeners()` sau `dispose()` sẽ ném lỗi ⇒ controller có cờ `_disposed`
  và `_notify()`.
* Chuỗi có nội suy (`'${n} dòng'`) **vẫn dịch được** qua `uiText` nhờ template
  `{value0}` — **đừng** đổi thành literal `'{value0} dòng'` (sẽ mất số liệu thật).
  Nhưng `Text('…')` (shim) dùng `translateExact` **không** áp template ⇒ chuỗi
  động phải đi qua `context.uiText(...)` tại chỗ.
* `uri.pathSegments` đã percent-encode ⇒ lấy tên file bằng
  `path.split(Platform.pathSeparator).last`.
