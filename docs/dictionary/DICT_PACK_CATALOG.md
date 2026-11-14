# Danh mục bộ từ điển tải trong app (DICT-PACK-001)

> Owner 2026-10-25: "Cho phép người dùng tải bộ từ điển ở setting home."
>
> Màn hình: **Home → Tải bộ từ điển** (hoặc **Từ điển MDX → ☁ Tải bộ từ điển**).

## 1. Người dùng thấy gì

1. **Danh sách bộ có sẵn** lấy từ một file JSON (`catalog`). Bấm **Tải & cài**:
   app tải file → giải nén → lập chỉ mục SQLite → bộ từ điển xuất hiện ngay
   trong "Quản lý từ điển" và dùng được **offline**.
2. **Tải từ link trực tiếp** — dán URL `ZIP` (chứa `.mdx` + `.mdd` + `.css`)
   hoặc URL `.mdx` trực tiếp. Hữu ích khi danh mục chưa có bộ mình cần.
3. **Nguồn danh mục** — dán URL JSON khác (HuggingFace / GitHub raw / CDN).
   Lưu bền theo máy; nút **Dùng mặc định** quay lại URL trong repo.

Không có bước tải nào chạy lúc mở app; tất cả đều do người dùng bấm.

## 2. Định dạng file danh mục

`assets/dictionary/packs.json` (bản đóng gói trong app = bản dự phòng khi
offline), đồng thời là nội dung của URL mặc định:

```
https://raw.githubusercontent.com/Pabhassaracitto/In4Up/main/assets/dictionary/packs.json
```

```json
{
  "version": 1,
  "updated": "2026-10-25",
  "packs": [
    {
      "id": "en-vi-ovdp",
      "name": "Anh → Việt (Open Vietnamese Dictionary)",
      "description": "386.600 mục từ…",
      "sourceLang": "en",
      "targetLang": "vi",
      "sizeMb": 11.4,
      "entryCount": 386600,
      "version": "1.1",
      "downloadUrl": "https://…/star_anhviet.mdx",
      "sha256": "tuỳ chọn — hex, kiểm tra sau khi tải",
      "license": "xem giấy phép và nguồn phân phối",
      "homepage": "https://github.com/catusf/tudien"
    }
  ]
}
```

Quy tắc parse (`lib/features/dictionary/models/dict_pack.dart`):

| Trường | Bắt buộc | Ghi chú |
|---|---|---|
| `id` | ✅ | Khoá theo dõi "đã cài"; không đổi sau khi phát hành |
| `downloadUrl` (hoặc `url`) | ✅ | ZIP hoặc `.mdx`/`.mdd` trực tiếp |
| `name` | — | Thiếu ⇒ dùng `id` |
| `sizeMb` | — | Số hoặc chuỗi (`"42.5"`) |
| `sha256` | — | Có ⇒ app từ chối file không khớp |

Dòng thiếu trường bắt buộc hoặc trùng `id` **bị bỏ** — không làm hỏng cả danh
mục. Danh mục cũng chấp nhận một **mảng JSON trần** (`[ {...}, {...} ]`).

## 3. Cách tự host danh mục

### GitHub (mặc định, 0 chi phí)

1. Sửa `assets/dictionary/packs.json` trên `main`.
2. Xong — URL raw ở trên luôn trả bản mới nhất (CDN GitHub, cache ~5 phút).
3. Muốn giữ danh mục tách khỏi repo app: tạo repo `in4up-dicts`, đặt
   `packs.json` + file từ điển trong **Releases** (asset), rồi dán URL raw/
   release asset vào ô "Nguồn danh mục".

> Lưu ý: GitHub chặn file >100 MB trong repo thường. Từ điển lớn nên để ở
> **Releases** (asset tối đa 2 GB) hoặc HuggingFace.

### HuggingFace (khuyến nghị cho file lớn)

1. Tạo dataset/repo public, upload `star_anhviet.mdx` (+ `.mdd`, `.css`).
2. URL tải trực tiếp có dạng:
   `https://huggingface.co/datasets/<user>/<repo>/resolve/main/<file>.mdx`
3. Đặt `packs.json` (có thể upload cùng repo) và dán URL raw của nó:
   `https://huggingface.co/datasets/<user>/<repo>/resolve/main/packs.json`

App tải bằng HTTP thường (không cần token) ⇒ repo phải **public**.

## 4. Bộ mặc định hiện có (cập nhật 2026-11-09)

Hai file trước đây ở thư mục gốc `quocanh38/dual-dictionary/main/` đã chuyển
sang thư mục con. Asset trong app nay trỏ commit cố định
`a2163f150264a9dbb545c3d1d56e50f8b2463656` và kiểm tra SHA-256; không tự tải.
GitHub API trả dữ liệu thực cho cả hai blob và đã kiểm chứng checksum. Đây
**không phải** nghiệm thu cài đặt end-to-end trên Android/iOS.

| id | File / số mục header | Dung lượng byte | SHA-256 |
|---|---|---:|---|
| `en-vi-ovdp` | `dicts-en-vi/star_anhviet.mdx` / 386.600 | 11.383.493 | `249a773f07ce7a30de9c081a4fefce13be1bc555444d459499d434e01f2fcea5` |
| `en-en-simple-wiktionary` | `samples/simple-en.mdx` / 22.310 | 2.222.808 | `992e689488b5f4538164df9dcaa40c30eba4d22380d5d52975790b219e4cc25e` |

Nguồn Simple English Wiktionary: [NOTICE của nhà phân phối](https://github.com/quocanh38/dual-dictionary/blob/a2163f150264a9dbb545c3d1d56e50f8b2463656/NOTICE.md), CC BY-SA 3.0+/4.0 & GFDL. Nhà phân phối ghi bộ Anh–Việt là OVDP/MIT, trong khi repo catusf/tudien khai CC0; **chưa xác minh được chuỗi giấy phép của chính bản MDX** nên không khẳng định nhãn CC0 cho bản này. Cần owner/người phát hành kiểm tra quyền trước khi phân phối lại.

App bản mới sửa đúng hai URL cũ trong catalog mặc định bằng asset đã đóng gói;
không sửa catalog tự chọn hoặc URL chính thức đã được cập nhật. App cũ vẫn cần
được cập nhật hoặc dùng link trực tiếp mới; sửa trên nhánh này không tự thay đổi
catalog đang phát hành trên `main`.

Bộ thương mại (Lạc Việt, OALD, Longman...) không được phân phối kèm; chỉ import
file mà người dùng có quyền sử dụng.

## 5. Thêm một bộ mới

1. Đóng gói `Ten.mdx` (+ `Ten.mdd`, `.css`, ảnh/âm thanh) vào **một** ZIP;
   giữ nguyên tên gốc để `DictBundleScanner` ghép cặp.
2. Upload (GitHub Release / HuggingFace).
3. Thêm một dòng vào `packs.json` với `id` mới + `downloadUrl`.
4. (Khuyến nghị) tính `sha256`:
   `sha256sum Ten.zip` rồi điền vào `sha256`.
5. Thử trên máy: Home → Tải bộ từ điển → nút của bộ mới → kiểm tra tra từ.

## 6. Ghi chú kỹ thuật

- Code: `lib/features/dictionary/services/dict_pack_service.dart` (tải, kiểm
  `sha256`, giải nén chống zip-slip, cài qua **đúng** đường
  `DictionaryService.importDictionaryBundle` ⇒ dùng chung mã index/ghép bundle).
- Ghi ra `*.part` rồi mới đổi tên ⇒ mạng đứt không để lại file hỏng.
- Bản giải nén nằm trong thư mục tạm và **bị xoá** sau khi cài; bộ đã cài nằm
  trong `dictionaries/` của app (`DictStorageMode.imported`).
- Test: `test/dictionary/dict_pack_test.dart` (parse danh mục, dòng hỏng, trùng
  id, bí danh `url`, `sizeMb` dạng chuỗi).
