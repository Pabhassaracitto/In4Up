# ADR-0040: Kiến trúc Home Screen Widgets «Snapshot Mirror» & Hợp đồng Điều hướng Hành động `in4up://action|nav`

- **Ngày:** 2026-11-25
- **Trạng thái:** ĐÃ HOÀN TẤT (`P0–P4` Android & iOS) trên `arena/16761e82-in4up` (`PLAN-050`).
- **Liên quan:** `ADR-0001` (chuẩn hoá SM-2 một hàm duy nhất), `ADR-0002` (phân tầng ngôn ngữ & Rule #5), `ADR-0003` (`PdfFileIdentity` & toạ độ đọc), `ADR-0011` (bong bóng dịch màn hình Android), `ADR-0018` (`DictionaryScreen` & kênh `in4up/deeplink`), `ADR-0022` (`DharmaProvider` `episodeKey`).

## 1. Bối cảnh

In4Up có 7 phòng Studio (*Đọc · Viết · Nghe · Nói · Xem · Hiểu · Nhớ*) và hơn 18 công cụ chuyên sâu. Khi mở từ màn hình chính điện thoại, người dùng hiện cần 3–5 thao tác mới chạm tới các tác vụ ngắn lặp lại nhiều lần mỗi ngày (tra 1 từ MDX, ghi chú nói STT, quét trang sách OCR, bật bong bóng dịch màn hình, xem thẻ SRS đến hạn, mở lại đúng trang PDF hoặc bài Pháp thoại đang dở).

Chủ dự án yêu cầu thiết kế và triển khai hệ thống **Widget & Lối tắt màn hình chính tiện lợi 1–2 chạm**, đồng thời bảo toàn tuyệt đối sự ổn định của ứng dụng đa nền tảng (`Flutter 3.44.1`, `minSdk 24`, `targetSdk 35`, `compileSdk 36`, 3 Android flavors `stable`/`beta`/`dev`, Web entrypoint `lib/main_web.dart`) và 5 Quy tắc vàng trong `AGENTS.md`.

## 2. Quyết định kiến trúc

### 2.1. Không khởi tạo Flutter Engine / Hive / SQLite từ Widget (`WidgetSnapshot Mirror`)
- Native Home Screen Widget (`AppWidgetProvider` trên Android và `WidgetKit` `In4UpWidgetsExtension` trên iOS) **chỉ đọc đúng 1 chuỗi JSON phẳng có phiên bản (`schemaVersion: 1`, trần kích thước `< 8 KB`)** lưu trong `SharedPreferences` riêng (`in4up_home_widgets_v1` trên Android) và `UserDefaults(suiteName: "group.com.in4up.shared")` (trên iOS, có fallback an toàn về `UserDefaults.standard` cho môi trường sideload).
- Toàn bộ việc tổng hợp dữ liệu thật (`LearningActivityService`, `VocabularyProvider`, `MemoryController`, `LearnByHeartProvider`, `PlayerProvider`, `RecentAudioService`, `TextProvider`, `RecentFilesService`) được thực hiện ở lớp thuần Dart `WidgetSnapshotBuilder` khi ứng dụng đang chạy (debounce `800 ms` + flush khi chuyển sang `AppLifecycleState.inactive`/`paused`).
- **Lý do:** Tránh tốn RAM/pin ở tiến trình nền Android, tránh xung đột khoá tệp Hive/SQLite đa tiến trình, và nằm gọn trong giới hạn RAM 30 MB Jetsam của iOS Widget Extension (`AppIntents` iOS 17+ lật thẻ trực tiếp tại chỗ, kèm Lock Screen `accessoryCircular`/`accessoryRectangular`/`accessoryInline` trên iOS 16+ và guard `#available` tương thích ngược tới `IPHONEOS_DEPLOYMENT_TARGET = 15.0`).

### 2.2. Zero phụ thuộc ngoài: Cầu nối mỏng `MethodChannel('in4up/home_widget')` + `RemoteViews` XML chuẩn
- **Không** thêm gói `home_widget` vào `pubspec.yaml` và **không** thêm `androidx.glance` (Jetpack Compose) vào `android/app/build.gradle.kts`.
- **Lý do:** Cùng nguyên tắc đã kiểm chứng ở `ADR-0018`: tránh xung đột giải phiên bản Dart `3.11.5` / Kotlin `17` trên CI và giữ APK tăng thêm `< 80 KB`. Bố cục Android dùng hoàn toàn các thẻ hợp lệ của `RemoteViews` từ API 24 (`LinearLayout`, `FrameLayout`, `RelativeLayout`, `TextView`, `ImageView`, `ProgressBar`; tuyệt đối không dùng `<View>` trần vốn chỉ hỗ trợ `RemoteViews` từ API 31+ và không dùng thuộc tính `app:*`).

### 2.3. Hợp đồng URI điều hướng thống nhất mở rộng từ `ADR-0018`
- Giữ nguyên kênh `MethodChannel('in4up/deeplink')` và hai host cũ (`dict`, `open`).
- Mở rộng thêm hai host an toàn có danh sách trắng (whitelist tĩnh) trong bộ phân tích thuần Dart `WidgetActionDeepLink`:
  - `in4up://action/<id>` (`dict_search`, `voice_capture`, `ocr_scan`, `screen_translate`, `ai_chat`, `review_due`, `resume_read`, `resume_listen`, `widget_settings`)
  - `in4up://nav/studio?target=<studio>` (`home`, `read`, `write`, `listen`, `speak`, `watch`, `understand`, `remember`, `cabin`, `tipitaka`, `youtube`)
- Mọi `Intent` từ Widget / Tile / Pinned Shortcut trên Android đều gắn `setPackage(context.packageName)` để các bản `com.in4up`, `com.in4up.beta`, `com.in4up.dev` cài song song trên cùng thiết bị không bao giờ cướp nhầm sự kiện của nhau.

### 2.4. An toàn Android 14/15 (`targetSdk = 35`)
- Không bao giờ gọi `startForegroundService` phát nhạc hoặc `MediaProjection` mù từ `AppWidgetProvider` khi ứng dụng đang ở trạng thái lạnh (tránh `ForegroundServiceStartNotAllowedException`).
- Mọi hành động cần mở luồng phát tiếp hoặc quét đi qua `PendingIntent.getActivity` tới `MainActivity` (`singleTop`) với hàng đợi `WidgetActionRouter` (khử trùng lặp `< 900 ms`).
- Các thao tác xem thẻ tại chỗ trên `FlashcardSrsWidgetProvider` (*Hiện/Ẩn nghĩa* và *Từ tiếp theo*) dùng `PendingIntent.getBroadcast` nội bộ chỉ cập nhật chỉ số trong `SharedPreferences` và vẽ lại `RemoteViews` — không khởi chạy dịch vụ nền và không sửa điểm SM-2 ngoài tầng Dart.
- Trên `TileService` (Quick Settings), phân nhánh API 34+ dùng `startActivityAndCollapse(PendingIntent)` thay cho overload `Intent` đã bị chặn ở `targetSdk >= 34`.

### 2.5. Tuân thủ Quy tắc vàng #2 (SM-2 3 kỹ năng), #3 (Reopen vị trí) & #5 (i18n)
- **SM-2:** Dữ liệu mỗi thẻ trong `WidgetSnapshot` giữ nguyên 3 trường tách biệt (`understandScore`, `listenScore`, `readScore`), hiển thị thành 3 chỉ báo riêng trên Widget. Việc chấm điểm thật luôn mở vào phiên chuẩn của `MemoryController` / `LearnByHeartHubScreen` (`ADR-0001`).
- **Reopen vị trí:** `resume_read` mở lại qua đúng `PdfReaderScreen` (bảo toàn `PdfFileIdentity` + trang/rect) hoặc `TextProvider`; `resume_listen` mở qua `PlayerProvider.loadSong(..., initialPosition: ...)` để giữ tiến độ.
- **i18n Rule #5:** `WidgetSnapshotBuilder` dịch sẵn toàn bộ nhãn giao diện (`WidgetChromeLabels`) thông qua `AppUITranslations.translate(sourceVi, localeCode)` trước khi ghi JSON. Tài nguyên tĩnh mặc định ở `android/app/src/main/res/values/strings_widgets.xml` là **English**, bản tiếng Việt chỉ đặt trong `res/values-vi/strings_widgets.xml` (kèm bản dịch đầy đủ cho các ngôn ngữ ưu tiên `hi`, `zh-rCN`, `zh-rTW`, `si`, `my`, `th`, `ja`).

## 3. Hệ quả & Kiểm chứng

- **Được:** Người dùng có trọn bộ 4 Home Screen Widgets (*Thanh Lệnh Nhanh*, *Tiếp Tục Học*, *Thẻ Từ & Vườn Trí Nhớ*, *Nhịp Điệu & Streak*), 2 ô Quick Settings Android (*Dịch màn hình*, *Ghi chú nói*), 4 App Icon Shortcuts (Android & iOS) và màn quản lý ghim 1 chạm ngay trong ứng dụng — mà không thêm bất kỳ gói phụ thuộc nào.
- **Kiểm chứng tự động:**
  1. Unit test thuần Dart kiểm tra toàn bộ ma trận URI, bảo toàn 3 trục SM-2, trần JSON `< 8 KB` và không rò rỉ ký tự tiếng Việt ở mọi locale `≠ vi`.
  2. GitHub Actions kiểm tra đồng thời `flutter analyze`, `flutter build web` và biên dịch APK Android thực tế (`vieneu_engine_build.yml`).
