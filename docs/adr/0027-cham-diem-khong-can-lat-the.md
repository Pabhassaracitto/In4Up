# ADR-0027 — Chấm điểm flashcard khi chưa lật thẻ

- **Ngày:** 2026-11-11
- **Trạng thái:** đề xuất trên `arena/6d4b3a0f-in4up` (PSRC-197), chờ CI và
  nghiệm thu thiết bị.
- **Phạm vi:** Vườn nhớ → phiên ôn flashcard (`lib/screens/memory_mode/`).
  KHÔNG đổi engine lịch ôn, không đổi schema `MemoryItem`.

## Bối cảnh

Audit v1.27.0 (PSRC-197): vào Tab Nhớ → **SRS / Cram / Khó**, flashcard bắt
người học lật thẻ rồi mới cho đánh giá. Hai chỗ chặn **độc lập** cùng áp luật
này:

1. `_GradeButtons` chỉ được render khi `isCardFlipped` (trước khi lật chỉ có
   dòng nhắc "🤔 Cố nhớ nghĩa rồi tap để lật").
2. `_commitSwipe` từ chối mọi hướng trừ **xuống** khi chưa lật và bắn snackbar
   "👆 Nhấn lật thẻ trước khi đánh giá".

Hệ quả: người **đã nhớ nghĩa** (đúng mục tiêu của chế độ nhồi — ôn nhanh,
nhiều lượt) vẫn bị bắt thêm một thao tác lật rồi mới chấm được ⇒ đứt nhịp học.
Ngoài ra `widgets/swipeable_flashcard.dart` + `swipe_card_controller.dart` là
bản flashcard **chết** (không file nào import) nhưng vẫn ôm nguyên luật cũ —
mầm tái phát khi ai đó "hồi sinh" nó.

## Quyết định

1. **Một cổng quyết định duy nhất, thuần Dart:** `RatingGate.allowsRating`
   (nút bấm) và `RatingGate.allowsSwipe` (vuốt) nằm trong
   `lib/screens/memory_mode/models/rating_gate.dart`. Không nơi nào khác được
   tự viết lại điều kiện `isFlipped`. Lý do: hai chỗ chặn lệch nhau chính là
   gốc của lỗi này.
2. **Mặc định CHO chấm trước khi lật** (`allowRateBeforeFlip = true`), cho mọi
   `ReviewMode` vì các mode dùng chung presenter. Nghĩa vẫn ẩn trên mặt trước
   — người học chủ động chọn "chấm luôn" hay "lật xem".
3. **Vuốt XUỐNG (hoãn học) luôn hợp lệ** ở mọi tổ hợp cài đặt: đó là quyết
   định về *thời điểm ôn*, không phải câu trả lời về trí nhớ (giữ hành vi cũ).
4. **Tắt được, và tắt là quay lại đúng hành vi cũ:** công tắc "Chấm điểm khi
   chưa lật thẻ" trong Cài đặt ôn tập (`ReviewSettings.allowRateBeforeFlip`).
   Khi tắt: ẩn hàng nút, hiện dòng nhắc lật, vuốt bị chặn như trước.
5. **Controller là chốt cuối:** `MemoryController.gradeCurrentCard` trả về sớm
   nếu `canRateCurrentCard == false`. UI đã chặn trước; chốt này để một đường
   gọi mới không thể chấm "mù".
6. **Xoá bản chết** `swipeable_flashcard.dart` + `swipe_card_controller.dart`
   thay vì sửa chúng: giữ hai bản flashcard song song là nguồn lỗi, không phải
   tài sản.
7. **i18n theo rule #5:** ba chuỗi mới có `en + zh/zh_TW/hi/si/my/th/ja` trong
   `tool/priority_native_pack.json` (sinh bằng generator) và English trong
   `tool/legacy_ui_english_overrides.json`. Nhãn `ReviewGrade` nay đi qua
   `context.uiText(...)` tại chỗ render (trước đây dựa vào shim `Text`).

## Hệ quả

- **Dễ:** một dòng luật, hai bề mặt (nút + vuốt) không thể lệch; test thuần
  chạy không cần plugin.
- **Rủi ro chấp nhận:** người học có thể tự chấm "Dễ" khi chưa từng thấy đáp
  án ⇒ dữ liệu lịch ôn bị "lạc quan" nếu họ bấm bừa. Chấp nhận vì (a) đây là
  lựa chọn chủ động của người học, (b) engine `markCorrect` vẫn giãn lịch theo
  stage như trước (không có công thức mới — ADR-0001), (c) tắt được trong Cài
  đặt ôn tập.
- **Không đụng:** `MemoryItem`/`MemoryStage`/công thức SM-2, luồng chấm trong
  Vườn (long-press, PSRC-22), và ba skill Hiểu–Nghe–Đọc (rule vàng #2).

## Kiểm chứng

- `test/srs/rate_before_flip_test.dart` — 3 test `RatingGate` (bật/tắt/hoãn
  học) · 3 test controller (mặc định, chấm được khi chưa lật, chốt cuối) ·
  2 widget test (4 nút trước khi lật & sang thẻ kế; tắt ⇒ hành vi cũ) ·
  2 test i18n.
- CI: step `PSRC-197` trong `.github/workflows/app_analyze.yml` (bỏ qua nếu
  nhánh chưa có file test).
- **Chưa kiểm:** máy thật (nhịp chấm bằng ngón tay; chữ nhắc mới ở màn
  360×640).
