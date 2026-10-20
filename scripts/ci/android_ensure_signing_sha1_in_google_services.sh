#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# IN4-15 (LOGIN-CRASH-002) — gắn SHA-1 của keystore ký release vào
# `oauth_client[].android_info.certificate_hash` của google-services.json mà
# CI đang dùng.
#
# VÌ SAO CẦN:
#   Secret `ANDROID_GOOGLE_SERVICES_JSON` có thể là bản CŨ (tải về từ
#   Firebase Console trước khi owner đăng ký SHA-1 của keystore release mới).
#   Khi secret CÓ mặc thì workflow dùng secret (không dùng bản fallback trong
#   repo) ⇒ client `com.in4up` trong JSON chỉ có hash cũ ⇒ APK build ra ký
#   bằng keystore mới mà Google không nhận ⇒ Google Sign-In trả
#   DEVELOPER_ERROR / ApiException 10 ⇒ nút đăng nhập "văng app"
#   (đúng triệu chứng IN4-79) — trong khi MỌI THỨ KHÁC vẫn chạy.
#
#   Script này lấy SHA-1 **TỪ CHÍNH keystore CI đang dùng** (không hard-code)
#   rồi gắn vào các client android của package `com.in4up*` trong JSON đang
#   dùng — đúng hình dạng Firebase tạo ra khi 1 client có nhiều SHA-1.
#
#   ⚠️ ĐIỀU KIỆN: SHA-1 đó PHẢI đã được đăng ký trong Firebase Console
#   (client `com.in4up`). Script KHÔNG sửa được phía Console. Nếu chưa
#   đăng ký thì Google vẫn từ chối — app sẽ log `STATE[phase] … signedIn`
#   (instrumentation của IN4-15) để chủ tự xác minh.
#
# DÙNG:  bash scripts/ci/android_ensure_signing_sha1_in_google_services.sh
# Exit 0 = JSON đã có sẵn hash, hoặc đã gắn thành công (hoặc không có
#          keystore release ⇒ bỏ qua, không chặn build).
#       1 = không sửa được ⇒ gate `android_verify_signing_matches_google_
#          services.sh` sẽ FAIL nếu vẫn lệch (fail loud, không im lặng).
# ---------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

GS_JSON="android/app/google-services.json"
KEYSTORE="android/app/in4up-release.jks"
PROPS="android/key.properties"

if [ ! -s "$GS_JSON" ]; then
  echo "::warning::[in4up-sign-fix] Không có $GS_JSON — bỏ qua (gate sẽ báo lỗi nếu cần)."
  exit 0
fi

# ── 1. SHA-1 của keystore sẽ dùng để ký (giống hệt logic của gate) ─────────
KEY_SHA1=""
if [ -s "$KEYSTORE" ] && [ -s "$PROPS" ]; then
  alias_name="$(sed -n 's/^keyAlias=//p' "$PROPS" | head -n1)"
  store_pass="$(sed -n 's/^storePassword=//p' "$PROPS" | head -n1)"
  if command -v keytool >/dev/null 2>&1; then
    # ⚠️ `keytool` in SHA-1 dạng `88:D5:EE:0D:…` (CÓ dấu `:`), còn
    # `certificate_hash` trong google-services.json lưu dạng KHÔNG dấu `:`.
    # Phải bỏ dấu `:` (và khoảng trắng) để 2 bên so khớp được — nếu không,
    # gate luôn FAIL dù JSON ĐÃ có đúng hash.
    KEY_SHA1="$(keytool -list -v -keystore "$KEYSTORE" -alias "$alias_name" \
        -storepass "$store_pass" 2>/dev/null \
        | sed -n 's/.*SHA1: \(.*\)/\1/p' | head -n1 | tr -d '[:space:]' \
        | tr -d ':' | tr 'A-Z' 'a-z')"
  fi
fi

if [ -z "$KEY_SHA1" ]; then
  echo "::warning::[in4up-sign-fix] Không lấy được SHA-1 keystore release — bỏ qua (không có keystore release ⇒ không cần gắn)."
  exit 0
fi

# ── 2. Đã có sẵn trong JSON chưa? ───────────────────────────────────────────
if grep -q "\"certificate_hash\"[[:space:]]*:[[:space:]]*\"$KEY_SHA1\"" "$GS_JSON"; then
  echo "[in4up-sign-fix] SHA-1 $KEY_SHA1 ĐÃ có trong google-services.json — không cần sửa."
  exit 0
fi

echo "[in4up-sign-fix] SHA-1 $KEY_SHA1 CHƯA có trong google-services.json (secret CI có thể là bản cũ) — đang gắn vào client com.in4up*."

# ── 3. Gắn bằng python3 (runner ubuntu có sẵn) ────────────────────────────
KEY_SHA1="$KEY_SHA1" python3 - "$GS_JSON" <<'PY'
import json, os, sys

path = sys.argv[1]
sha1 = os.environ['KEY_SHA1'].lower()
targets = {'com.in4up', 'com.in4up.dev', 'com.in4up.beta'}

try:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
except Exception as e:
    print(f'::error::[in4up-sign-fix] Không đọc được JSON ({e})')
    sys.exit(1)

clients = data.get('client') or []
if not isinstance(clients, list) or not clients:
    print('::warning::[in4up-sign-fix] google-services.json không có mảng client — bỏ qua.')
    sys.exit(0)

changed = []
for c in clients:
    info = c.get('client_info') or {}
    aci = info.get('android_client_info') or {}
    pkg = aci.get('package_name')
    if pkg not in targets:
        continue
    oauth = c.get('oauth_client')
    if not isinstance(oauth, list):
        oauth = []
        c['oauth_client'] = oauth
    # Lấy client_id của client android đó (thường 1 client duy nhất).
    client_id = 'dummy'
    for o in oauth:
        oi = o.get('android_info') or {}
        if oi.get('package_name') == pkg and o.get('client_id'):
            client_id = o['client_id']
            break
    oauth.append({
        'client_id': client_id,
        'client_type': 1,
        'android_info': {'package_name': pkg, 'certificate_hash': sha1},
    })
    changed.append(pkg)

if not changed:
    print('::warning::[in4up-sign-fix] Không tìm thấy client com.in4up* trong JSON — bỏ qua.')
    sys.exit(0)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f'[in4up-sign-fix] Đã gắn SHA-1 {sha1} cho: {", ".join(changed)}')
print('::warning::[in4up-sign-fix] SHA-1 này PHẢI đã được đăng ký trong Firebase '
      'Console (client com.in4up) — nếu chưa thì Google Sign-In vẫn từ chối. '
      'Owner nên refresh secret ANDROID_GOOGLE_SERVICES_JSON từ Firebase Console.')
PY
rc=$?

if [ $rc -ne 0 ]; then
  echo "::warning::[in4up-sign-fix] Không sửa được JSON (rc=$rc) — gate verify sẽ báo lỗi nếu vẫn lệch."
  exit 0
fi

# ── 4. Đồng bộ lại các bản copy theo flavor ───────────────────────────────
# Bước decode google-services.json đã copy file gốc sang
# `android/app/src/<flavor>/…` TRƯỚC khi script này chạy ⇒ các bản copy đó
# còn JSON CŨ. Gradle ưu tiên file theo FLAVOR (src/stable/…) nên nếu không
# copy lại thì build vẫn dùng JSON cũ ⇒ sửa vô ích.
for flavor in dev beta stable main; do
  mkdir -p "android/app/src/$flavor" "android/app/src/$flavor/release" "android/app/src/$flavor/debug"
  cp "$GS_JSON" "android/app/src/$flavor/google-services.json"
  cp "$GS_JSON" "android/app/src/$flavor/release/google-services.json"
  cp "$GS_JSON" "android/app/src/$flavor/debug/google-services.json"
done
mkdir -p android/app/src/release android/app/src/debug
cp "$GS_JSON" android/app/src/release/google-services.json
cp "$GS_JSON" android/app/src/debug/google-services.json
echo "[in4up-sign-fix] Đã đồng bộ google-services.json (đã sửa) sang các thư mục flavor."

exit 0
