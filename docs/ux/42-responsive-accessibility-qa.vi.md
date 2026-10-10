# I4U UX — C-30 Responsive / Accessibility QA

> Trạng thái: bộ kiểm định chạy được cho cả 7 vùng (16 kịch bản logic + **9** bằng chứng đo trên widget thật)
> + 2 phát hiện cần theo dõi.
> Nguồn: `docs/ux/39-capability-breakdown.vi.md` (C-30), `docs/ux/36-pre-freeze-review.vi.md` §6 (Split accessibility),
> `docs/ux/37-component-inventory.vi.md` (KeyboardAvoidingSurface / FocusTrap).
> Cập nhật: 2026-10-08.

## 1. Phạm vi

| Mã | Vùng | Câu hỏi kiểm định |
|---|---|---|
| `text-scale` | Text scale | Chrome kẹp theo chính sách, không vỡ khi chữ to |
| `keyboard` | Keyboard | Dùng `viewInsets` thật; input không bị bàn phím che |
| `screen-reader-labels` | Screen reader labels | Surface có nhãn đọc được — không "icon trần" |
| `touch-targets` | Touch targets | Vùng chạm ≥ ngưỡng Material, không bị bóp |
| `orientation` | Orientation | Đổi hướng chỉ đổi bố cục, không vỡ/mất input |
| `safe-area` | Safe area | Inset âm bị kẹp, surface nổi không đè navigation |
| `overlay-stacking` | Overlay stacking | Thứ tự lớp tất định theo policy dùng chung |

## 2. Cách chạy

```bash
flutter test test/responsive_accessibility_qa_test.dart
```

Trong code:

```dart
final report = await I4uResponsiveQa(evidence: widgetEvidence).run();
report.isComplete;        // đủ 7 vùng + mọi kiểm định đạt
report.toQualityRun();    // nối vào I4uQualityRun (C-31 dùng cùng hợp đồng)
print(report.toSummary());
```

**Cổng chặn (2 tầng, cố ý):**

1. **Không đo được ≠ đạt.** `screen-reader-labels` và `touch-targets` **không** có kịch bản logic
   nào (không thể kết luận bằng số học) — chúng chỉ được tính khi test widget cung cấp
   `I4uResponsiveEvidence`. Thiếu bằng chứng ⇒ `uncoveredAreas` khác rỗng ⇒ `isComplete = false`
   ⇒ `toQualityRun()` trả blocker.
2. **Hai tầng bằng chứng tách nhau.** Kịch bản logic bảo vệ *policy* (`AppResponsive`,
   `I4uSafeAreaPolicy`, `I4uOverlayPolicy`); bằng chứng widget đo *hành vi thật* (nhãn semantics,
   kích thước chạm, bàn phím, xoay máy). Báo cáo chỉ xanh khi cả hai cùng xanh.

## 3. Ma trận máy bắt

### 3.1 Kịch bản logic thuần (16)

| Mã | Vùng | Bất biến |
|---|---|---|
| C30-TXT-01 | text-scale | Cỡ chữ chrome kẹp đúng dải 0.95–1.15 (cả API số lẫn `TextScaler`) |
| C30-TXT-02 | text-scale | Số cột lưới tăng đơn điệu theo bề rộng (1/2/3/4) |
| C30-TXT-03 | text-scale | Bề rộng nội dung ≤ màn hình; không kéo dài vô hạn trên màn rộng; padding ngang tăng dần |
| C30-KBD-01 | keyboard | Inset hiệu dụng = `max(safe-area, viewInsets)`, không âm |
| C30-KBD-02 | keyboard | Offset surface nổi = inset + navigation + spacing; mở bàn phím phải đẩy lên |
| C30-KBD-03 | keyboard | Offset không bao giờ < navigation + spacing (lưới 5 bối cảnh) |
| C30-SAF-01 | safe-area | Inset âm/rác bị kẹp, không tạo padding âm |
| C30-SAF-02 | safe-area | Offset phản ánh giá trị runtime (3 bối cảnh ⇒ 3 giá trị) — chống hard-code |
| C30-SAF-03 | safe-area | Công thức offset khớp tài liệu trên lưới 36 tổ hợp (safe × view × nav) |
| C30-OVL-01 | overlay-stacking | Chuỗi lớp tăng nghiêm ngặt + quan hệ trên/dưới đối xứng |
| C30-OVL-02 | overlay-stacking | Mini Player không chen foreground khi có lớp phủ |
| C30-OVL-03 | overlay-stacking | Audio chỉ "tiếp tục nền" khi sheet lớn ẩn player |
| C30-OVL-04 | overlay-stacking | Shortcut scope ánh xạ đúng lớp (modal→dialog, player→miniPlayer, …) |
| C30-ORI-01 | orientation | Phân lớp cửa sổ đúng + không nhảy ngược khi quét 320→2000px |
| C30-ORI-02 | orientation | Đổi hướng ⇒ bố cục đổi theo (cột/padding/bề rộng dòng) |
| C30-ORI-03 | orientation | Ngưỡng breakpoint là một nguồn duy nhất, `classify` khớp đúng tại biên |

### 3.2 Bằng chứng đo trên widget thật (9)

| Mã | Vùng | Đo gì trên widget nào |
|---|---|---|
| C30-W-SAF-01 | safe-area | `I4uSafeAreaFloatingHost`: offset = 76 / 110 / 376 với (không inset) / (notch 34) / (bàn phím 300) |
| C30-W-A11Y-01 | screen-reader-labels | `Command Palette`: mỗi lệnh có nhãn semantics |
| C30-W-A11Y-02 | screen-reader-labels | `I4uGlobalChatSurface`: nút gửi icon-only có nhãn (`label`/`tooltip` khác rỗng) |
| C30-W-TCH-01 | touch-targets | Mục lệnh cao ≥ 48 logical px |
| C30-W-TCH-02 | touch-targets | Nút icon ≥ 40px **và** `MaterialTapTargetSize.padded` (vùng chạm 48 không bị shrinkWrap) |
| C30-W-TXT-01 | text-scale | Command Palette hiển thị ở trần cỡ chữ chính sách 1.15 — không tràn |
| C30-W-KBD-01 | keyboard | Bàn phím cao 300 ⇒ đáy ô nhập ≤ mép bàn phím |
| C30-W-ORI-01 | orientation | Dọc ↔ ngang: không tràn, ô nhập vẫn còn |
| C30-W-ORI-04 | orientation | Drift guard: ngưỡng cứng trong `main_shell.dart` phải thuộc policy (600/1024/1440) |

> Ghi chú kỹ thuật: `C30-W-TCH-02` cố ý kiểm **hai** điều kiện thay vì chỉ đo `IconButton`
> (Material 3 mặc định 40×40, vùng chạm 48 đến từ `MaterialTapTargetSize.padded`). Đo mỗi
> kích thước widget sẽ bỏ lọt trường hợp theme bị đặt `shrinkWrap`.

## 4. Phát hiện (không tự sửa trong C-30 — ghi lại để không mất)

### 4.1 Policy C-02 đã có, nhưng **chưa nối vào app** (ưu tiên cao)

`lib/core/responsive/safe_area_overlay_policy.dart` + `lib/core/responsive/app_responsive.dart`
được viết cho C-02 (safe-area/keyboard/overlay) và có test, nhưng **0 nơi trong `lib/` dùng chúng
ngoài chính QA/test**:

```text
grep -rn "AppResponsive\.\|I4uSafeAreaPolicy\.\|I4uOverlayPolicy\.\|I4uSafeAreaFloatingHost" lib \
  | grep -v "lib/core/responsive/" | grep -v "lib/core/qa/"
→ (rỗng)
```

Hệ quả cụ thể: `main_shell.dart` tự so ngưỡng cứng `>= 1024` ở 2 chỗ (dòng 1288 và 1381) — giá
trị **trùng** `AppResponsive.expandedWidth` nên hiện chưa lệch, nhưng đây là bản sao thứ hai của
cùng một ngưỡng. Kịch bản `C30-W-ORI-04` (drift guard) canh việc này: nếu ai đổi một bên, test đỏ.
Việc còn lại là **nối policy vào shell** — thuộc capability C-02b/C-10 (không nằm trong phạm vi QA).

> **✅ Đã nối phần breakpoint + trần overlay ở UX-C02b (2026-10-08):** `main_shell.dart` nay đọc
> `AppResponsive.expandedWidth` (2 chỗ, không còn literal `1024`); `command_palette.dart` đọc
> `AppResponsive.overlayDialogMaxWidth/Height`. Drift guard `C30-W-ORI-04` được siết thành 4 phép
> khẳng định (không literal `>= NNN` trong `lib/widgets/shell/` + `main_shell.dart`, shell **thật sự**
> dùng policy, palette **thật sự** dùng trần policy, không cap hard-code trong palette).
> **Chưa** nối: `I4uSafeAreaPolicy` / `I4uSafeAreaFloatingHost` / `I4uOverlayPolicy` cho các surface
> nổi thật — ~20 sheet/surface đang tự viết `viewInsets.bottom + N` (đổi sang host sẽ **cộng thêm**
> safe-area bottom ⇒ đổi cảm giác padding); `I4uOverlayPolicy.miniPlayerVisibleInForeground` cũng
> chưa khớp ngữ nghĩa với `_shouldShowShellMiniPlayer` (theo tab, không theo overlay state). Hai việc
> này để capability riêng, cần QA thiết bị.

### 4.2 Chrome tiếng Việt hard-code trong 2 widget shell (rule #5) — ✅ đã đóng ở I18N-002

`command_palette.dart` + `global_chat_surface.dart` có **8 literal tiếng Việt**, **không** đi qua
`uiText`/ARB (`grep uiText` trong 2 file = 0) ⇒ locale ≠ vi hiện nguyên tiếng Việt:

```text
'Không thể gửi lúc này. Hãy thử lại.'  'Không có source context'  'Đổi context'
'Đặt câu hỏi để bắt đầu.'  'Viết câu hỏi…'  'Gửi'   ← 6 literal trong global_chat_surface.dart
'Tìm lệnh hoặc workspace'  'Không tìm thấy lệnh phù hợp.'   ← 2 literal trong command_palette.dart
```

**Số liệu chính xác** (bản đầu ghi "7 chuỗi" do đếm sót): 7 nhãn **chưa có** English trong catalog
+ 1 nhãn (`'Gửi'`) **đã có** English (`generated_legacy_ui_fallbacks.dart` → `'Send'`) nhưng mã
nguồn vẫn hard-code nên key đó vô hiệu ở runtime. `'Global Chat'` không tính (đã là tiếng Anh).

**Đã sửa trong I18N-002** (2026-10-08):
- Bọc cả 7 nhãn bằng `context.uiText(...)` (thêm import `localized_material.dart`; bỏ `const` ở
  `InputDecoration`/`Padding`/`Center` tương ứng).
- Đăng ký English ở **cả hai** nơi: `lib/core/language/priority_ui_overrides.dart` (đường runtime —
  `AppUITranslations` đọc map này trước) và `tool/legacy_ui_english_overrides.json` (nguồn của
  generator). Chỉ `en`, theo tiền lệ 15 key Tipiṭaka: đó là canonical fallback của rule #5, không
  bịa bản dịch `hi/zh/zh_TW/si` chưa ai review.
- Bong bóng tin nhắn trong `global_chat_surface.dart` render bằng `material.Text` (import có tiền
  tố) — rule #5 **loại trừ nội dung user/AI**, không đi qua cơ chế dịch chrome.
- Máy bắt mới `test/shell_chrome_i18n_coverage_test.dart`: (1) literal Việt trong `lib/widgets/shell/`
  phải được bọc `uiText/tr`; (2) mọi nhãn bọc phải dịch được ở `en/hi/zh/zh_TW/si/ja` và không rơi
  về `vi`; (3) dựng thật 2 surface ở locale `en`, quét Text/RichText/Tooltip — không còn ký tự Việt.
  Test C-30 được ghim `locale: vi` (đo chrome, không đo dịch) để hai mối quan tâm không trộn nhau.

**Phát hiện kèm theo (đã ghi vào card I18N-001, chưa sửa):** "máy bắt" phân loại literal chrome
`tool/generate_legacy_ui_fallbacks.py` **đang chết** và **không được CI chạy**:
`ValueError: 68 reviewed overrides no longer match extracted presentation sources` (chạy thử
2026-10-08). Đây chính là lỗ hổng khiến 7 nhãn trên lọt qua. Sửa nó là capability riêng (68 key cũ
+ phân loại lại toàn bộ literal) — xem card `I18N-001` trong KANBAN.

## 5. Việc phải QA tay (không tự nhận đạt)

| Vùng | Việc trên thiết bị thật |
|---|---|
| text-scale | Cỡ chữ hệ thống Lớn nhất (Android/iOS) + cỡ chữ riêng của app; nội dung đọc giữ cỡ người dùng chọn |
| keyboard | Bàn phím có thanh gợi ý/emoji (chiều cao khác), xoay máy khi bàn phím đang mở |
| screen-reader-labels | TalkBack/VoiceOver: 5 tab đọc đúng tên + trạng thái chọn; player đọc đúng trạng thái phát; focus vào dialog và trả focus khi đóng |
| touch-targets | "Hiển thị ranh giới" của TalkBack/VoiceOver để đo vùng chạm thật; nút sát gesture bar |
| orientation | Xoay ở cả 5 workspace (không mất vị trí đang đọc); xoay khi đang phát; thu nhỏ cửa sổ desktop < 1024 |
| safe-area | Máy notch/gesture bar: surface nổi + bottom nav không chồng; bàn phím mở không cộng dồn inset sai |
| overlay-stacking | Command Palette mở trên sheet: đúng 1 lớp nhận input; Mini Player + Quick Actions + bottom nav không tranh vùng chạm |

## 6. Bằng chứng

- Máy bắt: `lib/core/qa/responsive_accessibility_qa.dart` +
  `test/responsive_accessibility_qa_test.dart` (16 kịch bản logic + **9** bằng chứng widget:
  `C30-W-SAF-01`, `C30-W-A11Y-01/02`, `C30-W-TCH-01/02`, `C30-W-TXT-01`, `C30-W-KBD-01`,
  `C30-W-ORI-01/04`).
- CI: bước *"UX shell contracts + C-31 state preservation (logic thuần)"* trong
  `.github/workflows/app_analyze.yml` nay chạy **24 file** test (đã gồm C-30 và
  `test/shell_chrome_i18n_coverage_test.dart` của I18N-002) — artifact `app-ux-contract-test-log`.
- Bằng chứng CI xanh cuối (2026-10-08, commit `fc5d7ea`): push `37804605761` + PR `37804624188`
  — analyze ✓, Rule 5 ✓, **step 24 success** trên 24 file test (có cả máy bắt shell của I18N-002).
  Lưu ý tương tác: C-30 đo chrome nên 2 finder đổi theo nhãn đã bản địa hoá (`find.byTooltip('Send')`
  ở locale mặc định của test env) — xem AGENTS.md “Bẫy widget test + locale”.
- Bằng chứng CI (2026-10-08): run `37800693993` **đỏ** đúng 2 test A11Y với lỗi
  *"A SemanticsHandle was active at the end of the test."* — ở Flutter 3.44.1,
  `WidgetTester._endOfTestVerifications` chạy cuối thân test **trước `addTearDown`**, nên
  `addTearDown(semantics.dispose)` là quá muộn. Đã sửa bằng `semantics.dispose()` tường minh trong
  thân test (giữ nguyên mọi phép đo) ⇒ run `37801748437` (push) và `37801754613` (PR) **xanh**,
  bước 24 success (commit `61d85e0`). Bài học đã ghi vào `AGENTS.md`.
- Kịch bản "không tự nhận đạt" được kiểm bằng test: chạy harness **không** kèm bằng chứng widget ⇒
  `isComplete = false` và `toQualityRun().hasBlocker = true`.

## 7. Việc còn mở

1. **Nối policy C-02 vào shell** (mục 4.1) — ✅ breakpoint + trần overlay đã nối ở UX-C02b;
   còn `I4uSafeAreaPolicy`/`I4uSafeAreaFloatingHost` (surface nổi, ~20 sheet) và
   `I4uOverlayPolicy` (ưu tiên mini player) — cần capability riêng + QA thiết bị vì đổi padding thật.
2. ~~Chuỗi chrome tiếng Việt trong 2 widget shell~~ — ✅ đã đóng ở I18N-002 (đăng ký `en`; T2
   `hi/zh/zh_TW/si` hiện rơi về `en` theo rule #5, chờ đợt dịch T2 như mọi key legacy khác).
3. **TalkBack/VoiceOver + cỡ chữ hệ thống thật**: không thể kết luận trong sandbox; cần QA tay theo §5.
4. **Split view ≥1440px** (`docs/ux/36` §6: divider, close từng pane, keyboard nav, screen reader label,
   minimum content width, fallback Replace) chưa được kiểm — chưa có màn hình Split thật để đo.
