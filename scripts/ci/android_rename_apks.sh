#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Đổi tên APK Universal (mọi chip — "chip phổ thông") → tên phát hành
# `in4up-Android-Universal-All-CPU-<tag>.apk` (card CI-ANDROID-04).
# Chạy SAU bước `flutter build apk` (không --split-per-abi), TRƯỚC verify/upload.
#
# CI-ANDROID-04 (owner 2026-10): RELEASE chỉ ship bản UNIVERSAL (1 file cài
# được trên mọi chip) thay vì 3 bản tách theo chip (armv7/arm64/x64).
#   - Universal: app-stable-release.apk / app-release.apk → đổi tên → ship.
#   - Split (app-<abi>-stable-release.apk...): nếu workflow cũ vẫn build
#     chúng thì XÓA để output chỉ còn đúng 1 APK release (không lẫn lộn).
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

echo "[in4up-rename] Thư mục $OUT trước khi xử lý:"
ls -la "$OUT"

# Xóa bản tách theo chip nếu có (workflow cũ chưa áp patch CI-ANDROID-04) —
# release chỉ còn bản universal.
for f in "$OUT"/app-arm64-v8a-stable-release.apk "$OUT"/app-stable-arm64-v8a-release.apk \
         "$OUT"/app-armeabi-v7a-stable-release.apk "$OUT"/app-stable-armeabi-v7a-release.apk \
         "$OUT"/app-x86_64-stable-release.apk "$OUT"/app-stable-x86_64-release.apk \
         "$OUT"/app-arm64-v8a-release.apk "$OUT"/app-armeabi-v7a-release.apk \
         "$OUT"/app-x86_64-release.apk; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[in4up-rename] Bỏ bản tách chip: $(basename "$f") (CI-ANDROID-04: chỉ ship Universal)"
  fi
done

# Universal (fat) APK — THẮNG CUỘC DUY NHẤT được đổi tên + ship.
renamed=0
for c in "app-stable-release.apk" "app-release.apk"; do
  if [ -f "$OUT/$c" ]; then
    mv "$OUT/$c" "$OUT/in4up-Android-Universal-All-CPU-${TAG}.apk"
    echo "[in4up-rename] $c → in4up-Android-Universal-All-CPU-${TAG}.apk"
    renamed=1
    break
  fi
done

if [ "$renamed" -ne 1 ]; then
  echo "::error::[in4up-rename] Không thấy APK Universal (app-stable-release.apk / app-release.apk) — bước 'Build Universal APK' có chạy chưa? (không dùng --split-per-abi)"
  ls -la "$OUT"
  exit 1
fi

echo "[in4up-rename] Kết quả:"
ls -lh "$OUT"/in4up-Android-*.apk
