#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Đổi tên APK Flutter sinh ra → tên phát hành `in4up-Android-<abi|Universal-All-CPU>-<tag>.apk`
# (card CI-ANDROID-01/03). Chạy SAU 2 bước `flutter build apk`, TRƯỚC verify/upload.
#
# LÝ DO TỒN TẠI:
#   Tên file do Flutter Gradle plugin sinh (FlutterPlugin.kt, 3.44.1):
#       app[-<abi>][-<flavor>]-<mode>.apk   → app-arm64-v8a-stable-release.apk (ABI TRƯỚC, flavor SAU)
#   Sổ tay từng ghi ngược (flavor trước) và workflow cũ `mv ... || true` ⇒ thiếu 3 APK
#   split mà job vẫn xanh. Script này:
#     - thử LẦN LƯỢT các tên có thể gặp (ABI-trước / flavor-trước / không-flavor) để không
#       gãy khi đổi phiên bản Flutter;
#     - THIẾU bất kỳ APK nào ⇒ exit 1 + `ls` thư mục để đọc log là biết ngay, không ship thiếu.
#
# Dùng:  scripts/ci/android_rename_apks.sh <tag> [out_dir]
#        out_dir mặc định build/app/outputs/flutter-apk
# ---------------------------------------------------------------------------
set -euo pipefail

TAG="${1:-}"
OUT="${2:-build/app/outputs/flutter-apk}"

if [ -z "$TAG" ]; then
  echo "::error::[in4up-rename] Thiếu tag/version (tham số 1)."
  exit 1
fi
if [ ! -d "$OUT" ]; then
  echo "::error::[in4up-rename] Không thấy thư mục $OUT — bước flutter build chưa chạy/đã đỏ?"
  exit 1
fi

echo "[in4up-rename] Thư mục $OUT trước khi đổi tên:"
ls -la "$OUT"

fail=0

# rename_first <dest> <candidate...>  — mv ứng viên đầu tiên tồn tại.
rename_first() {
  local dest="$1"; shift
  local c
  for c in "$@"; do
    if [ -f "$OUT/$c" ]; then
      mv "$OUT/$c" "$OUT/$dest"
      echo "[in4up-rename] $c → $dest"
      return 0
    fi
  done
  echo "::error::[in4up-rename] Không thấy APK nào trong: $* (đích $dest)"
  fail=1
  return 0
}

# Split-per-ABI (flavor stable)
for pair in "armeabi-v7a:armv7" "arm64-v8a:arm64" "x86_64:x64"; do
  abi="${pair%%:*}"; short="${pair##*:}"
  rename_first "in4up-Android-${short}-${TAG}.apk" \
    "app-${abi}-stable-release.apk" \
    "app-stable-${abi}-release.apk" \
    "app-${abi}-release.apk"
done

# Universal (fat) APK
rename_first "in4up-Android-Universal-All-CPU-${TAG}.apk" \
  "app-stable-release.apk" \
  "app-release.apk"

if [ "$fail" -ne 0 ]; then
  echo "::error::[in4up-rename] Thiếu APK — kiểm tra 2 bước 'Build Split APKs' / 'Build Universal APK' (có --flavor stable và --split-per-abi chưa?)."
  exit 1
fi

echo "[in4up-rename] Kết quả:"
ls -lh "$OUT"/in4up-Android-*.apk
