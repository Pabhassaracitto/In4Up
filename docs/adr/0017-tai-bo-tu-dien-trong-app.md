# ADR-0017: Tải bộ từ điển trong app bằng danh mục JSON tự host

- **Ngày:** 2026-10-25
- **Trạng thái:** ĐÃ TRIỂN KHAI (nhánh `arena/054f9e9a-in4up`; sandbox không có
  Flutter SDK nên **chưa chạy analyzer/test** — chờ CI)
- **Phạm vi:** `lib/features/dictionary/models/dict_pack.dart` (mới),
  `lib/features/dictionary/services/dict_pack_service.dart` (mới),
  `lib/features/dictionary/widgets/dict_pack_screen.dart` (mới),
  `lib/features/dictionary/widgets/dict_manager_screen.dart` (nút AppBar),
  `lib/screens/main_shell.dart` (mục `dict_packs` ở Home + Đọc),
  `assets/dictionary/packs.json` (mới), `docs/dictionary/DICT_PACK_CATALOG.md`,
  `test/dictionary/dict_pack_test.dart`.
  KHÔNG đụng `mdx_parser` (DICT-001) và luồng import thủ công
  (`DictImportService`) — luồng tải dùng lại đúng `importDictionaryBundle`.

## Bối cảnh

Người sở hữu: "Cho phép người dùng tải bộ từ điển ở setting home… nếu có link
thì đưa link còn không thì người dùng có thể cung cấp link hoặc upload bộ từ
điển lên HuggingFace."

Trước đây muốn có từ điển, người dùng **phải** tự tìm file `.mdx`/`.mdd`/`.css`
trên mạng, tải về máy rồi import thủ công (chọn nhiều file hoặc chọn thư mục).
Với người không chuyên đây là rào cản lớn; và không có cách nào để owner đẩy
một bộ mới cho mọi máy mà không phát hành app.

## Quyết định

### 1. Danh mục JSON là hợp đồng duy nhất

`assets/dictionary/packs.json` (đẩy lên `main` là URL mặc định
`https://raw.githubusercontent.com/Pabhassaracitto/In4Up/main/assets/dictionary/packs.json`
luôn mới). Người dùng đổi được "Nguồn danh mục" ngay trong màn hình (lưu ở
SharedPreferences `dict_pack_catalog_url`) ⇒ owner có thể host trên
HuggingFace / GitHub Pages / CDN mà không cần build lại app.

Lược đồ một dòng:

```json
{"id": "…", "name": "…", "description": "…", "sourceLang": "en",
 "targetLang": "vi", "sizeMb": 11.4, "entryCount": 386600, "version": "1.1",
 "downloadUrl": "https://…/dict.zip", "sha256": "…", "license": "…",
 "homepage": "https://…"}
```

Chỉ `id` + `downloadUrl` (hoặc alias `url`) là bắt buộc. Dòng hỏng/trùng `id`
bị **bỏ**, không làm sập danh mục — vì danh mục do người dùng tự host, không
thể giả định dữ liệu hoàn hảo. Danh mục mạng hỏng ⇒ rơi về bản asset đóng gói
(`assets/dictionary/packs.json`) ⇒ màn hình không trắng.

### 2. Cài đặt = tải → (kiểm sha256) → giải nén → import

`DictPackService.install(pack)`:

1. tải về thư mục tạm, ghi `*.part` rồi `rename` khi xong (mạng đứt không để
   lại file hỏng), tiến độ 5–65 %;
2. nếu danh mục có `sha256` ⇒ so khớp (68 %);
3. `.zip` ⇒ giải nén (70 %), **chặn zip-slip**: entry có `..`/đường dẫn tuyệt
   đối bị bỏ; không phải ZIP (link `.mdx` trực tiếp) ⇒ dùng luôn file đã tải;
4. lọc đúng phần mở rộng từ điển (`.mdx .mdd .css` + ảnh/âm thanh/font đi kèm);
5. `DictionaryService.instance.importDictionaryBundle(..., mode:
   DictStorageMode.imported, onProgress: …)` (80–100 %) — **dùng lại** luồng
   import đã có (manifest, ghép bundle, index), không có nhánh xử lý thứ hai;
6. `finally` **luôn** xoá thư mục tạm.

Vì sao `DictStorageMode.imported`: người dùng bấm "tải" là muốn có bản dùng
được lâu dài trong bộ nhớ app, không phải liên kết tới thư mục tạm bị hệ điều
hành dọn.

### 3. Hai đường vào + một đường dán link

- Home (và tab Đọc) có mục **"Tải bộ từ điển"** (`ToolItem` id `dict_packs`).
- "Quản lý từ điển" có nút `cloud_download` trên AppBar, quay lại thì tự
  `_loadDicts()` để danh sách cập nhật.
- Ô "Tải từ link trực tiếp" cho phép dán URL ZIP/MDX bất kỳ khi danh mục chưa
  có bộ cần.

### 4. Nội dung mặc định & giấy phép

`packs.json` chỉ chứa bộ **phân phối lại được**, có ghi nguồn + giấy phép:
`en-vi-ovdp` (Anh–Việt, 386 600 mục, CC0-1.0 — Open Vietnamese Dictionary
Project `catusf/tudien`) và `en-en-simple-wiktionary` (Simple English
Wiktionary, CC BY-SA). Oxford/Merriam-Webster bị loại vì không được phép
phân phối lại. Cách tự host (GitHub Releases / HuggingFace) ghi trong
`docs/dictionary/DICT_PACK_CATALOG.md`.

## Hệ quả

- Người dùng không chuyên cài được từ điển bằng một chạm; owner đổi/ thêm bộ
  bằng cách sửa JSON, không cần phát hành app.
- Vì danh mục trỏ tới host bên thứ ba, link có thể chết ⇒ màn hình hiển thị
  lỗi rõ ràng và vẫn cho dán link trực tiếp; khuyến nghị owner re-host và gắn
  `sha256`.
- Test thuần Dart (`test/dictionary/dict_pack_test.dart`) khoá phần parse danh
  mục + `DictPackService.fetchOverride` cho phần mạng; phần tải/giải nén chỉ
  kiểm bằng code review + thử tay trên máy.
