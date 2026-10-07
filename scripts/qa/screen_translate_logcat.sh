#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# XLAT-SCR-003 — dựng log TRƯỚC KHI sửa (mục 3.1 của prompt giao việc).
#
# Dùng trên MÁY CÓ `adb` + điện thoại Android thật (12/13/14). Sandbox không
# có adb/Android SDK nên script này dành cho chủ dự án chạy tay; kết quả ghi
# vào file để dán ngược vào card KANBAN (`docs/project/KANBAN.md`).
#
# Cách dùng:
#   scripts/qa/screen_translate_logcat.sh                 # ghi 90 giây
#   scripts/qa/screen_translate_logcat.sh 180 out.txt     # 180 giây, tên file tuỳ ý
#
# Quy trình lấy được đúng dòng chặn:
#   1. Gỡ app rồi cài lại (hoặc `adb shell pm revoke com.in4up
#      android.permission.SYSTEM_ALERT_WINDOW` để ép lại trạng thái "chưa cấp").
#   2. Chạy script này.
#   3. TRONG LÚC script chạy: Home → Cài đặt → bật "Dịch màn hình toàn hệ
#      thống" → chạm bong bóng vài lần → (tuỳ chọn) thu hồi quyền overlay.
#   4. Mở file log, tìm các dòng in đậm bên dưới.
#
# Dòng cần tìm (đây là "bằng chứng" ghi vào card):
#   - `ActivityTaskManager: Background activity start ...`  ⇒ chặn #1 (Android
#     10+ chặn mở activity từ nền) — trước khi sửa, dòng này là nguyên nhân
#     "bấm bong bóng không có gì xảy ra".
#   - `ActivityTaskManager: Background activity launch blocked ...` ⇒ tương tự,
#     bản Android 12+.
#   - `MediaProjection: ...` / `SecurityException` ⇒ chặn #2/#4 (thứ tự
#     foreground service ←→ getMediaProjection, hoặc createVirtualDisplay gọi
#     quá một lần trên cùng MediaProjection trên Android 14).
#   - `WindowManager: ... permission denied` / `Unable to add window` ⇒ chặn #3
#     (mất quyền SYSTEM_ALERT_WINDOW).
#   - `In4UpScreenTranslate: ...` ⇒ log do chính service của ta ghi (sau bản
#     sửa này mới có nhiều).
# ---------------------------------------------------------------------------
set -uo pipefail

DURATION="${1:-90}"
OUT="${2:-screen_translate_logcat_$(date +%Y%m%d_%H%M%S).txt}"

if ! command -v adb >/dev/null 2>&1; then
  echo "❌ Không tìm thấy adb. Cài Android platform-tools rồi chạy lại." >&2
  exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
  echo "❌ Không thấy thiết bị (adb get-state lỗi). Bật USB debugging và thử lại." >&2
  exit 1
fi

echo "ℹ️  Thiết bị: $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
echo "ℹ️  Android : $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r') (SDK $(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r'))"
echo "ℹ️  Ghi log trong ${DURATION}s → $OUT"
echo "ℹ️  BÂY GIỜ HÃY: mở In4Up → Cài đặt → bật 'Dịch màn hình toàn hệ thống' → chạm bong bóng."

# Xoá log cũ để file kết quả chỉ chứa lượt Reproduce vừa làm.
adb logcat -c

# -v threadtime để còn giữ PID/TID khi cần tách luồng.
timeout "$DURATION" adb logcat -v threadtime \
  | grep -iE "in4up|screentranslate|In4UpScreenTranslate|MediaProjection|ActivityTaskManager|WindowManager|VirtualDisplay|ImageReader" \
  > "$OUT"

echo "✅ Xong. Log: $OUT ($(wc -l < "$OUT") dòng)"

echo
echo "── Tóm tắt nhanh (nếu có) ──"
grep -iE "background activity (start|launch)|securityexception|permission denied|unable to add window" "$OUT" | head -20 || true

echo
echo "── Dòng do In4Up ghi (tag In4UpScreenTranslate) ──"
grep -i "In4UpScreenTranslate" "$OUT" | head -20 || true

echo
echo "👉 Dán các dòng trên vào card XLAT-SCR-003 (mục 'Bằng chứng logcat')."
