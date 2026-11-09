# ADR-0022: Pháp thoại từ Drive — danh tính nội dung tách khỏi tiến độ nghe

- **Ngày:** 2026-11-03
- **Trạng thái:** Đang triển khai — P1 (`DHRM-001`) đã có code + test + i18n và
  **CI xanh** trên `arena/c61e07dd-in4up` (analyze 0 error, `test/dharma/` xanh,
  commit `7e3be6b`); còn nghiệm thu thiết bị. P2–P5 còn proposed.
- **Phạm vi:** Nguồn nội dung "pháp thoại/sách nói/kinh tụng" từ Google Drive và
  cách lưu vị trí nghe. Không đổi schema các box Hive cũ, không đụng
  `lib/ffi/`/`UltraTimeStretch`, không đổi `PlaybackQueueController`.

## Bối cảnh

Chủ dự án đưa vào một thư mục Drive công khai gồm **pháp thoại tiếng Việt hệ Pa
Auk** (7 collection: kinh tụng, sách nói, bài giảng đã giảng xong, đang giảng,
ebook, biểu đồ, tài liệu quán bất tịnh) và một bản nháp đặc tả `DharmaTalk` do
một công cụ khác sinh ra.

Bản nháp đặt `driveFileId` làm khoá và để `lastPosition`/`isCompleted` **bên
trong** model nội dung. Trong repo hiện tại, ba sự kiện đã được ghi nhận khiến
cách đó không an toàn:

1. `PlayerProvider.saveCurrentPosition()` ghi tiến độ **theo đường dẫn** đang
   phát (`player_stats_mixin.dart:61` → `StorageService.savePosition(path, ms)`).
2. Luồng Drive hiện tại tải file vào `getTemporaryDirectory()/drive_cache/`
   (`google_drive_service.dart:326`) — thư mục hệ điều hành **được phép dọn**.
   Đây đúng là lớp lỗi đã phải sửa một lần cho `file_picker`
   (`AudioImportService`, SHADOW-FILE-001).
3. ADR-0019 §3 đã phải xử lý cùng vấn đề cho `content://`: không được tự gán dữ
   liệu cũ chỉ vì trùng tên/nội dung.

Ngoài ra, tên thật trên Drive cho thấy metadata **không** đọc được từ một chỗ:
vị Thầy nằm ở tên thư mục series, chủ đề ở tên file, năm/khoá thiền ở tên
series; cùng một vị Thầy có nhiều cách viết (`Revata`/`Reveta`,
`Kumārābhivaṃsa`/`Kumurabhivamsa`, `SU Kovida`/`Ngài U Kovida`).

## Quyết định

1. **Khoá danh tính là nội dung, không phải đường dẫn.** `episodeKey` =
   `drive:<fileId>` khi file còn trên Drive, và vẫn giữ nguyên khi nội dung được
   tải về máy (`libraryId` là trường phụ). Tiến độ, LRC, lời vàng đều trỏ
   `episodeKey`. Đổi nguồn phát (stream ⇄ file đã tải) không làm mất vị trí.
2. **Tách store tiến độ khỏi catalog.** `dharma_catalog` (metadata, ghi đè được
   khi đồng bộ Drive) và `dharma_progress` (chỉ app ghi). Đồng bộ Drive **không
   bao giờ** chạm tiến độ. `isCompleted` là **suy ra** (thủ công hoặc ≥95%/ngưỡng
   cuối), không phải trường được sync.
3. **Metadata do bộ phân tích thuần quyết định, không do LLM.**
   `DharmaNameParser` nhận tên thư mục + tên file, trả metadata có mức tin cậy;
   luôn giữ `rawName`; người dùng sửa được và bản sửa tay thắng alias máy. Thứ
   tự hiển thị dùng natural sort (Drive trả `B10, B11, B2…`).
4. **Thứ tự nguồn phát: đã-tải → tải-bền-vững → stream.** Nội dung nghe dài
   không lưu ở thư mục tạm. Stream chỉ là để nghe thử/nhẹ; nếu stream phải dùng
   token trong query string thì **không** làm, chuyển sang "tải rồi phát".
5. **Dùng lại tầng phát hiện có.** Pháp thoại chỉ tạo `AudioQueueItem` và đi qua
   `_loadQueueTrack`; không thêm trình phát thứ hai. Nhờ đó giữ nguyên các bất
   biến của ADR-0019: lưu vị trí **trước** khi đổi nguồn, generation vô hiệu hoá
   lần nạp cũ, bài lỗi giữ placeholder.
6. **"Lời vàng" dùng dữ liệu đã có.** `SoundMark(kind: quote)` + `MemoryItem`
   (đã có `audioPath/audioStart/audioEnd`) ở sóng P4; khi `lib/knowledge/` được
   nối vào app (INTEGRATE-1) thì ánh xạ sang `KnowledgeUnit` +
   `EvidenceLocator(timestampStart)` — trường đã tồn tại nên không tạo nợ schema.
7. **Không mở rộng phạm vi.** Ebook/PDF của Drive thuộc tab Đọc; STT cho cả file
   dài là hành động có chủ đích (pin/nhiệt), không tự động.

## Hệ quả

- Tích cực: tiến độ sống sót qua dọn cache, đổi nguồn, xoá file tải; đồng bộ
  Drive trở nên vô hại với dữ liệu người dùng; parser có test trên tên thật nên
  lọc theo vị Thầy/khoá thiền đáng tin; không hồi quy queue/karaoke.
- Tiêu cực / đánh đổi: thêm 2–3 box Hive và một lớp ánh xạ
  `episodeKey ⇄ path` (mỗi lần phát phải tra tiến độ theo `episodeKey` thay vì
  đọc thẳng `saved_positions`); đường dẫn cũ **không** được migrate tự động
  (người dùng có thể thấy bài cũ "chưa có tiến độ" một lần).
- Trung tính: dung lượng tải về là trách nhiệm của người dùng — UI phải hiện
  dung lượng trước khi tải và có màn xoá theo series.

## Phương án đã cân nhắc và loại

| Phương án | Loại vì |
|---|---|
| Dùng `driveFileId` làm khoá duy nhất (như bản nháp) | Mất khả năng nghe nội dung đã tải khi Drive bị ngắt/không có mạng; trộn danh tính nguồn với danh tính nội dung |
| Lưu `lastPosition`/`isCompleted` trong `DharmaTalk` | Mỗi lần sync ghi đè metadata sẽ xoá trạng thái người dùng trừ khi mọi lần sync đều merge |
| Giữ tiến độ theo path cache Drive như hiện tại | Cache bị dọn ⇒ mất vị trí (đã xảy ra với `file_picker`) |
| Coi mỗi file Drive là 1 queue riêng (hiện tại) | Không có "bài kế" trong series; người dùng phải mở lại từ đầu mỗi buổi |
| Dùng `lib/knowledge/` (MVA) làm nơi lưu ngay từ P1 | Module chưa nối vào app (chỉ 1 import nội bộ), INTEGRATE-1 chưa xong ⇒ ràng buộc sai thứ tự |
| Đoán chủ đề/tóm tắt bằng LLM | Sai và không kiểm chứng được; nội dung tôn giáo nhạy cảm, cần người xác nhận |

## Ghi nhận khi thi công P1 (2026-11-03)

Quyết định trên giữ nguyên sau khi va code thật; ba điểm cần ghi lại:

1. **`episodeKey` phải tính từ ĐỊA CHỈ PHÁT ổn định**, không từ index hay tên
   file: `local:<md5(path chuẩn hoá)>`. Cùng tên file ở hai series khác nhau ra
   hai khoá khác nhau — có test khoá lại (nếu không, hai buổi trùng tên sẽ dùng
   chung tiến độ).
2. **`DharmaProgress.isFinished` cần ngưỡng riêng cho bài ngắn** (≤60 s ⇒ 20%
   thay vì 30 giây), nếu không bài kinh tụng 40 giây bị đánh "xong" ngay khi
   mới nghe 10 giây.
3. **Sửa tay phải thắng parser nhưng không phá danh tính**: override tên vị Thầy
   đổi `speakerDisplay`/`speakerKey` (nhóm hiển thị) mà **không** đổi
   `seriesKey`/`episodeKey` — tiến độ đã có vẫn còn.
## Việc tiếp theo

`PLAN-042` §11: P1a (model + parser + test từ fixture thật) → P1b (danh mục trên
audio đã import) → P2/P3 (Drive: import bền vững, stream bằng header) → P4 (lời
vàng) → P5 (STT theo đoạn). Mọi chuỗi chrome mới theo rule #5 (AGENTS.md).
