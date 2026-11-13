# L10 — PDF/Web reader: karaoke, tự cuộn, tốc độ

> **Lane mới (tách từ L3)** vì L3 đã có 7 issue; phần "bên trong reader" đủ lớn để giao riêng. Số hiệu L10 để không đổi L1–L9 mà chủ dự án đã dùng.

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2.
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Trong PDF reader và Web reader: đọc **không dừng sớm**, chọn được chỗ bắt đầu đọc, **karaoke** (đánh dấu câu đang đọc) + **tự cuộn** theo, và áp **đúng tốc độ đọc**.

> Ranh giới với **L3**: L3 lo nạp tài liệu/thư viện/OCR/chọn giọng. L10 không sửa OCR, không sửa bộ chọn engine.

## Issue

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-231** | Web/PDF **dừng đọc sớm** + không chọn được chỗ bắt đầu đọc |
| **PSRC-232** | Web/PDF thiếu karaoke + tự cuộn theo lời đọc |
| **PSRC-229** | PDF không áp tốc độ đọc; nhãn tốc độ ở web reader sai |

## Thứ tự làm

**231 → 232 → 229.** Karaoke/tự cuộn vô nghĩa nếu việc đọc còn dừng giữa chừng.

## Hướng điều tra

Vùng code: `lib/features/pdf_reader/` (`pdf_reader_controller.dart`, `pdf_reader_screen.dart`), `lib/features/web_reader/` (`web_reader_controller.dart`, `web_reader_screen.dart`, `js/`), `lib/features/tts/**` (chỉ phần gọi phát, **không** chạm engine).

1. **231 dừng sớm**: thường do hàng đợi phát nằm trong vòng đời widget — rebuild/`dispose()` gọi `stop()`. Cần controller giữ hàng đợi ngoài widget; log "câu i/j" để chứng minh đọc hết. Kiểm tra cả trường hợp app chuyển nền.
2. **231 chọn chỗ bắt đầu**: dùng vị trí bấm/chọn text ⇒ map sang `index` câu trong danh sách câu **đã** dùng để phát. Dùng chung bộ chia câu với L3 § 233 — nếu buộc phải sửa bộ chia câu, ghi rõ trong commit body.
3. **232 karaoke**: cần tín hiệu "đang đọc câu nào" từ engine. Nếu engine chỉ báo theo câu ⇒ đánh dấu theo câu + ước lượng theo tiến độ trong câu; **không** giả vờ chính xác từng từ khi không có dữ liệu. Tự cuộn: chỉ cuộn khi câu hiện tại ra khỏi vùng nhìn, và **tạm dừng tự cuộn ~5s** khi người dùng vừa cuộn tay (bắt buộc, tránh giật).
4. **229**: kiểm tra `setSpeechRate` có được truyền xuống engine thật không (mỗi engine một thang: Sherpa/Piper thường 0.5–2.0), và nhãn UI hiển thị đúng hệ số đang dùng. Viết test cho hàm map tốc độ.

## File chạm (dự kiến)

`lib/features/pdf_reader/**`, `lib/features/web_reader/**`, test `test/pdf_reader/*`, `test/web_reader/*`.

## Nghiệm thu

- [ ] PDF 5 trang: đọc hết không dừng (có log hoặc test cho vòng lặp phát); bấm giữa trang 3 ⇒ đọc từ đó.
- [ ] Karaoke: câu đang đọc được đánh dấu và tự cuộn tới; cuộn tay ⇒ tự cuộn tạm dừng rồi bật lại.
- [ ] Tốc độ 1.5× nhanh hơn rõ rệt so với 1.0×; nhãn web reader đúng (test cho hàm map).
- [ ] `flutter analyze` 0 error; `app_analyze` + `listen_queue_tests` xanh.

## Không làm

- Không đổi OCR, không đổi bộ chọn engine/giọng (L3).
- Không đổi định dạng lưu highlight/ghi chú.

## Commit

```
fix(PSRC-231): đọc hết tài liệu và cho chọn chỗ bắt đầu [L10]
feat(PSRC-232): karaoke + tự cuộn khi đọc web/PDF [L10]
fix(PSRC-229): áp đúng tốc độ đọc và sửa nhãn tốc độ [L10]
```

## Phát hiện thêm

_(trống)_
