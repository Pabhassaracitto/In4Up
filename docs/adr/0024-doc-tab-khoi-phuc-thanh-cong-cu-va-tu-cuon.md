# ADR-0024 — Tab Đọc: khôi phục thanh công cụ, nhãn IPA và tự cuộn theo dòng đọc

- **Trạng thái:** đã triển khai trên `arena/0f9bbb45-in4up`, rebase lên tip
  `251e` = `95f9e2f` (2026-11-05); PR **#135** mở, base 251e, lịch sử
  rút gọn thành 1 commit tuyến tính không merge commit, `rebaseable = true`;
  chờ CI xanh trên head mới. Kế tiếp trực tiếp ADR-0021 / PR **#126**
  (đã merge vào `arena/01a0251e-in4up` ngày 2026-11-02). Còn nghiệm thu
  máy 360×640.
- **Định danh:** bản thảo mang số ADR-0023 / PLAN-043; sau rebase tip 251e
  `95f9e2f`, 2 số đó đã thuộc về «Nút Khái niệm đa ngữ» / «Worklist đa
  ngữ» của agent `arena/d2aeb948-in4up`, nên đổi thành **ADR-0024 /
  PLAN-044**. Chỉ đổi số, không đụng entry của agent khác (GOVERNANCE
  3.3), không đổi nội dung/phạm vi.
- **Nguồn:** owner báo 12 issue sau bản 1.21.0; yêu cầu «xem issue nào là issue
  cũ thì xem xét và giải quyết, còn lại để gửi AI khác». ADR này chỉ xử lý
  nhóm issue thuộc ngữ cảnh READ-UI-120 (tab Đọc / chrome / một cửa vào TTS).

## Bối cảnh

ADR-0021 dời `ReadTopBar`, `TranslationToolbar`, 5 action ngữ cảnh xuống
`ReadBottomDock` và đặt `showTopBar: false` trong luồng shell. Hệ quả không
lường trước: 9 nút vốn nằm trong `ReadTopBar` **vẫn còn trong mã nguồn nhưng
không còn đường vẽ ra màn hình**:

| Nút cũ | API vẫn còn | Sau PR #126 |
|---|---|---|
| «Không màu» (chu kỳ ColorMode) | `tp.cycleColorMode()` | mất |
| «Thông tin màu» | `tp.setShowColorModeDetails()` | mất |
| «Box từng từ / Bôi nhiều chữ» | `tp.setWordTapBoxes()` | mất |
| «Màu IPA» | `tp.setIpaLegendVisible()` | mất |
| «Đồng bộ tự động» | `controller.toggleAutoSync()` | chỉ còn trong sheet, giấu 2 lớp |
| «?» Hướng dẫn đọc theo dòng | `ReadLineHint.showSheet()` | mất |
| «Chế độ Focus» | `controller.toggleFocusMode()` | chỉ còn trong panel giấu |
| «Hiển thị» / «Cài đặt» | sheet / `ReadSettingsSheet` | còn (overflow cạnh ⚡) |

Owner phản hồi đúng: «các chức năng nút ... không còn thấy ở đâu nữa, trong khi
trước đây có. Hãy xem và sắp đặt vị trí một cách thông minh, linh hoạt, phù hợp
với ngữ cảnh hiện tại». Cùng lúc owner hỏi **«đồng bộ tự động» dùng để làm gì**:
đây là `ReadModeController.autoSyncEnabled` (Hive `read_auto_sync`, mặc định
bật). Nó (1) khớp dòng văn bản với mốc thời gian của audio LRC qua
`checkAudioSync()` → `scrollToLine()`, (2) ở chế độ «Một dòng» bám
`PlaybackController.activeLineNotifier` để đổi dòng đang đọc. **Trước ADR này
nó KHÔNG bám dòng khi phát TTS cả bài trong danh sách thường** ⇒ owner phải kéo
tay («mỏi tay, tốn sức»).

Hai chi tiết nhỏ cùng ngữ cảnh: dock mới dùng `Icons.abc` (vẽ đúng chữ "ABC")
trong khi thanh cũ `ReadBottomBar` đã dùng `textIcon: 'IPA'` ⇒ hai bố cục lệch
nhãn; và lựa chọn «Vị trí công cụ: Trên» quên không khôi phục `ReadTopBar`.

## Quyết định

### D1 — Một cụm điều khiển, ba lối vào, không thêm state

- `ReadDisplayControls` (`lib/screens/read_mode/widgets/read_display_controls.dart`)
  là **một** widget chứa toàn bộ nút tùy biến chữ + «?» + Focus + Đồng bộ tự
  động. Nó gọi thẳng API hiện có; không tạo setting/key mới, không sao chép
  state.
- Ba lối vào cùng trỏ vào cụm đó, **tùy ngữ cảnh**:
  1. dock đáy: icon `tune_rounded` cố định `Key('read-bottom-dock-display')`
     (ngoài vùng cuộn ngang ⇒ máy 320px vẫn thấy) — 1 chạm mở đúng panel
     «Hiển thị» (`toolsState=expanded`, `lastPanel=display`). Nhóm Hiển thị bị
     Ẩn ⇒ fallback sang sheet dùng chung. Chạm lần 2 thu gọn.
  2. overflow cạnh ⚡: mục «Hiển thị» ghi qua `ReadChromeLayoutStore` để mở
     panel dock (có `ReadModeController` ⇒ đủ auto-sync + Focus); «Cài đặt» giữ
     `ReadSettingsSheet`. Đường «Công cụ ở trên» vẫn mở
     `showReadDisplaySheet(context)`.
  3. `showReadDisplaySheet` / `ReadTopBar`: nhúng cùng một cụm. Controller
     `null` (app bar standalone) ⇒ 2 nút phụ thuộc controller tự ẩn, các nút
     còn lại vẫn dùng được.
- Panel «Hiển thị» của dock nhúng cụm này; panel «Đọc» **khi đang phát** hiện
  thêm công tắc «Đồng bộ tự động» ngay dưới phần tốc độ (đúng lúc owner cần
  tắt), còn lúc rảnh công tắc vẫn ở panel Hiển thị. `_DisplayPanel` bỏ chip
  Focus trùng để mỗi hành động đúng 1 chỗ (READ-ACT-001).
- `showTopBar: !_readChromeLayout.useBottomDock`: mặc định dock đáy **vẫn
  không** vẽ `ReadTopBar` (giữ ≤2 hàng chrome của ADR-0021); người dùng chọn
  «Vị trí công cụ: Trên» lấy lại thanh cũ như trước 1.21.0.

### D2 — «Đồng bộ tự động» mở rộng thành tự cuộn theo TTS, vẫn tắt được

- `read_auto_scroll_policy.dart` (hàm thuần Dart, có test) quyết định có cuộn:
  `autoSyncEnabled && isRunning && !singleLineMode && !manualScrollActive &&
  0 <= lineIndex < lineCount`.
- `ReadModeScreen` lắng `PlaybackController.activeLineNotifier`: cập nhật
  `currentLineIndex` (highlight) ở cả hai chế độ, rồi
  `_controller.scrollToLine(_scrollController, index)` ở danh sách thường.
- **Không giật tay người dùng**: `ScrollStartNotification` /
  `ScrollUpdateNotification` có `dragDetails != null` ⇒ đặt
  `_manualScrollUntil = now + 5s`; trong cửa sổ đó auto-follow đứng yên, hết
  5 giây tự nối lại. Cuộn do chương trình không có `dragDetails` ⇒ không tự
  kích hoạt khoảng nghỉ.
- Tắt hẳn = công tắc «Đồng bộ tự động» (đã có từ trước, lưu `read_auto_sync`).
  Không thêm preference, không đổi `checkAudioSync()` / đường audio LRC.

### D3 — ABC → IPA

- `_DockIcon` nhận `textIcon`; nút phiên âm của dock dùng `textIcon: 'IPA'`
  như `ReadBottomBar`, giữ nguyên kích thước ô 19px ⇒ không đổi chiều cao hàng.
  Không đụng `IpaDisplayMode` hay legend (icon `abc` ở đó là ký hiệu lớp IPA,
  không phải nút chế độ).

### D4 — Giữ nguyên hợp đồng cũ

Không `AnimatedSize` / `AnimatedSlide` / `AnimatedOpacity` / `ClipRect` trên
dock (READ-TOOLBAR-001 v2). Không gộp 2 engine TTS, không đổi
`PlaybackEngine` / anchor / `TtsPlaybackOwner`, không đưa action cấp từ
(`word_mini_pop`, PRON-002) vào dock, không đổi pin
`if (!readLibraryFull && _readModeIndex == 0)`. CI: không đổi gate nào,
chỉ nối thêm **1 file test thuần** vào bước `read-act-tests` đã có để
source-pin của ADR này thực sự chạy (`app_analyze.yml`).

## i18n (quy tắc vàng #5)

2 chuỗi mới: `Tùy biến chữ`, `Tự cuộn theo dòng đang đọc; tắt để cuộn tay.`
— đăng ký trong `tool/priority_native_pack.json` (`en` + `zh/zh_TW/hi/si/my/th/ja`),
sinh `generated_priority_native_pack.dart` bằng generator (`--check`: 3508
entry × 8), và review English trong `tool/legacy_ui_english_overrides.json`.
Các nhãn còn lại (`Không màu`, `Bôi nhiều chữ`, `Màu IPA`, `Đồng bộ tự động`,
`Hướng dẫn đọc theo dòng`, `Chế độ Focus`) đều đã có catalog từ trước.
`generated_legacy_ui_fallbacks.dart` tiếp tục **không** sinh lại (generator lệch
sẵn trên base); runtime ưu tiên native pack trước legacy fallback.

## Phân loại 12 issue owner gửi (để tiện quản lý)

**Giải quyết trong ADR này (issue cũ, cùng ngữ cảnh READ-UI-120):**

| Issue | Việc đã làm |
|---|---|
| «Không màu / Bôi nhiều chữ / Đồng bộ tự động / ? / focus không còn thấy ở đâu nữa ... sắp đặt thông minh, linh hoạt» | D1 (3 lối vào theo ngữ cảnh) + giải thích công dụng auto-sync ở trên |
| «Bổ sung cơ chế auto để màn hình ứng với chữ ... Có thể tắt» | D2 (auto-follow TTS + nhường 5s sau kéo tay + công tắc đã có) |
| «Tab đọc: ABC => nên chuyển thành IPA» | D3 |

**Để lại cho AI khác (không liên quan ngữ cảnh này):** bong bóng dịch chồng
chữ; crash khi ưu tiên TTS sherpa lúc bấm Đọc (cùng cụm model/offline với 2
issue Parakeet/sherpa bên dưới, cần logcat thiết bị); dịch Cabin nhân đôi dòng
khi nói thêm; thư viện «Gần đây» lỗi `PdfException`; pop từ vựng + 4 mức độ
khi bấm từ; bản dịch ra `https://linux.do/t/topic/111737` / kẹt «Thử kết nối
DeepLX»; offline Parakeet/sherpa chưa nạp model vẫn chọn được rồi văng app;
«không thấy thông tin thay đổi về vietnew / worlist»; thông báo import Parakeet
bản NeMo. Xem bảng chi tiết trong KANBAN `READ-UI-121`.

> Lưu ý: PR #128 (M4U-IMPORT-002) đã sửa `MissingPluginException` của
> `TtsNotificationService` và nhận diện layout NeMo trên 251e; nếu crash
> sherpa/offline vẫn tái hiện thì thuộc tầng native/model, cần log thiết bị —
> không phải regression của chrome tab Đọc.

## Kiểm chứng

- `test/read_ui_121_contract_test.dart`: source-pin 5 nút cũ, 3 lối vào,
  `textIcon IPA`, cấm animation, chính sách tự cuộn (5 case), 2 chuỗi i18n.
- `test/read_ui_120_contract_test.dart`: cập nhật pin `showTopBar` (mặc định
  vẫn không vẽ top bar), các pin P0/P1/P2 giữ nguyên.
- `test/read_chrome_layout_test.dart`, `read_bilingual_playback_test.dart`,
  `read_bottom_controls_visibility_test.dart`, `locale_chrome_no_vietnamese_test.dart`
  giữ nguyên.
- `test/read_ui_121_contract_test.dart` được nối vào bước
  `Read actions + mixed-language tests` của `app_analyze.yml` (thuần Dart,
  không plugin/mạng) ⇒ các source-pin ở trên chạy thật trên CI, không chỉ
  được analyze.
- Sandbox không có Flutter/Dart SDK ⇒ `flutter analyze` / `flutter test` chạy
  trên CI (`app_analyze.yml`), cộng `python3 tool/generate_priority_native_pack.py --check`
  và `git diff --check`.
- QA tay 360×640 (scale 1.0 / 1.3): 1 chạm thấy đủ 5 nút; bật/tắt Đồng bộ tự
  động rồi phát cả bài ⇒ màn hình bám dòng, kéo tay ⇒ đứng yên 5s; dock vẫn
  ≤2 hàng, vùng đọc ≥70%, không overflow / khối đen; đổi locale EN/JA không
  còn tiếng Việt ở 2 chuỗi mới.
