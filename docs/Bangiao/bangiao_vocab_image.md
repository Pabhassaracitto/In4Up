# Bàn giao: Vocabulary Image Feature (IMG-001)

## Tổng quan
Tính năng cho phép người dùng chọn/gán hình ảnh cho từ vựng khi lưu hoặc chỉnh sửa. Hình ảnh được lưu vào app documents với hash-based deduplication để tiết kiệm dung lượng.

## Lý thuyết
- **Dual-coding theory** (Paivio 1971): Hình ảnh giúp tăng cường mã hóa ký ức
- **Generation effect** (Slamecka & Graf 1978): Tự tìm hình ảnh giúp nhớ tốt hơn

## Cấu trúc module

```
lib/features/vocab_image/
├── vocab_image.dart              # Barrel export
├── vocab_image_service.dart      # Service quản lý hình ảnh
├── vocab_image_picker.dart       # Widget chọn hình ảnh
└── vocab_image_thumbnail.dart    # Widget hiển thị thumbnail
```

## Các thành phần chính

### 1. VocabImageService (`vocab_image_service.dart`)
- **pickFromGallery()**: Chọn ảnh từ gallery, copy vào app storage
- **saveFromBytes(bytes)**: Lưu bytes (web/camera/chia sẻ) → relative path
- **saveFromUrl(url, {client})**: Tải ảnh từ URL bằng `VocabImageWebService`
  (chặn không phải ảnh + trần 8MB) rồi lưu — **KHÔNG** lưu thẳng URL vào
  `imageUrl` vì ôn tập phải chạy offline và link ngoài mạng chết bất kỳ lúc nào
- **resolvePath()**: Chuyển relative path → absolute path
- **imageExists()**: Kiểm tra ảnh có tồn tại không
- **deleteImage()**: Xóa ảnh
- **Lưu trữ**: `vocabulary_images/<hash>.<ext>` trong app documents
- **Dedup**: MD5 hash → filename unique, skip write nếu trùng
- (chưa có: `totalSizeBytes()` — tài liệu cũ ghi vậy nhưng code chưa có)

### 2. VocabImagePicker (`vocab_image_picker.dart`)
- Hiển thị ảnh hiện tại hoặc placeholder "Thêm ảnh"
- **Tap**: mở `VocabImagePickerSheet` (IMG-WEB-001) — tab mặc định là
  **Tìm ảnh trên mạng**, "Trong máy" là tab thứ hai
- **Long press / dấu ×**: Xóa ảnh
- Nhận `word` + `meaning` để mồi từ khóa tìm ảnh
- Tự động cập nhật VocabularyProvider khi chọn/xóa
- Size: 100-140px, border radius 12px
- Ảnh là URL ngoài (dữ liệu cũ) → `Image.network`, không crash

### 2b. VocabImagePickerSheet (`vocab_image_picker_sheet.dart`) — IMG-WEB-001
- **Vì sao đảo thứ tự**: người dùng phản hồi "hình ở máy ít khi có" → mở sheet
  là TỰ TÌM ảnh trên mạng luôn (query = từ + nghĩa), chạm ảnh là xong.
- Lưới kết quả: `Image.network` (thumbnail) + title + credit (creator · license ·
  nguồn). Chạm → tải bytes → lưu app storage → `pop(path)`.
- Footer: "Bỏ ảnh hiện tại" (chỉ hiện khi từ đã có ảnh).
- Hàng trạng thái: `Nguồn: Pexels · API key: đã nhập/chưa nhập` + nút **API key**
  mở dialog chọn provider + dán key.
- `VocabImageSourceKind { web, device }` — chỗ cho `camera` + ML Kit (bước sau).

### 2b2. VocabImageQuickAddButton + attachVocabImage (`vocab_image_quick_add.dart`)
- Chỗ cho luồng **thêm từ 1 chạm**: nút "Thêm hình / Đổi hình" hiện ở trạng
  thái ĐÃ LƯU (sheet tap từ trong PDF) và action "Thêm hình" trong snackbar
  khi thêm từ ở Wordlist (`_addAndSaveNow`).
- `attachVocabImage(context, {wordId, word, meaning, currentImageUrl})` mở
  sheet, tự `updateImageUrl` qua VocabularyProvider; provider được lấy TRƯỚC
  khi mở sheet nên phần ghi không cần context sau await.
- **Không** gắn ở `selection_save_sheet` / `word_actions_sheet._showSavedSnack`
  / `floating_text_actions`: mấy chỗ đó pop sheet / gỡ overlay trước khi hiện
  snackbar → context đã chết, mở bottom sheet từ đó sẽ crash.

### 2c. VocabImageWebService + VocabImageApiConfig — API key là bắt buộc
- Provider: **Pexels** (key) · **Unsplash** (Access Key) · **Openverse** (token
  khuyến nghị) · **Wikimedia Commons** (không cần key).
- `VocabImageProvider.needsKey` → Pexels/Unsplash **bỏ qua** khi chưa có key,
  UI nhận `missingKeyProvider` để nhắc nhập key (không im lặng trả 0 kết quả).
- Order: provider đã chọn trước, các nguồn còn lại (dùng được) là fallback khi
  lỗi mạng / 429 / 0 kết quả.
- Nơi lưu key: `SharedPreferences` trên máy (mỗi provider 1 key) HOẶC
  `--dart-define=VOCAB_IMAGE_PROVIDER=pexels --dart-define=VOCAB_IMAGE_API_KEY=…`
  khi build. **Không bao giờ commit key vào repo**; build-time key chỉ dùng cho
  đúng provider đã khai (không đưa key Pexels cho Unsplash).
- Parser thuần tĩnh (`parsePexels`/`parseUnsplash`/`parseOpenverse`/
  `parseCommons`) — test không cần mạng: `test/vocab_image_search_test.dart`.

### 3. VocabImageThumbnail (`vocab_image_thumbnail.dart`)
- Hiển thị thumbnail compact trong danh sách từ
- Size: 36px (compact list), 120px (expanded detail)
- Tự động resolve path và hiển thị loading state

## Tích hợp UI

### Word Actions Sheet (Read mode)
- Hiển thị image picker khi từ đã tồn tại trong vocabulary
- Vị trí: Sau phần "Đánh dấu độ khó", trước "Quick Actions"

### Word List Screen
- **Compact list**: Hiển thị thumbnail 36px bên trái từ
- **Expanded detail**: Hiển thị preview 120px nếu có ảnh, hoặc image picker 100px nếu chưa có
- **Edit sheet**: Image picker 120px trong form chỉnh sửa

## VocabularyProvider
- **updateImageUrl(id, imageUrl)**: Method mới để cập nhật imageUrl
- Tự động gọi `_saveWord()` và `notifyListeners()`

## Dependencies
- `file_picker: ^11.0.2` (đã có trong pubspec.yaml)
- `crypto: ^3.0.6` (đã có trong pubspec.yaml)
- `http: ^1.2.2` (đã có — gọi API ảnh + tải bytes)
- `shared_preferences: ^2.3.5` (đã có — lưu API key trên máy)
- `path_provider` (đã có trong Flutter)
- **0 dependency mới** cho IMG-WEB-001

## Lưu ý khi bảo trì
1. **Dung lượng lưu trữ**: Ước tính ~100-300KB mỗi ảnh
2. **Hash-based dedup**: Cùng nội dung ảnh sẽ chỉ lưu 1 bản
3. **Relative path**: Lưu relative path vào WordEntry.imageUrl để portable
4. **Error handling**: Service trả về null nếu lỗi, UI hiển thị placeholder
5. **API key (yêu cầu của owner)**: tìm ảnh phải qua API có key. Mặc định
   của code là Pexels → trên máy chưa nhập key thì app tự rơi về
   Openverse/Wikimedia và nhắc nhập key. Owner cần chọn provider + dán key
   (hoặc set `--dart-define` trong CI build) — xem card `IMG-WEB-001`.
6. **Bước tiếp theo (chưa làm)**: camera + ML Kit — `Subject Segmentation`
   (xóa phông) và `Object Label` để chụp đồ vật thật gán vào từ vựng. Thêm
   giá trị `camera` vào `VocabImageSourceKind` là đủ chỗ, API sheet không đổi.

## Commit
- **Commit**: `c15b0b7` on `arena/01a07234-in4up`
- **Branch**: `arena/01a07234-in4up`

## Lịch sử

- 2026-09-05 | IMG-001 | `c15b0b7` on `arena/01a07234-in4up` — chọn ảnh từ máy.
- 2026-09-14 | IMG-WEB-001 | `arena/01a0a205-in4up` — đảo priority sang tìm
  ảnh trên mạng qua API key (Pexels/Unsplash/Openverse/Wikimedia), sheet chọn
  nguồn, dialog key, `saveFromUrl`/`saveFromBytes`, 2 file test.
