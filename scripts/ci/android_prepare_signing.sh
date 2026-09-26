#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Chuẩn bị keystore ký APK release cho GitHub Actions (card CI-ANDROID-03).
#
# LÝ DO TỒN TẠI:
#   android/app/build.gradle.kts đọc android/key.properties để ký release. Trên
#   CI file đó không tồn tại (gitignore) ⇒ Gradle fallback ký bằng DEBUG keystore
#   của runner — APK cài được nhưng mỗi runner một key ⇒ user không update đè
#   được giữa các release. Script này decode keystore từ secrets và ghi
#   key.properties để Gradle ký bằng KEY THẬT, ổn định qua mọi lần build.
#
# SECRETS CẦN (Settings → Secrets and variables → Actions):
#   ANDROID_KEYSTORE_BASE64   base64 của file .jks:  base64 -w0 in4up-release.jks
#   ANDROID_KEYSTORE_PASSWORD storePassword
#   ANDROID_KEY_ALIAS         keyAlias (ví dụ: in4up)
#   ANDROID_KEY_PASSWORD      keyPassword
#
# HÀNH VI:
#   - Đủ 4 secret  ⇒ ghi android/app/in4up-release.jks + android/key.properties,
#                    in fingerprint SHA-1/SHA-256 (đối chiếu Firebase/Google Sign-In).
#   - Thiếu secret ⇒ KHÔNG fail (exit 0) — build vẫn chạy, ký debug keystore,
#                    in WARNING rõ để đọc log biết đây không phải bản phát hành thật.
#   - Idempotent: chạy nhiều lần ra cùng kết quả.
#
# Dùng trong workflow (trước bước `flutter build apk`):
#   - name: Prepare Android release signing
#     env:
#       ANDROID_KEYSTORE_BASE64:   ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
#       ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
#       ANDROID_KEY_ALIAS:         ${{ secrets.ANDROID_KEY_ALIAS }}
#       ANDROID_KEY_PASSWORD:      ${{ secrets.ANDROID_KEY_PASSWORD }}
#     run: bash scripts/ci/android_prepare_signing.sh
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

KEYSTORE_PATH="android/app/in4up-release.jks"
PROPS_PATH="android/key.properties"

if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  echo "::warning::[in4up-sign] Thiếu secret ANDROID_KEYSTORE_BASE64 → APK release sẽ ký bằng DEBUG keystore của runner (cài được, nhưng không update đè được giữa các release). Thêm 4 secret ANDROID_KEYSTORE_* để ký key thật."
  rm -f "$PROPS_PATH"
  exit 0
fi

missing=()
[ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ] && missing+=(ANDROID_KEYSTORE_PASSWORD)
[ -z "${ANDROID_KEY_ALIAS:-}" ]         && missing+=(ANDROID_KEY_ALIAS)
[ -z "${ANDROID_KEY_PASSWORD:-}" ]      && missing+=(ANDROID_KEY_PASSWORD)
if [ ${#missing[@]} -gt 0 ]; then
  echo "::error::[in4up-sign] Có ANDROID_KEYSTORE_BASE64 nhưng thiếu secret: ${missing[*]} — không thể ký key thật. Bổ sung secret rồi chạy lại."
  exit 1
fi

mkdir -p "$(dirname "$KEYSTORE_PATH")"
# Chấp nhận cả base64 có xuống dòng lẫn 1 dòng.
if ! printf '%s' "$ANDROID_KEYSTORE_BASE64" | tr -d '\r\n ' | base64 -d > "$KEYSTORE_PATH" 2>/dev/null; then
  echo "::error::[in4up-sign] ANDROID_KEYSTORE_BASE64 không decode được (phải là: base64 -w0 in4up-release.jks)."
  exit 1
fi

if [ ! -s "$KEYSTORE_PATH" ]; then
  echo "::error::[in4up-sign] Keystore decode ra file rỗng."
  exit 1
fi

# Ghi key.properties — storeFile tương đối so với android/app (Gradle resolve bằng project.file()).
{
  echo "storeFile=$(basename "$KEYSTORE_PATH")"
  echo "storePassword=${ANDROID_KEYSTORE_PASSWORD}"
  echo "keyAlias=${ANDROID_KEY_ALIAS}"
  echo "keyPassword=${ANDROID_KEY_PASSWORD}"
} > "$PROPS_PATH"
chmod 600 "$PROPS_PATH" "$KEYSTORE_PATH"

echo "[in4up-sign] Đã ghi $PROPS_PATH (storeFile=$(basename "$KEYSTORE_PATH"), alias=${ANDROID_KEY_ALIAS})"

# Xác thực keystore + in fingerprint (không in mật khẩu). Sai mật khẩu/alias ⇒ fail SỚM,
# trước khi tốn ~10-20 phút compile native rồi mới chết ở bước ký.
if command -v keytool >/dev/null 2>&1; then
  if ! keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$ANDROID_KEY_ALIAS" \
        -storepass "$ANDROID_KEYSTORE_PASSWORD" -keypass "$ANDROID_KEY_PASSWORD" \
        2>/dev/null | grep -E "SHA1:|SHA256:|Alias name:|Valid from:"; then
    echo "::error::[in4up-sign] keytool không mở được keystore với alias/mật khẩu đã cho — kiểm tra lại 4 secret ANDROID_KEYSTORE_*."
    exit 1
  fi
else
  echo "[in4up-sign] (không có keytool trên PATH — bỏ qua bước verify fingerprint)"
fi
