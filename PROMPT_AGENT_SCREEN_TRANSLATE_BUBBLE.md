# Prompt giao việc — Dịch màn hình toàn hệ thống: CHẠM BONG BÓNG KHÔNG CÓ GÌ XẢY RA (XLAT-SCR-003)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. Việc này **bắt
buộc có máy Android thật** (Android 12/13/14 nếu có đủ) — sandbox không chạy
được foreground service, MediaProjection hay overlay.

Tiền đề: lane native đã có sẵn (XLAT-SCR-002, ADR-0011). Đây **không phải**
viết lại tính năng, mà là làm cho cú chạm bong bóng có kết quả — hoặc ít nhất
nói cho người dùng biết vì sao không có kết quả.

---

## 0. Luật phiên

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`).
  Không merge `main`/`251e` từ sandbox.
- `AGENTS.md` + quy tắc vàng (không đụng `lib/ffi/`, không gộp 3 SM-2, giữ
  reopen anchor, ADR cho thay đổi kiến trúc, i18n rule #5 đủ
  `en/hi/zh/zh_TW/si` trong `priority_ui_overrides.dart`, **đừng** chạy
  `tool/generate_arbs.py`).
- Không tải model lúc bootstrap. Build release `--flavor stable`.
- Card KANBAN: `XLAT-SCR-003` (append-only, xem `docs/GOVERNANCE.md`).
- Đọc trước: `PROMPT_AGENT_DICH_MAN_HINH.md`, `PROMPT_AGENT_DICH_MAN_HINH_P2.md`,
  `docs/adr/ADR-0011*` và card `XLAT-SCR-002` trong KANBAN.

## 1. Triệu chứng (chủ dự án, bản 0.10.3)

Home → Cài đặt → bật **Dịch màn hình toàn hệ thống** → bong bóng nổi hiện ra
→ **chạm vào bong bóng thì không có gì xảy ra** (không overlay, không toast,
không lỗi).

## 2. Phân tích ban đầu (dùng làm điểm xuất phát, phải kiểm chứng bằng log)

Chuỗi hiện tại: chạm bong bóng → `onBubbleTapped()` → `requestConsent()` →
**khởi chạy Activity xin quyền MediaProjection từ trong foreground service**.

Ba điểm chặn đã biết của Android, cả ba đều "im lặng":

1. **Android 10+ cấm khởi chạy Activity từ nền** (background activity start).
   Service không có "lý do được miễn" ⇒ hệ thống **bỏ qua** `startActivity`,
   log chỉ có một dòng `ActivityTaskManager: Background activity start ...`.
   Cách chuẩn: dùng `PendingIntent` qua **notification/bubble full-screen
   intent**, hoặc đưa người dùng về một Activity trong suốt (`Translucent`)
   làm cầu nối xin consent.
2. **Android 14 (API 34)**: foreground service loại `mediaProjection` phải
   được khai báo `android:foregroundServiceType="mediaProjection"` **và**
   consent phải xin lại **mỗi phiên**; `startForeground` sai loại ⇒
   `SecurityException`/service bị giết ngay.
3. **Quyền overlay** (`SYSTEM_ALERT_WINDOW`) bị thu hồi sau khi người dùng
   gỡ/cài lại hoặc app bị hệ thống "hạn chế" ⇒ view overlay không add được,
   `WindowManager.addView` ném, bị catch rỗng ở đâu đó.

## 3. Việc phải làm

1. **Dựng log trước, sửa sau**: `adb logcat | grep -iE "in4up|screentranslate|
   MediaProjection|ActivityTaskManager|WindowManager"`. Ghi lại **đúng** dòng
   chặn vào card KANBAN. Không sửa mò.
2. **Không bao giờ im lặng nữa** (bắt buộc, kể cả khi không sửa được gốc):
   mọi nhánh thất bại của `onBubbleTapped` phải có phản hồi thấy được —
   rung nhẹ + toast/notification tiếng Việt nói rõ bước tiếp theo ("Cần cấp
   lại quyền chụp màn hình", "Android 14 yêu cầu đồng ý lại mỗi lần bật"…).
3. **Sửa đường xin consent** theo cách Android cho phép (PendingIntent từ
   notification hoặc Activity cầu nối trong suốt), giữ nguyên kiến trúc
   ADR-0011 (chụp + vẽ ở native, OCR + dịch ở Dart).
4. **Khai báo manifest** đúng `foregroundServiceType` + quyền theo từng mức
   API; kiểm tra chéo `targetSdk` hiện tại của dự án.
5. **Tự kiểm tra quyền trước khi hiện bong bóng**: thiếu overlay hoặc thiếu
   consent thì bong bóng hiện ở trạng thái "cần thiết lập" và chạm vào là mở
   đúng màn hình cài đặt.
6. **i18n** đủ `en/hi/zh/zh_TW/si` cho mọi chuỗi mới.
7. **Test**: phần Kotlin chưa có CI biên dịch (xem card XLAT-SCR-002) — viết
   test thuần Dart cho máy trạng thái quyền (`ScreenTranslatePermissionState`:
   thiếu overlay / thiếu consent / sẵn sàng) và nối vào bước
   `Screen translate tests` có sẵn trong `app_analyze.yml`.

## 4. Nghiệm thu trên máy thật

1. Android 12/13: chạm bong bóng → hỏi consent → đồng ý → ≤3s có bản dịch đè.
2. Android 14: tắt rồi bật lại → **hỏi consent lại** → vẫn chạy.
3. Thu hồi quyền overlay trong Cài đặt hệ thống → chạm bong bóng → có hướng
   dẫn rõ ràng, **không** im lặng.
4. Từ chối consent → có thông báo, bong bóng vẫn sống, app không crash.
5. Tắt tính năng → overlay + notification + tiến trình ngầm biến mất sạch.
6. `flutter analyze` 0 error + bước test locale + screen translate xanh.
7. Một lượt `flutter build apk --flavor stable` thành công.
