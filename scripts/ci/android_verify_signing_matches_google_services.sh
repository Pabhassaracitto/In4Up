#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# IN4-15 (LOGIN-CRASH-002) — kiểm tra SHA-1 ký APK có KHỚP với
# google-services.json hay không.
#
# VÌ SAO CẦN:
#   Google Sign-In / Firebase Auth chỉ chấp nhận ID token khi SHA-1 của
#   chứng thư ký ký APK nằm trong `oauth_client[].android_info.
#   certificate_hash` của client `com.in4up` trong google-services.json.
#   Lệch ⇒ Google trả lỗi (DEVELOPER_ERROR / ApiException 10) ⇒ nút đăng
#   nhập "văng app" — mà APK vẫn cài được và mọi thứ khác vẫn chạy.
#
#   Nguyên nhân lệch đã xảy ra: keystore `in4up-release.jks` hiện có
#   SHA-1 = 88d5ee0da168b320c52f51b7aab404675862e5b0, còn bản JSON cũ trong
#   repo (fallback của CI) khai báo 8a1bc02e… ⇒ build release ký bằng key
#   mới mà JSON chưa có hash đó.
#
#   Nguyên tắc "4-cái-khớp": Console(SHA-1) → google-services.json →
#   secret CI → keystore CI ký. Script này kiểm 2 vế cuối (JSON ↔ keystore).
#
# CÁCH DÙNG:  bash scripts/ci/android_verify_signing_matches_google_services.sh
# Exit 0 = khớp (hoặc không có keystore release ⇒ chỉ warning);
#       1 = LỆCH ⇒ build release này KHÔNG đăng nhập được ⇒ phải fail.
# ---------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

GS_JSON="android/app/google-services.json"
KEYSTORE="android/app/in4up-release.jks"
PROPS="android/key.properties"

if [ ! -s "$GS_JSON" ]; then
  echo "::error::[in4up-sign] Không có $GS_JSON — không kiểm được SHA-1."
  exit 1
fi

# ── 1. Lấy SHA-1 của keystore sẽ dùng để ký ──────────────────────────────
KEY_SHA1=""
if [ -s "$KEYSTORE" ] && [ -s "$PROPS" ]; then
  alias_name="$(sed -n 's/^keyAlias=//p' "$PROPS" | head -n1)"
  store_pass="$(sed -n 's/^storePassword=//p' "$PROPS" | head -n1)"
  if command -v keytool >/dev/null 2>&1; then
    KEY_SHA1="$(keytool -list -v -keystore "$KEYSTORE" -alias "$alias_name" \
        -storepass "$store_pass" 2>/dev/null \
        | sed -n 's/.*SHA1: \(.*\)/\1/p' | head -n1 | tr -d '[:space:]' \
        | tr 'A-Z' 'a-z')"
  fi
fi

if [ -z "$KEY_SHA1" ]; then
  echo "::warning::[in4up-sign] Không lấy được SHA-1 keystore release (thiếu $KEYSTORE / keytool) — bỏ qua kiểm tra khớp hash. Nếu build này là bản PHÁT HÀNH, hãy kiểm tra tay: apksigner verify --print-certs <apk>"
  exit 0
fi

# ── 2. Lấy MỌI certificate_hash có trong google-services.json ─────────────
JSON_HASHES="$(grep -o '"certificate_hash"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]*"' \
  "$GS_JSON" | sed 's/.*"\([0-9a-fA-F]*\)"$/\1/' | tr 'A-Z' 'a-z' | sort -u)"

if [ -z "$JSON_HASHES" ]; then
  echo "::warning::[in4up-sign] google-services.json KHÔNG khai báo certificate_hash nào (thiếu oauth_client android) — không kiểm được; Google Sign-In có thể không hoạt động."
  exit 0
fi

echo "[in4up-sign] SHA-1 keystore ký release: $KEY_SHA1"
echo "[in4up-sign] certificate_hash có trong google-services.json:"
echo "$JSON_HASHES" | sed 's/^/  - /'

# ── 3. So khớp ────────────────────────────────────────────────────────────
if echo "$JSON_HASHES" | grep -qx "$KEY_SHA1"; then
  echo "✅ [in4up-sign] SHA-1 keystore CÓ trong google-services.json — Google Sign-In sẽ nhận ID token."
  exit 0
fi

echo "::error::[in4up-sign] SHA-1 keystore ký release KHÔNG có trong google-services.json ($KEY_SHA1). APK build này sẽ KHÔNG đăng nhập được (Google trả DEVELOPER_ERROR / ApiException 10) ⇒ nút đăng nhập văng app. Sửa: tải lại google-services.json từ Firebase Console (client com.in4up đã có SHA-1 này) → base64 → cập nhật secret CI ANDROID_GOOGLE_SERVICES_JSON (hoặc ANDROID_GOOGLE_SERVICES)."
exit 1
