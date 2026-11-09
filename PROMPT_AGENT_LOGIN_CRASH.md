# Prompt giao việc — (P0) Màn đăng nhập nhấn là VĂNG app (LOGIN-CRASH-002)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. Đây là mục
**P0 — vốn liếng người dùng** (đăng nhập = đồng bộ dữ liệu).

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; **không** đổi nhánh. PR nhắm **`251e`**
  (`arena/01a0251e-in4up`); **rebase 251e lên mới nhất trước** khi mở PR.
- Đọc `AGENTS.md` ở gốc repo trước. Quy tắc vàng: KHÔNG đụng `lib/ffi/`;
  i18n chuỗi mới đủ `en/hi/zh/zh_TW/si` (đăng ký
  `lib/core/language/priority_ui_overrides.dart`); KHÔNG chạy
  `tool/generate_arbs.py`; build release Android bắt buộc `--flavor stable`.
- Cập nhật card `LOGIN-CRASH-002` trong `docs/project/KANBAN.md`
  (status-only + append lịch sử). Commit nhỏ, push ngay. CI:
  `.github/workflows/app_analyze.yml`.

## 1. Triệu chứng (bản 1.10.4)

Màn đăng nhập → bấm nút đăng nhập (Google) → **app tắt ngay** (văng app).

## 2. Những gì đã xác minh (đừng làm lại)

- Build 1.10.4 (run `37724784118`) dùng commit **`e22cd3a`** = **tip mới
  nhất 251e** ⇒ **KHÔNG phải** build từ commit cũ. Code là mới nhất.
- Keystore ký = `in4up-release.jks`, **SHA-1 = `88:D5:EE:0D:A1:68:B3:20:
  C5:2F:51:B7:AA:B4:04:67:58:62:E5:B0`** — owner ĐÃ thêm SHA-1 này vào
  Firebase Console (app `com.in4up`).
- Cross-ref card `CI-BUILD-LOGIN-001` (lần 1.10.3: keystore chưa có trong
  google-services.json).

## 3. Nơi cần đọc

- `lib/services/auth_service.dart` (đường Google Sign-In, `_initializeFirebaseSafely`).
- `google-services.json` — **secret CI** `ANDROID_GOOGLE_SERVICES` /
  `ANDROID_GOOGLE_SERVICES_JSON` (owner quản lý — agent KHÔNG thấy giá trị).
- `android/key.properties` (CI sinh từ `scripts/ci/android_prepare_signing.sh`).

## 4. Việc phải làm

1. **Bắt log crash thật** (cần máy Android): `adb logcat -c` → bấm đăng
   nhập → `adb logcat -d > login_crash.log`. Dán **đúng stack trace** vào
   card. Sản phẩm bắt buộc.
2. **Xác nhận 2 đầu khớp SHA-1:**
   - SHA-1 của **APK đã ký**: `apksigner verify --print-certs <apk>` (hoặc
     đọc log `[in4up-sign]` in fingerprint).
   - SHA-1 trong **google-services.json** (client `com.in4up` →
     `certificate_hash`).
   - Hai cái phải **bằng nhau** (`88d5ee0d…`). Nếu khác ⇒ báo owner cập nhật
     secret google-services.json (agent không set được secret).
3. **Sửa đúng nguyên nhân** trong code (nếu lỗi Dart/đường auth): 1 giả
   thuyết 1 commit. Bọc `FirebaseAuth`/`GoogleSignIn` lỗi thành thông báo
   tiếng Việt có hành động, không để crash trần.
4. **i18n** + **test** thuần cho phần quyết định, nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Cài APK 1.10.4 (build sau fix) → đăng nhập Google → vào app OK, không crash.
2. `adb logcat` sạch (không `FATAL EXCEPTION` khi đăng nhập).
3. SHA-1 APK == SHA-1 trong google-services.json (kèm bằng chứng trong card).
4. `flutter analyze` 0 error + CI xanh.
