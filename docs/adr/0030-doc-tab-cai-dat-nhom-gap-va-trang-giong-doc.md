# ADR-0030 — Tab Đọc: Cài đặt thành nhóm gập, trang «Giọng đọc & engine», «Tách dòng tự động» về thanh công cụ

- **Trạng thái:** đã triển khai trên `arena/e941ce1f-in4up` (lane L3, nhánh con
  của `arena/60e35d65-in4up`), chờ CI và nghiệm thu máy thật.
- **Định danh:** Linear **PSRC-236** — bước 2/4 của yêu cầu owner «I4U - Màn
  hình». Bước 1 là PSRC-235 (cắt bỏ mục chết và lối vào trùng).
- **Nguồn:** owner báo giao diện tab Đọc và phần cài đặt «vốn đang rất dài»;
  duyệt kế hoạch 4 bước ngày 2026-11-15 và cho làm bước 2 cùng ngày.
- **Quan hệ:** kế tiếp ADR-0021 (chrome theo nhóm, một cửa vào TTS) và
  ADR-0024 (khôi phục thanh công cụ). Không đổi D1/D2/D4 của ADR-0021, không
  đổi cụm «Tùy biến chữ» của ADR-0024 D1. Chỉ **bổ sung** cho ADR-0021 D3:
  nguyên tắc «progressive disclosure» nay áp dụng cả cho bảng Cài đặt, và
  nhóm chrome thứ ba đổi nhãn (D4 bên dưới).

## Bối cảnh

Sau PSRC-235, «Cài đặt Text Studio» vẫn là **một trang cuộn**:

| Thứ tự | Mục | Tần suất dùng |
|---|---|---|
| 1–2 | Cỡ chữ, Căn lề | thường xuyên |
| 3 | Dịch & đọc song ngữ | theo tài liệu |
| 4–5 | Chế độ màu (+ kiểu tô, chú giải, ngữ pháp), Phiên âm / IPA | theo tài liệu |
| 6–7 | Dòng văn bản, Chế độ Focus: giữ tiêu đề | hiếm |
| 8 | Nguyên khối `TtsSettingsSection`: ưu tiên engine, giọng Piper, import model VieNeu, giọng VieNeu, tạo giọng, giọng Edge, thứ tự engine, Server API, trạng thái engine, cache, giấy phép | **một lần** |
| 9 | `AutoSplitSection` — chọn chế độ, xem trước, nút «Áp dụng» | là **thao tác**, không phải cài đặt |

Ba lỗi cấu trúc còn lại (đọc code, không đoán):

1. **Không thấy trạng thái nếu không cuộn.** Muốn biết đang tô màu kiểu gì,
   IPA bật hay tắt, đang dịch sang tiếng nào thì phải cuộn tới từng mục.
2. **Thứ chỉnh một lần nằm chung cột với thứ chỉnh hằng ngày.** Khối engine
   dài hơn toàn bộ phần còn lại cộng lại; người chỉ muốn đổi cỡ chữ vẫn phải
   mang theo cả khối đó trong thanh cuộn.
3. **Một thao tác nằm trong bảng cấu hình.** «Tách dòng tự động» ghi đè văn
   bản rồi tự đóng bảng — hành vi của công cụ, và nó nằm sau khối engine nên
   gần như không ai tìm thấy.

## Quyết định

### D1 — Ba nhóm gập, mỗi nhóm có dòng tóm tắt, mở một nhóm mỗi lần

| Nhóm | Dòng tóm tắt (ví dụ) | Nội dung |
|---|---|---|
| **Chữ & bố cục** | `Cỡ chữ 18 · Giữa` | Cỡ chữ, Căn lề văn bản, Dòng văn bản, Chế độ Focus: giữ tiêu đề |
| **Dịch & đọc song ngữ** | `English → Tiếng Việt` | chọn ngôn ngữ đích + cảnh báo cặp trùng |
| **Màu & phiên âm** | `Loại từ · IPA: Tắt` | Chế độ màu, kiểu tô, chú giải, ngữ pháp, Phiên âm / IPA, nguồn lưu IPA, màu IPA |

- Thứ tự nhóm giữ thứ tự tần suất của PSRC-235 (chữ → dịch → màu).
- Mở bảng: **gập hết** ⇒ cả bảng vừa một màn hình, đọc được toàn bộ trạng
  thái hiện tại mà không cuộn (nhận ra thay vì phải nhớ).
- Chạm một nhóm ⇒ mở nhóm đó và gập nhóm đang mở. Chạm lại ⇒ gập.
- Nhóm vừa mở được nhớ **trong phiên chạy app** (biến tĩnh, không ghi
  storage): đóng bảng rồi mở lại vẫn ở đúng nhóm vừa chỉnh.
- Cặp ngôn ngữ trùng (nguồn = đích) làm dòng tóm tắt đổi màu hổ phách ⇒ lỗi
  cấu hình lộ ra ngay ở tầng ngoài.
- Tiêu đề nhóm cao tối thiểu 56 px; tên và tóm tắt mỗi thứ một dòng, có «…»
  ⇒ không vỡ bố cục ở 320 px và ở các locale chữ dài (th, my, si).
- **Không animation**: gập/mở là build điều kiện (không `AnimatedSize`,
  `AnimatedCrossFade`, `ExpansionTile`) — cùng lý do ADR-0021 D4.
- Không thêm state mới vào `TextProvider`; mọi điều khiển bên trong là đúng
  các widget cũ, chỉ đổi chỗ đứng.
- «Vị trí công cụ» **không** được chép vào nhóm «Chữ & bố cục»: nó đã có ở
  panel «Tùy biến» của dock và ở Cài đặt giao diện; thêm chỗ thứ ba là lặp
  lại đúng lỗi PSRC-235 vừa sửa.

Khối dựng: `ReadSettingsGroup`, `ReadSettingsLinkRow`
(`lib/screens/read_mode/widgets/read_settings_group.dart`) — công khai để
widget test dựng được không cần provider.

### D2 — Cấu hình engine giọng đọc ra trang riêng «Giọng đọc & engine»

- Bảng Cài đặt chỉ còn **một dòng** «Giọng đọc & engine» (mũi tên phải =
  mở trang khác, khác với mũi tên xuống của nhóm gập).
- Trang `ReadVoiceSettingsPage` chứa nguyên `TtsSettingsSection`, không đổi
  nội dung, không đổi nơi lưu (`TtsService`). Nút quay lại trả về bảng Cài
  đặt.
- Trang có `Scaffold` riêng ⇒ SnackBar của import model / tạo giọng hiện
  ngay trên trang (trước đây nằm dưới bottom sheet).
- Không thêm lối vào TTS: trang này chỉ là **cấu hình**. Phát vẫn một cửa
  qua dock (ADR-0021 D1).

### D3 — «Tách dòng tự động» về thanh công cụ đọc

- Rời bảng Cài đặt; mở thành sheet riêng `showAutoSplitSheet`.
- Lối vào: chip «Tách dòng tự động» trong panel **Công cụ đọc** của dock;
  ở bố cục «Vị trí công cụ: Trên» (không có dock) là một nút trong
  `ReadTopBar`. Hai bố cục loại trừ nhau ⇒ vẫn «mỗi hành động một chỗ».
- Chip luôn hiện, kể cả khi chưa có dòng đang đọc: thao tác tác động lên
  toàn văn bản.
- Logic không đổi: `AutoSplitSection` → `TextProvider.loadFromLines`.
- Cuối bảng Cài đặt có một dòng chỉ đường («Nút đọc, tốc độ và Tách dòng tự
  động nằm ở thanh công cụ đọc.») cho người quen bảng cũ — bài học ADR-0024:
  dời nút mà không báo thì người dùng coi là «mất nút».

### D4 — Nhóm chrome «Thông tin & Hiển thị» → «Thông tin & Tùy biến»

Nhóm này (Cài đặt giao diện → Tab Đọc) bật/tắt đúng tab dock đã đổi tên thành
«Tùy biến» ở PSRC-235. Hai nơi cùng chỉ một thứ thì phải cùng tên. Chỉ đổi
**nhãn**; `storageKey` `read_chrome_group_display_v1` giữ nguyên ⇒ không mất
cấu hình đã lưu. Chuỗi cũ vẫn ở trong pack (pin `_newStrings` của READ-UI-120).

### D5 — Ghi chú: «Chế độ trải nghiệm» TẠM bỏ, sẽ thêm lại

- PSRC-235 đã xoá mục «Chế độ trải nghiệm» (Đọc / Nghe (TTS) / Dịch / Lái
  xe) vì `TextProvider.subMode` không được đọc ở đâu ⇒ mục đầu tiên của
  bảng bấm không đổi gì.
- **Owner xác nhận ngày 2026-11-15:** đồng ý **tạm** bỏ; khi mọi thứ ổn thật
  sự sẽ thêm lại.
- Điều kiện thêm lại: mỗi chế độ phải đổi được một hành vi **nhìn thấy
  được** trên màn Đọc. Không dựng lại bộ chọn chỉ ghi state.
- Còn nguyên để nối lại: khoá ARB `grammarExperienceMode`,
  `StorageService.getShellReadSubMode` / `saveShellReadSubMode`. Mã cũ
  (`_SubModeSelector`, `ReadSubMode`) lấy lại từ commit ngay trước PSRC-235.
- Vị trí khi thêm lại: một nhóm gập mới theo D1 (không đặt lại lên đầu bảng
  như một khối luôn mở).
- Tài liệu XP-MODE-001 (`wireframe` § 9.2, `review-checklist`) và `KANBAN.md`
  còn ghi bất biến «giữ nguyên mục cũ» — **chưa sửa** (hub / owner quyết);
  ADR này là nơi ghi quyết định mới nhất.

## Không làm trong ADR này

- Bước 3: chọn ngôn ngữ nguồn, nút đổi chiều ⇄, tự tránh cặp trùng.
- Bước 4: một quy ước điều khiển trong cụm «Tùy biến chữ» (switch = bật/tắt,
  nút phân đoạn = chọn 1 trong N, chip = mở bảng khác).
- Không dời công cụ lên header, không thêm tab vào bảng Cài đặt, không phóng
  to nút TTS (đã cân nhắc và bác ở bản kế hoạch: header đầy ở 320 px; nhãn
  tab bị cắt ở 26 locale; nút TTS trong Cài đặt là lối phát thứ hai, trái
  ADR-0021 D1).

## i18n (quy tắc vàng #5)

6 chuỗi mới, thêm vào cuối `tool/priority_native_pack.json` (8 locale) và
`tool/legacy_ui_english_overrides.json`, sinh lại
`generated_priority_native_pack.dart` bằng
`tool/generate_priority_native_pack.py`:

- `Chữ & bố cục`, `Màu & phiên âm`, `Giọng đọc & engine`
- `Thứ tự engine, giọng theo ngôn ngữ, model, cache`
- `Nút đọc, tốc độ và Tách dòng tự động nằm ở thanh công cụ đọc.`
- `Thông tin & Tùy biến`

Dùng lại chuỗi đã có: `Dịch & đọc song ngữ`, `Tách dòng tự động`, `Cỡ chữ`,
`Trái`, `Giữa`, nhãn `ColorMode` / `IpaDisplayMode`.

## Kiểm chứng

- `test/read_mode/psrc_236_read_settings_groups_test.dart` (nối vào step
  «Read actions + mixed-language tests» của `app_analyze.yml`):
  - widget test `ReadSettingsGroup` / `ReadSettingsLinkRow`: gập thì không
    dựng nội dung, mở thì dựng; chạm gọi callback; tóm tắt dài ở 320 px
    không tràn; nhãn được dịch theo locale;
  - source-pin: 3 nhóm đúng thứ tự, mọi điều khiển cũ còn nguyên, bảng
    không còn `TtsSettingsSection` / `AutoSplitSection`, không animation,
    trang giọng đọc và sheet tách dòng nối đúng chỗ;
  - catalog: 6 chuỗi mới đủ 8 locale, không rơi về tiếng Việt.
- Cập nhật pin cũ: `psrc_235_read_settings_dedup_test.dart` (thứ tự mục, tên
  nhóm), `read_chrome_layout_test.dart` (nhãn nhóm).
- **Chưa kiểm trên máy thật** (sandbox không có Flutter SDK): chiều cao bảng
  khi gập hết ở 360×640; cuộn khi đổi nhóm; trang «Giọng đọc & engine» —
  import model, tạo giọng, SnackBar; sheet «Tách dòng tự động» từ dock và từ
  thanh trên; nhãn ở th / my / si.
