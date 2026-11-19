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

## Báo cáo thực thi L10 — 2026-11-13

Nhánh: `arena/f25f2694-in4up`, rebase từ tip `origin/arena/60e35d65-in4up`; không merge, không đổi version, OCR hay engine/giọng.

### Thay đổi và máy bắt

| Issue | Nguyên nhân → sửa | Bằng chứng tự động |
|---|---|---|
| PSRC-231 | Web gửi đoạn không giới hạn, chưa có guard phiên/cue; PDF coi trang trắng là EOF; vùng chọn chỉ đọc rời. Giới hạn request web ở 400 UTF-16 units, giữ offset, chống callback phiên cũ; PDF bỏ qua trang trắng khi bật đọc tiếp. Đọc từ cue chứa vùng chọn, giữ offset DOM web (kể cả câu lặp); Text Mode PDF đổi offset toàn văn bản về trang/offset cục bộ, không tìm lần xuất hiện đầu. | `reader_cues_test.dart`: 500 câu/5000 ký tự; `pdf_reading_pages_test.dart`: 5 trang có trang trắng, hủy trong extraction, bắt đầu trang 3, offset câu lặp trong Text Mode; `reader_selection_dom_test.cjs`: vùng chọn ở lần xuất hiện thứ hai, bỏ header/script. |
| PSRC-232 | Callback câu chưa nối vào viewport web; PDF chỉ lật trang, không reveal câu trong trang. Tô theo callback câu thật (không giả vờ timing từng từ); Range overlay web không thay DOM gốc; PDF reveal rect chỉ khi ngoài viewport. Karaoke/follow bật mặc định, có nút/menu tắt riêng; gesture tay khóa follow 5 giây. | `reader_follow_policy_test.dart`: viewport/5 giây/tắt follow; `reader_follow_dom_test.cjs`: câu lặp, chỉ cuộn ngoài viewport, wheel override, bật/tắt độc lập, cleanup khi stop, DOM gốc không đổi. |
| PSRC-229 | `configure` chỉ đổi cấu hình, không đổi nguồn âm đang phát; nhãn web chỉ rebuild theo Play/Pause và làm tròn quarter-step. Nghe tốc độ từ service (cả setting ngoài), debounce restart cue hiện tại để engine nhận tốc độ mới; đang pause thì áp khi resume. Giữ multiplier trực tiếp, không map engine lần thứ hai; nhãn giữ 1.25x và cycle preset chính xác. | `reader_speed_test.dart`: identity multiplier 1.5, clamp/non-finite, nhãn 1.25/1.5, cycle đến 1.5 đúng. |

Các test Flutter và hai test DOM được gắn vào step **Agent F** có sẵn trong `app_analyze.yml`. Bổ sung reader paths cho `listen_queue_tests.yml` để tự chạy khi push; dispatch thủ công bị GitHub trả 403. Hai chuỗi UI mới được append vào priority pack đủ 8 locale; generator `--check` xanh.

### CI và giới hạn kiểm chứng

- Tree code được kiểm: commit `6a8d2c199a144c4d67859537553ff83e254d542b` (ba commit issue, đúng thứ tự 231 → 232 → 229).
- `listen_queue_tests`: **xanh**, run [43491408229](https://github.com/Pabhassaracitto/In4Up/actions/runs/43491408229).
- `app_analyze`: **xanh**, run [43491408093](https://github.com/Pabhassaracitto/In4Up/actions/runs/43491408093): analyze toàn app không có error, Agent F (gồm các test mới) xanh, locale/Rule 5 và web-build-validation xanh. Revision trước cũng xanh ở run 43490140196; kết quả nghiệm thu là run bản cuối 43491408093.
- Sandbox không có Flutter/Dart SDK: không tuyên bố đã chạy `flutter analyze` cục bộ. Chạy được hai test DOM Node/jsdom và generator pack cục bộ; Flutter analyze/tests chạy ở CI.
- Tái hiện trước sửa: đối chiếu được nhánh `return` ở trang trắng, request web nguyên đoạn, đường vùng chọn chỉ gọi `speakText`, và điều kiện rebuild nhãn. **Chưa tái hiện trực tiếp trên app/máy thật** vì sandbox không có thiết bị/Flutter.
- **Chưa kiểm máy thật:** PDF thực 5 trang (đặc biệt scan xen kẽ), chọn giữa trang 3, PDF zoom/rect và Text Mode; WebView Android/Windows trên trang động/iframe; pause/resume và Stop trong lúc đổi tốc độ; app chuyển nền/khóa màn hình; nghe/đo thời lượng 1.0x so với 1.5x trên từng engine. CI không chứng minh được các mục native/âm thanh này.

## Phát hiện thêm

Không sửa file của lane khác. Phần i18n pack và workflow là file chung, hub cần giữ các mục append/test path khi land. Không thay bộ chia câu chung của L3.
