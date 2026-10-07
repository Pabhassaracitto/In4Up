# I4U UX — C-31 State Preservation QA

> Trạng thái: bộ kiểm định chạy được cho cả 6 vùng + 3 lỗi thật đã sửa.
> Nguồn: `docs/ux/39-capability-breakdown.vi.md` (C-31), `docs/ux/38-shared-state-contract.vi.md`,
> `docs/ux/36-pre-freeze-review.vi.md` (§2 layer state machine, §5 semantic anchor fallback).
> Cập nhật: 2026-10-07.

## 1. Phạm vi

Sáu vùng bảo toàn trạng thái phải giữ trước khi UX Freeze được coi là đóng:

| Mã | Vùng | Câu hỏi kiểm định |
|---|---|---|
| `source-return` | Source context | Handoff Đọc/Nghe/Xem → workspace khác có giữ đúng nguồn để quay lại? |
| `reading-anchor` | Reading anchor | Mốc đọc khôi phục đúng, và **không highlight** khi không đủ tin cậy? |
| `draft` | Draft | Nháp chưa lưu có bị sự kiện hệ thống xoá mất không? |
| `playback` | Playback | Đổi lớp hiển thị có làm đổi trạng thái phát không? |
| `route-return` | Route return | Back/return đi đúng thứ tự lớp và trả đúng nguồn? |
| `offline-conflict` | Offline event/conflict | Log append-only, conflict không mất dữ liệu? |

## 2. Cách chạy

```bash
flutter test test/state_preservation_qa_test.dart
```

Trong code (dùng được từ QA harness khác):

```dart
final report = await const I4uStatePreservationQa().run();
report.isComplete;          // đủ 6 vùng + mọi kịch bản giữ đúng
report.toQualityRun();      // nối vào I4uQualityRun của UX freeze (C-30)
print(report.toSummary());  // log cho QA tay / CI
```

**Cổng chặn (không pass rỗng):** `isComplete` chỉ `true` khi mọi kịch bản đạt **và**
cả 6 vùng đều có kịch bản. Vùng chưa có máy bắt nằm trong `uncoveredAreas` ⇒
`toQualityRun()` trả `fail` (blocker). Việc chỉ kết luận được trên thiết bị thật
nằm ở `kI4uPreservationManualChecks` và không bao giờ tự động được tính là đạt.

## 3. Ma trận máy bắt (26 kịch bản)

| Mã | Vùng | Bất biến được giữ |
|---|---|---|
| C31-SRC-01 | source-return | Chọn đoạn → capability → quay lại giữ source/block/offset |
| C31-SRC-02 | source-return | Fingerprint round-trip đủ 9 trường (kể cả `createdAt`, `returnPath`) |
| C31-SRC-03 | source-return | Xem → Hiểu giữ nguồn + mốc thời gian + phụ đề đang chọn |
| C31-SRC-04 | source-return | Mở panel aA không mất nguồn/mốc đang đọc |
| C31-SRC-05 | source-return | Nguồn đang ôn sống suốt phiên Nhớ (start → reveal → rate → thẻ kế → pause) |
| C31-ANC-01 | reading-anchor | Cùng revision + block: offset đúng, confidence 1.0 |
| C31-ANC-02 | reading-anchor | Revision đổi + mất dấu vết: trả `null` (không highlight sai) |
| C31-ANC-03 | reading-anchor | Còn từ đã chọn: fallback tìm từ, tin cậy ≥ 0.8 và < 1.0 |
| C31-ANC-04 | reading-anchor | Mốc nguồn khác / văn bản rỗng: không rò sang nguồn hiện tại |
| C31-ANC-05 | reading-anchor | Offset vượt độ dài bị kẹp; dữ liệu cũ thiếu revision vẫn đọc được |
| C31-DFT-01 | draft | Nháp AI Coach sống qua gợi ý → submit → feedback |
| C31-DFT-02 | draft | Nguồn đổi revision KHÔNG xoá nháp đang gõ (cùng hint/step/source) |
| C31-DFT-03 | draft | Đóng panel công cụ giữ ngữ cảnh đoạn; nháp ghi chú còn đủ chỗ neo |
| C31-DFT-04 | draft | Back khi có nháp: `confirmDraft`/`saveDraft` TRƯỚC khi trả nguồn |
| C31-DFT-05 | draft | Pause giữ thẻ/tầng học thuộc/rating/nguồn; thẻ mới xoá rating cũ |
| C31-PLY-01 | playback | Quick Actions thu gọn rồi **khôi phục** Mini Player, playback không đổi |
| C31-PLY-02 | playback | Sheet lớn ẩn foreground, audio tiếp tục; đóng sheet khôi phục mini |
| C31-PLY-03 | playback | Expanded Player là ngoại lệ full-screen; đóng ra về mini, mốc phát giữ |
| C31-PLY-04 | playback | Mở/đóng player Thư viện nghe không mất mục đang chọn |
| C31-PLY-05 | playback | Đổi chế độ phụ đề không nhảy mốc thời gian/mất nguồn |
| C31-RTN-01 | route-return | Thứ tự back: overlay → panel → sheet → nháp → nguồn → route → Home |
| C31-RTN-02 | route-return | Trả nguồn mang đúng `returnPath`; ở Home nhường thoát cho nền tảng |
| C31-OFF-01 | offline-conflict | Conflict < 5 phút: event muộn không tính mastery nhưng KHÔNG bị xoá |
| C31-OFF-02 | offline-conflict | Hai thứ tự sync ra cùng kết quả; chạy lại không đổi (deterministic + idempotent) |
| C31-OFF-03 | offline-conflict | Log append-only: `eventId` trùng bị từ chối; nén không mất dấu vết audit |
| C31-OFF-04 | offline-conflict | Conflict chỉ áp cho cùng unit + cùng skill (không gộp 3 skill) |

## 4. Lỗi thật phát hiện và đã sửa

| # | Vị trí | Triệu chứng | Sửa |
|---|---|---|---|
| 1 | `I4uCoachFlowController.markStale()` | Sự kiện hệ thống (nguồn đổi revision) xoá `answerDraft` + `hintLevel` ⇒ mất chữ người học đang gõ | Giữ nháp/hint/step khi `stale`; chỉ `nextStep()`/`start()` mới xoá (chủ ý của người học) |
| 2 | `I4uRememberFlowController` (`pause`, `nextCard`, các bước khác) | `pause()` xoá `stage`/`rating`/`source`; `nextCard()` xoá `stage`; mọi bước xoá `source` ⇒ UI quên tầng học thuộc và **mất nguồn đang ôn** (vi phạm rule vàng #3) | Giữ `source` suốt phiên; giữ `stage` khi pause/sang thẻ; `rating` thuộc thẻ đang mở; thêm `loadSource()` |
| 3 | `I4uMiniPlayerSurfaceState` | Đóng Quick Actions/sheet lớn không khôi phục được Mini Player (không có bộ nhớ trạng thái trước) ⇒ trái `docs/ux/36 §2 (largeSheetClosed → restore previous mini state)` | Thêm `suspendedMode` + khôi phục khi lớp phủ đóng; trạng thái phát không đổi |

Mỗi lỗi có test nhớ lại: `test/state_preservation_qa_test.dart` (kịch bản),
`test/remember_flow_test.dart`, `test/coach_flow_test.dart`,
`test/mini_player_surface_state_test.dart`.

## 5. Việc phải QA tay (không tự nhận đạt)

| Vùng | Việc trên thiết bị thật |
|---|---|
| source-return | Đọc → chọn đoạn → Hiểu → quay lại đúng trang/đoạn; Nghe/Xem → Hiểu → quay lại đúng mốc audio; xoay/khóa máy giữa handoff |
| reading-anchor | Mở lại tài liệu đã sửa ngoài app (revision đổi) — không highlight; PDF re-flow/đổi cỡ chữ; tài liệu bị xoá/di chuyển |
| draft | Đang gõ ghi chú → back/khoá app → mở lại; nguồn đổi revision khi đang gõ; từ chối lưu nháp |
| playback | Quick Actions/sheet khi đang phát; đóng sheet → Mini Player trở lại; chuyển 5 workspace khi đang phát |
| route-return | Back từng lớp trên Android; back ở Home; deep-link/tab switch rồi back |
| offline-conflict | 2 thiết bị cùng ôn 1 thẻ trong 5 phút; tắt mạng khi đang ôn rồi mở lại; conflict ghi chú/vị trí đọc |

## 6. Bằng chứng

- Máy bắt: `lib/core/qa/state_preservation_qa.dart` + `test/state_preservation_qa_test.dart`
  (thuần Dart: không plugin, không mạng, không `BuildContext`).
- CI: `flutter analyze` trên nhánh này phải 0 error (nhánh nền trước đó đỏ vì lỗi
  cú pháp `main_shell.dart` — xem mục 7).
- Số kịch bản: 26 kịch bản / 6 vùng; trạng thái cụ thể đọc từ `toSummary()`.

## 7. Việc còn mở (không tự nhận đã đóng)

1. **Bước CI riêng cho C-31 chưa có.** `app_analyze.yml` chỉ chạy các file test
   được liệt kê tường minh; thêm bước mới cần quyền sửa `.github/workflows/`
   (token hiện tại không có quyền `workflows`). Đề xuất: thêm step
   `flutter test test/state_preservation_qa_test.dart` cạnh các bước UX contract.
2. **Route return trên navigator thật** (Flutter Router/back stack) thuộc QA tay —
   harness chỉ kiểm lớp quyết định thuần (`I4uBackDismissCoordinator`).
3. **Offline sync thật** (Firestore + hàng đợi pending, LHB-006) không thuộc phạm vi
   C-31; C-31 kiểm engine log/conflict thuần Dart (`ReviewEvent`, `InMemoryReviewEventStore`).
4. **Anchor fallback "text fingerprint → nearby search"** trong `docs/ux/36 §5` chưa
   hiện thực; hành vi hiện tại là trả `null` (không highlight sai) — an toàn nhưng
   chưa khôi phục được nhiều trường hợp; ghi lại như việc mở.
