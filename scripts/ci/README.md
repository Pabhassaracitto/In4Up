# scripts/ci — công cụ cho GitHub Actions

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
