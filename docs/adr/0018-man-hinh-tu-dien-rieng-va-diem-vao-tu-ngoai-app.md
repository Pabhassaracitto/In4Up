# ADR-0018: Một màn hình Từ điển riêng + 4 đường vào từ ngoài app

- **Ngày:** 2026-10-27
- **Trạng thái:** ĐÃ CHỐT — **P1 đã có mã nguồn** (2026-10-27). P2/P3/P4 chưa làm.
  Ghi chú lệch so với bản đề xuất: màn hình đặt ở `widgets/` (không phải
  `screens/` — xem "Cập nhật khi làm P1" ở cuối), và gợi ý dùng API mới
  `DictionaryService.suggest()`, không phải `lookupPrefix()`.
- **Phạm vi dự kiến:**
  `lib/features/dictionary/widgets/dictionary_screen.dart` (mới),
  `lib/features/dictionary/services/dict_deep_link.dart` (mới, thuần Dart),
  `lib/features/dictionary/widgets/*` (tái dùng, không viết lại),
  `lib/screens/main_shell.dart` (`_openTool` thêm `dictionary` → màn mới),
  `lib/main.dart` (bắt link khởi động + stream),
  `android/app/src/main/AndroidManifest.xml` + `MainActivity.kt`,
  `ios/Runner/Info.plist` + `AppDelegate.swift`,
  `windows/runner/main.cpp` → Dart đọc `entrypointArguments`,
  `linux/`, `pubspec.yaml` (1 phụ thuộc: `app_links`), `test/dictionary/dict_deep_link_test.dart`.

## Bối cảnh

Owner (2026-10-27) hỏi ba việc liền nhau:

1. "cách hiển thị từ điển đã ok chưa?" → đã trả lời bằng bản vá
   DICT-I18N-001 / DICT-VIEW-003 (xem KANBAN).
2. Có nên làm **màn hình Từ điển riêng** để sau này có **bong bóng nổi**
   (tra từ ở bất kỳ app nào) và để **app/browser khác gọi ngược** vào từ
   điển của In4Up?
3. Làm sao để **file** có tuỳ chọn "Mở bằng In4Up"?

Hiện trạng kỹ thuật (đã kiểm tra trong repo, không suy đoán):

| Thứ cần cho (2) và (3) | Hiện có? | Bằng chứng |
| --- | --- | --- |
| Màn hình tra cứu (có ô tìm, gợi ý, lịch sử) | **Không** | chỉ có `DictManagerScreen` (kiểu trang cài đặt: danh sách bộ từ điển + import) |
| API gợi ý theo tiền tố | **Có nhưng chưa ai gọi** | `DictionaryService.lookupPrefix(prefix, limit:)` (dictionary_service.dart:102) |
| Đường vào chung `lookup(word) → trang` | **Không** | mỗi nơi tự gọi: `DictResultSheet.show` (read_text_action_runner.dart:204), `DictEntryDetailSheet.show` (pdf_word_tap_sheet.dart:115, word_analysis_sheet.dart:266) |
| Deep link `in4up://` | **Không** | `pubspec.yaml` không có `app_links`/`uni_links`/`go_router`; `AndroidManifest.xml` chỉ có `VIEW audio/*` cho `MainActivity` |
| Nhận chữ từ app khác (`ACTION_PROCESS_TEXT`) | **Không** | manifest không có filter `text/plain` |
| Bong bóng nổi | **Có hạ tầng, dùng cho dịch màn hình** | `ScreenTranslatePlugin.kt`, `TranslationOverlayView.kt`, quyền `SYSTEM_ALERT_WINDOW` đã khai |
| Mở file bằng In4Up | **Không** | iOS `Info.plist` **không** có `CFBundleDocumentTypes`; `MainActivity` **không** có `onNewIntent`/`getIntent`; `windows/runner/main.cpp:43-46` truyền `argv` vào `set_dart_entrypoint_arguments` nhưng **Dart không đọc** |
| Web | không đăng ký được handler hệ điều hành | giới hạn của trình duyệt ⇒ chỉ chia sẻ RA ngoài |

Vì sao cần **một** màn hình thay vì 4 đường vào riêng lẻ: mỗi đường vào
(deep link, PROCESS_TEXT, bong bóng, mở file) chỉ là một cách **đưa một
chuỗi/tệp vào app**. Nếu mỗi đường tự dựng UI riêng thì sẽ có 4 kiểu hiển
thị khác nhau, 4 chỗ xử lý lỗi "chưa có bộ từ điển", 4 chỗ lưu lịch sử.
Một màn hình + một hàm `open(context, word)` biến 4 đường vào thành 4
**adapter mỏng**.

## Quyết định

### 1. `DictionaryScreen` là đích duy nhất của mọi tra cứu

Màn hình gồm: ô tìm kiếm (gõ là gợi ý qua `DictionaryService.suggest`,
debounce 220 ms), chip chọn bộ từ điển đang bật, 30 từ tra gần nhất (lưu
`SharedPreferences`, khoá `dict_screen_history_v1`), và **thân trang dùng lại
`DictDefinitionView`** (`compact: false`, `light: true` khi nền sáng) — không
viết lại renderer.

Điểm vào công khai (duy nhất):

```dart
// lib/features/dictionary/widgets/dictionary_screen.dart
static Future<void> open(
  BuildContext context, {
  String? query,   // từ cần tra ngay khi mở
  String? source,  // home | pdf | read | deep_link | file | bubble | unknown
});
```

`source` chỉ để ghi nhật ký/lịch sử ("pdf", "read", "deep_link", "file",
"bubble"), KHÔNG đổi cách hiển thị.

Các màn hiện có **không bị xoá**: sheet nhỏ trong PDF/Read vẫn giữ (owner
đã chốt "không modal, không che nội dung" ở ADR-0016) — chúng chỉ thêm
một nút "Mở trang từ điển" gọi `DictionaryScreen.open(...)`.

### 2. Deep link: một bộ phân tích thuần Dart, không thêm router

Schema:

```
in4up://dict?w=ubiquitous            # tra một từ
in4up://dict?w=h%E1%BB%8Dc%20sinh    # có dấu cách → bắt buộc percent-encode
in4up://open?path=/sdcard/x.mdx      # mở một tệp (mục 4)
```

`DictDeepLink.parse(String raw, {String source})` trả về
`DictDeepLinkRequest?` (`kind: word|file`, `value`, `source`) — **thuần Dart**,
không phụ thuộc `BuildContext` và **không bao giờ ném**. Nhờ vậy link từ
web/desktop/Android/iOS dùng chung một chỗ kiểm tra an toàn.
`DictDeepLink.parseArguments(argv)` làm việc đó cho `argv` của Windows/Linux.

Bảo mật: chỉ chấp nhận `w` ≤ **64** ký tự (đếm theo rune để không cắt giữa ký
tự Unicode), bỏ ký tự điều khiển; với `path` chỉ chấp nhận tệp do chính app mở
được (`.mdx`, `.mdd`, `.pdf`, `.txt`, `.md`, `.markdown`, `.epub`), từ chối mọi
đường dẫn có `..`. Không nhận `*/*`.

Không chọn `go_router`: app dùng `Navigator` trần ở `lib/main.dart`
(3 `MaterialApp`), thêm router là đổi kiến trúc điều hướng toàn app — quá
đắt cho một nhu cầu "mở đúng một màn". Không chọn `uni_links` (không còn
được bảo trì tích cực, không hỗ trợ Windows/Linux).

**Đã đổi so với bản đề xuất: KHÔNG dùng `app_links`** (xem "Cập nhật P1 phần 2"
ở cuối) — dùng khuôn MethodChannel sẵn có của repo (`in4up/deeplink`), zero phụ
thuộc mới.

### 3. Bốn giai đoạn (mỗi giai đoạn tự đứng được)

| # | Việc | Nền tảng | Giá trị | Phụ thuộc |
| --- | --- | --- | --- | --- |
| **P1** | `DictionaryScreen` + `DictDeepLink` + `in4up://dict` | Android, iOS, Windows, Linux | có chỗ để tra tử tế (ô tìm + gợi ý + lịch sử); link từ web/Zalo/Telegram mở được app | không |
| **P2** | `ACTION_PROCESS_TEXT` (bôi đen chữ ở app khác → "In4Up") + Share Extension iOS | Android (dễ), iOS (vừa) | tra từ ngay trong lúc đọc app khác, không cần chuyển app | P1 |
| **P3** | Mở tệp bằng In4Up (mục 4) | Android, iOS, Windows, Linux | "Open with In4Up" trong trình quản lý tệp | P1 |
| **P4** | Bong bóng nổi tra từ | **chỉ Android** (thực tế) | tra từ trên mọi màn hình, kể cả web | P1 + P2 |

P4 dùng lại đúng khuôn `ScreenTranslate*`: một `Service` giữ bong bóng +
`SYSTEM_ALERT_WINDOW` + một `OverlayView` nhỏ (ô nhập + kết quả gọn).
Khác biệt duy nhất so với bong bóng dịch: **không** cần `MediaProjection`
(không chụp màn hình) ⇒ chỉ cần `foregroundServiceType="specialUse"`, nhẹ
hơn và ít rủi ro pin hơn. Kết quả trong bong bóng là bản rút gọn từ
`DictTextCleaner.merge(...)`; bấm "Mở rộng" → `DictionaryScreen.open`.

iOS: **không hứa** bong bóng nổi. Hệ điều hành không cho app vẽ đè app
khác. Đường tương đương là **bàn phím tuỳ biến** (tra từ ngay trong bàn
phím) — đắt, cần Full Access, và phải giải thích quyền riêng tư; để sau,
chỉ làm nếu owner thật sự cần.

### 4. "Mở bằng In4Up" — từng nền tảng

| Nền tảng | Cần khai báo | Cần mã | Ghi chú |
| --- | --- | --- | --- |
| **Android** | thêm `<intent-filter>` cho `MainActivity`: `VIEW` + `DEFAULT` + `BROWSABLE` với `scheme="in4up"` `host="dict"`; và `VIEW` + `DEFAULT` + `CATEGORY_OPENABLE` cho `application/pdf`, `text/plain`, `application/epub+zip`, `application/octet-stream` kèm `pathPattern=".*\\.(mdx|mdd)"` + `mimeType="application/x-mdx"` | `MainActivity.onNewIntent` + đọc `getIntent()` lúc khởi động ⇒ gọi MethodChannel `in4up/deeplink` | Đang có sẵn `singleTop` + `taskAffinity=""` nên **không** tạo task mới — đúng ý |
| **iOS** | `CFBundleDocumentTypes` (role `Viewer`, `LSHandlerRank="Alternate"`), `UTImportedTypeDeclarations` cho `mdx`/`mdd`, `LSSupportsOpeningDocumentsInPlace=true`, `CFBundleURLTypes` thêm scheme `in4up` | `AppDelegate` → `application(_:open:options:)` và `application(_:openURL:options:)` → MethodChannel | `Alternate` để **không** cướp PDF của app khác |
| **Windows** | không cần (argv đã được truyền) | Dart đọc `PlatformDispatcher`? **Không** — phải đọc `main(List<String> args)` (`windows/runner/main.cpp` đã `set_dart_entrypoint_arguments`) | Cài đặt "Open with" phải qua registry/installer — chỉ làm khi có installer; trước mắt dùng `in4up.exe "C:\\x.mdx"` |
| **Linux** | file `.desktop`: `MimeType=application/pdf;text/plain;application/epub+zip;` + `Exec=in4up %f` | đọc `args` trong `main` | `.tar.gz` hiện không có `.desktop` ⇒ phải thêm khi đóng gói |
| **macOS** | `CFBundleDocumentTypes` + entitlement `com.apple.security.files.user-selected.read-only` | như iOS | chưa có job build macOS |
| **Web** | không thể | — | Chỉ hỗ trợ chia sẻ **ra** (`navigator.share`) — dùng cho "gửi từ đang chọn sang In4Up" |

Nguyên tắc: **không** nhận `*/*`. Chỉ nhận đúng đuôi/mime cần thiết, nếu
không thì menu "Mở bằng" của người dùng sẽ bị In4Up chiếm chỗ cho mọi tệp.

## Hệ quả

**Được:** một chỗ sửa giao diện từ điển là mọi nền tảng cùng đổi; thêm
đường vào mới chỉ là ~30 dòng adapter; lịch sử/gợi ý dùng chung; bong bóng
tái dùng hạ tầng overlay đã có test thực địa.

**Mất / rủi ro:**

- Thêm 1 phụ thuộc (`app_links`). Rủi ro build: **trung bình** — cần build
  lại cả 4 nền tảng; nếu vỡ, quay lại bằng cách bỏ `app_links` và chỉ dùng
  MethodChannel tự viết (Android/iOS) + argv (desktop).
- Android 12+ : custom scheme `in4up://` vẫn được, nhưng từ Android 12 nếu
  muốn link **https** mở app thì cần `assetlinks.json` trên domain ⇒ chưa
  làm, và **không** cần cho mục đích này.
- Bong bóng nổi xin `SYSTEM_ALERT_WINDOW` — người dùng phải tự bật trong
  Cài đặt; phải có màn hướng dẫn + nút mở thẳng (đã có
  `openOverlaySettings` trong `ScreenTranslatePlugin`).
- Mở tệp `.mdx` từ ngoài = **import** chứ không chỉ đọc: phải hỏi "nhập bộ
  từ điển này?" trước khi ghi vào DB, tránh việc một tệp lạ tự thêm dữ liệu.

## Việc phải làm (khi owner chốt)

1. `dict_deep_link.dart` + `test/dictionary/dict_deep_link_test.dart` (thuần
   Dart, chạy được cả khi CI không có máy ảo).
2. `dictionary_screen.dart` + `DictionaryScreen.open`; thay `case 'dictionary'`
   và `case 'dict_manager'` trong `_openTool` (main_shell.dart:1125) để mở
   màn mới; giữ `DictManagerScreen` làm màn con ("Quản lý bộ từ điển").
3. `app_links` + `MethodChannel in4up/deeplink` cho Android/iOS.
4. Manifest/Info.plist/`.desktop`/argv như bảng trên.
5. Chỉ sau khi 1–4 xong mới làm P4 (bong bóng).


## Cập nhật khi làm P1 (2026-10-27)

Những chỗ **thực tế khác bản đề xuất** — ghi lại để lần sau không phải dò lại:

| Đề xuất | Thực tế | Vì sao |
| --- | --- | --- |
| `features/dictionary/screens/dictionary_screen.dart` | `features/dictionary/widgets/dictionary_screen.dart` | Module từ điển **không có** thư mục `screens/`; mọi màn của module nằm trong `widgets/` (`dict_manager_screen.dart`, `dict_pack_screen.dart`). Thêm thư mục chỉ để khớp ADR là chia đôi quy ước. |
| Gợi ý qua `lookupPrefix()` | `DictionaryService.suggest(prefix, {limit, dictId})` (mới) | `lookupPrefix()` **dừng ở bộ từ điển đầu tiên có kết quả** (đúng cho autocomplete 1 dòng). Người dùng cài 2 bộ (Anh–Việt + Anh–Anh) sẽ chỉ thấy gợi ý của bộ đứng đầu. Bản mới gộp **mọi** bộ đang bật, khử trùng không phân biệt hoa/thường, giữ thứ tự ưu tiên manifest. `lookupPrefix()` giữ nguyên cho chỗ đang dùng. |
| Debounce 150 ms | 220 ms | Gõ tiếng Việt có dấu cần thêm thời gian cho tổ hợp phím; 220 ms vẫn dưới ngưỡng cảm nhận ~250 ms. |
| 20 từ lịch sử, "3 khoá/1 dòng tuỳ chọn" | 30 từ, **một** khoá `dict_screen_history_v1` (`List<String>`) | Ba khoá/1 dòng là dư thừa: lịch sử chỉ là danh sách chuỗi. Thêm `DictHistory` (thuần Dart) để test được phần thứ tự/khử trùng/giới hạn mà không cần plugin. Chỉ lưu từ **tra được** — lịch sử toàn từ không tìm thấy thì vô dụng. |
| `open(context, word)` tham số vị trí | `open(context, {query, source})` | `word` là **tuỳ chọn**: mở từ Home (không có từ nào) phải dùng cùng một hàm, không cần biến thể thứ hai. |
| Chip lọc bộ từ điển | có, nhưng chỉ hiện khi **> 1** bộ | Một bộ thì chip "Tất cả" chỉ chiếm chỗ. |

### Nghiệm thu P1 (đã xanh trên CI)

- `test/dictionary/dict_history_test.dart` — thứ tự, khử trùng, giới hạn, lọc, không sửa list gốc.
- `test/dictionary/dict_suggest_test.dart` — `suggest()` gộp **cả hai** bộ + khử trùng + `limit` + `dictId` + tiền tố rỗng; `lookup(word, dictId:)` lọc đúng một bộ, không truyền thì gộp.
- `flutter analyze` sạch (chỉ ERROR là fatal).

**Bài học CI (đừng lặp lại):** một `testWidgets` có sqflite/`SharedPreferences`
thật **treo** trên runner (run 40575300780 chạm trần 25 phút của job và bị
cancel, đúng lớp sự cố đã ghi cho `workspace_shell_integration_test.dart`).
Vì vậy màn hình hiện **không** có test widget tự động; muốn có lại thì phải
thêm seam bơm dữ liệu cho `DictionaryScreen` để test không cần plugin thật
(ghi ở KANBAN mục "việc còn lại").


## Cập nhật P1 phần 2 — deep link (2026-10-27)

Đã làm (`arena/929f549e-in4up`): `DictDeepLink` + `DictDeepLinkRouter` + native
Android/iOS + đọc `argv` trên desktop. CI 🟢 run **40590420956** /
**40590413726** (+ web build **40590413795**).

| Đề xuất | Thực tế | Vì sao |
| --- | --- | --- |
| Dùng plugin `app_links` | **Không thêm phụ thuộc nào** — MethodChannel `in4up/deeplink` | Repo đã có khuôn MethodChannel cho 4 kênh (`in4up/audiolib`, `in4up/textlib`, `in4up/dictionary`, `in4up/ocr`) ⇒ phần native chỉ ~40 dòng. Thêm một phụ thuộc nghĩa là thêm một version phải giải trên CI mỗi lần build, cộng rủi ro plugin chậm cập nhật khi Flutter đổi API nhúng. |
| `DictDeepLink.parse(Uri)` trả record `(word, path, source)` | `DictDeepLink.parse(String, {source})` trả `DictDeepLinkRequest?` | Đầu vào thật là **chuỗi** (`intent.dataString`, `url.absoluteString`, `argv[i]`); nhận `String` để một chỗ xử lý được cả `C:\x.mdx` (thứ `Uri.parse` hiểu nhầm thành scheme `c`) và `file://`. |
| `open(context, word)` cho mọi nơi | thêm `DictionaryScreen.route({query, source})` | Cầu nối chỉ có `navigatorKey.currentState` — `Navigator.of(navigator.context)` không tìm thấy chính nó. `open()` nay dùng chung `route()` ⇒ vẫn **một** định nghĩa màn hình. |
| iOS `CFBundleDocumentTypes` cho mdx/mdd | **chưa** (thuộc P3) | P1 chỉ cần nhận URL scheme; khai kiểu tài liệu mà chưa xử lý tệp sẽ làm In4Up xuất hiện trong "Mở bằng" rồi không làm gì. |
| Mở tệp (P3) | `DictDeepLinkRouter.deferredFiles` giữ yêu cầu | Bóc link tệp đã an toàn nhưng luồng mở tệp chưa có ⇒ giữ lại thay vì nuốt lặng. |

**Nghiệm thu P1 phần 2**

- `test/dictionary/dict_deep_link_test.dart` — 25 ca thuần Dart: link tốt, 4 tên
  khoá (`w`/`word`/`q`/`text`), percent-encode tiếng Việt, host rỗng, scheme
  `i4u`, `https://in4up.app/dict`; ca xấu (thiếu `w`, host/scheme lạ, từ > 64,
  ký tự điều khiển, chuỗi rỗng, `..`, đuôi `.apk`/`.mkv`), `argv`, `file://`,
  đường dẫn Windows.
- Máy thật: `adb shell am start -a android.intent.action.VIEW -d "in4up://dict?w=ubiquitous"`
  → mở đúng từ; Windows: `in4up.exe "in4up://dict?w=ubiquitous"`.

**Chưa kiểm được trong sandbox:** biên dịch Kotlin/Swift (CI chỉ chạy analyze +
`flutter test` + build web) ⇒ phần native cần một lần build thật (Android/iOS)
trước khi phát hành.

## Phương án đã cân nhắc và loại

- **Dùng `receive_sharing_intent`:** chỉ làm share-in, không làm deep link
  hay mở tệp ⇒ vẫn phải thêm 2 cơ chế nữa. `PROCESS_TEXT` trên Android
  còn tốt hơn share cho việc "bôi đen → tra từ" vì không mở hộp thoại chia sẻ.
- **Nhúng từ điển vào bong bóng dịch sẵn có:** bong bóng dịch đang gắn với
  `MediaProjection` + engine dịch; ghép sẽ khiến xin quyền chụp màn hình chỉ
  để tra từ. Tách riêng service nhẹ hơn.
- **Web link `https://in4up.app/dict?w=`:** cần domain + `assetlinks.json`;
  hoãn, nhưng `DictDeepLink.parse` đã chấp nhận cả `https` để sau này chỉ
  cần thêm file tĩnh.

## Nghiệm thu

- Gõ `adb shell am start -a android.intent.action.VIEW -d "in4up://dict?w=ubiquitous"` → mở đúng từ.
- Bôi đen một từ trong Chrome → menu ⋮ → "In4Up" → mở đúng màn hình với từ đó (P2).
- Trình quản lý tệp → chọn `.mdx` → "Mở bằng" → In4Up → hỏi nhập bộ từ điển (P3).
- Bong bóng: bật quyền, mở app khác, bấm bong bóng, nhập từ → có nghĩa gọn; "Mở rộng" → `DictionaryScreen` (P4).
- Test đơn vị `dict_deep_link_test.dart`: URL xấu/thiếu `w`/quá dài/`path` lạ ⇒ trả `null`, không ném.
