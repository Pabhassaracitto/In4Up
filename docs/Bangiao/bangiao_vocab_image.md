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
- **saveFromUrl()**: Lưu ảnh từ URL (dùng cho Unsplash/Pixabay)
- **resolvePath()**: Chuyển relative path → absolute path
- **imageExists()**: Kiểm tra ảnh có tồn tại không
- **deleteImage()**: Xóa ảnh
- **totalSizeBytes()**: Đếm tổng dung lượng ảnh đã lưu
- **Lưu trữ**: `vocabulary_images/<hash>.jpg` trong app documents
- **Dedup**: MD5 hash → filename unique, skip write nếu trùng

### 2. VocabImagePicker (`vocab_image_picker.dart`)
- Hiển thị ảnh hiện tại hoặc placeholder "Thêm ảnh"
- **Tap**: Chọn ảnh từ gallery
- **Long press**: Xóa ảnh
- Tự động cập nhật VocabularyProvider khi chọn/xóa
- Size: 120-140px, border radius 12px

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
- `path_provider` (đã có trong Flutter)

## Lưu ý khi bảo trì
1. **Dung lượng lưu trữ**: Ước tính ~100-300KB mỗi ảnh
2. **Hash-based dedup**: Cùng nội dung ảnh sẽ chỉ lưu 1 bản
3. **Relative path**: Lưu relative path vào WordEntry.imageUrl để portable
4. **Error handling**: Service trả về null nếu lỗi, UI hiển thị placeholder
5. **Future expansion**: Có thể thêm Unsplash/Pixabay API search

## Commit
- **Commit**: `c15b0b7` on `arena/01a07234-in4up`
- **Branch**: `arena/01a07234-in4up`
