# L11 — Backlog cũ + hàng đợi In Review (ngoài cổng beta)

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD).
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

> ⚠️ **Lane này KHÔNG thuộc cổng beta 1.29.0.** Nó tồn tại để backlog cũ có chủ, và để chủ dự án có thể nhắn một câu và kéo một nhúm vào cùng nhánh beta nếu rảnh. Hub chỉ land sau khi 10 lane trên xong.

## Mục tiêu

Dọn phần còn lại của project I4U: (a) **chốt 2 issue đang In Review** đã sửa xong, (b) phân loại các issue mở **ID ≤ PSRC-196** — mỗi cái phải được gán vào một lane khu vực (L1–L10) hoặc đóng với lý do.

## A. Hai issue đang In Review — chốt trước

| # | Trạng thái | Việc cần làm |
|---|---|---|
| **PSRC-14** | In Review | `READ-SELECT-002` (kéo chọn nhiều từ). Mô tả nói đã sửa, CI xanh (run `37529218138`). **Việc của agent:** kiểm lại trên nhánh beta, chạy lại test liên quan, nếu đúng ⇒ comment bằng chứng rồi chuyển **Done** |
| **PSRC-6** | In Review | `XLAT-MIX-001` (câu trộn ngôn ngữ). Như trên |

Không viết lại code nếu đã xanh — chỉ **xác minh + đóng**, hoặc mở lại nếu thấy hồi quy.

**Đính chính của agent L11 (2026-11-13):** run `37529218138` trong bảng trên là của
**PSRC-6** (`XLAT-MIX-001`, head `74af5d8`, nhánh `arena/78cea3c6-in4up`), không phải của
PSRC-14. Hai run của PSRC-14 (`READ-SELECT-002`) là `37653001863` và `37654112487`
(nhánh `arena/a106f0d6-in4up`) — lấy từ card KANBAN `READ-SELECT-002`.

### A.1 PSRC-14 — `READ-SELECT-002`: kết quả xác minh (2026-11-13, agent L11)

**Kết luận: ĐẠT ⇒ đã comment bằng chứng trên Linear và chuyển `Done`.**
Xác minh trên nhánh `arena/d0e2d365-in4up`, nền `962e7e1` (= tip `arena/60e35d65-in4up`).

| Mục | Bằng chứng đọc được trong mã |
|---|---|
| Luật chọn nhiều từ (thuần logic) | `lib/screens/read_mode/services/word_range_selection.dart` — `WordRange` (mỏ neo `anchorIndex` ↔ đầu kéo `focusIndex`), `resolveWordRange`, `buildWordSelectionText`, `wordIndexAtPoint`, `WordSelectionState`. Đầu file ghi đúng nguyên nhân gốc của audit 1.e: mỗi từ là một `GestureDetector`, không có `SelectableText` |
| Widget ô chữ vào chế độ chọn | `lib/screens/read_mode/widgets/colored_text_widget.dart` — giữ một từ ⇒ `WordSelectionState.activate(lineIndex)` (dòng 339); kéo/chạm từ thứ hai ⇒ `resolveWordRange` (dòng 326, 347) + `wordIndexAtPoint` (dòng 371); 4 nút trên thanh hành động gọi **một đường duy nhất** `ReadTextActionRunner.run(...)` (dòng 225–240); ghi selection thật bằng `TextProvider.selectTextWithOffsets(...)` (dòng 413–418); thoát chọn khi chạm ra ngoài/đổi dòng (dòng 78–97, 378–379) |
| Hướng dẫn thao tác cho người dùng | `lib/screens/read_mode/widgets/read_line_hint.dart:119` — "Giữ một từ ở chế độ ô chữ: vào chế độ chọn nhiều từ; nút Từ chi tiết mở bảng tra từ đầy đủ." |
| Máy bắt (test tự động) | `test/read_mode/word_range_selection_test.dart` — **18 test / 5 nhóm**: mỏ neo ↔ đầu kéo, chuỗi ghép + offset trong dòng, `wordIndexAtPoint` khi kéo quá mép, chọn thông minh kề vùng chọn, chạm ra ngoài thì bỏ chọn |
| Test đã nối CI | `.github/workflows/app_analyze.yml` bước **"Read actions + mixed-language tests (logic thuần)"** liệt kê `test/read_mode/word_range_selection_test.dart` (dòng ~916) |
| CI xanh | Nhánh cha: run **`43360617301`** (head `0ad2f2f9`) — step "Read actions + mixed-language tests" = `success`, "Analyze full app (chỉ ERROR là fatal)" = `success`, "Rule 5 test" = `success`. Tip nhánh cha `962e7e1` chỉ **hơn** `0ad2f2f9` 3 commit tài liệu (`gh api …/compare/0ad2f2f9...962e7e1` ⇒ `ahead_by 3, behind_by 0`) ⇒ code không trôi từ lần xanh đó. Run gốc của issue: `37653001863`, `37654112487` (đều `success`, xác minh lại qua GitHub API ngày 2026-11-13) |

**Chưa kiểm được trên máy thật:** sandbox của agent **không có Dart/Flutter SDK, không có
thiết bị/`adb`** ⇒ không tự chạy `flutter test` hay chạm–giữ–kéo thật được; test được chạy
lại bằng CI (xem run ở trên). Phần nghiệm thu chạm tay vẫn thuộc chủ dự án: giữ 1 từ → kéo
qua 4–5 từ → bấm **Dịch**/**Ngữ pháp** đúng cụm đó; thoát chọn rồi chạm 1 từ vẫn phát âm như
cũ; chế độ dòng (`SelectableText`) và interlinear không đổi hành vi. Nội dung này được ghi rõ
trong comment Linear, không giấu.

### A.2 PSRC-6 — `XLAT-MIX-001`: kết quả xác minh (2026-11-13, agent L11)

**Kết luận: ĐẠT ⇒ đã comment bằng chứng trên Linear và chuyển `Done`.**

| Mục | Bằng chứng đọc được trong mã |
|---|---|
| Bộ tách mẩu theo ngôn ngữ | `lib/features/translation/mixed_language_segmenter.dart` — `segmentByLanguage` + `containsForeignSegment` (dòng 160): chấm điểm từng mẩu theo dấu thanh tiếng Việt, từ chức năng tiếng Anh, chữ Hán/Kana |
| Nhánh dịch hỗn hợp | `lib/features/translation/translation_service.dart` — import segmenter (dòng 28), gọi `_translateMixedLanguage` (dòng 473), định nghĩa tại dòng 516: chỉ gửi đi dịch các mẩu **khác** ngôn ngữ đích rồi ghép lại đúng thứ tự |
| Nới guard "nguồn trùng đích" | `lib/features/translation/text_provider_translation.dart:251` dùng `containsForeignSegment` ⇒ hết cảnh cả ba tầng cùng từ chối im lặng |
| Máy bắt (test tự động) | `test/translation/mixed_language_test.dart` — **9 test** trong nhóm `segmentByLanguage`: câu tiếng Anh xen tiếng Việt được nhận ra (đúng bug 1.h), ghép lại ra đúng nguyên văn từng ký tự, đích là tiếng Anh thì câu tiếng Việt mới là ngoại ngữ, mẩu quá ngắn được gộp (không tự nhận ngoại ngữ), đoạn rỗng/trắng, nhiều câu Anh liền nhau gộp thành một mẩu, **tiếng Việt CÓ DẤU không bao giờ bị coi là ngoại ngữ** |
| Test đã nối CI | cùng bước **"Read actions + mixed-language tests (logic thuần)"** của `app_analyze.yml` (dòng ~925 liệt kê `test/translation/mixed_language_test.dart`) |
| CI xanh | Run gốc của issue **`37529218138`** — xác minh lại qua GitHub API ngày 2026-11-13: `conclusion: success`, head `74af5d8`, nhánh `arena/78cea3c6-in4up`, 2026-10-06. Trên nhánh cha hiện tại: run **`43360617301`** (`0ad2f2f9`) step read-actions/mixed-language = `success`, analyze = `success`; tip `962e7e1` chỉ hơn 3 commit tài liệu ⇒ không hồi quy |

**Giới hạn đã biết (giữ nguyên như mô tả issue, không "sửa" nhầm):** tiếng Việt viết
**không dấu** là nhập nhằng thật (`di`, `toi`…) nên một dòng không dấu có thể bị coi là
ngoại ngữ và dịch thừa; chấp nhận được vì **nguyên văn không bao giờ bị thay**. Test
khoá lại đúng kỳ vọng này.

**Chưa kiểm được trên máy thật:** mở một tài liệu Việt xen Anh trên thiết bị, đặt đích
tiếng Việt rồi bấm Dịch (cần engine dịch thật — mạng hoặc model Hy-MT đã tải). Sandbox
không có Dart/Flutter SDK lẫn mạng tới engine dịch ⇒ chỉ chứng minh được ở tầng logic
thuần + CI, đã ghi rõ trong comment Linear.

## B. Backlog cũ — bảng phân loại

Những issue dưới đây **đã biết** và được gán sẵn. Chúng **không** nằm trong đợt 1 của lane khu vực tương ứng; làm khi hub yêu cầu.

| # | Nội dung ngắn | Lane khu vực |
|---|---|---|
| PSRC-196 | Live cabin: đồng bộ chọn tab | L1 — **trùng PSRC-199** ⇒ đóng as duplicate khi 199 xong |
| PSRC-195 | Xuất file media kẹt "Estimating duration…" | L2 (đã đưa vào đợt 1 vì chặn 202/203) |
| PSRC-180 | Tạo lời lỗi FfmpegKit | L2 (đợt 1) |
| PSRC-179 | Đồng bộ khoảng lặng nút AB | L2 (đợt 1) |
| PSRC-194 | Icon dịch cabin hiện trên tab Nghe/Speaking | L4 |
| PSRC-193 | Tipitaka: chỉ mục con sai danh mục | L3 |
| PSRC-178 | Tên gọi "Lặp câu tiếp theo" | L3 |
| PSRC-174, PSRC-172 | Linux: quét thư viện không phản hồi | L5 |

## C. Phần chưa đọc hết — việc của agent L11

Page JSON của Linear bị giới hạn kích thước nên ~15 issue còn lại (ID thấp hơn PSRC-172, trạng thái Backlog) **chưa được liệt kê ở trên**. Agent L11 làm:

1. Mở Linear, project **I4U**, state **Backlog**, sắp theo `createdAt` tăng dần, **đọc từng trang ≤ 12 issue** (trang lớn hơn sẽ bị cắt giữa).
2. Với mỗi issue: gán **một** lane khu vực L1–L10 (theo thư mục `lib/features/...` mà nó chạm), hoặc đề xuất **đóng** (trùng/không còn tái hiện/ngoài sản phẩm) kèm lý do.
3. Ghi kết quả vào **§ D** của chính file này (một commit tài liệu), không sửa issue nào khác ngoài comment phân loại.
4. Chỉ sửa code khi chủ dự án chỉ định issue cụ thể.

## D. Bảng phân loại do agent điền

| # | Nội dung ngắn | Lane | Ghi chú |
|---|---|---|---|
| _(agent điền)_ | | | |

## Nghiệm thu

- [x] PSRC-14 và PSRC-6: có comment bằng chứng + đóng, hoặc mở lại kèm lý do.
      → cả hai **ĐẠT**, đã chuyển `Done` ngày 2026-11-13; bằng chứng ở § A.1 và § A.2,
      phần chưa kiểm máy thật ghi rõ trong từng mục và trong comment Linear.
- [ ] Mọi issue Backlog của I4U xuất hiện **đúng một lần** trong § B hoặc § D.
- [ ] Không issue nào bị đóng mà không có lý do viết ra.
- [ ] `app_analyze` xanh (nếu có sửa code).

## Commit

```
docs(PSRC-14): xác minh và đóng READ-SELECT-002 [L11]
docs(PSRC-6): xác minh và đóng XLAT-MIX-001 [L11]
docs(backlog): phân loại issue cũ vào lane khu vực [L11]
```

## Phát hiện thêm

_(trống)_
