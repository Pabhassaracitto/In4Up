# Tipiṭaka → Worklist → Học thuộc lòng

## Mục tiêu

Biến một đoạn đang đọc trong Tipiṭaka thành một đơn vị học có thể quay lại
nguồn bất kỳ lúc nào:

```text
Reader (Pāli + bản dịch + ngữ cảnh)
  ├─ lưu từ
  ├─ lưu cụm từ
  ├─ lưu cả đoạn / câu
  └─ mở lại nguồn
       ├─ Tipiṭaka book + segment + offset
       ├─ Read tab
       └─ Learn by heart / FSRS
```

Thiết kế này kế thừa worklist hiện có (`WordEntry`, `VocabularyProvider`) và
học thuộc lòng hiện có (`LearnByHeartItem`, `LearnByHeartProvider`) thay vì tạo
một hệ thống từ vựng thứ ba.

## Nguyên tắc dữ liệu

### 1. Không sao chép mất nguồn

Worklist lưu một `SourceAnchor`, không chỉ lưu text:

```text
sourceType       = tipitaka
sourceDatabaseId = installed DB fingerprint/schema version
bookId           = tipitaka_books.id
bookCode         = VIN01M_MUL / ABH01A_ATT
segmentId        = tipitaka_segments.id
reference        = DN 1.1 / nguồn gốc trong DB
paragraphNo      = số đoạn
startOffset      = vị trí bắt đầu trong pali_text
endOffset        = vị trí kết thúc
selectedText     = bản chụp để hiển thị khi DB được cập nhật
```

`segmentId` + `bookId` là khóa mở lại chính. `selectedText` chỉ là fallback và
để bảo toàn đúng cụm mà người dùng đã chọn.

### 2. Lưu ngữ cảnh quanh lựa chọn

Mỗi mục lưu thêm:

- Pāli đầy đủ của đoạn chứa lựa chọn.
- Bản dịch đang hiển thị.
- Một đoạn trước và sau, hoặc `contextBefore/contextAfter`.
- Ngôn ngữ và phiên bản bản dịch.
- Ghi chú cá nhân, tag, folder worklist.

Khi database được thay mới, resolver thử theo thứ tự:

1. `segmentId` nếu fingerprint còn khớp.
2. `bookCode + reference + sourceRowKey`.
3. `bookCode + paragraphNo + selectedText`.
4. Báo “nguồn đã thay đổi” nhưng vẫn giữ bản chụp và cho phép người dùng
   chọn đoạn gần nhất.

### 3. Một mục có thể đi vào nhiều luồng học

Không copy một `WordEntry` thành một `LearnByHeartItem` độc lập. Dùng liên kết:

```text
worklistItemId
  ├─ vocabularyEntryId?      → WordEntry hiện có
  ├─ learnByHeartItemId?     → LearnByHeartItem hiện có
  ├─ sourceAnchor             → mở Reader
  └─ studyMode                → word / phrase / passage
```

Như vậy việc sửa nghĩa, tag, đánh giá SM-2 hoặc nội dung học không tạo bản ghi
trùng và vẫn mở được nguồn Tipiṭaka.

## UX đề xuất

### Trong Tipiṭaka Reader

1. Chạm một từ Pāli: mở sheet tra cứu hiện có.
2. Chọn **Lưu từ vào Worklist**.
3. Bôi chọn nhiều từ: chọn **Lưu cụm từ**.
4. Menu trên đoạn: **Lưu đoạn để học thuộc**.
5. Sau khi lưu, SnackBar nhỏ:
   - “Đã lưu vào Worklist”
   - nút “Mở Worklist”
   - nút “Học ngay”
6. Mỗi card có icon bookmark khi mục đã được lưu.

### Trong Worklist

Mỗi item hiển thị:

- từ/cụm từ;
- nghĩa ngắn;
- Pāli và bản dịch;
- nguồn `VIN01M · MUL · reference`;
- nút **Mở nguồn**;
- nút **Học thuộc**;
- trạng thái hiểu/nghe/đọc và ngày ôn.

Bộ lọc nên có: `Tất cả`, `Từ`, `Cụm`, `Đoạn`, `Từ Tipiṭaka`, `Đến hạn ôn`.

### Trong Học thuộc lòng

Tạo `LearnByHeartItem` từ `studyMode = passage` với:

- `title`: tên sách + reference;
- `paliText`: đoạn Pāli;
- `vietnameseText`: bản dịch đang chọn;
- `sourceAnchor`: liên kết quay về Reader;
- `keywords`: các từ/cụm đã đánh dấu;
- `notes`: ghi chú ngữ cảnh.

Màn hình học có nút **Mở nguồn** ở header và sau khi đánh giá có nút
**Quay lại đoạn đang học**.

## Lộ trình triển khai

### Phase 1 — Anchor và resolver

**Trạng thái: đã triển khai nền tảng.** `TipitakaSourceAnchor` và
`TipitakaContextSnapshot` được lưu lossless trong `WordEntry`; reader dùng
`TipitakaSourceResolver` để thử segment ID rồi fallback source row/reference/
paragraph/selected text.

- Tạo `TipitakaSourceAnchor` và `TipitakaContextSnapshot`.
- Thêm `sourceAnchorJson` vào WordEntry hoặc bảng liên kết riêng.
- Viết resolver mở lại segment sau khi DB được import lại.
- Test DB cũ, DB mới và trường hợp reference thay đổi.

### Phase 2 — Lưu từ/cụm từ trong Reader

**Trạng thái: đã triển khai.** Pāli selectable text trong Reader có action lưu
từ/cụm; mỗi paragraph có action lưu cả đoạn. Tất cả đều đi qua
`VocabularyProvider` hiện có và chỉ bổ sung context/anchor cho entry trùng.

- Tách selection toolbar dùng chung với Read tab.
- Dùng `VocabularyProvider`/`WordEntry` hiện có.
- Thêm `sourceAnchor`, `contextSnapshot`, `sourceType` vào serialization.
- Không tạo bản sao nếu word đã tồn tại; chỉ thêm anchor/context mới.

### Phase 3 — Liên kết Learn by Heart

- Thêm `learnByHeartItemId` hoặc bảng liên kết N-N.
- Adapter `TipitakaSegment → LearnByHeartItem`.
- Thêm nút “Học thuộc” từ Reader và Worklist.
- Giữ nguyên FSRS/SM-2 hiện có; chỉ bổ sung nguồn và context.

### Phase 4 — Đồng bộ và khả năng chịu thay đổi DB

- Fingerprint normalized DB bằng schema + số lượng/hash metadata, không hash toàn
  bộ DB lớn ở UI thread.
- Resolver báo các anchor stale sau khi import DB mới.
- Cho phép sửa anchor thủ công và ghi log migration.

## Tiêu chí nghiệm thu

- Lưu một từ trong Tipiṭaka mở được lại đúng đoạn và đúng vị trí.
- Lưu một cụm giữ nguyên offset và bản chụp ngữ cảnh.
- Từ đã lưu trong Read tab và Tipiṭaka không bị nhân đôi.
- Từ/cụm có thể đưa vào học thuộc mà không mất liên kết nguồn.
- Thay DB vẫn mở được bằng fallback reference/text hoặc báo stale rõ ràng.
- Có đường quay lại nguồn từ Worklist và từ màn hình học thuộc lòng.

## Thứ tự ưu tiên

1. `SourceAnchor` + mở lại nguồn.
2. Lưu từ/cụm và context vào Worklist hiện có.
3. Tạo LearnByHeart item có liên kết.
4. Đồng bộ anchor khi DB thay đổi.
5. Sau cùng mới thêm proofreading, chia sẻ link và đồng bộ cloud.
