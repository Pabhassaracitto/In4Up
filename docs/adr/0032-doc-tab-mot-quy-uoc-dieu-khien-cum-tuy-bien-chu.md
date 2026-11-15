# ADR-0032 — Tab Đọc: một quy ước điều khiển trong cụm «Tùy biến chữ»

- **Trạng thái:** đã triển khai trên `arena/16084fc2-in4up` (lane L3, nhánh con
  của `arena/60e35d65-in4up`); mã commit và run CI ghi trong PR của nhánh này
  (nhánh hub có thể bị viết lại lịch sử nên ADR không ghi mã). **Chờ owner
  duyệt hình dạng và nghiệm thu máy thật.**
- **Định danh:** Linear **PSRC-239** — bước 4/4 của yêu cầu owner «I4U - Màn
  hình».
- **Nguồn:** kế hoạch 4 bước owner đã duyệt (2026-11-15): «switch = bật/tắt,
  nút phân đoạn = chọn 1 trong N, chip = mở bảng khác».
- **Quan hệ:** **bổ sung ADR-0024 D1** — cụm vẫn là MỘT widget dùng chung cho
  ba lối vào, vẫn gọi API sẵn có, không thêm setting / khoá lưu. ADR này chỉ
  đổi *kiểu điều khiển* bên trong cụm. Không đổi ADR-0021, ADR-0030, ADR-0031.

## Bối cảnh

Cụm «Tùy biến chữ» (`ReadDisplayControls`) có 6 chip **trông giống hệt nhau**
(`ActionChip`) và một công tắc. Đọc code thì 6 chip đó làm ba loại việc:

| Chip | Thật ra là | Vấn đề |
|---|---|---|
| «Độ khó» (nhãn đổi theo chế độ) | xoay vòng 4 chế độ màu | không thấy 3 lựa chọn còn lại; muốn về «Không màu» phải bấm tới 3 lần |
| «Thông tin màu», «Màu IPA», «Chế độ Focus» | bật / tắt | trạng thái chỉ hiện qua màu icon 14 px |
| «Bôi nhiều chữ» ⇄ «Box từng từ» | đổi giữa hai kiểu chạm chữ | nhãn đổi theo trạng thái ⇒ không rõ nhãn là «đang ở» hay «bấm để sang» |
| «Hướng dẫn đọc theo dòng» | mở một bảng khác | trông y như các nút bật / tắt |

Nhìn vào không đoán được bấm sẽ xảy ra gì — phải bấm thử.

## Quyết định

### D1 — Hình dạng nói lên loại việc

| Loại việc | Điều khiển | Mục trong cụm |
|---|---|---|
| Chọn 1 trong N | nhóm nút **chung một viền**, lựa chọn đang dùng tô nền | Chế độ màu (4), Kiểu chạm chữ (2) |
| Bật / tắt | **công tắc** | Thông tin màu, Màu IPA, Chế độ Focus, Đồng bộ tự động |
| Mở bảng khác | **chip rời có mũi tên ›** | Hướng dẫn đọc theo dòng |

Bản vẽ: `docs/project/assets/psrc-239-tuy-bien-chu-wireframe.png` (nguồn
`.svg`). Đây là bản vẽ tay để duyệt hình dạng, không phải ảnh chụp app.

Thứ tự trong cụm: tiêu đề → chế độ màu → kiểu chạm chữ → các công tắc →
«Đồng bộ tự động» (kèm dòng giải thích của ADR-0024) → chip «Hướng dẫn đọc
theo dòng».

### D2 — Chỉ đổi hình dạng; hàm gọi và nơi lưu giữ nguyên

| Mục | Trước | Sau |
|---|---|---|
| Chế độ màu | `tp.cycleColorMode()` | `tp.setColorMode(mode)` |
| Kiểu chạm chữ | `tp.setWordTapBoxes(!tp.wordTapBoxes)` | như cũ (chỉ gọi khi chọn lựa chọn *khác* cái đang dùng) |
| Thông tin màu | `tp.setShowColorModeDetails(!…)` | `tp.setShowColorModeDetails(value)` |
| Màu IPA | `tp.setIpaLegendVisible(!…)` | `tp.setIpaLegendVisible(value)` |
| Chế độ Focus | `ctrl.toggleFocusMode()` | như cũ |
| Đồng bộ tự động | `ctrl.toggleAutoSync()` | như cũ |
| Hướng dẫn | `ReadLineHint.showSheet(context)` | như cũ |

- `setColorMode` là API **sẵn có** của `TextProvider`; nó ghi cùng một chỗ
  (`_storage.saveColorMode`) như `cycleColorMode`, và bộ chọn «Chế độ màu»
  trong Cài đặt Text Studio đã dùng nó. Không thêm hàm, không thêm khoá lưu.
- `cycleColorMode` vẫn còn và vẫn được nút trên `ReadTopBar` (bố cục «Công cụ
  ở trên») dùng. ADR này **không** đổi `ReadTopBar`: thanh đó là hàng nút icon
  gập được, không phải cụm này.
- Mục theo ngữ cảnh tự ẩn như trước: «Màu IPA» chỉ hiện khi lớp IPA đang bật;
  «Chế độ Focus» và «Đồng bộ tự động» chỉ hiện khi có `ReadModeController`.

### D3 — Kiểu chạm chữ là «chọn 1 trong 2», không phải công tắc

Kế hoạch ban đầu xếp mục này vào loại bật / tắt. Khi làm thì thấy hai trạng
thái **đều có tên riêng** trong app («Bôi nhiều chữ» và «Box từng từ»), và
owner quen gọi nút này là «Bôi nhiều chữ» — tức tên của trạng thái *tắt*. Một
công tắc chỉ mang được một nhãn; chọn nhãn nào thì tên kia cũng biến mất.
Vì vậy mục này dùng nhóm hai lựa chọn, cả hai tên cùng hiện.

Hệ quả cần biết: lời giải thích của PSRC-235 (nhấn giữ lựa chọn «Box từng
từ») vẫn viết theo kiểu công tắc — «Tắt = bôi nhiều chữ (mặc định). Bật = mỗi
từ một hộp…». Chữ **không đổi** (đã dịch 8 locale, đang được test ghim). Ở
đây «Tắt» ứng với lựa chọn «Bôi nhiều chữ», «Bật» ứng với «Box từng từ».
Nếu owner muốn mục này là công tắc đúng như kế hoạch, hoặc muốn viết lại câu
giải thích, đó là một thay đổi nhỏ riêng.

### D4 — Không dùng `SegmentedButton`; các lựa chọn được phép xuống hàng

`SegmentedButton` của Material chia đều bề rộng và không xuống hàng. Bốn nhãn
chế độ màu ở tiếng Miến / Sinhala / Thái dài hơn tiếng Việt nhiều; ở 320 px
chúng sẽ bị cắt. Cụm dùng `ChoiceChip` đặt trong một khung viền chung
(`Wrap`): đủ chỗ thì một hàng, thiếu thì xuống hàng, vẫn trong cùng một viền.

- Không có dấu tích trên lựa chọn đang dùng (dấu tích làm chip đổi bề rộng ⇒
  cả hàng nhảy); trạng thái thể hiện bằng nền và chữ đậm.
- Màu nền «đang chọn» dùng cùng màu với bộ chọn «Chế độ màu» trong Cài đặt.

### D5 — Công tắc xếp 2 cột khi đủ chỗ

Ba công tắc ngắn (Thông tin màu, Màu IPA, Chế độ Focus) xếp 2 cột khi cụm
rộng từ 280 px và cỡ chữ hệ thống ≤ 1.3; ngoài ra về 1 cột. Chạm cả hàng hoặc
chạm nút gạt đều đổi. «Đồng bộ tự động» giữ nguyên một hàng riêng vì có dòng
giải thích.

Cụm **cao hơn trước** — ước lượng trên bản vẽ là thêm khoảng một hàng (không
đo được trong sandbox). Panel «Tùy biến» của dock cao tối đa 320 px và cuộn
được, nên ở dock sẽ phải cuộn nhiều hơn một chút để tới «Vị trí công cụ».

### D6 — Tách phần vẽ khỏi phần nối dây

`ReadDisplayControls` (nối `TextProvider` / `ReadModeController`) giữ nguyên
tên và tham số ⇒ ba lối vào không đổi một dòng nào. Phần vẽ là
`ReadDisplayControlsView`, chỉ nhận giá trị và callback ⇒ widget test dựng
được không cần provider / Hive. Không thêm state vào provider.

## Không làm trong ADR này

- Không đổi `ReadTopBar` (hàng nút icon của bố cục «Công cụ ở trên»).
- Không đổi các chip khác của panel «Tùy biến» ngoài cụm («Bố cục đọc», «Cài
  đặt», «Vị trí công cụ») và các panel khác của dock.
- Không gộp «Đồng bộ tự động» ở panel âm thanh với mục cùng tên trong cụm.
- Không đổi chữ của lời giải thích «Box từng từ» (xem D3).
- Không thêm setting, khoá lưu hay API mới.

## i18n (quy tắc vàng #5)

**Không thêm chuỗi mới.** Mọi nhãn của cụm đã có trong gói 8 locale; «CEFR» là
tên riêng, hiện nguyên văn như trước. Hai kiểu chạm chữ nay cùng hiện, nên
«Box từng từ» và «Bôi nhiều chữ» xuất hiện đồng thời (trước đây mỗi lúc một
nhãn).

## Kiểm chứng

- `test/read_mode/psrc_239_display_controls_convention_test.dart` (nối vào
  step «Read actions + mixed-language tests» của `app_analyze.yml`):
  - widget test `ReadDisplayControlsView`: đúng kiểu điều khiển cho từng mục;
    chọn thẳng chế độ màu; chạm hàng / nút gạt đổi một lần; mục theo ngữ cảnh
    tự ẩn; 2 cột ở 320 px, 1 cột khi cỡ chữ lớn; không tràn với 8 locale ×
    (320 / 360 px, màn ngang) × lề dock / lề sheet × cỡ chữ 1.0 / 1.15;
  - source-pin: mỗi kiểu điều khiển dựng ở đúng một chỗ; hàm được gọi không
    đổi; cụm vẫn dùng chung cho dock và sheet;
  - gói ngôn ngữ: 13 chuỗi của cụm đủ 8 locale.
- **Pin cũ đã sửa công khai:** `test/read_ui_121_contract_test.dart` ghim
  `tp.cycleColorMode()` và `tp.colorMode.label` trong file cụm. Nay ghim
  `tp.setColorMode(mode)`, `for (final mode in ColorMode.values)` và
  `label: mode.label,` trong file cụm, và ghim `tp.cycleColorMode()` ở
  `read_top_bar.dart` (nơi nó vẫn được dùng).
- Pin của `psrc_235_read_settings_dedup_test.dart` (lời giải thích «Box từng
  từ», `tp.setWordTapBoxes(!tp.wordTapBoxes)`) giữ nguyên, không sửa.
- Widget test chạy bằng font thử của Flutter (mỗi ký tự rộng bằng cỡ chữ) nên
  bắt được tràn bố cục, **không** cho biết chữ thật trông ra sao.
- **Chưa kiểm trên máy thật** (sandbox không có Flutter SDK): hình dạng và
  màu thật của nhóm lựa chọn; nhãn th / my / si xuống hàng thế nào; chiều cao
  cụm trong panel dock ở 360×640 và khi xoay ngang; cỡ nút gạt đã thu nhỏ có
  dễ chạm không; nhấn giữ «Box từng từ» ra lời giải thích; ba lối vào (dock,
  sheet «Bố cục đọc», mục cạnh ⚡).
