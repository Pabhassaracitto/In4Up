# L3 — Tab Đọc: thư viện, tài liệu, OCR

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2.
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Tab Đọc phải: mở được `.docx`, không treo khi quét thư mục lớn, OCR lấy đủ chữ (từ chế độ TT và không quét vùng trống), tinh chỉnh AI không báo sai cấu hình, chọn đúng giọng khi đọc song ngữ, và highlight đúng đoạn đang phát.

> Ranh giới: **L10** lo *bên trong* PDF/Web reader (karaoke, tự cuộn, tốc độ). L3 lo **điều phối** đọc: chọn tài liệu, thư viện, OCR, engine/giọng, đồng bộ highlight.

## Issue

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-206** | Quét thư mục nhiều tài liệu ⇒ treo/lag |
| **PSRC-207** | `.docx` không mở được |
| **PSRC-208** | Chế độ TT (text-translate) chỉ ra chữ ở trang 2 |
| **PSRC-209** | Tinh chỉnh AI sau OCR báo sai cấu hình |
| **PSRC-210** | OCR từ TT quét cả vùng trống |
| **PSRC-230** | Đọc song ngữ Sherpa/Piper chỉ dùng **một** giọng tiếng Việt cho cả nội dung Anh lẫn Việt; hai giọng Anh-Anh/Anh-Mỹ đã thêm trong setting nhưng khi phát không dùng |
| **PSRC-233** | Tab đọc đồng bộ sai đoạn đang phát |

Đợt 2 (cùng khu vực): **PSRC-193** (Tipitaka chỉ mục con sai danh mục), **PSRC-178** (tên gọi "Lặp câu tiếp theo").

## Hướng điều tra

Vùng code: `lib/screens/read_mode/**`, `lib/screens/text_library/**`, `lib/services/text_source_loader.dart`, `lib/features/pdf_reader/**`, `lib/features/ocr/**`, `lib/features/tts/**` (chọn engine/giọng — **không** chạm `engines/vieneu_*`).

1. **206**: quét thư mục thường là `Directory.list(recursive: true)` + parse metadata trên UI thread. Cần `Isolate.run`/`compute`, cập nhật theo lô. Tìm `listSync`, `Directory(`, `scan`.
2. **207**: `.docx` = ZIP + `word/document.xml`. Kiểm tra (a) bộ lọc extension/mime có nhận `docx`, (b) bước giải nén lấy text, (c) `.doc` cũ / file có mật khẩu ⇒ báo rõ "chưa hỗ trợ".
3. **208/210**: vòng lặp OCR theo trang — index lệch 0-based, render trang chưa xong đã OCR, và vùng cắt (crop) rỗng vẫn bị đưa vào OCR. Kiểm tra `pageIndex`, `await` render, và ngưỡng bỏ qua vùng < N pixel.
4. **209**: "báo sai cấu hình" = kiểm tra điều kiện tiên quyết (model/API key) trước khi gọi; thông báo phải nêu **cái gì** thiếu.
5. **230**: hai nghi vấn: (a) chọn giọng theo ngôn ngữ của **câu đầu** rồi dùng cho cả tài liệu, (b) map locale sai (`en` vs `en-GB`/`en-US`, `zh-TW` vs `zh`) nên rơi về giọng mặc định tiếng Việt. Chọn theo **từng câu**, cache theo `locale`, và log giọng đã chọn cho từng câu để chứng minh.
6. **233**: highlight lệch do (a) đơn vị câu khác nhau giữa engine và UI, hoặc (b) offset tính trên text gốc nhưng text đã bị thay. Cần **một** nguồn: index câu do bộ chia câu tạo ra, engine báo "đang đọc câu #n".
7. 230 và 233 dùng chung bộ chia câu ⇒ nếu sửa bộ chia câu, ghi rõ trong commit body (L10 cũng dùng).

## File chạm (dự kiến)

`lib/screens/read_mode/**`, `lib/screens/text_library/**`, `lib/services/text_source_loader.dart`, `lib/features/pdf_reader/**` (phần nạp/OCR), `lib/features/ocr/**`, `lib/features/tts/**` (chọn giọng). Test: `test/text/*`, `test/ocr/*`, `test/tts/*`.

## Nghiệm thu

- [ ] Quét 500 file: UI phản hồi, có progress, không ANR (test cho bộ lọc + isolate).
- [ ] Mở `.docx` 3 trang: đúng thứ tự, vào được tab đọc; `.doc` báo "chưa hỗ trợ".
- [ ] OCR tài liệu 2 trang: trang 2 có chữ; không sinh khối rỗng từ vùng trống.
- [ ] Tinh chỉnh AI sau OCR: giữ số khối (map 1–1), sai cấu hình thì báo đúng thiếu gì.
- [ ] Tài liệu Việt + Trung (`zh-TW`) đọc song ngữ: mỗi câu đúng giọng/engine (test chọn theo locale).
- [ ] Highlight trùng câu đang phát trong 10 câu liên tiếp.
- [ ] `flutter analyze` 0 error; `app_analyze` + `listen_queue_tests` xanh.

## Không làm

- Không làm karaoke/tự cuộn/tốc độ trong reader (L10).
- Không thêm engine OCR mới.

## Commit

```
fix(PSRC-206): quét thư mục lớn không treo UI [L3]
fix(PSRC-207): mở tài liệu .docx trong tab đọc [L3]
fix(PSRC-208): OCR chế độ TT lấy đủ mọi trang [L3]
fix(PSRC-210): OCR bỏ qua vùng trống [L3]
fix(PSRC-209): báo đúng cấu hình thiếu khi tinh chỉnh AI [L3]
fix(PSRC-230): chọn đúng giọng theo từng ngôn ngữ khi đọc song ngữ [L3]
fix(PSRC-233): highlight đúng đoạn đang phát [L3]
```

## Phát hiện thêm

### PSRC-235 — gọn «Cài đặt Text Studio», bước 1/4 (2026-11-15, ngoài cổng 35 issue)

Yêu cầu owner «I4U - Màn hình»: giao diện tab Đọc và phần cài đặt «vốn đang rất dài». Owner đã duyệt kế hoạch 4 bước; PSRC-235 là bước 1 («cắt bỏ»), không đổi kiến trúc.

| Bước | Nội dung | Trạng thái |
|---|---|---|
| 1 | Bỏ mục chết «Chế độ trải nghiệm», bỏ lối phát/tốc độ TTS trùng trong Cài đặt, bỏ 2 công tắc trùng, hết trùng tên «Hiển thị» | **xong** — PSRC-235 |
| 2 | Cài đặt thành nhóm gập có dòng tóm tắt; tách cấu hình engine giọng đọc ra trang riêng; «Tách dòng tự động» về thanh công cụ | **xong** — PSRC-236, ADR-0030 (xem mục dưới) |
| 3a | «Đổi vai» văn bản ⇄ bản dịch (thay cho nút đổi chiều ⇄ — owner duyệt 2026-11-15): IPA / tô màu / tra từ chạy được trên bản dịch; lưu theo tài liệu, có «Đổi lại» | **xong** — PSRC-237, ADR-0031 (xem mục dưới) |
| 3b | Chọn ngôn ngữ nguồn («Tự nhận diện» + danh sách), tự tránh cặp trùng | **xong** — PSRC-238, ADR-0031 mục «Bổ sung — bước 3b» (xem mục dưới) |
| 4 | Một quy ước điều khiển trong cụm Tùy biến chữ: switch = bật/tắt, nút phân đoạn = chọn 1 trong N, chip = mở bảng khác | **xong, chờ owner duyệt hình dạng** — PSRC-239, ADR-0032 (xem mục dưới) |

Tên mới (một đích đến = một tên):

| Đích đến | Tên cũ | Tên mới | Lối vào |
|---|---|---|---|
| Panel thứ 3 của dock | Hiển thị | **Tùy biến** | tab dock, nút tune ở dock, mục popup cạnh ⚡ |
| Sheet nhanh (preset, bản dịch, IPA, một dòng) | Hiển thị | **Bố cục đọc** | chip trong panel Tùy biến, nút ở ReadTopBar |
| Mục 2 công tắc trong Cài đặt | Hiển thị | **Dòng văn bản** | Cài đặt Text Studio |

Bằng chứng CI (`app_analyze`):

- `6701d79` (PSRC-235 trên nền `7b19f94`): run **43714103071** — xanh cả 4 job.
- `a00c638` (cùng thay đổi, rebase lên `d047780`): run **43714162481** — `analyze-and-locale-test` xanh (analyze, Rule 5, step «Read actions + mixed-language tests» có test PSRC-235); job `knowledge-regressions` đỏ ở step «PSRC-183..186 + PSRC-171 — VieNeu TTS state/import/clone contract».
- Step đó đỏ **sẵn trên nhánh cha**: run **43714090932** của chính `d047780` (PSRC-171b, lane L6) hỏng đúng step này ⇒ không do PSRC-235. L3 không sửa (`engines/vieneu_*` ngoài phạm vi lane) — **báo hub / L6**.

Cần owner / hub quyết:

1. **Xung đột với XP-MODE-001 — owner đã trả lời 2026-11-15: đồng ý TẠM bỏ «Chế độ trải nghiệm», sẽ thêm lại khi mọi thứ ổn thật sự.** Quyết định và điều kiện thêm lại ghi ở **ADR-0030 D5**. Còn lại cho hub: `docs/project/XP-MODE-001-wireframe.md` § 9.2, `XP-MODE-001-review-checklist.md` (mục C và bước QA «“Chế độ trải nghiệm” cũ vẫn còn nguyên») và `KANBAN.md` vẫn ghi bất biến *giữ nguyên* mục cũ — L3 **không sửa** (file hub / owner duyệt). Đường nối lại còn nguyên: khoá ARB `grammarExperienceMode`, `getShellReadSubMode` / `saveShellReadSubMode`; mã `_SubModeSelector` + `ReadSubMode` lấy từ commit ngay trước PSRC-235.
2. ~~Tên nhóm «Thông tin & Hiển thị» chưa khớp tab dock «Tùy biến».~~ Đã đổi thành «Thông tin & Tùy biến» ở PSRC-236 (ADR-0030 D4).
3. Chưa kiểm trên máy thật: bảng Cài đặt sau rút gọn, độ rộng tab «Tùy biến» ở 320/360 px và locale dài (th/my/si), tooltip nhấn giữ của chip «Box từng từ», bố cục «Vị trí công cụ: Trên».

### PSRC-236 — Cài đặt Text Studio thành nhóm gập, bước 2/4 (2026-11-15, ngoài cổng 35 issue)

Quyết định: `docs/adr/0030-doc-tab-cai-dat-nhom-gap-va-trang-giong-doc.md`.

| Trước (sau PSRC-235) | Sau PSRC-236 |
|---|---|
| Một trang cuộn 9 mục | 3 nhóm gập + 1 dòng mở trang con; gập hết thì vừa một màn hình |
| Giá trị đang chọn chỉ thấy khi cuộn tới mục | Mỗi nhóm có dòng tóm tắt: «Cỡ chữ 18 · Giữa», «English → Tiếng Việt», «Loại từ · IPA: Tắt» |
| Khối engine giọng đọc nhúng ở cuối bảng | Trang riêng «Giọng đọc & engine» (`ReadVoiceSettingsPage`) |
| «Tách dòng tự động» ở cuối bảng cấu hình | Chip trong panel «Công cụ đọc» của dock; nút trong `ReadTopBar` ở bố cục «Công cụ ở trên» |
| Nhóm chrome «Thông tin & Hiển thị» | «Thông tin & Tùy biến» (khớp tab dock) |

Không đổi: logic của mọi điều khiển, nơi lưu, một cửa vào TTS (ADR-0021 D1), cụm «Tùy biến chữ» (ADR-0024 D1). Không thêm state vào `TextProvider`.

Bằng chứng CI (`app_analyze`):

- `2de3829` (PSRC-236 trên nền `82e8b27`; lúc chạy CI commit mang mã `998dbf0`, cùng nội dung): run **43716805789** — xanh cả 4 job; step «Analyze full app» và «Read actions + mixed-language tests» (có `psrc_236_read_settings_groups_test.dart`, `psrc_235_…`, `read_chrome_layout_test.dart`) đều xanh. Cùng nền này PSRC-235 cũng hết đỏ ở step VieNeu (nhánh cha đã sửa ở `16f33cb`).

Chưa kiểm trên máy thật (sandbox không có Flutter SDK): bảng khi gập hết ở 360×640; cuộn khi đổi nhóm; trang «Giọng đọc & engine» — import model, tạo giọng, SnackBar; sheet «Tách dòng tự động» từ dock và từ thanh trên; nhãn ở th / my / si.

Phát hiện thêm khi làm PSRC-236:

- `test/read_chrome_layout_test.dart` và `test/read_ui_120_contract_test.dart` **không nằm trong step nào** của `app_analyze.yml` ⇒ pin của READ-UI-120 trước giờ không chạy trên CI. PSRC-236 đã nối `read_chrome_layout_test.dart` (có sửa nhãn). `read_ui_120_contract_test.dart` chưa nối — chưa rõ nó còn xanh hay không; **báo hub**.

### PSRC-237 — «Đổi vai» văn bản ⇄ bản dịch, bước 3a/4 (2026-11-15, ngoài cổng 35 issue)

Quyết định: `docs/adr/0031-doc-tab-doi-vai-van-ban-va-ban-dich.md`.

Vì sao đổi kế hoạch: bước 3 ban đầu có «nút đổi chiều ⇄». Owner hỏi nút đó để làm gì. Đọc code thì ngôn ngữ nguồn do **nội dung** văn bản quyết định, nên đảo nhãn cặp ngôn ngữ chỉ tạo ra cặp sai. Nhu cầu thật của owner là: văn bản tiếng mẹ đẻ đã dịch sang tiếng Anh, muốn xem IPA / từ khó **trên phần tiếng Anh** — mà mọi công cụ đó chỉ đọc dòng văn bản chính.

| Trước | Sau PSRC-237 |
|---|---|
| IPA / tô màu / CEFR / chạm tra từ không với tới bản dịch; bật lên không ra gì, không giải thích | Nút «Đổi vai văn bản ⇄ bản dịch» đưa bản dịch lên làm văn bản chính; mọi công cụ sẵn có chạy trên nó |
| — | Dải «Đang đọc bản dịch máy · <ngôn ngữ>» + «Đổi lại» ngay trên vùng đọc |
| — | Gợi ý «Đổi vai» khi IPA / tô màu đang bật trên văn bản không phải tiếng Anh đã có bản dịch tiếng Anh (đóng được) |
| — | Mở lại file / tài liệu cloud đã đổi vai thì tự đổi vai lại, khi bản dịch về đủ |

Văn bản gốc không mất: khi đang đổi vai, đổi ngôn ngữ, dịch lại, tô lại từ cache / cloud đều bị chặn hoặc bỏ qua; «Xóa tất cả bản dịch» đổi lại trước rồi mới xoá; «Tách dòng tự động» đổi lại trước khi mở.

Bằng chứng CI (`app_analyze`):

- `5ff6fb4` (PSRC-237 trên nền `82e8b27`; lúc chạy CI commit mang mã `f30e56d`, cùng nội dung): run **43741197944** — xanh cả 4 job; job `analyze-and-locale-test` (132894531206): step «Analyze full app», «Rule 5 test» và «Read actions + mixed-language tests» (có `psrc_237_role_swap_test.dart`) đều xanh. Deploy web **43741197866** xanh.

Chưa kiểm trên máy thật (sandbox không có Flutter SDK): nút mới ở hàng 2 thanh dịch trên màn 320 / 360 px; dải trạng thái ở th / my / si; IPA + tô màu + chạm tra từ trên bản dịch sau khi đổi vai; phát song ngữ khi đang đổi vai; mở lại file và tài liệu cloud đã đổi vai; «Tách dòng tự động» khi đang đổi vai.

Phát hiện thêm khi làm PSRC-237:

- **Web Reader dùng chung đích dịch của tab Đọc** (`web_reader_screen.dart`, `web_word_tap_sheet.dart` đọc `textProvider.translationTargetLanguage`). Khi tài liệu ở tab Đọc đang đổi vai, Web Reader sẽ dịch sang ngôn ngữ gốc của tài liệu đó. Sửa cần chạm file ngoài lane ⇒ **báo hub** — PSRC-241.
- Chọn ngôn ngữ đích trong «Cài đặt Text Studio» khi đang đổi vai bị chặn đúng, nhưng lý do chỉ hiện ở thanh công cụ dịch (dòng «Lỗi: …» ghép chuỗi tiếng Việt — kiểu thông báo lỗi sẵn có của mixin dịch, không riêng PSRC-237).
- `test/translation_source_language_test.dart` (khoá hành vi nguồn dịch gắn tay) **không nằm trong step nào** của `app_analyze.yml`; bước 3b sẽ cần nó ⇒ nối khi làm 3b (PSRC-238).

Việc kế tiếp đã ghi trên Linear (2026-11-15):

| Issue | Nội dung | Ai làm |
|---|---|---|
| PSRC-238 | Bước 3b — chọn ngôn ngữ nguồn + tự tránh cặp trùng | lane L3 — **xong**, xem mục dưới |
| PSRC-239 | Bước 4 — một quy ước điều khiển trong cụm «Tùy biến chữ» | lane L3 — đã làm, xem mục PSRC-239 |
| PSRC-240 | Thêm lại «Chế độ trải nghiệm» với hành vi thật (để sau, khi ổn) | chờ owner chốt hành vi |
| PSRC-241 | Web Reader dùng chung đích dịch của tab Đọc | ngoài lane — hub giao |
| PSRC-242 | Việc dọn cho hub: `read_ui_120_contract_test.dart` chưa vào CI, tài liệu lệch, lỗi dịch ghép chuỗi | hub |

### PSRC-238 — chọn ngôn ngữ nguồn + tự tránh cặp trùng, bước 3b/4 (2026-11-15, ngoài cổng 35 issue)

Quyết định: `docs/adr/0031-doc-tab-doi-vai-van-ban-va-ban-dich.md`, mục «Bổ sung — bước 3b» (E1–E5). Nhánh `arena/dd25d9d8-in4up`.

| Trước | Sau PSRC-238 |
|---|---|
| Nguồn do app tự nhận diện; nhận sai (vd tiếng Anh thành tiếng Đức) thì không sửa được | Bảng chọn ngôn ngữ ở thanh dịch và trong Cài đặt chọn được cả **nguồn** («Tự nhận diện» + danh sách) lẫn đích |
| Lựa chọn nguồn (nếu có) mất khi mở tài liệu khác | Lưu theo tài liệu (file / cloud), tự gắn lại khi mở lại; tài liệu khác và văn bản dán tay về «Tự nhận diện» |
| Nguồn trùng đích: bấm «Dịch» ra một dòng lỗi đỏ | Bảng chọn, thanh dịch và Cài đặt đề nghị sẵn một đích khác — nút «Dịch sang …», một chạm |
| Đang «Đổi vai», đổi ngôn ngữ trong Cài đặt bị chặn mà không thấy lý do | Lý do hiện ngay dưới nút chọn ngôn ngữ; thanh dịch báo trước khi mở bảng |
| Giọng đọc văn bản gốc theo kết quả nhận diện | Theo nguồn hiệu dụng (đã chọn thì dùng nguồn đã chọn) |

Không đổi: engine dịch, khoá cache, cách nhận diện ngôn ngữ, thẻ «Dịch màn hình» (vẫn bảng chỉ-chọn-đích). Không thêm nút đảo cặp.

Bằng chứng CI (`app_analyze`):

- Ba commit mã của PR #187 (feat + ci + fix; lúc chạy CI mang mã `1f92268` / `8819b1c` / `d19ac63`): run **43752025563** — xanh cả 4 job; job `analyze-and-locale-test` (132927859657): step «Analyze full app», «Rule 5 test» và «Read actions + mixed-language tests» (có `psrc_238_source_language_test.dart` và `translation_source_language_test.dart`) đều xanh.
- Nhánh hub được rebase / viết lại lịch sử trong lúc làm, nên nhánh L3 phải rebase theo và **mã commit đổi sau mỗi lần** (nội dung không đổi). Tài liệu này vì vậy gọi commit theo vai trò (feat / ci / fix / docs); mã hiện hành và run CI trên đầu nhánh hiện hành ghi trong PR #187.
- Hai run trước đó đỏ ở step «Read actions…» — **43750323982** (commit feat, lúc đó `1f92268`) và **43751253328** (commit ci, lúc đó `8819b1c`): 305 test đạt, 1 hỏng. Test hỏng là test **có sẵn** `translation_source_language_test.dart` › «translateLine: call site đơn dòng cũng retry với nguồn tài liệu», lần đầu được chạy trên CI: `translateLine` gọi thẳng singleton `TranslationService()` nên dựng Hive thật (`HiveError`). Sửa ở commit fix (lúc đó `d19ac63`; đi qua dịch vụ đã tiêm, như `translateAll`; production không đổi).

Chưa kiểm trên máy thật (sandbox không có Flutter SDK): bảng chọn cặp ở 320 / 360 px và khi xoay ngang; hàng «nguồn → đích» với tên ngôn ngữ dài (th / my / si); chọn nguồn rồi đóng app, mở lại file / tài liệu cloud; lời đề nghị «Dịch sang …» ở thanh dịch khi bố cục hẹp; giọng đọc song ngữ sau khi đổi nguồn; đổi nguồn khi đang phát.

Phát hiện thêm khi làm PSRC-238:

- Step «Read actions…» chỉ ghi annotation cho lỗi so khớp (dòng `Expected:`). Test hỏng vì ném exception thì không có annotation nào — phải tải log mới biết. Commit ci của PR #187 thêm một annotation tóm tắt (tên test hỏng + vài dòng lỗi đầu). Các step test khác của `app_analyze.yml` có cùng kiểu grep ⇒ cùng điểm mù; L3 không sửa (ngoài lane) — **báo hub**, gộp vào PSRC-242.
- File LRC / SRT trước đây **không** xoá nguồn gắn tay của tài liệu trước (hai đường nạp này không gọi `resetTranslationForNewDocument`). Nay mọi đường nạp đều khôi phục nguồn theo tài liệu ở `_setSourceMeta` nên hết.
- Còn nguyên từ 3a: Web Reader dùng chung đích dịch và chỉ truyền nguồn khi nguồn được gắn (PSRC-241); tài liệu trộn ngôn ngữ mất mã nguồn từng dòng sau khi đổi vai rồi đổi lại.

### PSRC-239 — một quy ước điều khiển trong cụm «Tùy biến chữ», bước 4/4 (2026-11-15, ngoài cổng 35 issue)

Quyết định: `docs/adr/0032-doc-tab-mot-quy-uoc-dieu-khien-cum-tuy-bien-chu.md`. Nhánh `arena/16084fc2-in4up`. Bản vẽ: `docs/project/assets/psrc-239-tuy-bien-chu-wireframe.png` (nguồn `.svg`; vẽ tay, không phải ảnh chụp app).

| Trước | Sau PSRC-239 |
|---|---|
| Chế độ màu: một chip, bấm để xoay vòng 4 chế độ | Nhóm 4 lựa chọn chung một viền, chọn thẳng |
| «Bôi nhiều chữ» ⇄ «Box từng từ»: một chip, nhãn đổi theo trạng thái | Nhóm 2 lựa chọn, cả hai tên cùng hiện |
| «Thông tin màu», «Màu IPA», «Chế độ Focus»: chip, trạng thái chỉ hiện qua màu icon | Công tắc (2 cột khi đủ chỗ) |
| «Hướng dẫn đọc theo dòng»: chip giống các nút bật / tắt | Chip rời có mũi tên › |
| «Đồng bộ tự động»: công tắc | Không đổi |

Không đổi: hàm được gọi và nơi lưu (chế độ màu gọi `setColorMode` — API sẵn có, cùng chỗ lưu với `cycleColorMode`); `ReadDisplayControls` vẫn là một widget cho cả ba lối vào (ADR-0024 D1); `ReadTopBar`; chữ của lời giải thích «Box từng từ». Không thêm chuỗi i18n.

Lệch so với kế hoạch (cần owner biết):

1. **«Box từng từ» là nhóm 2 lựa chọn chứ không phải công tắc** — lý do ở ADR-0032 D3 (hai trạng thái đều có tên; công tắc chỉ mang được một tên). Lời giải thích khi nhấn giữ vẫn viết «Tắt = … Bật = …».
2. **«Nút phân đoạn» không phải `SegmentedButton` của Material** mà là các lựa chọn trong một khung viền chung, được phép xuống hàng — lý do ở ADR-0032 D4 (nhãn dài ở th / my / si).
3. **Code đi cùng bản vẽ**, không phải bản vẽ trước rồi mới code như issue ghi. PR chưa gộp cho tới khi owner duyệt; nếu owner muốn hình dạng khác thì sửa trong cùng PR.
4. Cụm cao hơn trước khoảng một hàng (ước lượng trên bản vẽ); panel dock vẫn cuộn được.

Pin cũ đã sửa: `test/read_ui_121_contract_test.dart` (ghim `tp.cycleColorMode()` trong file cụm → nay ghim `tp.setColorMode(mode)` ở cụm và `tp.cycleColorMode()` ở `read_top_bar.dart`). Pin PSRC-235 không sửa.

Bằng chứng CI: mã commit và run ghi trong PR của nhánh (tài liệu này gọi commit theo vai trò — feat / docs).

Chưa kiểm trên máy thật (sandbox không có Flutter SDK): hình dạng, màu và khoảng cách thật của nhóm lựa chọn; nhãn th / my / si xuống hàng; chiều cao cụm trong panel dock ở 360×640 và khi xoay ngang; nút gạt thu nhỏ có dễ chạm không; nhấn giữ «Box từng từ»; ba lối vào (dock, sheet «Bố cục đọc», mục cạnh ⚡).
