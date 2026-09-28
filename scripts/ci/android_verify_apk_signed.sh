#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Kiểm tra MỌI APK truyền vào đều CÓ CHỮ KÝ — fail sớm thay vì đẩy APK không cài
# được lên GitHub Release (card CI-ANDROID-03).
#
# Bối cảnh: build.gradle.kts từng thiếu `signingConfig` cho release ⇒ AGP xuất
# `*-release-unsigned.apk`, Flutter plugin đổi tên thành `app-*-release.apk` nên
# nhìn tên file KHÔNG phân biệt được. Người dùng tải về mới biết "App not installed".
# Script này là lưới an toàn: chạy sau bước build/rename, trước upload/release.
#
# Cách kiểm:
#   1. Có apksigner (Android SDK build-tools) ⇒ `apksigner verify --print-certs`
#      (kiểm thật sự v1/v2/v3 + in SHA-256 cert để đối chiếu giữa các release).
#   2. Không có apksigner (máy dev thiếu build-tools) ⇒ fallback python: tìm
#      "APK Sig Block 42" (v2/v3) hoặc META-INF/*.RSA|*.DSA|*.EC (v1) trong zip.
#
# Dùng:  scripts/ci/android_verify_apk_signed.sh build/app/outputs/flutter-apk/*.apk
# Exit 0 = tất cả đã ký; 1 = có APK unsigned / không đọc được / không có file.
# ---------------------------------------------------------------------------
set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "::error::[in4up-sign] Không có APK nào để kiểm (glob không khớp file?)."
  exit 1
fi

find_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return 0
  fi
  local sdk
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do
    [ -n "$sdk" ] && [ -d "$sdk/build-tools" ] || continue
    # build-tools mới nhất trước
    local cand
    cand="$(ls -1d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -n1)"
    if [ -n "$cand" ] && [ -x "${cand}apksigner" ]; then
      echo "${cand}apksigner"
      return 0
    fi
  done
  return 1
}

APKSIGNER="$(find_apksigner || true)"
fail=0

for apk in "$@"; do
  if [ ! -f "$apk" ]; then
    echo "::error::[in4up-sign] Không thấy file: $apk"
    fail=1
    continue
  fi

  if [ -n "$APKSIGNER" ]; then
    # --min-sdk-version 24 khớp minSdk của app (apksigner cần để chọn scheme cần kiểm).
    if out="$("$APKSIGNER" verify --verbose --print-certs --min-sdk-version 24 "$apk" 2>&1)"; then
      echo "✅ $(basename "$apk"): đã ký"
      echo "$out" | grep -E "Verified using v[123].*true|Signer #1 certificate SHA-256|Signer #1 certificate DN" | sed 's/^/     /'
    else
      echo "::error::[in4up-sign] $(basename "$apk") KHÔNG có chữ ký hợp lệ (Android sẽ từ chối cài):"
      echo "$out" | tail -n 5 | sed 's/^/     /'
      fail=1
    fi
  else
    # Fallback không cần SDK: đọc cấu trúc file.
    if python3 - "$apk" <<'PY'
import sys, zipfile
p = sys.argv[1]
ok_v2 = False
with open(p, "rb") as f:
    f.seek(0, 2)
    size = f.tell()
    # Tìm magic của APK Signing Block trong 8 MB cuối (nằm ngay trước Central Directory).
    f.seek(max(0, size - 8 * 1024 * 1024))
    ok_v2 = b"APK Sig Block 42" in f.read()
ok_v1 = False
try:
    with zipfile.ZipFile(p) as z:
        ok_v1 = any(n.startswith("META-INF/") and n.upper().endswith((".RSA", ".DSA", ".EC"))
                    for n in z.namelist())
except zipfile.BadZipFile:
    print("     (không phải file zip hợp lệ)")
    sys.exit(2)
print(f"     v1(JAR)={'có' if ok_v1 else 'không'}  v2/v3(APK Signing Block)={'có' if ok_v2 else 'không'}")
sys.exit(0 if (ok_v1 or ok_v2) else 1)
PY
    then
      echo "✅ $(basename "$apk"): đã ký (kiểm bằng cấu trúc file — không có apksigner)"
    else
      echo "::error::[in4up-sign] $(basename "$apk") KHÔNG có chữ ký (unsigned) — Android sẽ từ chối cài."
      fail=1
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "::error::[in4up-sign] Có APK chưa ký. Kiểm tra android/app/build.gradle.kts (signingConfig) và bước 'Prepare Android release signing'."
  exit 1
fi
echo "[in4up-sign] Tất cả $# APK đều đã ký."
