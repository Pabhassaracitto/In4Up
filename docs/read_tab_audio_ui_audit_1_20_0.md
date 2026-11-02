# Audit v1.20.0 — Audio & hiển thị tab Đọc: quan điểm thiết kế

> **Trạng thái:** ✅ ĐÃ DUYỆT VÀ TRIỂN KHAI (2026-11-02) trên
> `arena/bada56c3-in4up`. Quyết định kiến trúc: **ADR-0021**
> (`docs/adr/0021-doc-tab-chrome-va-tts.md`). Chờ CI + nghiệm thu thiết bị.
> Bản dưới đây giữ nguyên như biên bản audit để đối chiếu.
> Phạm vi: tab Đọc trong `MainShell` (không áp dụng cho `ReadModeScreen` standalone,
> PDF/Web/Tipiṭaka reader).

---

## 0. Kết luận ngắn

| Câu hỏi của owner | Quan điểm |
|---|---|
| Gộp 2 phần phát TTS? | **Gộp phần điều khiển (UI + state), KHÔNG gộp 2 engine.** Một nút «Đọc», một bảng tùy chỉnh, một bộ thông số. Hai *phạm vi* (dòng hiện tại / cả bài) là 2 mode của cùng một session owner. |
| Bỏ lệ thuộc «dịch xong mới phát»? | **Bỏ.** Đây là lệ thuộc dữ liệu bị đưa lên thành lệ thuộc điều khiển. Phát nguồn ngay; bản dịch là lớp bổ sung khi có. |
| Đưa hết công cụ xuống dưới như tab Nghe? | **Nên**, nhưng phải đưa *cùng lúc* `ReadTopBar`, `TranslationToolbar` và 5 nút context header xuống chung một dock — nếu chỉ dời 5 nút thì vẫn còn 3 tầng chrome trên. |
| «Hiển thị» + «Cài đặt» lên sát nút sấm sét? | **Nên**, nhưng gom thành **một** nút overflow cạnh bolt (màn 320 px không đủ chỗ cho 2 icon mới). |
| Thêm tinh chỉnh nhóm trong «Giao diện shell»? | **Nên, nhưng giới hạn**: 3 nhóm × 3 trạng thái + mặc định gộp. Không cho kéo-thả tự do ở v1.20.x. |

**Ý chính:** vấn đề không phải "có 2 nút phát", mà là **tab Đọc có 4 tầng chrome + 1 cơ chế ẩn/hiện kiểu nhị phân**. Cơ chế tối giản đã có (`_readerChromeVisible = false`) nhưng sai *độ hạt*: đang ẩn **toàn bộ** (kể cả nút phát), hoặc hiện **toàn bộ** (6 hàng icon). Cần đổi từ all-or-nothing sang **per-group progressive disclosure**.

---

## 1. Thực trạng đối chiếu code

### 1.1 Bốn tầng chrome phía trên vùng đọc

| Tầng | File | Nội dung |
|---|---|---|
| A. App bar shell | `lib/screens/main_shell.dart:1399–1480` | Thư viện, Web, Tam tạng, tiêu đề, ⚡ bolt, thư viện phải |
| B. Workspace header | `main_shell.dart:1550–1580`, `:1719–1785` | Mode switch + `Mở nguồn / Dịch / Ngữ pháp / Phát âm / Từ điển` + dòng «Áp dụng cho …» |
| C. Reader chrome | `lib/screens/read_mode/read_mode_screen.dart:352–385` | `ReadTopBar` (tô màu, nhãn, box từ, màu IPA, đồng bộ, hướng dẫn, **Hiển thị**, **Cài đặt**, Focus), `IpaLegendStrip`, grammar legend, `TranslationToolbar` |
| D. Cụm đáy | `read_mode_screen.dart:420–433` | `SmartPlaybackBar` + `ReadBottomBar` (A− A+ Dịch IPA Đọc Mark Từ đã lưu) |

`ReadSourcePicker` (`read_mode_screen.dart:367`) **không** xuất hiện trong luồng shell vì
`main_shell.dart:1208` truyền `showSourcePicker: false` → nhóm **Nguồn** hiện đúng là 3
icon ở app bar. Owner nhận xét "đã khá gọn" là chính xác: **giữ nguyên, đừng đụng**.

### 1.2 Hai đường TTS — cùng engine, khác frontend và khác state

| | «Đọc dòng hiện tại» | «Đọc song ngữ» (Smart Playback) |
|---|---|---|
| Vào | `read_bottom_bar.dart:104–135` → `TextProvider.speakCurrentLine()` (`text_provider.dart:1478`) | `smart_playback_bar.dart:21–150` → `PlaybackController` → `PlaybackEngine` |
| Phạm vi | 1 dòng, owner `TtsPlaybackOwner.preview` | cả bài, recipe (mode/lặp/khoảng lặng/tốc độ/anchor resume), thông báo hệ thống |
| Tốc độ | `tp.ttsSpeed` → key `tts_speed` (`storage_service.dart:126`) | `PlaybackRecipe.speed` → key `playback_recipe` (`playback_controller.dart:273`) |
| Tùy chỉnh | nằm trong `ReadSettingsSheet` (`read_settings_sheet.dart:132–146`, `TtsSettingsSection`) | ngay trên thanh (`_expanded`, `_showSpeedSlider`, `_PatternBuilder`, `_PresetSheet`) |

Cả hai đi qua chung `TtsService` và chung cơ chế session độc quyền
`TtsPlaybackOwner` (`text_provider.dart:46–137`). **Hệ quả thực tế:** hai tốc độ được
lưu ở hai key khác nhau, và `PlaybackEngine.play()` gọi `tts.setSpeechRate(recipe.speed)`
trong khi `TextProvider` gọi `_ttsService.configure(speed: _ttsSpeed)` → người dùng chỉnh
chỗ này, chỗ kia không đổi (và có thể ghi đè nhau trong cùng phiên). Đây là lý do mạnh
nhất để **thống nhất một nguồn sự thật về cấu hình TTS**, không chỉ là chuyện thẩm mỹ.

### 1.3 Vì sao mặc định bị chặn bởi bản dịch

- `PlaybackController._recipe = PlaybackRecipe.bilingual` (`playback_controller.dart:29`) → **mặc định là song ngữ**.
- `_startPlayback()` (`smart_playback_bar.dart:457–482`): nếu `mode != enOnly` thì chặn khi
  `isTranslating` («Đang dịch, vui lòng chờ hoàn tất…») và `await tp.translateAll()` khi chưa có bản dịch.
- Các mode chip cũng tự gọi `translateAll()` (`:219`, `:337`).
- Trong khi `TranslationDisplayMode` mặc định là `hidden`
  (`text_provider_translation.dart:17`) và `TranslationToolbar` vẫn có nút Dịch riêng
  → **có 2 nơi cùng phát lệnh dịch**, dễ chạy chéo.

`enOnly` đã phát được không cần dịch ⇒ lệ thuộc này **không phải bản chất**, chỉ là lựa chọn
luồng điều khiển hiện tại.

### 1.4 Cơ chế "tối giản" đã có, nhưng nhị phân

- `read_mode_screen.dart:108` `_readerChromeVisible = false` → mở tab Đọc là ẩn **mọi** chrome.
- `:496–545` FAB «Công cụ đọc» để gọi lại; `:665–668` smart-hide theo hướng cuộn.
- `CollapsibleBottomControls` gập chiều cao về 0 khi ẩn/Focus.
- `CollapsibleActionBar` (`lib/widgets/collapsible_action_bar.dart`) đã có pattern 2 tầng
  gộp (icon) ⇄ bung (nhãn), đang dùng cho cả 3 tab.
- Tab Nghe có thêm pattern **dock + inline panel**: `_SmartActionBar`
  (`listen_mode_screen.dart:2279–2500`) — tap = hành động chính, long-press/tap tốc độ = mở
  đúng 1 panel chi tiết ngay phía trên hàng nút, có `maxHeight`; và nhóm công cụ trên đã có
  persist `listen_workspace_tools_expanded_v1` (`main_shell.dart:1655–1667`).

→ **Không cần phát minh cơ chế mới.** Chỉ cần áp 2 pattern có sẵn vào tab Đọc và cho cấu hình
mức nhóm.

---

## 2. Trả lời chi tiết

### 2.1 Gộp 2 TTS — có, nhưng "gộp mặt, không gộp ruột"

Nên có **một cửa vào duy nhất**: một pill «Đọc» ở dock đáy.

- Tap → phát theo cấu hình hiện tại (mặc định: đọc dòng hiện tại, không bắt dịch).
- Long-press / mũi tên ⇄ → mở inline panel chứa toàn bộ tùy biến: phạm vi (dòng / đoạn / cả bài),
  chế độ (nguồn / đích / xen kẽ / custom), giọng theo ngôn ngữ, **một** tốc độ, khoảng lặng,
  lặp, preset, ngôn ngữ đích, và đường dẫn tới cài đặt engine nâng cao.
- Giữ `PlaybackEngine` + `PlaybackRecipe` + anchor resume nguyên vẹn (đang có test pin
  `test/read_bilingual_playback_test.dart`), và giữ `speakCurrentLine()` như shortcut
  `scope = currentLine` của cùng controller. **Không** xóa: đọc 1 dòng là thao tác tra cứu
  từ/đọc lại câu rất hay dùng, khác mục đích với phát cả bài.

Điều phải làm trước khi gộp UI: **chốt một nguồn tốc độ** (bỏ `recipe.speed` hoặc biến nó
thành view của `tp.ttsSpeed`), và gộp 2 luồng gọi `translateAll()` về 1 coordinator.

### 2.2 Tách lệ thuộc bản dịch

- Phát **ngay** với giọng nguồn; bản dịch khi có thì tự nhập vào lượt đích.
- Trạng thái «đang dịch…» hiển thị *trong* thanh phát (đã có `_LiveStatusBar`), không phải
  snackbar chặn.
- Chế độ `viOnly` khi chưa có bản dịch: vẫn phát nguồn + nhãn rõ "chờ bản dịch", hoặc hỏi
  một lần; không khóa nút Play.
- «Tự dịch khi phát song ngữ» nên là **tùy chọn** (tôn trọng offline / dữ liệu / chi phí API),
  mặc định bật cho ai đã bật bản dịch, tắt cho người chỉ đọc nguồn.
- Sửa gốc: mặc định recipe nên là `enOnly` (hoặc `lastUsed` có migrate), không phải `bilingual`.

### 2.3 Đưa công cụ xuống dưới — có, nhưng phải dời cả cụm

Đề xuất phân vùng lại (content-first):

```
TRÊN   [Thư viện] [Web] [Tam tạng]   Tiêu đề   [⚡] [⧉ Hiển thị/Cài đặt]
       ── nhóm Nguồn: GIỮ NGUYÊN, không đổi ──
       (không còn workspace header 5 nút, không còn ReadTopBar,
        không còn TranslationToolbar thường trực)

VÙNG ĐỌC  ← chiếm toàn bộ chiều cao còn lại

DƯỚI   ┌─ dock 1 hàng, ~40–48 px ─────────────────────────────┐
       │ [▶ Đọc] [A− A+] [Dịch] [IPA] [Mark] [Từ đã lưu] [⋯] │
       └───────────────────────────────────────────────────────┘
       bung ⇄ panel inline (cao tối đa theo viewport, 1 panel/lần)
```

Hai lưu ý khi dời:

1. Dòng «Áp dụng cho: đoạn đang chọn — …» (`main_shell.dart:1723–1745`) là **feedback bắt
   buộc** của `ReadTextActionRunner` (READ-ACT-001/READ-SELECT-002). Dời 4 nút xuống dock
   thì phải dời cả dòng này vào panel, nếu không người dùng không biết đang dịch đoạn nào.
2. `ReadBottomBar` đang là `SingleChildScrollView` ngang (`read_bottom_bar.dart:44–50`):
   trên máy nhỏ, các nút cuối nằm **ngoài màn hình không có affordance** — đó là lý do
   owner có cảm giác "bấm icon người nói chỉ phát 1 dòng, còn tùy chỉnh biến đâu mất".
   Dock mới phải có nút `⋯` rõ ràng thay vì cuộn ngang im lặng.

**Ràng buộc kỹ thuật quan trọng:** `_SmartActionBar` của tab Nghe dùng `AnimatedSize`
(`listen_mode_screen.dart:2378`). **Không copy nguyên widget này sang tab Đọc** —
`READ-TOOLBAR-001` / `test/read_bottom_controls_visibility_test.dart` cấm
`AnimatedSize / AnimatedSlide / AnimatedOpacity / ClipRect` trên cụm đáy tab Đọc vì gây
khối đen trên GPU Mali/Adreno. Copy *pattern* (một hàng + một panel inline), dựng bằng
build điều kiện như `CollapsibleBottomControls` đang làm.

### 2.4 «Hiển thị» + «Cài đặt» lên cạnh bolt

Đồng ý về mặt thông tin học (đây là cấu hình khung đọc, không phải công cụ tác động lên chữ).
Nhưng app bar reader đã có 4 icon + tiêu đề; thêm 2 icon riêng dễ ép tiêu đề ở 320 px.
Đề xuất **một** nút `tune/⋯` đặt ngay cạnh ⚡, mở menu nhỏ anchored gồm: `Hiển thị`,
`Cài đặt đọc`, `Chế độ Focus`, `Bảng màu IPA / ngữ pháp`. Vẫn đạt ý owner, mà không tăng
rủi ro overflow. `ReadTopBar` khi đó có thể bỏ hẳn khỏi luồng shell (giữ lại cho màn
standalone nếu cần).

### 2.5 Nhóm trong «Giao diện shell»

`ShellUiSettingsScreen` hiện chỉ có toggle toàn cục (`compact mode`, `auto-hide`,
`long-press`, `remember submode`, nguồn mặc định, thứ tự tab). Thêm **mức nhóm** là đúng chỗ,
nhưng nên giữ hẹp:

| Nhóm | Vị trí | Mặc định | Trạng thái cho phép |
|---|---|---|---|
| Nguồn | trên cùng (app bar) | luôn hiện | không cho ẩn (mất đường vào nội dung) |
| Công cụ | dock đáy | **gộp / 1 hàng** | gộp · bung · ẩn (vẫn gọi qua FAB/⚡) |
| Thông tin & Hiển thị | cạnh ⚡ | icon đơn | gộp · bung |

Mỗi nhóm lưu: `defaultCollapsed`, `rememberExpanded`, `allowHide`; key kiểu
`read_chrome_group_<id>_v1` (noi theo `listen_workspace_tools_expanded_v1`). Thêm 1 lựa chọn
nâng cao duy nhất: «Vị trí công cụ: dưới (mặc định) / trên (hành vi cũ)» để không phá thói
quen người dùng cũ mà vẫn đổi được mặc định.

**Không nên** ở v1.20.x: kéo-thả sắp xếp từng nút, ẩn từng icon lẻ, profile theo ngôn ngữ,
hay "auto-hide theo thời gian" (đã bỏ ở AUDIT-2026-10-20 mục 3 vì người dùng chưa kịp chọn).
Mỗi tổ hợp thêm là một tổ hợp phải test overflow + i18n.

---

## 3. Lộ trình đề xuất

**P0 — hết «phải dịch mới phát» + hết 2 tốc độ (rủi ro thấp, giá trị cao)**
1. Đổi mặc định recipe sang `enOnly`/`lastUsed`, bỏ 3 nhánh chặn trong `_startPlayback`.
2. Chốt một nguồn `speed`; migrate `playback_recipe.speed` → key chung.
3. Gộp lệnh `translateAll()` về một coordinator; chống chạy chéo với nút Dịch.

**P1 — một dock, tối giản mặc định**
4. Dời `Hiển thị / Cài đặt / Focus` lên menu cạnh ⚡; bỏ `ReadTopBar` khỏi luồng shell.
5. Dời 5 nút context + `TranslationToolbar` vào dock đáy; giữ dòng «Áp dụng cho».
6. Gộp `SmartPlaybackBar` + `ReadBottomBar` thành 1 hàng + 1 panel inline build điều kiện.
7. Đổi `_readerChromeVisible` nhị phân thành state mức nhóm (dock **luôn** có pill «Đọc»;
   các nhóm khác mới chịu smart-hide). Đây là điểm mấu chốt: đừng để nút phát biến mất
   khi cuộn.

**P2 — cấu hình trong «Giao diện shell»**
8. 3 nhóm × trạng thái, persist, nút «Khôi phục mặc định», preview trực tiếp trong màn cài đặt.
9. Viết ADR + cập nhật `docs/shell_manual_qa_checklist.md` mục 8/11.

**Tiêu chí nghiệm thu (đo được, không cảm tính)**
- 360×640, text scale 1.0 và 1.3: vùng đọc chiếm ≥ 70% chiều cao thân shell khi dock gộp;
  tổng số hàng chrome cố định ≤ 2 (app bar + dock).
- Mở tab Đọc lần đầu, có văn bản, **chưa dịch**: bấm «Đọc» phát trong < 1 s, không snackbar chặn.
- Đổi tốc độ ở panel → đọc dòng hiện tại và đọc cả bài **cùng giá trị**; kill app mở lại vẫn giữ.
- Bung bất kỳ panel nào: không `RenderFlex overflow`, không khối đen (chạy
  `test/read_bottom_controls_visibility_test.dart`).
- Focus mode, smart-hide, tap nền, resume anchor, `TtsPlaybackOwner` độc quyền: không regression.

---

## 4. Rủi ro & ràng buộc đã biết

- **GPU:** cấm widget animation trên cụm đáy (READ-TOOLBAR-001 v2).
- **i18n (`AGENTS.md` #5):** mọi nhãn mới («Đọc», «Phạm vi», «Khôi phục mặc định», tooltip…)
  phải có `en` + đủ `hi/zh/zh_TW/si` trong cùng PR; chạy gate
  `test/locale_chrome_no_vietnamese_test.dart`, `test/language/priority_native_pack_test.dart`.
- **Test pin cần cập nhật:** `test/read_mode/read_chrome_compact_test.dart` (đang assert
  `_readerChromeVisible = false`), `test/read_mode/audit_2026_10_20_ui_compact_test.dart`,
  `test/read_bottom_controls_visibility_test.dart`, `test/read_bilingual_playback_test.dart`,
  `test/read_mode/read_text_action_runner_test.dart`, `test/workspace_shell_integration_test.dart`.
- **Hợp đồng đang giữ:** READ-ACT-001 (4 action chỉ 1 chỗ), READ-FOCUS-001/002,
  READ-SELECT-002, I4U-READ-UX-001 (Mode → Source → Tool → Settings tách lớp).
  Đề xuất ở đây **không gộp Source vào Tool** — chỉ dời Tool xuống dưới.
- **Đừng** dời các hành động theo từ (`word_mini_pop`, `word_actions_sheet`, PRON-002)
  xuống dock: chúng gắn với vị trí chạm, không phải chrome khung.

---

## 5. Điều mình sẽ phản đối

1. Gộp `PlaybackEngine` vào `TextProvider.speak()` cho "gọn code" → mất anchor resume,
   notification, recipe/preset và phá 23+ test pin.
2. Ẩn hẳn công cụ theo thời gian (auto-hide) thay vì bung/gộp theo ý người dùng.
3. Thêm 2 icon rời rạc vào app bar mà không đo 320 px.
4. Dùng `AnimatedSize` cho panel dock tab Đọc.
5. Cho phép kéo-thả tự do toàn bộ nút ngay trong bản audit này — độ phức tạp tăng, lợi ích
   với màn hình nhỏ gần như bằng 0 so với "mặc định gộp + bung khi cần".
