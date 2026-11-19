# ADR-0031 — Tab Đọc: «Đổi vai» văn bản ⇄ bản dịch để dùng IPA / tô màu / tra từ trên bản dịch

- **Trạng thái:** đã triển khai trên `arena/e941ce1f-in4up` (lane L3, nhánh con
  của `arena/60e35d65-in4up`) ở `5ff6fb4`; CI xanh (run 43741197944, chạy
  lúc commit mang mã `f30e56d`, cùng nội dung); chờ nghiệm thu máy thật.
- **Định danh:** Linear **PSRC-237** — bước 3a/4 của yêu cầu owner «I4U - Màn
  hình». Bước 3b (chọn ngôn ngữ nguồn + tự tránh cặp trùng) là **PSRC-238**,
  triển khai trên `arena/dd25d9d8-in4up` (PR #187), cũng thuộc ADR này (mục
  «Bổ sung — bước 3b»); CI xanh (run 43752025563, chạy lúc commit sửa cuối
  mang mã `d19ac63`; mã đổi sau các lần rebase theo nhánh hub, nội dung không
  đổi); chờ nghiệm thu máy thật.
- **Nguồn:** kế hoạch ban đầu của bước 3 có «nút đảo chiều cặp ngôn ngữ».
  Owner hỏi nút đó dùng để làm gì (2026-11-15). Đọc code thì thấy nó **không
  dùng được** (xem «Bối cảnh» mục 2). Owner duyệt phương án thay thế: «Đổi vai
  văn bản ⇄ bản dịch», lưu theo tài liệu, có nút đổi lại, có gợi ý đúng lúc
  và có nhãn «bản dịch máy».
- **Quan hệ:** không đổi ADR-0005 (IPA là lớp riêng), ADR-0021, ADR-0024,
  ADR-0030. Không đổi cách dịch, cache dịch hay cách chọn engine.

## Bối cảnh

Ca sử dụng của owner: mở một văn bản tiếng mẹ đẻ (Việt, Thái, Miến, Sinhala…),
dịch sang tiếng Anh, rồi muốn học tiếng Anh trên chính bản dịch đó — xem IPA,
tô màu loại từ / CEFR, chạm vào từ để tra.

Đọc code, không đoán:

1. **Mọi công cụ từ vựng chỉ nhìn `TextItem.content`.** IPA
   (`LineIpaService`), tô màu (`SyntaxHighlighterService`), CEFR và chạm tra
   từ đều chạy trên dòng văn bản chính, và chỉ hiểu tiếng Anh. Bản dịch nằm ở
   `TextItem.translation` — một chuỗi trần, không công cụ nào với tới. Hệ quả:
   với ca trên, bật IPA / tô màu **không ra gì**, và app không nói vì sao.
2. **Đảo chiều cặp ngôn ngữ không giải quyết được.** Ngôn ngữ nguồn do **nội
   dung văn bản** quyết định (`detectedSourceLanguage` đọc 24 dòng đầu). Đảo
   nhãn «VI → EN» thành «EN → VI» trên một văn bản tiếng Việt chỉ tạo ra một
   cặp sai; văn bản vẫn là tiếng Việt.
3. **Không có kho lưu nội dung dòng.** Mở lại tài liệu là đọc lại file / bản
   cloud rồi dựng lại `TextItem` từ đầu (`id` tài liệu cũng sinh mới). Bản
   dịch quay về qua `TranslationCache` (file) hoặc `translations_<cloudId>_<lang>`
   (cloud).

## Quyết định

### D1 — «Đổi vai» hoán đổi hai trường của từng dòng đã dịch

`swapLineRoles()` (`lib/features/translation/line_role_swap.dart`, hàm thuần):
với mỗi dòng **có bản dịch ở ngôn ngữ đích hiện tại**, đổi `content` ⇄
`translation`. Bản dịch thành văn bản chính ⇒ toàn bộ công cụ sẵn có chạy trên
nó mà **không phải viết lại công cụ nào**.

- Dòng chưa có bản dịch **giữ nguyên** (không mất chữ, không để dòng trống).
- Mốc thời gian, `id` đi theo dòng ⇒ tài liệu LRC / SRT vẫn khớp âm thanh.
- Không cắt khoảng trắng: gọi lại với cặp mã đảo ngược là phép nghịch đảo,
  trả đúng từng ký tự của văn bản gốc.
- Sau khi đổi, lớp chủ (`TextProvider.onLineRolesSwapped`) phân tích lại từ
  loại, dựng lại `fullText`, xoá cache dấu IPA. Toàn văn gốc (kể cả mốc thời
  gian của LRC) được giữ riêng và trả lại khi đổi lại.

Đã cân nhắc và loại:

| Phương án | Vì sao loại |
|---|---|
| Cho IPA / tô màu chạy trên cả dòng dịch | Phải nhân đôi đường dựng dòng (`TextLineWidget`, cache, chạm từ, lưu từ vựng) — rủi ro cao ở khu vực đang ghim nhiều hợp đồng UI |
| Tạo tài liệu mới từ bản dịch | Mất liên kết với văn bản gốc và mốc thời gian; thư viện đầy bản sao |
| Nút đảo chiều cặp ngôn ngữ | Không đổi được ngôn ngữ của văn bản (Bối cảnh mục 2) |

### D2 — Văn bản gốc không được phép mất

Khi đang đổi vai, văn bản gốc nằm ở dòng dịch, nên mọi thao tác **ghi vào dòng
dịch** đều bị chặn hoặc đổi nghĩa:

| Thao tác | Khi đang đổi vai |
|---|---|
| Đổi ngôn ngữ đích / nguồn | Chặn, báo «hãy đổi lại trước» |
| «Dịch lại tất cả», dịch lại một dòng | Chặn, báo lý do |
| Dịch nền tự động (phát song ngữ) | Bỏ qua im lặng |
| «Xóa tất cả bản dịch» | **Đổi lại trước rồi mới xoá** — thứ bị xoá là bản dịch máy |
| Tô lại bản dịch từ cache / từ cloud | Bỏ qua |
| Lưu bản dịch của tài liệu cloud | Bỏ qua (không lưu văn bản gốc thành «bản dịch») |
| «Tách dòng tự động» | Đổi lại trước khi mở bảng tách — thứ được tách luôn là văn bản gốc |

### D3 — Cặp ngôn ngữ đi theo, nhưng không ghi đè lựa chọn của người dùng

Đổi vai thì đích dịch trong bộ nhớ thành ngôn ngữ gốc và nguồn dịch được gắn
vào ngôn ngữ vừa đưa lên, để nhãn «EN → VI», giọng đọc và phát song ngữ đều
đúng. Thay đổi này **không ghi vào cài đặt chung**: rời tài liệu là trả về
đích người dùng đã chọn.

### D4 — Lưu theo tài liệu bằng một dấu nhỏ, không lưu nội dung

Vì không có kho lưu nội dung dòng (Bối cảnh mục 3), thứ được lưu chỉ là một
dấu trong hộp cài đặt Hive:

- khoá `read_role_swap_v1_<md5(danh tính tài liệu)>`, danh tính là
  `file:<đường dẫn>` hoặc `cloud:<id>`;
- giá trị `<mã đã đưa lên>><mã gốc>><số dòng đã đổi>`, ví dụ `EN>VI>42`.

Mở lại tài liệu: sau khi bản dịch quay về (cache hoặc cloud), nếu đích dịch
vẫn là ngôn ngữ đã đưa lên **và** số dòng có bản dịch không ít hơn lúc lưu thì
tự đổi vai lại. Thiếu một trong hai điều kiện thì mở ở dạng gốc — không bao
giờ dựng ra tài liệu nửa nọ nửa kia từ dữ liệu thiếu.

Văn bản dán tay / sinh bởi AI không có danh tính bền ⇒ đổi vai chỉ sống trong
phiên. Đổi lại thì xoá dấu.

### D5 — Giao diện: một nút, một dải trạng thái, một gợi ý đúng lúc

- **Nút «Đổi vai văn bản ⇄ bản dịch»** (`translation-role-swap-button`) trong
  `TranslationToolbar`, cạnh nút bố cục dịch và nút làm mờ; có thêm trong bảng
  tuỳ chọn khi nhấn giữ nút Dịch. Chỉ bấm được khi đã có bản dịch.
- **Dải «Đang đọc bản dịch máy · <ngôn ngữ>» + «Đổi lại»**
  (`read-role-swap-strip`) ngay trên vùng đọc, ở mọi bố cục (dock hay thanh
  trên). Người đọc luôn biết thứ đang đọc là do máy dịch.
- **Gợi ý** (`read-role-swap-hint`): khi IPA hoặc tô màu đang bật, văn bản
  không phải tiếng Anh và đã có bản dịch tiếng Anh thì cùng dải đó hỏi «IPA và
  tô màu chỉ chạy trên tiếng Anh. Đổi vai để dùng trên bản dịch?». Đóng được,
  và không hỏi lại trên cùng tài liệu trong phiên. Gợi ý là **điều kiện hiển
  thị**, không móc vào các nút bật / tắt ⇒ không đụng tới các lời gọi điều
  khiển đang được ghim trong bảng Cài đặt.

Không dùng widget animation (READ-TOOLBAR-001).

## Giới hạn đã biết

- Bản dịch máy có thể sai; IPA / CEFR tính trên câu tiếng Anh do máy viết.
  Dải trạng thái nói rõ điều này bằng chữ «bản dịch máy».
- Tài liệu **trộn nhiều ngôn ngữ**: sau khi đổi vai rồi đổi lại, mã ngôn ngữ
  nguồn ghi trên từng dòng được đặt về ngôn ngữ chung của tài liệu (nội dung
  chữ không đổi). Có thể ảnh hưởng giọng đọc của các dòng khác ngôn ngữ.
- Đánh dấu độ khó theo từ (`TextItem.words`) đi theo dòng, không theo ngôn ngữ.
- ~~Trong bảng «Cài đặt Text Studio», chọn ngôn ngữ đích khi đang đổi vai bị
  chặn nhưng lý do chỉ hiện ở thanh công cụ dịch.~~ Đã sửa ở bước 3b (E5):
  lý do hiện ngay dưới nút chọn ngôn ngữ, đủ 8 locale.
- **Web Reader dùng chung đích dịch** (`translationTargetLanguage` của
  `TextProvider`): khi tài liệu ở tab Đọc đang đổi vai, Web Reader dịch sang
  ngôn ngữ gốc của tài liệu đó. Sửa cần chạm file ngoài lane L3 — đã báo hub
  trong phiếu L3.

## Bổ sung — bước 3b (PSRC-238): chọn ngôn ngữ nguồn, tự tránh cặp trùng

Ngày: 2026-11-15. Cùng ADR vì cùng một chỗ gắn nguồn (`_pinnedTranslationSourceCode`)
mà «Đổi vai» đang mượn.

**Vấn đề.** Ngôn ngữ nguồn do app tự nhận diện từ 24 dòng đầu. Văn bản ngắn,
lẫn tên riêng dễ bị nhận sai (tiếng Anh thành tiếng Đức ⇒ đòi tải gói dịch
tiếng Đức, đọc bằng giọng Đức) và người dùng không có chỗ nào để sửa: hàm
`setTranslationSourceLanguage` đã có từ XLAT-MLKIT-001 nhưng không giao diện
nào gọi tới, lựa chọn cũng không được lưu. Nguồn trùng đích thì bấm «Dịch» chỉ
ra một dòng lỗi đỏ.

### E1 — Bảng chọn ngôn ngữ chọn được cả nguồn lẫn đích

`showTranslationPairPicker` (cùng bảng với bảng chọn đích cũ) có thêm hàng
«Ngôn ngữ nguồn → Ngôn ngữ đích» ở đầu; chạm vào phía nào thì danh sách bên
dưới là của phía đó. Phía nguồn có dòng «Tự nhận diện» đứng đầu, kèm ngôn ngữ
app đang nhận ra — để người dùng thấy có cần chọn tay hay không. Bảng trả về
`TranslationPairChoice {sourceCode, target}`; `null` ở mỗi trường = không đổi.

Bảng mở từ nút cặp ngôn ngữ ở thanh dịch và ở nhóm «Dịch & đọc song ngữ» của
Cài đặt. Thẻ «Dịch màn hình» vẫn dùng bảng chỉ-chọn-đích (`onSelected`), không
đổi.

Giao diện tab Đọc (thanh dịch, Cài đặt, thanh phát) đọc **nguồn hiệu dụng**
`translationSourceLanguage` thay cho kết quả nhận diện thô — nên giọng đọc của
văn bản gốc cũng đi theo nguồn đã chọn. `detectedSourceLanguage` giữ nguyên
nghĩa và chỉ còn được đưa vào bảng chọn làm «kết quả nhận diện».

### E2 — Lưu theo tài liệu, cùng danh tính với dấu «Đổi vai»

Lựa chọn lưu trong hộp cài đặt Hive dưới khoá
`read_translation_source_v1_<md5(khoá tài liệu)>`, khoá tài liệu là
`roleSwapDocumentKey` (`file:<đường dẫn>` / `cloud:<id>`). «Tự nhận diện» thì
xoá. Chuỗi lạ / hỏng coi như chưa chọn.

`_setSourceMeta` — điểm mọi đường nạp tài liệu đi qua, cũng là lúc mới biết
danh tính tài liệu — gọi `restoreSavedTranslationSource()`: có lưu thì gắn
lại, chưa lưu (hoặc văn bản dán tay, không có khoá) thì về «Tự nhận diện».
Việc này xảy ra **trước** khi tô bản dịch từ cache và trước khi khôi phục
«Đổi vai», vì cả hai đều đọc nguồn hiệu dụng. Hệ quả tốt kèm theo: nguồn của
tài liệu trước không còn sót sang file LRC / SRT (hai đường nạp này trước đây
không xoá nguồn gắn).

Khôi phục **không** xoá bản dịch và không dịch lại: bản dịch đã lưu vốn được
tạo với chính nguồn đó.

Sửa nội dung, bật / tắt tách dòng, «Tách dòng tự động» dựng lại dòng của
**cùng** tài liệu ⇒ bọc trong `reparseKeepingTranslationSource` để nguồn không
rơi. Cần cho văn bản dán tay: nó không có khoá để khôi phục.

### E3 — Không phá «Đổi vai»

«Đổi vai» mượn chỗ gắn nguồn (D3). Vì vậy:

- đang đổi vai thì `restoreSavedTranslationSource` không làm gì, và
  `setTranslationSourceLanguage` / `setTranslationLanguagePair` bị chặn như
  các thao tác ở D2 ⇒ chỗ lưu chỉ chứa lựa chọn của người dùng, không bao giờ
  chứa mã mượn tạm;
- «Đổi lại», và bỏ trạng thái đổi vai trên cùng tài liệu
  (`clearRoleSwapState`), trả lại nguồn người dùng đã chọn;
- rời tài liệu (`dropRoleSwapState`) thì bỏ; tài liệu kế tiếp tự khôi phục
  nguồn của nó.

### E4 — Nguồn trùng đích: đề nghị, không dừng ở lỗi

`suggestTargetAvoidingSource` chọn một đích khác theo thứ tự: ngôn ngữ giao
diện của app → nguồn ngay trước khi đổi → tiếng Anh → tiếng Việt. Không bao
giờ trả ngôn ngữ trùng nguồn.

- Trong bảng chọn: chọn nguồn trùng đích thì bảng **ở lại**, chuyển sang phía
  đích và hiện «Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau.» kèm nút
  «Dịch sang <ngôn ngữ>» (một chạm, áp cả nguồn lẫn đích) và «Chỉ đổi nguồn»
  (giữ cặp trùng — chỉ cần đúng giọng đọc, không cần dịch).
- Ở thanh dịch: bấm «Dịch» khi cặp trùng thì dòng lỗi đỏ được thay bằng cùng
  lời đề nghị đó; nhận lời thì đổi đích và dịch luôn. Chuỗi lỗi cũ vẫn được
  ghi vào `translationError` cho các màn hình khác đang đọc nó;
  `translationBlockedBySamePair` chỉ đánh dấu «lỗi này là do cặp trùng».
- Ở Cài đặt: dưới dòng «Hãy chọn ngôn ngữ đích khác ngôn ngữ nguồn.» có nút
  «Dịch sang <ngôn ngữ>».

`setTranslationLanguagePair` áp cả hai phía rồi mới dịch lại **một** lượt —
không dịch dở với cặp trung gian.

Không tự đổi đích thay người dùng: đích dịch là cài đặt chung của app, đổi
ngầm sẽ ảnh hưởng tài liệu khác.

### E5 — Đang đổi vai: nói lý do tại chỗ

Thanh dịch báo lý do bằng SnackBar **trước** khi mở bảng. Trong Cài đặt,
SnackBar bị bảng che, nên dòng «Đang đổi vai — hãy đổi lại trước khi đổi ngôn
ngữ hoặc dịch lại.» hiện ngay dưới nút chọn ngôn ngữ
(`read-settings-role-swap-note`).

### Không làm ở 3b

- Không thêm nút đảo cặp ngôn ngữ (lý do ở phần Bối cảnh).
- Không đổi engine dịch, khoá cache, hay cách nhận diện ngôn ngữ.
- Web Reader vẫn chỉ truyền nguồn khi nguồn được gắn (ngoài lane L3 —
  PSRC-241).

### Giới hạn của 3b

- Văn bản dán tay / AI sinh: nguồn đã chọn chỉ sống trong phiên.
- File bị đổi tên / chuyển chỗ là tài liệu khác ⇒ mất lựa chọn (như dấu «Đổi
  vai»).
- Lựa chọn không đồng bộ giữa các máy (lưu cục bộ).
- Gắn nguồn thì **mọi** dòng dùng nguồn đó, kể cả dòng lẫn ngôn ngữ khác —
  đúng hành vi sẵn có của nguồn gắn tay (XLAT-MLKIT-001).

## i18n (quy tắc vàng #5)

8 chuỗi mới, đủ 8 locale trong `tool/priority_native_pack.json`, kèm bản tiếng
Anh trong `tool/legacy_ui_english_overrides.json`:
«Đổi vai văn bản ⇄ bản dịch», «Đổi vai», «Đổi lại», «Đang đọc bản dịch máy»,
«Đã đổi vai: bản dịch thành văn bản chính», «Đã đổi lại văn bản gốc»,
«IPA và tô màu chỉ chạy trên tiếng Anh. Đổi vai để dùng trên bản dịch?»,
«Đang đổi vai — hãy đổi lại trước khi đổi ngôn ngữ hoặc dịch lại.»

Bước 3b thêm 4 chuỗi, cùng cách: «Dịch sang {ngôn ngữ}», «Chỉ đổi nguồn»,
«Ngôn ngữ nguồn: {ngôn ngữ}», «Nguồn do bạn chọn cho tài liệu này. Khi đọc
song ngữ, In4Up sẽ chuyển giọng … ↔ … trước từng lượt đọc.» Các chuỗi còn lại
của bảng chọn dùng lại chuỗi đã có.

## Kiểm chứng

- `test/read_mode/psrc_237_role_swap_test.dart`, chạy trong bước
  `read-act-tests` của `.github/workflows/app_analyze.yml`:
  hàm thuần (đổi rồi đổi lại trả nguyên văn, dòng chưa dịch giữ nguyên, dấu
  lưu hỏng bị từ chối), mixin (cặp ngôn ngữ đi theo, các thao tác ở D2 bị
  chặn, «Xóa tất cả bản dịch» giữ văn bản gốc, lưu / xoá / khôi phục dấu), và
  ghim nguồn cho phần giao diện.
- Bước 3b: `test/read_mode/psrc_238_source_language_test.dart` (cùng bước CI):
  hàm thuần (đích đề nghị không bao giờ trùng nguồn, với mọi nguồn × mọi ngôn
  ngữ giao diện), mixin (chọn lại nguồn thì dịch đúng cặp; lưu / khôi phục
  theo tài liệu; không kéo nguồn sang tài liệu khác; các ca với «Đổi vai»; cặp
  trùng thành lời đề nghị; đổi cả cặp chỉ dịch lại một lượt), bảng chọn dạng
  widget (kể cả 320 px), ghim nguồn cho phần nối dây và gói ngôn ngữ.
  `test/translation_source_language_test.dart` (hành vi nguồn gắn tay, có từ
  XLAT-MLKIT-001) được nối vào cùng bước — trước đó không chạy trên CI.
- **Chưa kiểm trên máy thật** — xem danh sách trong PSRC-237 và PSRC-238.
