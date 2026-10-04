#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Đồng bộ iOS deployment target cho toàn bộ dự án (Podfile + Xcode project +
# AppFrameworkInfo.plist).
#
# LÝ DO TỒN TẠI:
#   google_mlkit_commons / google_mlkit_translation (MLKitVision) khai báo
#   `s.platform = :ios, '15.5'`. Nếu app target thấp hơn, `pod install` sẽ đỏ:
#     [!] CocoaPods could not find compatible versions for pod "google_mlkit_commons"
#         ... they required a higher minimum deployment target
#     Error: The plugin "google_mlkit_commons" requires a higher minimum iOS
#            deployment version than your application is targeting.
#
# Repo đã được set sẵn đúng giá trị; script này là lưới an toàn cho CI
# (idempotent — chạy nhiều lần vẫn ra cùng kết quả) và in ra để debug.
#
# Dùng: scripts/ci/ios_set_deployment_target.sh [target]   (mặc định 15.5)
# ---------------------------------------------------------------------------
set -euo pipefail

TARGET="${1:-${IOS_MIN_TARGET:-15.5}}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "==> iOS deployment target = ${TARGET}"

python3 - "$TARGET" <<'PY'
import re
import sys
from pathlib import Path

target = sys.argv[1]
changed = []


def write(path: Path, old: str, new: str) -> None:
    if old != new:
        path.write_text(new, encoding="utf-8")
        changed.append(str(path))


# 1) ios/Podfile — platform :ios, 'X' + biến $ios_deployment_target
podfile = Path("ios/Podfile")
if podfile.exists():
    src = podfile.read_text(encoding="utf-8")
    # Chấp nhận cả `platform :ios, ...` lẫn `platform(:ios, ...)`
    out = re.sub(
        r"^\s*#?\s*platform\s*\(?\s*:ios.*$",
        "platform(:ios, $ios_deployment_target)",
        src,
        flags=re.MULTILINE,
    )
    out = re.sub(
        r"^\s*\$ios_deployment_target\s*=.*$",
        "$ios_deployment_target = '%s'" % target,
        out,
        flags=re.MULTILINE,
    )
    if "$ios_deployment_target =" not in out:
        # Podfile cũ chưa có biến -> chèn ngay trước dòng platform
        out = out.replace(
            "platform(:ios, $ios_deployment_target)",
            "$ios_deployment_target = '%s'\nplatform(:ios, $ios_deployment_target)" % target,
            1,
        )
    write(podfile, src, out)

# 2) ios/Runner.xcodeproj/project.pbxproj
pbx = Path("ios/Runner.xcodeproj/project.pbxproj")
if pbx.exists():
    src = pbx.read_text(encoding="utf-8")
    out = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = %s;" % target,
        src,
    )
    write(pbx, src, out)

# 3) ios/Flutter/AppFrameworkInfo.plist — MinimumOSVersion
plist = Path("ios/Flutter/AppFrameworkInfo.plist")
if plist.exists():
    src = plist.read_text(encoding="utf-8")
    out = re.sub(
        r"(<key>MinimumOSVersion</key>\s*\n(\s*)<string>)[0-9.]+(</string>)",
        lambda m: m.group(1) + target + m.group(3),
        src,
    )
    write(plist, src, out)

print("Đã cập nhật:", ", ".join(changed) if changed else "(không có gì thay đổi — đã đúng sẵn)")
PY

echo "--- ios/Podfile (platform) ---"
grep -nE "ios_deployment_target|platform\\(?:ios" ios/Podfile || true
echo "--- project.pbxproj ---"
grep -n "IPHONEOS_DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj || true
echo "--- AppFrameworkInfo.plist ---"
grep -A1 "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist || true
