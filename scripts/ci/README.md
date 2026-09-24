# scripts/ci — công cụ cho GitHub Actions

## `android_prepare_signing.sh` (CI-ANDROID-03)

Decode keystore từ secrets → `android/app/in4up-release.jks` + ghi
`android/key.properties` để `android/app/build.gradle.kts` ký APK release bằng
**key thật**. Chạy TRƯỚC `flutter build apk`. Cần 4 secret:

| Secret | Giá trị |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 in4up-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | storePassword |
| `ANDROID_KEY_ALIAS` | alias (vd `in4up`) |
| `ANDROID_KEY_PASSWORD` | keyPassword |

- Thiếu `ANDROID_KEYSTORE_BASE64` ⇒ **không fail**, in `::warning::`; Gradle fallback
  ký **debug keystore** (APK vẫn cài được, nhưng không update đè được giữa các
  release vì mỗi runner một debug key).
- Có BASE64 nhưng thiếu 1 trong 3 secret còn lại, hoặc sai mật khẩu/alias ⇒ fail
  **sớm** (keytool -list) trước khi tốn 15 phút compile native.
- In SHA-1/SHA-256 của cert (không in mật khẩu) — dán vào Firebase Console cho
  Google Sign-In.

Vì sao cần: `release {}` trong build.gradle.kts từng không có `signingConfig`
(từ commit c5d7adbf) ⇒ AGP xuất `*-release-unsigned.apk`, Flutter đổi tên che
mất hậu tố ⇒ Android từ chối cài mọi bản release (local lẫn Actions).

## `android_verify_apk_signed.sh <apk...>` (CI-ANDROID-03)

Lưới an toàn sau bước rename, trước upload/release: mọi APK phải có chữ ký.
Dùng `apksigner verify --print-certs` nếu tìm thấy (PATH / `$ANDROID_HOME/build-tools/*`),
không thì đọc cấu trúc file (`APK Sig Block 42` = v2/v3, `META-INF/*.RSA|DSA|EC` = v1).
Exit 1 nếu có APK unsigned / thiếu file / glob rỗng ⇒ job đỏ thay vì ship APK hỏng.

Chạy tay ở máy dev (không cần Android SDK):

```bash
scripts/ci/android_verify_apk_signed.sh build/app/outputs/flutter-apk/*.apk
```

## `ios_set_deployment_target.sh [target]`

Đồng bộ iOS deployment target ở **3 nơi** (mặc định `15.5`, hoặc biến
`IOS_MIN_TARGET`):

- `ios/Podfile` (`$ios_deployment_target` + dòng `platform(:ios, ...)`)
- `ios/Runner.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET`)
- `ios/Flutter/AppFrameworkInfo.plist` (`MinimumOSVersion`)

Idempotent — chạy bao nhiêu lần cũng ra một kết quả, và in giá trị hiện tại để
đọc log CI.

**Vì sao 15.5?** `google_mlkit_translation` → `google_mlkit_commons` →
**MLKitVision** khai `s.platform = :ios, '15.5'`. Target thấp hơn thì `pod
install` đỏ:

```
[!] CocoaPods could not find compatible versions for pod "google_mlkit_commons"
    ... they required a higher minimum deployment target.
Error: The plugin "google_mlkit_commons" requires a higher minimum iOS
       deployment version than your application is targeting.
```

Muốn hạ target xuống lại thì phải bỏ hẳn `google_mlkit_translation` khỏi
`pubspec.yaml` (dịch offline ML Kit sẽ mất).

## `ios_ci_workflow.patch`

Patch cho `.github/workflows/build.yml` và `.github/workflows/build_final_complete.yml`
(GitHub App của agent **không có quyền `workflows`** nên không push trực tiếp được).

Nội dung patch:

- env dùng chung `IOS_MIN_TARGET: '15.5'`;
- thay 2 bước `sed` ép 15.0 bằng 1 lệnh gọi `ios_set_deployment_target.sh`;
- `flutter config --no-enable-swift-package-manager` — 4 plugin của app
  (`whisper_flutter_new`, `google_mlkit_translation`, `google_mlkit_commons`,
  `flutter_tts`) đều KHÔNG hỗ trợ SPM, đi thuần CocoaPods cho nhanh và bớt rủi ro;
- `pod install --repo-update` chạy sớm để lỗi phụ thuộc hiện ngay;
- bước chẩn đoán `if: failure()` in Podfile + deployment target + `Podfile.lock`.

Cách áp:

```bash
git apply scripts/ci/ios_ci_workflow.patch
git add .github/workflows && git commit -m "ci(ios): deployment target 15.5 + tắt SPM"
```

> Không áp patch thì CI **vẫn xanh được**: `ios/Podfile` cố ý viết
> `platform(:ios, $ios_deployment_target)` (có ngoặc) nên bước `sed` cũ ép 15.0
> không khớp, còn `project.pbxproj` bị ép 15.0 thì `post_install` kéo lại 15.5.
