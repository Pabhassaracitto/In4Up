# L1 — Live cabin

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2.
**Nhánh:** tạo từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Live cabin (dịch trực tiếp) phải: sửa/xoá được nội dung đã hiện, chuyển đúng chiều chủ→đích khi đổi sang tài liệu đọc, có tuỳ chọn đồng bộ **cả phiên** sang Đọc/Nghe/Hiểu (kể cả phiên đã lưu), và không chết sau dòng dịch đầu khi chạy offline Sherpa.

## Issue

Link: `https://linear.app/in4up/issue/PSRC-<số>`

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-199** | Không sửa/xoá được nội dung đã hiện trong cabin |
| **PSRC-200** | Chọn chủ→đích sai khi chuyển sang tài liệu đọc |
| **PSRC-201** | Thiếu tuỳ chọn đồng bộ phiên sang Đọc/Nghe/Hiểu (cả phiên đã lưu) |
| **PSRC-223** | Cabin **offline** (Sherpa) dừng sau dòng dịch đầu tiên |

Đợt 2 (cùng khu vực): **PSRC-196** — trùng PSRC-199; đóng as duplicate khi 199 xong.

## Hướng điều tra

Vùng code: `lib/features/cabin/**` — `live_cabin_screen`, `cabin_session_store`, `stts_cabin_service`, `cabin_read_bridge`; đích đồng bộ ở `lib/screens/{read_mode,listen_mode,text_library}/**`.

1. **199**: item đang hiện có `id` ổn định và có bản ghi bền trong `cabin_session_store` chưa? Nếu panel chỉ giữ widget/text thì thao tác xoá không có chỗ bám. Cần `id` + API sửa/xoá ở store, rồi panel nghe store.
2. **200**: chiều truyền khi `source == target`, và việc reset buffer lúc đổi chiều. Tìm `direction`, `swap`, `reverse`, `source`. Kiểm tra `cabin_read_bridge` map đúng "chủ" và "đích" sang tài liệu đọc.
3. **201**: đồng bộ phiên = chép **toàn bộ** các dòng (kể cả phiên đã lưu) sang màn hình đích theo định dạng của nó; phải chịu được phiên dài (chia trang, không nạp một lần).
4. **223**: nghi vấn vòng lặp async không restart sau chunk đầu, hoặc engine bị `dispose` sau dòng đầu. Kiểm tra `await` trong vòng lặp + xử lý `continuous`. **Lưu ý:** engine VieNeu thuộc L6 — chỉ sửa phía cabin.

## File chạm (dự kiến)

`lib/features/cabin/**`, `lib/screens/listen_mode/**` (chỉ phần nhận phiên), test `test/cabin/*`.

## Nghiệm thu

- [ ] Xoá một dòng đã hiện ⇒ không quay lại sau rebuild; sửa được nội dung dòng.
- [ ] Chuyển cabin → tài liệu đọc: đúng chiều chủ→đích (có test chọn chiều).
- [ ] Đồng bộ phiên 50 dòng sang Đọc/Nghe/Hiểu: đủ 50, không treo UI.
- [ ] Cabin offline Sherpa 3 câu liên tiếp: dòng 2 và 3 vẫn hiện và được đọc.
- [ ] `flutter analyze` 0 error; `app_analyze` + `listen_queue_tests` xanh.

## Không làm

- Không thiết kế lại UI cabin.
- Không sửa engine TTS (L6).

## Commit

```
fix(PSRC-199): sửa/xoá nội dung đã hiện trong cabin [L1]
fix(PSRC-200): đúng chiều chủ→đích khi chuyển sang tài liệu đọc [L1]
feat(PSRC-201): đồng bộ cả phiên cabin sang Đọc/Nghe/Hiểu [L1]
fix(PSRC-223): cabin offline Sherpa không dừng sau dòng đầu [L1]
```

## Phát hiện thêm

_(trống)_
