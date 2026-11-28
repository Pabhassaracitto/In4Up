# PLAN-050 — Hệ sinh thái Widget & Lối tắt Màn hình chính «1–2 Chạm» cho In4Up

> **Trạng thái:** ✅ `implemented (Android P0–P3 + iOS App Shortcuts)` — **Đã thi công và kiểm chứng xanh trên CI (`App Analyze + Locale Test`, `Web Build`, `VieNeu Android arm64 APK Build`)** trên nhánh `arena/16761e82-in4up` (tách từ `74242d4` · `v1.29.2+31`); riêng phần iOS `WidgetKit` SwiftUI Extension (`P4`) để dành cho chặng tiếp theo theo quyết định `Q1`.
> **Định danh:** `PLAN-050` · **ADR:** [`ADR-0040`](../adr/0040-home-screen-widgets-va-action-deeplink.md).
> **Ràng buộc bất biến tuân thủ:** 5 Quy tắc vàng trong `AGENTS.md` (không đụng `lib/ffi/` UltraTimeStretch; không gộp 3 kỹ năng SM-2 Hiểu–Nghe–Đọc; bảo toàn mở lại đúng vị trí nguồn PDF/Audio/Dharma; lập ADR trước khi đổi kiến trúc; tuân thủ tuyệt đối Rule #5 i18n chrome).

---

## 0. Tóm tắt điều hành (TL;DR)

1. **Bài toán UX cốt lõi của In4Up:**
   In4Up đã phát triển thành một **Knowledge OS local-first** rất giàu năng lực (7 phòng Studio: *Đọc · Viết · Nghe · Nói · Xem · Hiểu · Nhớ* + hơn 18 công cụ sâu như Từ điển MDX/MDD, Pháp thoại, Tipiṭaka, OCR quét sách, Bong bóng dịch màn hình, Thuộc lòng FSRS, Cabin dịch trực tiếp, AI Chat). Tuy nhiên, **càng nhiều tính năng thì "ma sát truy cập" càng cao**: hiện tại người dùng mất **3–5 chạm** mới vào được một tác vụ ngắn 5–15 giây (tra 1 từ, nói lưu 1 câu, quét 1 trang sách, bật bong bóng dịch, xem số thẻ đến hạn).
2. **Hiện trạng kỹ thuật trong repo (đã kiểm tra thực chứng):**
   - **Chưa có bất kỳ Widget hay App Shortcut nào** (`AppWidgetProvider = 0`, `WidgetKit = 0`, `shortcuts.xml = 0`, `TileService = 0`).
   - **Tin rất tốt — 70% nền móng phía dưới đã có sẵn:**
     - Cầu nối `MethodChannel('in4up/deeplink')` + scheme `in4up://`, `i4u://` đã hoạt động trên cả Android (`MainActivity.kt` `singleTop`) và iOS (`AppDelegate.swift`) theo `ADR-0018`.
     - Logic gộp dữ liệu thật không dùng mock đã được chuẩn hoá ở `ContinueLearningCard` (`HOME-CONTINUE-001`), `FocusStreakCard` / `LearningActivityService` (`HOME-STREAK-001`), `MemoryGardenCard`, `QuickCaptureSheet` và `QuickSuggestionPicker`.
3. **5 Cạm bẫy kỹ thuật chí mạng nếu làm theo hướng dẫn đại trà (đã chặn từ thiết kế):**
   - **Cạm bẫy 1 — Khởi tạo Flutter Engine / Hive / SQLite từ Widget:** Widget chạy trong tiến trình hệ thống siêu nhẹ (iOS giới hạn RAM Widget Extension ở mức **~30 MB**; Android Battery Saver chặn tiến trình nền nặng). Mở Hive/SQLite hay dựng Flutter Engine sẽ gây văng/treo hoặc hao pin. **Giải pháp:** Kiến trúc **«Widget Snapshot Mirror»** — App khi chạy ghi 1 chuỗi JSON phẳng `< 8 KB` vào `SharedPreferences` / iOS `App Group UserDefaults`; Native Kotlin/Swift đọc trực tiếp trong `< 2 ms`, **0 Flutter Engine**.
   - **Cạm bẫy 2 — Crash `ForegroundServiceStartNotAllowedException` trên Android 14/15 (`targetSdk = 35`):** Không được gọi `startForegroundService` phát audio hay bật `MediaProjection` mù từ nền khi app đang tắt hẳn (cold state). **Giải pháp:** Tách rạch ròi đường **Warm** (broadcast điều khiển tức thì 0 mở màn hình) và đường **Cold** (`PendingIntent.getActivity` với URI `autoplay=1` / `ScreenCaptureRequestActivity`).
   - **Cạm bẫy 3 — Lệch 3 Flavor (`com.in4up`, `com.in4up.beta`, `com.in4up.dev`):** Mọi `ComponentName`, `PendingIntent`, action broadcast và `App Group` phải lấy động từ `context.packageName` / `$(PRODUCT_BUNDLE_IDENTIFIER)`.
   - **Cạm bẫy 4 — Vi phạm Quy tắc vàng #2 (SM-2) & #3 (Reopen vị trí):** Tuyệt đối không viết lại công thức SM-2 bằng Kotlin/Swift và không gộp 3 điểm Hiểu–Nghe–Đọc; Widget mở lại PDF/Audio/Pháp thoại phải đi qua đúng router khôi phục `PdfFileIdentity` + `episodeKey`.
   - **Cạm bẫy 5 — Vi phạm Rule #5 i18n trên Widget Native:** Dart sẽ dịch sẵn toàn bộ nhãn giao diện theo `LocaleProvider` + `AppUITranslations` hiện hành trước khi ghi vào `WidgetSnapshot`, còn XML fallback tĩnh mặc định là **English** (`values/strings.xml`) và chỉ `values-vi/` dùng tiếng Việt ⇒ **0% rò rỉ chữ Việt khi máy để ngôn ngữ khác**.
4. **Giải pháp tổng thể «Hệ sinh thái 1–2 Chạm» (3 tầng bổ trợ, Zero dependency mới trong `pubspec.yaml`):**
   - **Tầng 1 (Không tốn diện tích màn hình):** **App Icon Shortcuts** (nhấn giữ icon app → 4 lối tắt + ghim thành nút 1-chạm) & **Android Quick Settings Tiles** (vuốt thanh trạng thái bật ngay *Bong bóng dịch màn hình* hoặc *Ghi chú nói*).
   - **Tầng 2 (Bộ 5 Widget Chủ lực tinh gọn):**
     1. **`I4U Thanh Lệnh Nhanh` (`4×1` / `4×2`):** Ô tìm Từ điển (1 chạm bung sẵn bàn phím) + 3 nút tuỳ chọn (*Mic STT · Quét OCR · Dịch màn hình / AI Chat*).
     2. **`I4U Tiếp Tục Học` (`4×2` / `2×2`):** 1 chạm quay lại đúng trang PDF/Văn bản đang đọc hoặc phát tiếp bài Audio/Pháp thoại đang dở.
     3. **`I4U Thẻ Từ & Vườn Trí Nhớ` (`2×2` / `4×2`):** Hiển thị thẻ đến hạn + 3 vạch kỹ năng *Hiểu · Nghe · Đọc* riêng biệt; **chạm 1 lật nghĩa ngay trên màn hình chính (không mở app)**, chạm 2 qua thẻ khác hoặc nhảy thẳng vào phiên ôn tập.
     4. **`I4U Nhịp Điệu & Chuỗi Ngày Học` (`2×2` / `4×2`):** Chuỗi ngày `🔥 Streak` + biểu đồ 7 ngày thật từ `LearningActivityService` + nút hành động giữ chuỗi theo ngữ cảnh.
     5. **`I4U Ghim Cá Nhân` (`1×1` / `2×2`):** Nút **📌 «Đưa ra màn hình chính»** ngay trong menu của từng cuốn PDF, bộ Pháp thoại, sách Tipiṭaka hoặc phòng Studio.
   - **Tầng 3 (Trải nghiệm "1 chạm thêm Widget" trong App):** Trang **«Widget & Lối tắt màn hình chính»** trong Cài đặt gọi thẳng `AppWidgetManager.requestPinAppWidget()` (Android 8+), giúp người dùng ghim widget ngay trong app mà không cần tự mò ngoài màn hình chính.

---

## 1. Khảo sát hiện trạng dự án (Đọc mã thực chứng)

| Hạng mục khảo sát | Vị trí trong mã nguồn | Hiện trạng thực tế | Đánh giá & Hệ quả cho thiết kế Widget |
|---|---|---|---|
| **Home Screen Widget / Shortcut / Quick Tile** | `android/`, `ios/`, `pubspec.yaml` | **Chưa có 100%** (grep toàn repo = 0 kết quả cho `AppWidgetProvider`, `WidgetKit`, `ShortcutManager`, `TileService`). | Thiết kế mới hoàn toàn, không vướng di sản cũ. |
| **Cầu nối Deep Link hệ điều hành** | `lib/features/dictionary/services/dict_deep_link_router.dart`, `MainActivity.kt:94,213,275`, `AppDelegate.swift:8` | **Đã có khuôn mẫu rất sạch** (`MethodChannel('in4up/deeplink')`, zero plugin ngoài, xử lý cả cold-start `getInitialLink` lẫn warm-start `onNewIntent`). | **Tái sử dụng trực tiếp!** Chỉ cần mở rộng filter ở `AndroidManifest.xml` + `MainActivity.consumeInitialDeepLink()` (hiện mới nhận `host == "dict" \|\| host == "open"`) để nhận thêm `action` và `nav`. |
| **Điều hướng Shell trung tâm** | `lib/screens/main_shell.dart:83,1152`, `lib/core/navigation/shell_navigation_request.dart` | `MainShell` quản lý 5 tab chính (`home`, `listen`, `read`, `understand`, `remember`), sub-mode (`Nghe/Nói/Xem`, `Đọc/Viết`) và `_handleTool(toolId)` cho >18 công cụ; `ShellNavigationRequest` hiện mới có `read` và `listen`. | Cần nâng cấp `ShellNavigationRequest` (hoặc `AppActionRouter`) để điều phối mở thẳng bất kỳ tab/sub-mode/tool/sheet nào một cách idempotent (không chồng route khi bấm widget nhiều lần). |
| **Dữ liệu «Tiếp tục học»** | `lib/screens/home/widgets/continue_learning_card.dart`, `continue_learning_section.dart` | Đọc dữ liệu thật từ `PlayerProvider.currentSongTitle`, `TextProvider.currentDocument/currentTextPath`, `VocabularyProvider.dueCount`. | Tuy nhiên khi **mới mở app từ trạng thái tắt hẳn**, `PlayerProvider` có thể chưa nạp bài gần nhất nếu chỉ đọc state RAM. Snapshot cho Widget nên lấy kết hợp cả `RecentAudioService` / `DharmaProvider` (`episodeKey`) / `RecentFilesService` (`PdfFileIdentity`) để **luôn nhớ bài đang dở kể cả sau khi khởi động lại máy**. |
| **Dữ liệu «Nhịp điệu & Streak»** | `lib/services/learning_activity_service.dart:89` | **Cực kỳ thuận lợi:** Đã lưu sẵn dưới dạng **1 chuỗi JSON gọn** tại khoá `SharedPreferences` `'in4up_learning_activity_v1'` (gồm streak, hoạt động hôm nay theo 6 loại, lịch sử ngày theo giờ địa phương). | Có thể trích xuất trực tiếp sang `WidgetSnapshot` mỗi khi `LearningActivityService.record()` chạy. |
| **Dữ liệu Từ vựng & Ôn tập SRS / Thuộc lòng** | `lib/providers/vocabulary_provider.dart:23` (`Hive` `'vocabulary_v2'`), `MemoryController`, `LearnByHeartProvider` (`SharedPreferences`) | Từ vựng nằm trong Hive; Thuộc lòng nằm trong SharedPreferences; SM-2 tách biệt 3 kỹ năng *Hiểu – Nghe – Đọc* (Quy tắc vàng #2, `ADR-0001`). | Native Widget **không đọc Hive**. Khi danh sách từ đến hạn thay đổi, Dart trích sẵn top 5–10 thẻ đến hạn (kèm 3 mức điểm kỹ năng riêng biệt, IPA, nghĩa) ra `WidgetSnapshot` JSON. |
| **Ghi chú nói nhanh & Từ gợi ý** | `lib/screens/home/quick_capture/quick_capture_sheet.dart`, `quick_suggestion_sheet.dart` | Đã gộp chung 1 luồng STT thật (ưu tiên Sherpa offline → speech hệ thống), đóng sheet dừng mic sạch. | Thêm cờ `autoStartRecording: true` vào `QuickCaptureSheet.show(...)` là đạt ngay trải nghiệm **1 chạm từ màn hình chính → nói luôn**. |
| **Tra từ điển tập trung** | `lib/features/dictionary/widgets/dictionary_screen.dart` (`ADR-0018`) | Đã là đích duy nhất `DictionaryScreen.open(context, {query, source})`, có lịch sử 30 từ và `suggest()` đa bộ từ điển. | Thêm tuỳ chọn `autofocusSearch: true` khi `query == null` và `source == 'widget'` để **1 chạm từ Widget → bàn phím bật sẵn chờ gõ**. |
| **Quét OCR tài liệu** | `lib/features/ocr/ocr_service.dart`, `MainActivity.kt:150` (`OCR-SCAN-CRASH-001`) | Đã có `OcrPrecheck` kiểm tra Google Play Services + RAM ≥ 1.7 GB + crash shield trước khi mở scanner. | Mọi lối tắt OCR từ Widget **bắt buộc đi qua đúng luồng `OcrPrecheck`**, không gọi tắt plugin ML Kit để giữ nguyên lưới chống sập app. |
| **Bong bóng Dịch màn hình** | `lib/features/screen_translate/screen_translate_channel.dart`, `ScreenTranslateService.kt` | Đã có ForegroundService (`mediaProjection\|specialUse`) + `ScreenCaptureRequestActivity` xin consent chuẩn Android 14/15. | Cực hợp để gắn vào **Quick Settings Tile** + nút trên **Thanh Lệnh Nhanh** (chỉ hiện trên Android vì `ScreenTranslateChannel.platformSupported` chỉ true trên Android). |
| **Phát Audio & TTS nền** | `lib/audio/audio_player_service.dart`, `lib/screens/read_mode/services/tts_notification_service.dart` | `AudioPlayerService` bọc `just_audio` + `UltraEngineFFIV2` trực tiếp trong tiến trình chính; `targetSdk = 35`. | Không giả định có `MediaBrowserService` độc lập khi app đã bị kill. Thiết kế nút Play/Pause trên Widget theo cơ chế 2 chế độ **Warm Broadcast / Cold Activity Resume** để an toàn 100% trên Android 12–15. |
| **Cấu hình Build & Flavors** | `android/app/build.gradle.kts:88-155`, `pubspec.yaml` | Flutter `3.44.1` (Dart `3.11.5`), `minSdk 24`, `targetSdk 35`, `compileSdk 36`, Kotlin `17`, 3 flavors (`stable`, `beta`, `dev`). | **Không thêm plugin ngoài hay Jetpack Glance/Compose** để giữ tốc độ build, tránh xung đột Gradle/Kotlin trên CI và giữ 0 MB phình APK. |

---

## 2. Triết lý Sản phẩm: Biến «Siêu ứng dụng nhiều tầng» thành «Trợ lý 1–2 Chạm»

### 2.1. Phân tầng tần suất sử dụng & Giảm số chạm

Thay vì nhồi nhét cả 25 tính năng lên màn hình chính (gây loạn thị giác và tê liệt lựa chọn — *Hick's Law*), ta phân loại toàn bộ chức năng của In4Up theo **nhịp sinh học sử dụng trong ngày**:

| Nhóm hành vi | Tình huống thực tế của người dùng | Hiện tại (số chạm) | Khi có Widget / Shortcut | Mức giảm ma sát |
|---|---|---|---|---|
| **1. Phản xạ tức thời (3–15 giây)** | Đang đọc sách giấy / chat gặp từ lạ cần tra MDX; chợt nghĩ ra 1 câu/từ muốn nói lưu lại; cần chụp quét 1 trang sách; cần bật bong bóng dịch màn hình. | **4–5 chạm** *(Mở app → chờ shell → mở Công cụ / cuộn Home → chọn mục → bấm ô nhập/mic)* | **1 chạm duy nhất** *(Bấm thẳng ô tìm / nút Mic / nút OCR / nút Dịch trên Thanh Lệnh Nhanh)* | **Giảm 75–80% thao tác** |
| **2. Ôn tập vi mô & Giữ lửa (30 giây – 2 phút)** | Mở khoá điện thoại lúc rảnh 30 giây chờ thang máy/xe buýt: liếc xem từ vựng hôm nay, lật xem nghĩa, kiểm tra chuỗi ngày học `🔥 Streak`. | **3–4 chạm** *(Mở app → sang tab Nhớ → vào phiên Review)* | **0 chạm** *(nhìn thấy ngay từ + streak)* · **1 chạm** *(lật nghĩa ngay trên màn hình chính hoặc vào thẳng phiên ôn)* | **Tăng tần suất tiếp xúc SRS gấp 5–10 lần/ngày** |
| **3. Quay lại dòng chảy sâu (10–60 phút)** | Đọc tiếp cuốn PDF giáo trình / Kinh Tipiṭaka ở đúng trang hôm qua, hoặc nghe tiếp bài Pháp thoại / luyện nghe A–B đang dở. | **3–4 chạm** *(Mở app → chuyển tab Đọc/Nghe → mở Thư viện/Gần đây → chọn bài)* | **1 chạm duy nhất** *(Bấm thẳng dòng bài đang dở trên Widget «Tiếp Tục Học» hoặc icon Ghim riêng)* | **0 giây tìm kiếm lại bài cũ** |

### 2.2. Nguyên tắc Vàng về UX Widget (Chuẩn Material You & Apple HIG)
1. **Mỗi vùng chạm ≥ `48×48 dp`:** Tuyệt đối không đặt các nút bé li ti sát nhau gây bấm nhầm trên màn hình điện thoại nhỏ (`360×640`).
2. **Tối đa 4 điểm tương tác chính trên 1 Widget cỡ nhỏ/vừa:** Rõ ràng, thoáng mắt, đồng bộ bảng màu thương hiệu In4Up (Nền tối sâu `#080B1A` / `#141829`, viền kính mờ, điểm nhấn Tím `#6C63FF`, Xanh ngọc `#53D6BD`, Cam lửa `#FF6B35`, Xanh lá vườn nhớ `#4CAF50`).
3. **Trung thực tuyệt đối với dữ liệu thật (No Mock Data):** Chưa có bài đọc dở thì nói rõ trạng thái rỗng kèm nút bắt đầu nhanh; chưa học hôm nay thì hiện lời nhắc nhẹ giữ nhịp; không bao giờ bịa con số giả.

---

## 3. Thiết kế Chi tiết Bộ 5 Widget Chủ lực & Hệ thống Lối tắt

### Widget 1 — `I4U Thanh Lệnh Nhanh` (Omni Action Bar)
- **Kích thước:** Bản chuẩn **`4×1`** (thanh ngang mảnh đặt ngay trên thanh dock màn hình chính — giống vị trí thanh Google Search) và bản mở rộng **`4×2`**.
- **Đối tượng:** **100% người dùng In4Up** — chiếc widget "cửa ngõ vạn năng" gọn nhất nhưng quyền lực nhất.
- **Bố cục trực quan (`4×1`):**
  ```text
  ╭──────────────────────────────────────────────────────────────────╮
  │  [I4U] 🔍 Tra từ điển...                  [🎙️]   [📷]   [🫧/🤖] │
  ╰──────────────────────────────────────────────────────────────────╯
       ▲ Chạm 1: Mở Từ điển + bung bàn phím     ▲      ▲       ▲
                                                │      │       └─ Chạm 1: Bật Bong bóng Dịch (Android) / AI Chat
                                                │      └───────── Chạm 1: Quét trang sách OCR ngay
                                                └──────────────── Chạm 1: Mở Quick Capture & thu âm ngay
  ```
- **Khả năng tuỳ biến (2 chạm thiết lập, 1 chạm dùng mãi mãi):** Trong Cài đặt Widget của In4Up, người dùng được tự chọn **3 nút hành động bên phải** từ danh sách:
  `🎙️ Ghi chú nói` · `📷 Quét OCR` · `🫧 Dịch màn hình (Android)` · `🤖 I4U AI Chat` · `🗣️ Cabin Live` · `🌱 Ôn tập ngay` · `📖 Tipiṭaka` · `▶️ YouTube Học`.

---

### Widget 2 — `I4U Tiếp Tục Học` (Smart Resume Hub)
- **Kích thước:** Chuẩn **`4×2`** (hiển thị cả Đọc + Nghe) và thu gọn **`2×2`** (chỉ hiện mục gần nhất vừa dùng).
- **Bố cục trực quan (`4×2`):**
  ```text
  ╭──────────────────────────────────────────────────────────────────╮
  │  ⚡ TIẾP TỤC HỌC                                    💧 12 từ hẹn │
  │  ┌────────────────────────────────────────────────────────────┐  │
  │  │ 🎧 Pháp thoại B08 — Thiền Định              23:15/54:00 [▶]│  │
  │  └────────────────────────────────────────────────────────────┘  │
  │  ┌────────────────────────────────────────────────────────────┐  │
  │  │ 📖 Visuddhimagga.pdf · Trang 47 / 812                   [→]│  │
  │  └────────────────────────────────────────────────────────────┘  │
  ╰──────────────────────────────────────────────────────────────────╯
  ```
- **Luồng 1–2 chạm:**
  - **Chạm dòng Nghe:** Mở thẳng Tab Nghe / Pháp thoại đúng `episodeKey` và vị trí giây đã lưu.
  - **Chạm nút `[▶/⏸]`:** Nếu app đang ấm → phát/tạm dừng tức thì (0 chuyển màn hình); nếu app tắt hẳn → mở app và tự động phát tiếp (`autoplay=1`).
  - **Chạm dòng Đọc:** Mở lại đúng `PdfReaderScreen` (bảo toàn `PdfFileIdentity` + trang/toạ độ theo Quy tắc vàng #3) hoặc `ReadModeScreen` / `TipitakaLibraryScreen`.
  - **Chạm góc phải `💧 12 từ hẹn`:** Nhảy thẳng vào phiên ôn tập Vườn Trí Nhớ.

---

### Widget 3 — `I4U Thẻ Từ & Vườn Trí Nhớ` (Interactive Flashcard & SRS)
- **Kích thước:** Nhỏ **`2×2`** (1 từ gọn) · Vừa **`4×2`** (có câu ví dụ + nút lật/chuyển thẻ) · Lớn **`4×3`** (kèm thống kê Vườn Trí Nhớ / Thuộc lòng).
- **Điểm ăn tiền vượt trội:** Cho phép **Lật thẻ xem nghĩa** và **Qua thẻ tiếp theo** **ngay trên màn hình chính mà KHÔNG cần mở app** (dùng `BroadcastReceiver` cập nhật `RemoteViews` trên Android và `AppIntent` trên iOS 17+)!
- **Bố cục trực quan (`4×2`):**
  ```text
  ╭──────────────────────────────────────────────────────────────────╮
  │  🌱 VƯỜN TRÍ NHỚ · Cần ôn: 12            Hiểu ●●○ Nghe ●○○ Đọc ●●●│
  │                                                                  │
  │  ubiquitous  /juːˈbɪk.wɪ.təs/                            [🔊]   │
  │  ▸ (Đã lật): Phổ biến khắp nơi, có mặt ở mọi nơi                 │
  │                                                                  │
  │  [ 👁 Ẩn/Hiện nghĩa ]     [ ⏭ Từ tiếp (2/8) ]    [ 🚀 Ôn ngay ] │
  ╰──────────────────────────────────────────────────────────────────╯
  ```
- **Bảo vệ kiến trúc SM-2 (Quy tắc vàng #2 & `ADR-0001`):**
  - Ba chỉ báo kỹ năng **Hiểu · Nghe · Đọc** được vẽ tách biệt, tuyệt đối không cộng gộp thành 1 con số trung bình.
  - Thao tác ngoài màn hình chính là **Xem/Hồi tưởng chủ động (Passive/Active Preview)** trên bộ đệm 8–10 thẻ đến hạn đã trích sẵn trong `WidgetSnapshot`. Khi bấm **`🚀 Ôn ngay`** (1 chạm), app mở thẳng vào màn chấm điểm chuẩn `MemoryController` / `LearnByHeartHubScreen` để toàn bộ lịch SM-2 / FSRS chỉ đi qua **một hàm tính duy nhất trong Dart**.

---

### Widget 4 — `I4U Nhịp Điệu Học Tập` (Streak & 7-Day Activity Pulse)
- **Kích thước:** Nhỏ **`2×2`** (biểu tượng ngọn lửa lớn + chuỗi ngày + trạng thái hôm nay) · Vừa **`4×2`** (kèm biểu đồ cột 7 ngày thật).
- **Bố cục trực quan (`2×2` & `4×2`):**
  ```text
  ╭───────────────────────────╮   ╭──────────────────────────────────────────────────╮
  │  🔥 14 NGÀY               │   │  🔥 14 NGÀY LIÊN TIẾP         ✅ 18p đọc · 5 từ  │
  │  Chuỗi học liên tiếp      │   │                                                  │
  │                           │   │   ▂   ▅   ▃   ▇   ▄   ▆   █  (7 ngày qua: 6/7)  │
  │  ⏳ Chưa học hôm nay      │   │  19  20  21  22  23  24  [25]                    │
  │  [ ⚡ Học 2 phút giữ lửa ]│   │                        [ ⚡ Ôn 5 từ giữ nhịp → ] │
  ╰───────────────────────────╯   ╰──────────────────────────────────────────────────╯
  ```
- **Hành vi 1 chạm thông minh:** Nút CTA tự động đổi đích theo ngữ cảnh thật:
  - Hôm nay chưa học & có thẻ đến hạn → *«Ôn N từ giữ lửa»* (`in4up://action/review_due`).
  - Hôm nay chưa học & đang có sách đọc dở → *«Đọc tiếp 2 phút»* (`in4up://action/resume_read`).
  - Hôm nay đã hoàn thành → Mở Dashboard tiến độ.

---

### Widget 5 — `I4U Kệ Ghim Cá Nhân` & Lối tắt Hệ thống «1–2 Chạm»
Ngoài 4 widget thông tin động ở trên, một chuyên gia hàng đầu luôn tận dụng **3 cơ chế gốc cực nhẹ của hệ điều hành** để cho người dùng trải nghiệm **1 chạm cá nhân hoá tối đa**:

1. **Nút 📌 «Đưa ra màn hình chính» (Pinned Shortcuts — Android `ShortcutManagerCompat` / Configurable 1×1-2×2 Widget):**
   - Xuất hiện trong menu `⋮` của: **một file PDF/sách đang đọc**, **một chuỗi Pháp thoại**, **một bài Kinh Tipiṭaka**, **một bài Thuộc lòng**, hoặc **bất kỳ công cụ nào trong ngăn `Công Cụ` (`ToolsOverlayV2`)**.
   - Người dùng bấm *«Đưa ra màn hình chính»* → Hệ điều hành đặt ngay 1 icon riêng tên cuốn sách/phòng học đó lên màn hình chính → Từ hôm sau **chỉ đúng 1 chạm** là mở thẳng cuốn sách đó ở đúng trang đang đọc!
2. **App Icon Long-Press Shortcuts (Nhấn giữ biểu tượng In4Up ngoài màn hình):**
   - Không cần cài thêm bất kỳ widget nào: nhấn giữ icon In4Up hiện ngay 4 lối tắt nhanh:
     1. `🔍 Tra từ điển`
     2. `🎙️ Ghi chú nói`
     3. `📷 Quét tài liệu OCR`
     4. `🌱 Ôn từ đến hạn (N)` *(cập nhật động theo số thẻ thực tế!)*
3. **Android Quick Settings Tiles (Ô cài đặt nhanh trên thanh thông báo — Vuốt & Chạm từ MỌI ứng dụng):**
   - **Tile 1 — `I4U Dịch màn hình`:** Đang lướt trình duyệt, đọc tài liệu ngoại văn ở app khác → vuốt nhẹ thanh trạng thái bấm 1 cái là hiện ngay bong bóng `ScreenTranslateService` mà không cần thoát ra màn hình chính!
   - **Tile 2 — `I4U Tra từ / Ghi âm`:** Gọi nhanh tra cứu hoặc ghi chú nói xuyên ứng dụng.
4. **iOS Lock Screen & Control Center Widgets (iOS 16–18):**
   - Cụm widget phụ kiện trên Màn hình khoá iPhone: vòng tròn `🔥 14`, badge `💧 12 thẻ`, hoặc nút tròn 1 chạm mở thẳng Tra từ / Ghi chú nói.

---

## 4. Kiến trúc Kỹ thuật Chuẩn In4Up (An toàn, Nhẹ, 0 Dependency Rác)

### 4.1. Quyết định công nghệ: Tự chủ `MethodChannel('in4up/home_widget')` thay vì kéo gói ngoài

| Phương án | Phân tích kỹ thuật trong bối cảnh repo In4Up | Quyết định |
|---|---|---|
| Dùng plugin `home_widget` + Jetpack Glance | Kéo thêm dependency giải version với Dart `3.11.5`; Glance kéo cả Jetpack Compose Compiler + Runtime vào Gradle dễ xung đột Kotlin `17` / NDK `28` trên CI và làm tăng vài MB APK. Đằng nào giao diện Widget Android/iOS cũng bắt buộc viết native 100%. | ❌ **Loại** |
| **Thuần Dart `WidgetSnapshotBuilder` + `MethodChannel('in4up/home_widget')` + Android `RemoteViews` XML + iOS `WidgetKit` SwiftUI** | **0 dependency mới trong `pubspec.yaml` và `build.gradle.kts`!** Cùng triết lý đã thành công rực rỡ ở `ADR-0018` (`in4up/deeplink`) và `PLAN-047`. Nhẹ tuyệt đối (thêm `< 80 KB` mã biên dịch), chạy từ Android 7.0 (`minSdk 24`) đến Android 16 (`compileSdk 36`), test tự động 100% phần dựng dữ liệu & i18n bằng `flutter test` trên CI. | ✅ **CHỌN** |

### 4.2. Sơ đồ luồng dữ liệu một chiều «Widget Snapshot Mirror»

```text
┌────────────────────────────────────────────────────────────────────────────┐
│  TIẾN TRÌNH APP CHÍNH (Flutter / Dart)                                     │
│                                                                            │
│  VocabularyProvider ─┐                                                     │
│  MemoryController   ─┼─► WidgetSnapshotBuilder (Thuần Dart, Test 100%)     │
│  LearnByHeartProv.  ─┤     • Bảo toàn 3 trục SM-2 (Hiểu·Nghe·Đọc)          │
│  LearningActivity   ─┤     • Dịch sẵn nhãn UI qua AppUITranslations        │
│  Player / Dharma    ─┤       (chuẩn Rule #5: locale ≠ vi -> EN/bản địa)    │
│  Text / RecentFiles ─┘     • Giới hạn kích thước JSON ≤ 8 KB               │
│                                      │                                     │
│                         Debounce 800ms + AppLifecycle (paused/inactive)    │
│                                      ▼                                     │
│                     MethodChannel('in4up/home_widget')                     │
└───────────────────┬────────────────────────────────────┬───────────────────┘
                    │ Android                            │ iOS
                    ▼                                    ▼
┌───────────────────────────────────────┐  ┌─────────────────────────────────┐
│ SharedPreferences                     │  │ UserDefaults                    │
│ ("in4up_home_widgets_v1")             │  │ (suite: "group.<bundle_id>")    │
│   • widget_snapshot_json              │  │   • widget_snapshot_json        │
│   • flip_state / deck_index           │  └────────────────┬────────────────┘
└───────────────────┬───────────────────┘                   │
                    ▼                                       ▼
┌───────────────────────────────────────┐  ┌─────────────────────────────────┐
│ AppWidgetProvider (Kotlin + XML)      │  │ WidgetKit Extension (SwiftUI)   │
│   • Đọc JSON < 2ms (0 Flutter Engine) │  │   • TimelineProvider đọc JSON   │
│   • Lật/đổi thẻ tại chỗ qua Broadcast │  │   • iOS 17+ Button(intent:)     │
│   • Mở hành động qua PendingIntent    │  │   • Link(destination: in4up://) │
│     URI `in4up://action/...`          │  └─────────────────────────────────┘
└───────────────────────────────────────┘
```

### 4.3. Cấu trúc `WidgetSnapshot` (Versioned Schema `v1`, `< 8 KB`)

```json
{
  "schemaVersion": 1,
  "updatedAtEpochMs": 1795580000000,
  "locale": "vi",
  "labels": {
    "searchHint": "Tra từ điển In4Up...",
    "continueHeader": "TIẾP TỤC HỌC",
    "dueBadge": "12 từ đến hạn",
    "streakTitle": "14 ngày liên tiếp",
    "flipShow": "Hiện nghĩa",
    "flipHide": "Ẩn nghĩa",
    "reviewNow": "Ôn ngay",
    "skillUnderstand": "Hiểu",
    "skillListen": "Nghe",
    "skillRead": "Đọc"
  },
  "streak": {
    "days": 14,
    "activeToday": true,
    "todaySummary": "18 phút đọc · 5 từ",
    "weekBars": [0.2, 0.6, 0.35, 0.9, 0.45, 0.75, 1.0],
    "weekDayLabels": ["19", "20", "21", "22", "23", "24", "25"]
  },
  "resume": {
    "listen": {
      "title": "Pháp thoại B08 — Thiền Định",
      "subtitle": "23:15 / 54:00",
      "progress": 0.43,
      "isPlaying": false,
      "deepLink": "in4up://action/resume_listen?autoplay=1&src=widget"
    },
    "read": {
      "title": "Visuddhimagga.pdf",
      "subtitle": "Trang 47 / 812",
      "progress": 0.06,
      "deepLink": "in4up://action/resume_read?src=widget"
    }
  },
  "srs": {
    "dueVocabCount": 12,
    "dueLhbCount": 3,
    "deck": [
      {
        "id": "w_01",
        "word": "ubiquitous",
        "ipa": "/juːˈbɪk.wɪ.təs/",
        "meaning": "Phổ biến khắp nơi, có mặt ở mọi nơi",
        "example": "Smartphones have become ubiquitous in daily life.",
        "understandLevel": 2,
        "listenLevel": 1,
        "readLevel": 3
      }
    ]
  },
  "quickBarSlots": ["voice_capture", "ocr_scan", "screen_translate"]
}
```

> **Tại sao nhúng `labels` đã dịch sẵn vào JSON là chìa khoá kiến trúc cho In4Up?**
> Kho dịch chuẩn của In4Up (`AppUITranslations` + `generated_priority_native_pack.dart` cho `vi/en/hi/zh/zh_TW/si/my/th/ja`) nằm ở tầng Dart. Nhờ Dart dịch sẵn `labels` trước khi xuất snapshot và đặt fallback mặc định ở `android/app/src/main/res/values/strings.xml` bằng **tiếng Anh chuẩn** (chỉ `res/values-vi/strings.xml` dùng tiếng Việt), Widget tự động khớp 100% ngôn ngữ người dùng chọn trong In4Up và **tuân thủ tuyệt đối Rule #5 (`AGENTS.md`)** mà không phải bảo trì song song 8 bộ XML/Strings ở hai hệ điều hành.

### 4.4. Tiết kiệm Pin & Nhiệt độ tuyệt đối
- **Không dùng `Timer` chạy ngầm đánh thức máy:** `updatePeriodMillis` trong `appwidget_info.xml` đặt ở mức tối thiểu hợp lệ của Android (`1800000` ms = 30 phút, hoặc `86400000` ms cho thanh tĩnh) chỉ để đổi ngày mới lúc qua nửa đêm.
- **Chỉ cập nhật theo sự kiện thật (Event-Driven + Lifecycle Flush):**
  - Chỉ đẩy snapshot mới khi: (1) lưu/ôn xong từ, (2) đổi bài đọc/nghe hoặc bấm Play/Pause, (3) ghi `LearningActivityService.record()`, (4) đổi ngôn ngữ hoặc cấu hình nút nhanh, (5) app chuyển sang `AppLifecycleState.paused`.
  - Không bao giờ ghi đĩa theo mỗi khung hình thanh trượt tiến độ audio (tiết kiệm I/O flash và pin).
  - Kiểm tra `hasActiveWidgets()` ở Native trước: nếu người dùng chưa đặt widget nào ra màn hình chính thì việc cập nhật `RemoteViews` được bỏ qua ngay lập tức (`O(1)`).

---

## 5. Hợp đồng URI Điều hướng 1-Chạm (Mở rộng `ADR-0018`)

Mọi hành động từ Widget, App Shortcut và Quick Settings Tile đều quy về **một cổng kiểm tra an toàn thuần Dart duy nhất** (`AppDeepLink` mở rộng tương thích ngược 100% với `DictDeepLink`):

| URI (`in4up://` hoặc `i4u://`) | Hành vi 1-Chạm đích | Bảo vệ an toàn & UX |
|---|---|---|
| `in4up://dict?autofocus=1&src=widget` | Mở `DictionaryScreen` + **tự đặt con trỏ vào ô tìm & bật bàn phím ngay** | Nếu trên đỉnh Navigator đang là `DictionaryScreen` thì chỉ focus lại ô tìm, không push chồng màn thứ 2. |
| `in4up://dict?w=<từ>&src=widget` | Tra ngay từ cụ thể (đã có từ `ADR-0018`) | Giới hạn ≤ 64 rune, lọc ký tự điều khiển. |
| `in4up://action/voice_capture?autostart=1` | Đưa về Shell + mở `QuickCaptureSheet` + **bắt đầu thu âm STT ngay** | Nếu chưa cấp quyền Mic thì hiện hộp xin quyền chuẩn, không văng app. |
| `in4up://action/ocr_scan` | Chạy `OcrPrecheck.decide()` → mở thẳng máy quét ML Kit (Android) / chọn ảnh (iOS) | Giữ nguyên crash shield `OCR-SCAN-CRASH-001` cho máy thiếu GMS hoặc RAM < 1.7 GB. |
| `in4up://action/screen_translate` | *(Android)* Nếu đã đủ quyền overlay → bật bong bóng dịch; nếu thiếu → mở màn cấp quyền hướng dẫn rõ | Trên iOS/Desktop bị bỏ qua an toàn hoặc chuyển về dịch văn bản. |
| `in4up://action/ai_chat?autofocus=1` | Mở `AiChatScreen` sẵn sàng nhập câu hỏi | Kiểm tra trạng thái model/API sẵn có của `AiServiceFacade`. |
| `in4up://action/review_due?mode=srs\|lhb` | Nhảy thẳng vào phiên ôn tập `Vườn Trí Nhớ` hoặc `Thuộc Lòng` | Không bắt người dùng bấm thêm lần nữa ở Home. |
| `in4up://action/resume_read` | Mở lại tài liệu đọc gần nhất (`PdfReaderScreen` với `PdfFileIdentity` + trang, hoặc `ReadModeScreen` / `Tipitaka`) | Nếu tệp gốc đã xoá/mất quyền SAF → báo nhẹ và mở Thư viện Đọc (đúng tinh thần `AUDIT-1.21.0 #4`). |
| `in4up://action/resume_listen?autoplay=1` | Mở lại bài Audio / buổi Pháp thoại (`episodeKey`) gần nhất và phát tiếp từ vị trí đã lưu | Đi qua đúng `PlayerProvider` / `DharmaProvider` để giữ lịch sử & queue `PLAN-039`. |
| `in4up://nav/studio?target=<mode>` | Mở thẳng 1 trong 7 phòng (`read`, `write`, `listen`, `speak`, `watch`, `understand`, `remember`, `cabin`, `tipitaka`, `youtube`) | Whitelist cứng danh sách `target`, từ chối mọi giá trị lạ. |

---

## 6. Lộ trình Triển khai 5 Pha (Từ «Ăn ngay rủi ro thấp» đến «Hệ sinh thái hoàn chỉnh»)

Mỗi pha được thiết kế **tự đứng vững và phát hành độc lập được**, không bắt người dùng chờ làm hết cả 5 pha mới có tính năng dùng:

### Pha P0 — Nền móng Điều hướng 1-Chạm + App Shortcuts + Android Quick Settings Tile
- **Mục tiêu:** Chưa cần người dùng dọn chỗ màn hình chính đã có ngay trải nghiệm **1–2 chạm** từ icon ứng dụng và thanh trạng thái!
- **Hạng mục công việc:**
  1. Viết `ADR-0040` chốt hợp đồng URI `in4up://action/*`, `in4up://nav/*` và kiến trúc `WidgetSnapshot` không khởi chạy Flutter Engine.
  2. Mở rộng parser thuần Dart + router điều phối vào `MainShell`, `DictionaryScreen` (`autofocus`), `QuickCaptureSheet` (`autostart`), `OcrPrecheck`.
  3. Cập nhật `AndroidManifest.xml` + `MainActivity.consumeInitialDeepLink()` nhận thêm host `action` và `nav` (giữ nguyên tương thích `dict` và `open`).
  4. Khai báo **Static & Dynamic App Shortcuts** (Android `res/xml/shortcuts.xml` + iOS `Info.plist` `UIApplicationShortcutItems`): *Tra từ · Ghi chú nói · Quét OCR · Ôn từ đến hạn*.
  5. Thêm **Android `TileService`** cho *«I4U Dịch màn hình»* và *«I4U Ghi chú nói»* trên thanh Quick Settings.
- **Kiểm thử CI:** Unit test 100% ma trận URI tốt/xấu/lặp + test điều hướng idempotent không chồng màn hình.

### Pha P1 — Hạ tầng `WidgetSnapshot` + Widget #1 (`Thanh Lệnh Nhanh 4×1`) & Widget #4 (`Nhịp Điệu & Streak 2×2 / 4×2`) + Nút «Ghim ngay trong App»
- **Mục tiêu:** Đưa 2 widget có tỷ lệ sử dụng hàng ngày cao nhất ra màn hình chính Android, kèm nút bấm 1 chạm ghim widget từ trong app.
- **Hạng mục công việc:**
  1. Xây `lib/features/home_widgets/widget_snapshot_builder.dart` (thuần Dart, tích hợp dịch sẵn nhãn theo Rule #5 i18n) + `widget_sync_service.dart` (debounce + lifecycle hook).
  2. Đăng ký `MethodChannel('in4up/home_widget')` trong `MainActivity.kt` (hỗ trợ cả 3 flavor `stable`/`beta`/`dev`).
  3. Thiết kế `QuickBarWidgetProvider` (`4×1`, co giãn mượt lên `4×2`) và `StreakPulseWidgetProvider` (`2×2`, mở rộng lên `4×2` có biểu đồ 7 cột).
  4. Tạo màn cài đặt gọn **«Widget & Lối tắt màn hình chính»** (cho phép chọn 3 nút trên Thanh Lệnh Nhanh + nút **«Thêm ra màn hình chính»** gọi `AppWidgetManager.requestPinAppWidget`).
- **Kiểm thử CI:** Test `widget_snapshot_builder_test.dart` & `widget_snapshot_i18n_test.dart` (đảm bảo mọi locale `≠ vi` không bao giờ xuất hiện ký tự tiếng Việt trong snapshot JSON).

### Pha P2 — Widget #2 (`Tiếp Tục Học: Đọc & Nghe / Pháp thoại 4×2`)
- **Mục tiêu:** Giải quyết triệt để nhu cầu "1 chạm quay lại đúng trang sách / đúng phút bài giảng đang dở".
- **Hạng mục công việc:**
  1. Đồng bộ metadata bài đọc gần nhất (`RecentFilesService` / `TextProvider` / `PdfFileIdentity`) và bài nghe/Pháp thoại gần nhất (`RecentAudioService` / `DharmaProvider` / `PlayerProvider`) vào `WidgetSnapshot`.
  2. Xây `ContinueLearningWidgetProvider` (`4×2` và `2×2`) với xử lý chuẩn Android `targetSdk 35` cho nút `[▶/⏸]` (Warm toggle trong RAM vs Cold launch `autoplay=1`).
- **Kiểm thử nghiệm thu:** Đọc PDF tới trang 47 → đóng hẳn app → bấm Widget → mở đúng trang 47; đang nghe Pháp thoại ở phút `23:15` → đóng hẳn app → bấm `[▶]` trên Widget → phát tiếp đúng `23:15`.

### Pha P3 — Widget #3 (`Thẻ Từ & Vườn Trí Nhớ SRS Tương tác 2×2 / 4×2`)
- **Mục tiêu:** Biến màn hình chính thành không gian ôn từ thụ động & chủ động mỗi lần mở máy mà không hao pin.
- **Hạng mục công việc:**
  1. Xuất mini-deck tối đa 10 thẻ ưu tiên cao nhất (`MemoryController.dueItems` + tuỳ chọn chuyển sang `LearnByHeartProvider.dueItems`) kèm đủ 3 mức điểm **Hiểu · Nghe · Đọc** tách biệt.
  2. Xây `FlashcardWidgetProvider` hỗ trợ 2 thao tác tại chỗ không mở app: **`[👁 Hiện/Ẩn nghĩa]`** và **`[⏭ Qua từ tiếp]`** (lưu chỉ số thẻ hiện hành trong `SharedPreferences` của widget), cùng nút **`[🚀 Ôn ngay]`** mở thẳng phiên chấm điểm chuẩn trong app.

### Pha P4 — Tính năng 📌 «Đưa ra màn hình chính» theo Tài nguyên & iOS `WidgetKit` Extension
- **Mục tiêu:** Hoàn thiện cá nhân hoá sâu (ghim từng cuốn sách/bộ Pháp thoại/phòng Studio) và phủ trọn hệ sinh thái iOS / iPadOS.
- **Hạng mục công việc:**
  1. Thêm mục menu **📌 «Đưa ra màn hình chính»** (`ShortcutManagerCompat.requestPinShortcut`) tại thẻ sách PDF, danh mục Pháp thoại, sách Tipiṭaka, bài Thuộc lòng và các công cụ trong `ToolsOverlayV2`.
  2. Tạo target `In4UpWidgetsExtension` trên iOS (SwiftUI `WidgetKit` + `App Group` `group.$(PRODUCT_BUNDLE_IDENTIFIER)`):
     - Hỗ trợ `systemSmall`, `systemMedium` cho *Thanh Lệnh Nhanh*, *Tiếp Tục Học*, *Thẻ Từ SRS* (dùng `Button(intent:)` cho iOS 17+ lật thẻ trực tiếp) và *Streak*.
     - Bổ sung `accessoryCircular` / `accessoryRectangular` cho Màn hình khoá iOS.
     - Cập nhật workflow CI iOS signing / provisioning nếu bật App Group trên bản phát hành Apple Developer.

---

## 7. Ma trận Kiểm thử & Tiêu chí Nghiệm thu (Definition of Done)

1. **Tự động trên GitHub Actions CI (không cần máy ảo):**
   - `test/home_widgets/app_deep_link_test.dart`: kiểm chứng 100% URI hợp lệ, tham số biên, đường dẫn giả mạo `..`, scheme lạ, độ dài vượt ngưỡng, tính idempotent.
   - `test/home_widgets/widget_snapshot_builder_test.dart`: kiểm chứng trích xuất dữ liệu thật từ streak, thẻ SRS (đảm bảo 3 kỹ năng Hiểu–Nghe–Đọc không bị gộp), empty state trung thực, kích thước JSON `< 8 KB`.
   - `test/home_widgets/widget_snapshot_i18n_test.dart`: chạy qua toàn bộ `en`, `ja`, `hi`, `zh`, `zh_TW`, `si`, `my`, `th` xác nhận **0 ký tự tiếng Việt lọt vào chrome nhãn widget** (Rule #5).
2. **Nghiệm thu trên thiết bị thật (Checklist cầm máy cho Chủ dự án):**
   - Bấm từng nút trên Widget ở cả **2 trạng thái**: (a) App đang chạy ngầm (Warm) và (b) vừa Vuốt xoá App khỏi đa nhiệm / khởi động lại máy (Cold) → đều vào đúng màn hình trong 1 chạm, không màn hình đen, không crash `targetSdk 35`.
   - Kiểm tra cài song song bản `stable` (`com.in4up`) và `beta` (`com.in4up.beta`) trên cùng 1 máy Android → Widget của bản nào điều khiển đúng bản đó, không nhận nhầm broadcast.
   - Kiểm tra màn hình hẹp `360×640` và phóng chữ hệ thống `1.15×–1.3×` → chữ trên Widget cắt dòng (`ellipsize="end"`) gọn gàng, không đè nút, vùng chạm ≥ `48dp`.

---

## 8. Năm câu hỏi chốt nhanh dành cho Chủ dự án (Kèm đề xuất mặc định)

Để có thể bắt tay thi công ngay từ **Pha P0 + P1**, chủ dự án chỉ cần xác nhận (hoặc giữ nguyên mặc định chuyên gia đề xuất dưới đây):

- **Q1 — Nền tảng ưu tiên làm trước:** Thi công **Android trước ở P0–P3** (nơi có cả Bong bóng dịch màn hình, Quick Settings Tile, Pinned Shortcut và không vướng cấu hình Apple App Group provisioning trên CI), sau đó mở sang **iOS WidgetKit ở P4**? *(Đề xuất: **Đồng ý — Android trước**).*
- **Q2 — Ba nút mặc định trên «Thanh Lệnh Nhanh `4×1`»:** Cạnh ô `🔍 Tra từ điển`, 3 nút mặc định ban đầu cho người mới là **`🎙️ Ghi chú nói` · `📷 Quét OCR` · `🫧 Dịch màn hình`** (trên máy không hỗ trợ Dịch màn hình thì tự thay bằng `🤖 AI Chat`), và cho phép đổi trong Cài đặt? *(Đề xuất: **Đồng ý**).*
- **Q3 — Tương tác trên Widget «Thẻ Từ SRS»:** Chốt phương án **Lật xem nghĩa + Chuyển thẻ xem trước ngay trên màn hình chính (0 mở app)**, còn bấm **«Ôn ngay»** thì mở vào màn chấm điểm chuẩn trong app để bảo vệ tuyệt đối công thức SM-2 3 kỹ năng? *(Đề xuất: **Đồng ý — an toàn 100% cho lịch ôn SM-2/FSRS**).*
- **Q4 — Có làm thêm Quick Settings Tile (trên thanh kéo thông báo Android) ở ngay P0 không?** Vì In4Up đã có sẵn Bong bóng dịch màn hình và Ghi chú nói, thêm Tile trên thanh trạng thái chỉ tốn ~80 dòng Kotlin nhưng cực kỳ tiện khi đang mở app khác. *(Đề xuất: **Có làm luôn ở P0**).*
- **Q5 — Quy trình đưa vào nhánh DEV (`arena/01a0251e-in4up`):** Giữ nguyên kỷ luật tách PR/path-checkout sạch theo từng pha nhỏ (`P0` xong xanh CI + cầm máy ổn mới sang `P1`), không chạm `KANBAN.md`/`PLAN.md` trên nhánh con cho tới khi chốt hợp nhất? *(Đề xuất: **Đồng ý**).*
