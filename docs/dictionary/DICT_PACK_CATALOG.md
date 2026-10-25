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
      "license": "CC0-1.0",
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

## 4. Bộ mặc định hiện có (đã kiểm tra tồn tại)

| id | Nội dung | Dung lượng | Nguồn / giấy phép |
|---|---|---|---|
| `en-vi-ovdp` | Anh → Việt, 386.600 mục (kể cả dạng biến đổi) | ~11,4 MB | Open Vietnamese Dictionary Project — `catusf/tudien` (**CC0-1.0**), phân phối lại trong `quocanh38/dual-dictionary` |
| `en-en-simple-wiktionary` | Anh → Anh (Simple English Wiktionary) | ~2,2 MB | Simple English Wiktionary (**CC BY-SA 3.0+/4.0** & GFDL) |

Bộ khác (Lạc Việt MTD, OALD, từ điển chuyên ngành…) **không** đóng gói sẵn vì
giấy phép: người dùng tự import file đã mua/tự có (đường import cũ vẫn giữ).

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
