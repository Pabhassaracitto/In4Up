# ADR-0021 — Tab Đọc: chrome theo nhóm và một cửa vào TTS

- **Trạng thái:** đã triển khai trên nhánh làm việc `arena/bada56c3-in4up`;
  PR **#126** (base `arena/01a0251e-in4up`) `mergeable = CLEAN`, **CI 16/16
  xanh** gồm `flutter analyze` + locale test, `android-resolver-compile`,
  `build` và 13 job test. Còn nghiệm thu thiết bị thật (360×640).
  Owner đã duyệt đề xuất trong `docs/read_tab_audio_ui_audit_1_20_0.md`
  (2026-11-02). Card `READ-UI-120` (KANBAN) + `PLAN-041` đã append theo luật
  GOVERNANCE.md (chỉ thêm, không xoá); owner có thể đổi mã card nếu muốn.
  Xung đột `docs/project/KANBAN.md` với card `LINUX-AUTH-001` của base đã được
  giải quyết bằng cách gộp base và giữ nguyên cả 2 card. Nhánh sau đó được rút
  gọn thành **một commit tuyến tính** có parent là base tip, vì GitHub tắt
  *Rebase and merge* khi head chứa merge commit (`rebaseable = false`).
- **Bối cảnh:** v1.20.0 có 2 đường phát TTS (thanh «Đọc song ngữ» ở đáy và
  icon người nói trong `ReadBottomBar`), 2 nguồn tốc độ (`tts_speed` /
  `playback_recipe.speed`), và 4 tầng chrome phía trên vùng đọc. Cờ
  `_readerChromeVisible` ẩn/hiện **toàn bộ** chrome ⇒ trên điện thoại nhỏ hoặc
  mất hết nút (kể cả Play), hoặc hiện 6 hàng icon lấn chữ. Play mặc định bị
  chặn bởi `await translateAll()`.

## Quyết định

### D1 — Một cửa vào, hai phạm vi, một nguồn tốc độ

- `ReadBottomDock` sở hữu **một** pill «Đọc». Tap = phát theo phạm vi đang
  chọn (`currentLine` → `TextProvider.speakCurrentLine`, `wholeDocument` →
  `PlaybackController`), tap lần 2 = dừng **mọi** phiên TTS. Long-press mở
  preset. Phạm vi, tốc độ, chế độ, giọng, khoảng lặng, lặp nằm trong panel
  «Đọc» — không còn nằm trong màn Cài đặt.
- **Không gộp engine.** `PlaybackEngine` + `PlaybackRecipe` + anchor resume +
  notification giữ nguyên; `TextProvider.speak` vẫn là preview. Hai phạm vi là
  hai mode của cùng một session owner (`TtsPlaybackOwner`).
- Nguồn tốc độ duy nhất: `TextProvider.ttsSpeed` (Hive `tts_speed`).
  `PlaybackController.recipe.speed` chỉ là bản phản chiếu trong phiên phát,
  nhận qua `start(..., speed:)` / `syncSpeed()`. `main.dart` migrate một lần
  từ `playback_recipe.speed` trước khi `TextProvider` restore.
- API công khai trong `smart_playback_bar.dart`: `startReadPlayback`,
  `toggleReadPlayback`, `setReadSpeed`, `adjustReadSpeed`,
  `showPlaybackPresetSheet`. Thanh cũ và dock đều gọi chung 4 hàm này.

### D2 — Bản dịch là lớp bổ sung, không phải điều kiện tiên quyết

- Mặc định recipe đổi từ `bilingual` → `enOnly` (máy đã lưu recipe vẫn giữ).
- `startReadPlayback` **không** `await translateAll()`, không snackbar chặn.
  `PlaybackEngine` đã có `hasCurrentTarget` ⇒ tự bỏ lượt đích khi dòng chưa
  dịch; vì `tp.lines` là danh sách trực tiếp, bản dịch xong sẽ được đọc ở các
  dòng sau.
- `viOnly` mà chưa có bản dịch ⇒ phát nguồn cho riêng phiên đó qua
  `recipeOverride` (không ghi đè recipe bền vững).
- «Tự động dịch khi phát song ngữ» là tùy chọn (mặc định bật) trong
  `ReadChromeLayout`; `translateAll()` vốn đã có guard `if (_isTranslating)`,
  nên không chạy chéo với nút Dịch của `TranslationToolbar`.

### D3 — Chrome theo 3 nhóm, progressive disclosure

| Nhóm | Vị trí | Mặc định | `allowHide` |
|---|---|---|---|
| Nguồn | app bar trên cùng (2 icon web / tipitaka) | `collapsed` | **false** |
| Công cụ đọc | dock đáy, 1 hàng ~44px | `collapsed`, luôn hiện kể cả lúc cuộn | true |
| Thông tin & Hiển thị | 1 nút overflow cạnh ⚡ | `collapsed` | true |

- Ba nhóm đều có 3 trạng thái `collapsed / expanded / hidden`, riêng Nguồn bị
  khoá chip «Ẩn» (`allowHide = false`) và `fromJson` cũng ép `hidden` về
  `collapsed` — đúng ý owner «để ở trên cùng như hiện thời đã khá gọn», đồng
  thời không cho mất đường vào nội dung. Bung nhóm Nguồn ⇒ hiện đủ 3 nguồn
  (`ReadSourcePicker`: Tài liệu / Web / Tam tạng) dưới app bar.
- Mỗi nhóm có key `read_chrome_group_<source|tools|display>_v1`
  (`ReadChromeGroupId.storageKey`). Đây là **bản chiếu** của blob
  `read_chrome_layout_v1`, được ghi đồng bộ trong cùng một lần
  `saveReadChromeLayout()`; lúc đọc, key riêng (nếu có) thắng blob. Không tạo
  ba nguồn sự thật — cùng lý do đã gộp `tts_speed` ở D1.

- `ReadChromeLayout` (`lib/models/read_chrome_layout.dart`) là model thuần
  Dart: `ReadChromeGroupId` (3 nhóm) × `ReadChromeGroupState` (3 trạng thái),
  vị trí công cụ (`bottom` mặc định / `top` hành vi cũ), ghi nhớ trạng thái
  bung, tự dịch nền, phạm vi đọc, panel gần nhất. Một JSON string
  `read_chrome_layout_v1` + 3 key chiếu theo nhóm.
- `ReadChromeLayoutStore` (`ValueNotifier`) là nguồn sự thật duy nhất; app bar
  `main_shell`, `ReadModeScreen` và màn «Giao diện shell» cùng nghe.
- Dock có đúng **1 panel inline tại một thời điểm** (Đọc / Công cụ đọc /
  Hiển thị), cao tối đa `42% viewport` (clamp 160–320), cuộn dọc, mũi tên
  bung **nằm ngoài vùng cuộn ngang** để máy nhỏ vẫn thấy lối vào.
- Dời cả `TranslationToolbar`, 5 nút `ReadTextActionBar` và dòng
  «Áp dụng cho …」 xuống panel Công cụ (READ-ACT-001 giữ nguyên: mỗi hành
  động vẫn chỉ có 1 chỗ). `ReadTopBar` bị tắt trong luồng shell
  (`showTopBar: false`) nhưng giữ cho caller standalone.
- `Hiển thị` + `Cài đặt` lên **một** `PopupMenuButton` cạnh ⚡ (không thêm 2
  icon rời rạc: app bar reader đã có 4 icon + tiêu đề). `showReadDisplaySheet`
  nhận `ReadModeController?` — 2 switch phụ thuộc controller tự ẩn khi gọi từ
  app bar shell.

### D4 — Không animation trên cụm đáy

`READ-TOOLBAR-001` v2 (khối đen trên Mali/Adreno) vẫn là hợp đồng cứng:
`ReadBottomDock` **không** dùng `AnimatedSize / AnimatedSlide /
AnimatedOpacity / ClipRect`. Bung/gộp = build điều kiện, đổi cây widget tức
thì. `CollapsibleBottomControls` và test pin của nó giữ nguyên cho đường cũ.

## Hệ quả

- Máy mới: tab Đọc chỉ còn 2 hàng chrome cố định (app bar + dock). Vùng đọc
  tăng đáng kể; `SmartPlaybackBar` 2 hàng và `ReadTopBar` không còn thường
  trực trong luồng shell.
- Người dùng cũ có thể quay lại bố cục cũ bằng «Vị trí công cụ: Trên» — khi
  đó `ReadModeScreen` dựng đúng `CollapsibleBottomControls` +
  `SmartPlaybackBar` + `ReadBottomBar` như trước.
- Mất (chấp nhận): tốc độ riêng của `playback_recipe` cũ bị migrate về
  `tts_speed`; preset quiz/shadowing (0.75x) nay **cũng đổi tốc độ chung** —
  đó là hệ quả có chủ đích của «một nguồn sự thật».

## i18n (quy tắc vàng #5)

7 chuỗi chrome mới được đăng ký trong `tool/priority_native_pack.json`
(`en` + `zh/zh_TW/hi/si/my/th/ja`) và sinh
`lib/core/language/generated_priority_native_pack.dart` bằng generator
(`--check` xanh). Bản English cũng được review trong
`tool/legacy_ui_english_overrides.json`. Các nhãn còn lại đều dùng lại chuỗi
đã có catalog.

> Ghi chú: `tool/generate_legacy_ui_fallbacks.py` **đã lệch với nguồn từ trước
> đợt này** (hàng trăm override không còn khớp presentation source; con số
> thay đổi theo đợt cập nhật ARB của base), nên ta không sinh lại cả file.
> Runtime vẫn đúng rule #5 vì `AppUITranslations.translate` kiểm tra native
> pack trước, rồi mới tới legacy English fallback. Không sửa tay file
> generated. Ba override của thông báo chặn cũ («Đang dịch, vui lòng chờ hoàn
> tất…», «Chưa có bản dịch để đọc song ngữ.», «Hãy chọn ngôn ngữ đích khác
> nguồn trước khi phát.») đã bị xoá khỏi JSON vì chuỗi nguồn không còn tồn tại
> ⇒ trên cùng một cây mã, số override lệch **giảm 3** so với base (không tăng).

## Kiểm chứng

- `test/read_chrome_layout_test.dart` — model, round-trip, dữ liệu hỏng.
- `test/read_ui_120_contract_test.dart` — pin P0/P1/P2 + rule #5.
- `test/read_chrome_layout_test.dart` — 3 nhóm, `allowHide`, key lưu, round-trip.
- Test cũ giữ nguyên: `read_chrome_compact_test.dart`,
  `read_bottom_controls_visibility_test.dart`, `read_bilingual_playback_test.dart`,
  `read_workspace_test.dart`, `locale_chrome_no_vietnamese_test.dart`.
- QA tay theo `docs/shell_manual_qa_checklist.md` mục 4.3 / 8.1 / 11.1:
  360×640 + text scale 1.3, bấm Play khi **chưa dịch**, đổi tốc độ rồi đọc
  cả 2 phạm vi, kill app mở lại, bung panel khi đang phát, Focus mode,
  «Vị trí công cụ: Trên», locale EN + JA.
- CI không thay nghiệm thu tai nghe trên thiết bị thật (Edge/Piper, offline,
  đang dịch nền).
