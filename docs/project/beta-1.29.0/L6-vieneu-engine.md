# L6 — VieNeu / Vieu-TTS

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2 + § 2.2.
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

VieNeu-TTS phải **chạy thật** trên máy thật arm64 — không phải "fail gracefully": import được model, khởi tạo được engine, import và tạo được giọng, và mục import nằm đúng vị trí UI.

> **Hub đã làm, đừng làm lại:** đường tải/import `sea_g2p.bin` trong app — `lib/features/tts/vieneu_g2p_dictionary.dart`, `packages/in4up_stt/lib/tts/vieneu_tts_paths.dart`, test `test/tts/vieneu_g2p_dictionary_test.dart`, CI step `vieneu-native-contract`. ADR: `docs/adr/0028-*`. **Còn mở:** kiểm máy thật (chủ dự án chạy) + 3 câu hỏi ở ADR-0029 § 6 (thuộc L7).

## Issue

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-214** | Mục import **phía trên** không nhận model |
| **PSRC-215** | Import Q8_0 báo "thành công" nhưng **thiếu engine** |
| **PSRC-216** | Không khởi tạo được engine |
| **PSRC-217** | Import giọng lỗi |
| **PSRC-218** | Tạo giọng từ mẫu báo lỗi |

## Thứ tự làm (bắt buộc)

**214 → 215 → 216 → 217 → 218.** 214/215 là đường nạp model; không sửa được hai cái này thì 216 không có gì để khởi tạo.

## Hướng điều tra

Vùng code: `packages/in4up_stt/lib/tts/vieneu_tts_core.dart` (+ worker isolate), `lib/features/tts/engines/vieneu_tts_engine.dart`, `lib/screens/settings/**` (TTS), `native/tts_vieneu/**` + CMake.

1. **214**: hai lối import (mục trên vs mục dưới) có thể gọi hai hàm khác nhau — so sánh chúng; cái trên có thể chưa validate/đăng ký file vào danh sách model.
2. **215**: "thành công" chỉ nghĩa là file đã copy, chưa kiểm **engine sẵn sàng**. Cần: sau khi import, chạy bước self-check (nạp GGUF + `sea_g2p.bin`) và chỉ báo thành công khi qua; nếu thiếu `sea_g2p.bin` thì thông báo nêu **tên file** + nút tải.
3. **216**: đường khởi tạo cần 3 thứ cùng thư mục: GGUF + `sea_g2p.bin` + config (`vieneu_v3_turbo.json`). Thiếu `sea_g2p.bin` ⇒ `text_frontend` **throw** (đã biết). Kiểm tra thứ tự: xác thực file → khởi tạo native → trạng thái "sẵn sàng" (một hàm `probe()` thay vì try/catch rải rác).
4. **217/218**: voice-clone cần mẫu wav 16k mono; kiểm tra resample, copy mẫu vào thư mục app-private (ADR-0029), và ghi metadata giọng để lần sau hiện trong danh sách. Ghi lỗi native nguyên văn vào log/issue.
5. Không chạm `third_party/sea-g2p`, `third_party/audio.cpp` — submodule chưa checkout trong sandbox, **đừng** "khôi phục".

## File chạm (dự kiến)

`packages/in4up_stt/lib/tts/**`, `lib/features/tts/**`, `native/tts_vieneu/**` + `android/vieneu/**` (chỉ khi buộc phải sửa native), test `test/tts/*`.

## Nghiệm thu

- [ ] Cả **hai** lối import đều nhận model Q8_0 (test đơn vị cho bước validate).
- [ ] Import xong ⇒ trạng thái "engine sẵn sàng"; thiếu `sea_g2p.bin` ⇒ báo tên file + nút tải, **không** báo thành công.
- [ ] Khởi tạo engine ⇒ đọc được một câu tiếng Việt trên máy thật arm64.
- [ ] Import giọng có sẵn + tạo giọng từ mẫu ⇒ giọng mới dùng được ngay và sống qua lần mở app sau.
- [ ] `app_analyze` xanh **và** `vieneu_engine_build` xanh (APK arm64 + 3 `.so`).
- [ ] Ghi rõ phần **chưa kiểm trên máy thật**.

## Không làm

- Không đổi định dạng file model, không tải model từ nguồn ngoài `pnnbao97/vieneu` (ADR-0028).
- Không thiết kế lại UI cài đặt TTS — chỉ đổi vị trí/thứ tự nếu Linear yêu cầu.

## Commit

```
fix(PSRC-214): mục import phía trên nhận model VieNeu [L6]
fix(PSRC-215): import Q8_0 chỉ báo thành công khi engine sẵn sàng [L6]
fix(PSRC-216): khởi tạo engine VieNeu báo rõ file thiếu [L6]
fix(PSRC-217): import giọng cho VieNeu [L6]
fix(PSRC-218): tạo giọng từ mẫu với VieNeu [L6]
```

## Phát hiện thêm

_(trống)_
