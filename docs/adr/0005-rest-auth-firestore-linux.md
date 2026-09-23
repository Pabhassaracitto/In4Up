# ADR-0005: Linux auth + sync qua Firebase REST API (fallback khi FlutterFire không có plugin native)

- **Ngày:** 2026-09-23
- **Trạng thái:** ĐÃ TRIỂN KHAI trên `arena/01a0ca82-in4up`; chờ CI build Linux +
  nghiệm thu trên máy Linux thật (đăng nhập Google + sync từ vựng 2 chiều).
- **Phạm vi:** thêm mới `lib/services/firebase_rest_auth.dart`,
  `lib/services/firestore_rest_client.dart`; sửa `lib/services/auth_service.dart`,
  `lib/services/vocab_sync_service.dart`, `lib/screens/home/home_screen.dart`,
  `lib/main.dart`, `lib/providers/vocabulary_provider.dart`. **Không thêm dependency
  mới** (`http`, `hive_flutter` đã có), không đổi schema dữ liệu Firestore.

## Bối cảnh

FlutterFire (firebase_core / firebase_auth / cloud_firestore) không phát hành
implementation native cho **Linux**. Hệ quả trên bản Linux hiện tại:

1. `Firebase.initializeApp()` văng `MissingPluginException` → `_initializeFirebaseSafely()`
   nuốt lỗi, `isFirebaseAvailable = false`, `Firebase.apps` rỗng.
2. `_FirebaseAuthButton` (tab Home) có guard `Firebase.apps.isEmpty` → thay nút đăng
   nhập bằng icon ⚡ xám không bấm được — "không thấy chỗ đăng nhập ở tab Home".
3. `VocabSyncService.initialize()` early-return khi `!hasDb` → sync từ vựng tắt hoàn toàn.

Ba lựa chọn:

1. **Chấp nhận offline trên Linux** — đơn giản nhưng mất hẳn tính năng đăng nhập +
   sync trên nền tảng đó.
2. **Dùng SDK pure-Dart bên thứ ba** (vd `firebase_dart`) — thêm dependency lớn, không
   phải distribution chính thức, rủi ro bảo trì.
3. **Tự viết REST client mỏng trên API công khai chính thức của Firebase** — Identity
   Toolkit (`signInWithIdp`), Secure Token (`token`), Firestore v1 REST (`documents:commit`,
   `documents:runQuery`). Không plugin, không dependency mới.

## Quyết định

Chọn **(3)**, với nguyên tắc "fallback trong suốt, không đổi hành vi nền tảng khác":

- **Phát hiện backend:** `AuthService.isPluginAuthAvailable` (try `FirebaseAuth.instance.app`)
  — true trên Android/iOS/macOS/Windows/Web, false trên Linux. Tất cả consumer đi qua
  facade thống nhất (`authStateChanges`, `currentUserInfo`, `signInWithGoogle`,
  `signOut`, `getIdToken`), không chạm `FirebaseAuth.instance` trực tiếp nữa.
- **Auth Linux:** tái dùng nguyên vẹn OAuth browser flow có sẵn
  (`_signInWithGoogleDesktop`: localhost callback + code exchange) — chỉ khác bước cuối:
  `POST identitytoolkit…/accounts:signInWithIdp` với Google ID token thay vì
  `signInWithCredential`. User nhận được **cùng uid** với Android/Windows (cùng project
  vipsound-df903) → dữ liệu về đúng tài khoản.
- **Token lifecycle:** refresh token + profile lưu Hive box `firebase_rest_auth`;
  `getIdToken()` cache với margin 2 phút, hết hạn thì `POST securetoken…/token`;
  HTTP 400 khi refresh → kết thúc phiên (đăng xuất), lỗi mạng → giữ phiên optimistic.
- **Sync Linux:** `VocabSyncService` giữ nguyên đường plugin; thêm nhánh
  `_useRestSync = !hasDb` (`_flushPendingRest` / `_pullRest`):
  - Push: `documents:commit` chunk 200 doc/commit (mỗi doc = 1 write `update` + 1 write
    `transform` `REQUEST_TIME` cho `_syncedAt` — tương đương `FieldValue.serverTimestamp()`,
    đúng loại kiểu Timestamp để Android/Windows đọc lại được).
  - Pull: có checkpoint → `documents:runQuery` filter `_syncedAt > checkpoint`
    (tương đương `where(isGreaterThan:)` của plugin); không checkpoint/forceAll →
    list collection có pagination.
  - Quy tắc hòa giải giữ nguyên: "bản ghi có `updatedAt` mới hơn thắng", tách thành
    `_applyPulledDoc` dùng chung cả 2 nhánh.
- **Value codec:** chuyển đổi 2 chiều Dart JSON ↔ Firestore REST fields
  (`stringValue`/`integerValue`/`timestampValue`/…) tương thích với dữ liệu plugin đã ghi.
- **Robustness desktop:** `connectivity_plus` có thể không có implementation Linux →
  `_hasNetwork()` try/catch, mặc định coi như online (HTTP tự fail, pending queue giữ nguyên).
  `authStateChanges` của REST tự implement semantics "mỗi subscriber nhận trạng thái
  hiện tại ngay khi subscribe" giống plugin (stream per-subscriber + fan-out).

## Hệ quả

- **Nút đăng nhập xuất hiện lại trên Linux** (icon 👤 → browser OAuth → avatar + logout),
  sync từ vựng bật/tắt theo auth state qua listener thống nhất ở `main.dart`.
- **Không realtime push trên Linux** (REST không có stream như gRPC của plugin): pull
  chạy lúc mở app / bật sync / khi có connectivity event; push chạy qua pending queue
  debounce 5s như cũ. Chấp nhận được với use case 1 người dùng offline-first.
- **Text library cloud (text_library_service) vẫn offline trên Linux** — ngoài phạm vi
  ADR này; `_isFirebaseLoggedInSafe` trong text_library_drawer vẫn check plugin (trung
  thực: chưa có đường REST cho Firestore streaming của text library).
- **Bảo mật:** refresh token nằm trong Hive (plaintext) như toàn bộ dữ liệu app; nếu
  cần nâng cấp thì thêm `flutter_secure_storage` (libsecret) sau.
- **OAuth desktop cần env** `GOOGLE_DESKTOP_CLIENT_ID/SECRET` — CI Linux đã truyền sẵn
  qua dart-define từ secrets.
