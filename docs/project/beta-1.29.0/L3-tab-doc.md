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

_(trống)_
