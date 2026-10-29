# I4U18-DOCS-001 — Checklist QA thủ công liên lane

> Dành cho owner nghiệm thu trên thiết bị · Cập nhật 2026-09-30
>
> Guide thao tác: [`USER_GUIDE.vi.md`](USER_GUIDE.vi.md). Đánh dấu `Pass`,
> `Fail`, `Blocked` hoặc `N/A`; với Fail ghi build, thiết bị, bước, thông báo và
> bằng chứng đã che dữ liệu nhạy cảm.

## A. Ma trận thiết bị và chuẩn bị

| Trường | Thiết bị 1 | Thiết bị 2 (nếu có) |
|---|---|---|
| Build/commit |  |  |
| OS + phiên bản |  |  |
| Model máy/RAM |  |  |
| Locale app | `vi` | `en` hoặc locale ≠ vi |
| Mạng | Wi-Fi + offline | Wi-Fi/LAN |
| Dung lượng trống trước test |  |  |

Fixture nhỏ, hợp pháp:

- [ ] Piper: một voice `.onnx` + `.onnx.json`, và bundle có
  `espeak-ng-data/phontab`.
- [ ] Whisper: một `ggml-*.bin` hợp lệ.
- [ ] Zipformer: `tokens.txt` + encoder + decoder + joiner của đúng profile.
- [ ] API cloud key hạn mức thấp; Ollama/LM Studio trên máy cùng LAN.
- [ ] Một MDX nhỏ đã biết số entry; nếu có, MDD/CSS cùng basename để kiểm giới
  hạn tài nguyên.
- [ ] Pack Tipiṭaka Pāli Roman + một pack bản dịch.
- [ ] 3 audio, 2 video (một MP4 H.264/AAC), PDF text-layer, PDF scan và ảnh
  trang sách Latin/Pāḷi.
- [ ] Chụp dung lượng app trước test; không thêm fixture/model vào Git.

## B. Model offline

### B1. Piper/eSpeak

- [ ] Import thư mục bundle → voice xuất hiện, badge/trạng thái sẵn sàng.
- [ ] Import nhiều file (`onnx/json/txt`) qua picker → không báo thành công giả.
- [ ] `espeak-ng-data` hiện đã cài; thiếu `phontab` cho lỗi rõ, không crash.
- [ ] Chọn voice, bật Piper ưu tiên, đọc câu đúng ngôn ngữ khi tắt mạng.
- [ ] Xóa/đổi tên một file trong fixture lỗi → app từ chối hoặc fallback giọng hệ
  thống, không sập.
- [ ] Hủy tải giữa chừng → UI thoát progress; tải/import lại thành công.

### B2. Whisper/Zipformer

- [ ] Import Whisper → tạo LRC offline từ audio ngắn; timestamp tăng dần.
- [ ] `auto` và một ngôn ngữ chỉ định cho transcript hợp lý.
- [ ] Zipformer VI đủ bốn nhóm file → Cabin nhận mic khi offline.
- [ ] Zipformer EN streaming chạy Cabin; không bị dùng nhầm cho file/LRC.
- [ ] Chọn thiếu tokens/joiner hoặc sai profile → thông báo cụ thể, không
  SIGABRT/crash native.
- [ ] Thu hồi quyền mic → hướng dẫn cấp quyền hoặc lỗi rõ.

## C. Server/API/BYOK/local server

- [ ] Thêm cloud provider, field key che mặc định; key không hiện trong snackbar,
  debug log hoặc ảnh trạng thái.
- [ ] Kiểm tra kết nối + tải `/v1/models` + chọn model + lưu qua restart app.
- [ ] Chat/API tương ứng hoạt động; tắt provider thì không tiếp tục request.
- [ ] **Chỉ offline**: theo dõi server và xác nhận 0 request cho capability đó.
- [ ] **Ưu tiên online**: server nhận request trước; cắt mạng thì dừng/fallback rõ.
- [ ] **Ưu tiên offline**: model local được dùng trước khi server dự phòng.
- [ ] Ollama/LM Studio bằng IP LAN từ điện thoại hoạt động.
- [ ] `localhost` trên điện thoại thất bại có kiểm soát; HTTP public bị chặn,
  HTTP private LAN được phép.
- [ ] Key sai → 401/unauthorized; cổng sai → timeout/no-network; không spinner vô
  hạn.
- [ ] Xóa provider → routing không giữ tham chiếu chết.

## D. Từ điển MDX/MDD/CSS

- [ ] Import MDX → card hiện tên, entry count > 0, mặc định bật.
- [ ] Tap từ có trong MDX ở Read mode → nghĩa xuất hiện offline.
- [ ] Lưu từ → meaning/IPA từ MDX được điền khi dữ liệu có sẵn.
- [ ] Tắt từ điển → lookup không trả kết quả từ nguồn đó; bật lại khôi phục.
- [ ] Xóa từ điển → DB biến mất khỏi danh sách, app mở lại không có manifest
  chết.
- [ ] MDX hỏng/không hỗ trợ → lỗi rõ, không crash, không để card 0 entry giả.
- [ ] Xác nhận giới hạn bản hiện tại: picker không nhận MDD/CSS rời; không ghi
  Pass cho audio/image/style nếu chưa có UI link thật.
- [ ] Nếu build đã bổ sung link MDD/CSS: ảnh/audio/CSS render sau restart, đường
  dẫn tương đối không thoát resource directory, thiếu resource chỉ degrade.

## E. Tipiṭaka/Pāli

- [ ] Import Pāli Roman `.db/.sqlite/.zip` → DB ready, số tạng/sách/đoạn > 0.
- [ ] Import một bản dịch sau Pāli → reader song ngữ ghép đúng đoạn.
- [ ] Tải pack Pa-Auk có progress; hủy/mất mạng không cài DB nửa vời.
- [ ] Tìm một từ Pāli có dấu → kết quả mở đúng sách/đoạn.
- [ ] Restart app → pack vẫn sẵn sàng.
- [ ] Import bản dịch trước Pāli → hướng dẫn/failure rõ; cài Pāli rồi phục hồi.
- [ ] ZIP hỏng hoặc không có SQLite → báo lỗi, DB đang dùng vẫn nguyên vẹn.

## F. Audio/video library

### F1. Audio

- [ ] Lần đầu xin đúng quyền Audio/Music; từ chối quyền có màn giải thích.
- [ ] Quét MediaStore → 3 fixture xuất hiện; kéo refresh không tạo bản trùng.
- [ ] Tìm theo title/artist → lọc đúng; xóa query trả đủ danh sách.
- [ ] Chạm `content://` → phát được, mini-player cập nhật và Recent ghi nhận.
- [ ] Chọn nhiều file → bài đầu tự phát, playlist đủ số bài, chạm đổi bài được.
- [ ] Restart/để hệ thống dọn cache → audio đã import vào vùng bền vẫn mở được.
- [ ] Xóa danh sách playlist không xóa file gốc.

### F2. Video

- [ ] Thêm MP4 → card title/duration đúng, phát/pause/seek được.
- [ ] Thêm container được cho phép nhưng codec không hỗ trợ → lỗi rõ, không màn
  đen vô hạn.
- [ ] Restart → danh sách video còn và file còn phát được.
- [ ] Xác nhận giới hạn: bản hiện tại chưa có scan/filter/playlist video; chỉ
  nghiệm thu các mục đó khi có control thật trong build.

## G. PDF/OCR/TTS/IPA

- [ ] PDF text-layer: mở, search, chọn chữ, chuyển trang và reopen vị trí đúng.
- [ ] TTS đọc theo câu, pause/resume, đổi tốc độ/ngôn ngữ, tự sang trang.
- [ ] PDF scan: TTS nhận ra không có text và hiện **Quét chữ trang này**.
- [ ] OCR trang PDF → preview cho sửa → nạp text; không ghi đè PDF gốc.
- [ ] Android Document Scanner tự crop nhiều trang; iOS chọn ảnh có sẵn; desktop
  không hiện flow OCR không khả dụng.
- [ ] Ảnh mờ/không chữ → empty/error có hành động thử lại, không crash.
- [ ] Pāḷi Roman: kiểm thủ công dấu `ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ`; lỗi OCR có thể sửa
  trước khi nạp.
- [ ] IPA cycle đúng `Tắt → Dòng hiện tại → Toàn văn`; không chồng text/overflow.
- [ ] Panel màu IPA bật/tắt từng nhóm; chạm word-chip phát âm.
- [ ] Từ có IPA trong MDX hiện provenance MDX; từ không dữ liệu degrade hợp lý.
- [ ] Piper thiếu/hỏng trong lúc PDF TTS → fallback/lỗi rõ, không crash.

## H. QA liên lane và i18n

- [ ] Chuỗi liên hoàn: MDX import → mở PDF → tap từ → lưu meaning/IPA → TTS từ.
- [ ] Chuỗi liên hoàn: OCR ảnh → sửa text → IPA → TTS offline.
- [ ] Chuỗi liên hoàn: Tipiṭaka Pāli → đọc song ngữ → chọn/lưu từ → tra MDX.
- [ ] Chuỗi liên hoàn: audio scan → tạo LRC Whisper → mở transcript trong Đọc →
  IPA/TTS.
- [ ] Chuyển locale `en`: toàn bộ chrome của các màn test không còn tiếng Việt;
  nội dung Pāli/Việt do user import vẫn giữ nguyên.
- [ ] Chuyển thêm một locale chưa phủ hết (ví dụ `ja`/`bn`): fallback là English,
  không phải Vietnamese.
- [ ] Font scale 1.3–1.5 và màn hẹp: nút import/progress/dialog không overflow.
- [ ] Back/đóng picker/hủy dialog ở mọi luồng không làm mất dữ liệu đã cài.
- [ ] Offline sau khi import: model, MDX, Tipiṭaka, media local và PDF vẫn dùng
  được; chỉ cloud/API/download bị chặn có giải thích.

## I. Kết quả nghiệm thu

| Nhóm | Pass | Fail | Blocked/N/A | Ghi chú/issue |
|---|---:|---:|---:|---|
| Model offline |  |  |  |  |
| Server/API |  |  |  |  |
| Dictionary |  |  |  |  |
| Tipiṭaka |  |  |  |  |
| Audio/video |  |  |  |  |
| PDF/OCR/TTS/IPA |  |  |  |  |
| i18n/liên lane |  |  |  |  |

Quyết định owner: **[ ] Accept · [ ] Accept có lỗi theo dõi · [ ] Reject**

Người nghiệm thu: __________  Ngày: __________  Build: __________
