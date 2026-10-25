# Bàn giao — YT-TTS-PROVIDER-001: mở video YouTube ⇒ màn hình trắng

**Báo cáo (owner, 2026-10-25):** build từ commit `027f4029` (nhánh `251e`) —
tìm kiếm YouTube xong, chọn một video ⇒ **màn hình trắng tinh**.

## Nguyên nhân gốc — hai class trùng tên `TtsService`

App có **hai** class cùng tên, ở hai thư mục khác nhau:

| File | Loại | Ai dùng |
|---|---|---|
| `lib/features/tts/tts_service.dart` | `class TtsService extends ChangeNotifier` — bộ máy TTS thật, `factory TtsService() => _instance` (singleton) | tab Đọc (qua `FlutterTtsServiceImpl`), Code YouTube mới |
| `lib/screens/read_mode/services/tts_service.dart` | `abstract class TtsService` — interface | `main.dart` đăng ký **type này** |

`lib/main.dart`:
```dart
import 'screens/read_mode/services/tts_service.dart';   // ← type ABSTRACT
...
Provider<TtsService>(create: (_) => FlutterTtsServiceImpl()),
```

Code của Đợt 5 (`yt_player_screen.dart`) lại import bên kia và đọc qua Provider:
```dart
import '../../features/tts/tts_service.dart';           // ← type CHANGENOTIFIER
...
_readAloud = YtReadAloudController(context.read<TtsService>());   // initState
...
context.read<TtsService>(),                                      // mở sheet đọc
```

Provider tra theo **đúng `Type`**. Hai class trùng tên nhưng là hai `Type` khác
nhau ⇒ `ProviderNotFoundException` ném ra **ngay trong `initState()`** ⇒ cả
`YtPlayerScreen` không dựng được ⇒ người dùng chỉ thấy khung trắng, **không có
log nào hiện trên UI**.

Không liên quan gì tới WebView, mạng, hay wrapper GitHub Pages — nên mọi "thử
mạng / đổi video / xoá cache WebView" đều vô ích.

## Cách sửa

Không đọc `TtsService` qua Provider nữa; dùng **singleton** `TtsService()`:

```dart
late final TtsService _tts = TtsService();          // singleton của features/tts
...
_readAloud = YtReadAloudController(_tts);           // initState
...
showYtReadAloudSheet(context, _settings, _tts, hasTranslation: ...);
```

Dùng singleton **không** làm mất tính năng: `FlutterTtsServiceImpl` (thứ mà
Provider trả về cho tab Đọc) cũng bọc đúng singleton đó
(`_appTts = appTts ?? app_tts.TtsService()`), nên giọng/engine/tốc độ/ưu tiên
online-offline vẫn **dùng chung** giữa tab Đọc và màn YouTube.

Kèm theo: `YtReadAloudController.dispose()` chỉ `stop()` TTS khi **chính nó**
đang đọc — trước đó dừng vô điều kiện, sẽ cắt ngang việc đọc của tab Đọc (vì
giờ là singleton dùng chung).

## Máy bắt (test) — `test/yt_tts_provider_collision_test.dart`

Khoá cả 3 vế, để lần sau không ai "sửa lại cho gọn" rồi tái phát:

1. `features/tts.TtsService` **≠** `read_mode.TtsService` (hai `Type` khác nhau).
2. `main.dart` **phải** đăng ký type `read_mode` (`Provider<TtsService>(`) — nếu
   ai đổi, test đỏ và buộc đọc lại chú thích.
3. Quét toàn bộ `lib/features/youtube/**`: **không được** có
   `read<TtsService>` / `watch<TtsService>`; player phải dùng
   `late final TtsService _tts = TtsService();` và truyền `_tts` cho cả
   controller lẫn sheet.
4. Hợp đồng singleton: `_instance` + `factory TtsService() => _instance` phải
   còn — controller dựa vào đó để chung giọng với tab Đọc.

Chú thích trong code cũng bị bỏ trước khi quét (vì chính chú thích giải thích
lỗi có nhắc chuỗi đó).

## Bài học áp dụng cho chỗ khác

* Có **hai class trùng tên** trong repo ⇒ mọi `context.read<X>()` phải đối chiếu
  với `main.dart` xem **type nào** được đăng ký. Trước đây `TextProvider` /
  `PlayerProvider` may mắn vì chỉ có một class mỗi loại.
* Một exception trong `initState()` biểu hiện ra ngoài **không phải** màn hình
  lỗi có chữ, mà là **khung trắng** — khi owner báo "trắng tinh", nghi ngay
  Provider/`late` chưa khởi tạo trong `initState`, chứ không phải WebView.
