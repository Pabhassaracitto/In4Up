#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Đổi tên APK (chỉ chip arm64-v8a — "chip phổ thông") → tên phát hành
# `in4up-Android-arm64-v8a-<tag>-<commit5>.apk` (card CI-ANDROID-04).
# <commit5> = 5 ký tự đầu hash commit (GITHUB_SHA) — build local không có đuôi.
# Chạy SAU bước `flutter build apk` (không --split-per-abi), TRƯỚC verify/upload.
#
# CI-ANDROID-04 (owner 2026-10): RELEASE chỉ ship 1 bản CHO CHIP PHỔ THÔNG
# arm64-v8a (abiFilters trong build.gradle.kts) thay vì universal 3-ABI
# (~212 MB) hay 3 bản tách theo chip (armv7/arm64/x64).
#   - arm64: app-stable-release.apk / app-release.apk → đổi tên → ship.
#   - Split (app-<abi>-stable-release.apk...): nếu workflow cũ vẫn build
#     chúng thì XÓA để output chỉ còn đúng 1 APK release (không lẫn lộn).
#
# Dùng:  scripts/ci/android_rename_apks.sh <tag> [out_dir]
#        out_dir mặc định build/app/outputs/flutter-apk
# ---------------------------------------------------------------------------
set -euo pipefail

TAG="${1:-}"
OUT="${2:-build/app/outputs/flutter-apk}"
# Đuôi 5 ký tự hash commit — GITHUB_SHA (GitHub Actions tự đặt env này).
# Build local (không có GITHUB_SHA) → bỏ đuôi hash. `${GITHUB_SHA:-}` để
# không lỗi với `set -u` khi biến chưa set (local).
SHA="${GITHUB_SHA:-}"
SHA="${SHA:0:5}"
if [ -n "$SHA" ]; then
  APK_NAME="in4up-Android-arm64-v8a-${TAG}-${SHA}.apk"
else
  APK_NAME="in4up-Android-arm64-v8a-${TAG}.apk"
fi

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

# IN4-73: Xóa bản tách theo chip KHÔNG phải arm64 (armv7/x86_64) nếu có —
# release chỉ ship arm64-v8a. KHÔNG xóa bản arm64 (nay là bản cần ship).
for f in "$OUT"/app-armeabi-v7a-stable-release.apk "$OUT"/app-stable-armeabi-v7a-release.apk \
         "$OUT"/app-x86_64-stable-release.apk "$OUT"/app-stable-x86_64-release.apk \
         "$OUT"/app-armeabi-v7a-release.apk "$OUT"/app-x86_64-release.apk; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[in4up-rename] Bỏ bản tách chip (không arm64): $(basename "$f") (IN4-73: chỉ ship arm64-v8a)"
  fi
done

# APK arm64-v8a — THẮNG CUỘC DUY NHẤT được đổi tên + ship. Chấp nhận mọi tên
# output arm64 (fat "app-stable-release.apk" HAY tên kèm ABI nếu Flutter/AGP
# đổi cách đặt tên khi dùng --target-platform android-arm64).
renamed=0
for c in "app-stable-release.apk" "app-release.apk" \
         "app-arm64-v8a-stable-release.apk" "app-stable-arm64-v8a-release.apk" \
         "app-arm64-v8a-release.apk"; do
  if [ -f "$OUT/$c" ]; then
    mv "$OUT/$c" "$OUT/$APK_NAME"
    echo "[in4up-rename] $c → $APK_NAME"
    renamed=1
    break
  fi
done

if [ "$renamed" -ne 1 ]; then
  # Fallback an toàn: nếu đúng 1 .apk duy nhất trong thư mục output (tên lạ do
  # Flutter/AGP đổi cách đặt tên) thì đổi tên nó; nhiều hơn 1 .apk ⇒ không đoán,
  # báo lỗi để người xem kiểm tra.
  mapfile -t apks < <(ls -1 "$OUT"/*.apk 2>/dev/null || true)
  if [ "${#apks[@]}" -eq 1 ] && [ -f "${apks[0]}" ]; then
    mv "${apks[0]}" "$OUT/$APK_NAME"
    echo "[in4up-rename] (fallback) $(basename "${apks[0]}") → $APK_NAME"
    renamed=1
  fi
fi

if [ "$renamed" -ne 1 ]; then
  echo "::error::[in4up-rename] Không thấy APK arm64 (app-stable-release.apk / app-arm64-v8a-*.apk) — bước 'Build APK (arm64-v8a only — IN4-73)' có chạy chưa?"
  ls -la "$OUT"
  exit 1
fi

echo "[in4up-rename] Kết quả:"
ls -lh "$OUT"/in4up-Android-*.apk
