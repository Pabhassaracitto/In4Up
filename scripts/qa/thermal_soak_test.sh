#!/usr/bin/env bash
# scripts/qa/thermal_soak_test.sh
#
# QA-PERF-001 — Script hỗ trợ kiểm thử NHIỆT ĐỘ/PIN trên THIẾT BỊ THẬT khi
# chạy nhiều tác vụ nặng của in4up cùng lúc (AI chat local, dịch Hy-MT
# offline, Whisper on-device). KHÔNG chạy được trong sandbox/CI — cần máy
# Android thật cắm qua `adb` (tốt nhất: máy KHÔNG phải flagship, RAM thấp,
# vì đó là nhóm có nguy cơ cao nhất theo audit docs/qa_heavy_task_thermal_audit.md).
#
# Cách dùng:
#   1. Cài app lên máy, bật "Dừng tối ưu mức sử dụng pin" (BATTERY-OPT-001)
#      — đây chính là kịch bản rủi ro cao nhất (không còn lưới an toàn Doze).
#   2. Cắm máy qua USB, bật USB debugging, chạy:
#        scripts/qa/thermal_soak_test.sh com.in4up 600
#      (tham số 2: tên package, mặc định com.in4up; tham số 3: số giây theo
#      dõi, mặc định 600 = 10 phút)
#   3. TRONG LÚC script đang chạy, trên máy: mở AI chat gửi vài tin nhắn dài,
#      đồng thời mở màn Dịch (Hy-MT offline) dịch đoạn văn dài, đồng thời bắt
#      đầu bóc băng (Whisper) 1 file audio dài — xem mục "Kịch bản" bên dưới.
#   4. Kết thúc: xem file CSV `thermal_soak_<timestamp>.csv` — cột nhiệt độ
#      pin (desiCelsius/10) và %CPU của tiến trình app theo thời gian.
#
# Kịch bản tối thiểu để tái hiện rủi ro đã nêu trong audit (mục "Phát hiện #1"):
#   a) Mở tab "Dịch" → dịch 1 đoạn văn dài (Hy-MT offline) — bấm dịch rồi
#      NGAY LẬP TỨC chuyển tab.
#   b) Mở tab AI Chat → gửi 1 câu hỏi dài trong lúc (a) còn đang chạy.
#   c) Mở màn Nghe → import 1 file audio dài (>10 phút) → bấm "Bóc băng"
#      (Whisper on-device) trong lúc (a) và (b) còn đang chạy.
#   d) Lặp lại (a)-(c) 3-5 lần trong 10 phút, quan sát:
#        - Nhiệt độ pin (cột battery_temp_c) có vượt 42-45°C không (ngưỡng
#          Android bắt đầu throttle nhiệt trên nhiều máy).
#        - %CPU tiến trình app có duy trì gần 100% x số lõi liên tục không.
#        - App có bị hệ thống kill (ANR/OOM) giữa chừng không — xem
#          logcat song song: `adb logcat | grep -E "ActivityManager|OutOfMemory|ANR"`
#
# Pass/Fail gợi ý (điều chỉnh theo máy test):
#   - FAIL nếu nhiệt độ pin tăng liên tục không có dấu hiệu plateau sau 10
#     phút, hoặc app crash/bị kill trong kịch bản trên.
#   - FAIL nếu CPU duy trì ~100% đa lõi NGAY CẢ KHI chỉ 1 engine đang thực sự
#     cần chạy (dấu hiệu nhiều isolate nặng chồng nhau không cần thiết).
#   - PASS nếu nhiệt độ tăng rồi ổn định (plateau) ở mức máy vẫn dùng được,
#     không crash, không ANR trong toàn bộ phiên test.

set -euo pipefail

PKG="${1:-com.in4up}"
DURATION="${2:-600}"
INTERVAL=5
TS="$(date +%Y%m%d_%H%M%S)"
OUT="thermal_soak_${TS}.csv"

if ! command -v adb >/dev/null 2>&1; then
  echo "❌ Không tìm thấy 'adb' trong PATH. Cài Android platform-tools trước." >&2
  exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
  echo "❌ Không có thiết bị adb nào đang kết nối (adb get-state lỗi)." >&2
  exit 1
fi

echo "📋 Theo dõi gói: $PKG — trong $DURATION giây, lấy mẫu mỗi ${INTERVAL}s"
echo "📝 Ghi log vào: $OUT"
echo "timestamp,battery_temp_c,battery_level,app_cpu_percent,app_mem_kb" > "$OUT"

elapsed=0
while [ "$elapsed" -lt "$DURATION" ]; do
  now="$(date +%H:%M:%S)"

  # dumpsys battery: "temperature: 328" là đơn vị desiCelsius (/10 = °C).
  temp_raw="$(adb shell dumpsys battery 2>/dev/null | grep -i temperature | grep -o '[0-9]\+' || echo 0)"
  temp_c="$(awk -v t="$temp_raw" 'BEGIN { printf "%.1f", t/10 }')"
  level="$(adb shell dumpsys battery 2>/dev/null | grep -i '  level' | grep -o '[0-9]\+' || echo 0)"

  # %CPU của tiến trình app qua `top` (Android toybox top hỗ trợ -n 1 -b).
  cpu_pct="$(adb shell "top -n 1 -b 2>/dev/null | grep $PKG | awk '{print \$9}' | head -1" || echo 0)"
  cpu_pct="${cpu_pct:-0}"

  # RSS (KB) qua dumpsys meminfo — cột TOTAL PSS dòng đầu.
  mem_kb="$(adb shell "dumpsys meminfo $PKG 2>/dev/null | grep TOTAL | head -1 | awk '{print \$2}'" || echo 0)"
  mem_kb="${mem_kb:-0}"

  echo "$now,$temp_c,$level,$cpu_pct,$mem_kb" | tee -a "$OUT"

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

echo "✅ Xong. Mở $OUT bằng Excel/Sheets để vẽ biểu đồ nhiệt độ/CPU theo thời gian."
