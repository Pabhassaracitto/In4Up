# I4U — Background Removal trong Wordlist (Phase 1)

## Đã tích hợp

Luồng **Thêm/Sửa từ vựng → Hình ảnh → Trong máy** hiện có:

1. **Chụp ảnh** bằng camera hoặc **Thư viện**.
2. Xem ảnh gốc trong preview.
3. Bấm **Tách nền tự động** để chạy Google ML Kit Subject Segmentation.
4. Chuyển đổi **Ảnh gốc / Đã tách nền** để so sánh.
5. **Dùng ảnh này** để lưu ảnh đang xem. Ảnh đã tách nền được lưu thành PNG có alpha
   trong `ApplicationDocumentsDirectory/vocabulary_images` và `imageUrl` của
   WordEntry vẫn là relative path như luồng ảnh hiện tại.

Các file chính:

- `lib/features/background_removal/base_background_remover.dart` — Strategy contract.
- `lib/features/background_removal/mlkit_background_remover.dart` — Phase 1.
- `lib/features/background_removal/background_removal_service.dart` — coordinator.
- `lib/features/background_removal/rmbg_background_remover.dart` — Phase 2 seam,
  không import ONNX và không đóng gói model.
- `lib/features/vocab_image/vocab_image_picker_sheet.dart` — camera/gallery,
  preview và toggle so sánh.

## Dependency

Đã thêm vào `pubspec.yaml`:

```yaml
dependencies:
  google_mlkit_subject_segmentation: ^0.2.0
  image_picker: ^1.2.1
  image: ^4.8.0
```

`file_picker`, `path_provider` và `crypto` đã có sẵn trong project. Chạy:

```bash
flutter pub get
```

`image` là dependency trực tiếp để kiểm soát việc decode/re-encode output PNG của
ML Kit; không nên dựa vào việc nó đang được kéo transitively.

## Android / iOS

- Android hiện đã có `minSdk = 24` và manifest dependency `subject_segment`.
  ML Kit Subject Segmentation là beta và hiện plugin chỉ hỗ trợ Android.
- Model Google là **unbundled Play Services model**: model không nằm trong APK.
  Play Services có thể cần mạng ở lần provision đầu tiên; sau khi model có trên
  máy, xử lý ảnh không cần mạng. Đây là giới hạn của API, không nên quảng bá là
  offline tuyệt đối ở lần chạy đầu.
- `Info.plist` đã có `NSCameraUsageDescription` và
  `NSPhotoLibraryUsageDescription` cho image picker. Trên iOS, camera/gallery
  hoạt động nhưng nút ML Kit sẽ giữ ảnh gốc vì Subject Segmentation chưa có
  implementation iOS trong plugin.

## Contract cho engine mới

```dart
abstract class BaseBackgroundRemover {
  Future<Uint8List?> removeBackground(Uint8List imageBytes);
}
```

Nếu strategy thất bại, UI không mất ảnh gốc. `BackgroundRemovalService` cũng đã
có đường fallback từ strategy nâng cao về ML Kit để dùng lại khi Phase 2 được bật.
Xem `docs/background_removal_phase2.md` trước khi thêm runtime ONNX hoặc model.
