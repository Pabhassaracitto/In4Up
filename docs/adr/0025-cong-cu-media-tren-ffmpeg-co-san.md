# ADR-0025 — Công cụ media (chuyển đổi · cắt · tách · nối) trên FFmpeg CÓ SẴN, không thêm thư viện

- **Trạng thái:** 📋 proposed (chưa code). Chờ owner duyệt 4 câu hỏi ở
  [PLAN-046 §12](../plans/PLAN-046-cong-cu-am-thanh-video.md).
- **Nguồn:** người sở hữu (2026-11-06) gửi 2 câu trả lời của AI khác
  (Gemini) khuyên dùng `ffmpeg_kit_flutter_full` cho MP4/M4A→MP3 và
  cắt/tách/nối audio, yêu cầu khảo sát repo và lên kế hoạch tích hợp.
- **Bối cảnh kỹ thuật:** xem `docs/plans/PLAN-046-cong-cu-am-thanh-video.md` §1.

## Bối cảnh

App **đã có** FFmpeg ở dạng plugin mobile:
`ffmpeg_kit_flutter_new: ^4.6.2` khai báo trong `packages/in4up_stt/pubspec.yaml`,
Android kéo `com.antonkarpenko:ffmpeg-kit-full-gpl:2.2.3` (có `libmp3lame`, `aac`,
`opus`, `vorbis`). Trên desktop, plugin bị **loại khỏi build Windows** bằng patch
CMake (`windows/CMakeLists.txt:151-204`) và FFmpeg được gọi qua
`Process.run('ffmpeg')` (`packages/in4up_stt/lib/utils/src/ffmpeg_process_impl.dart`).

Tức là câu hỏi thật **không phải** "có nên thêm FFmpeg vào Flutter?" mà là
**"làm sao dùng FFmpeg đang có cho mục đích người dùng mà không phá luồng STT"**.

Ba lực đẩy:

1. Người dùng có nhu cầu thật: MP4/M4A → MP3, cắt đoạn, tách chương, nối file.
2. `AudioConverter` hiện tại phục vụ **STT**, không phục vụ tai người: nó ép
   `-ar 16000 -ac 1 -c:a pcm_s16le` cho mọi đầu ra. Dùng lại cho export sẽ ra
   file chất lượng thoại 16 kHz — không chấp nhận được cho bản xuất chia sẻ.
3. Đường gọi hiện tại **không huỷ được** và **không có tiến trình**
   (`ffmpeg_kit_impl.dart:13-26`: ghép chuỗi lệnh, không giữ `FFmpegSession`,
   "giải phóng RAM" bằng `Future.delayed(50ms)`). Với tác vụ 90 phút, đây là
   nguồn OOM/tắc UI.

## Quyết định

### D1 — Không thêm dependency; mở rộng hạ tầng có sẵn

- **Không** thêm `ffmpeg_kit_flutter_full` (Gemini đề xuất): gói của `arthenica`
  **đã archive** (repo `arthenica/ffmpeg-kit`, `archived = true`, cập nhật cuối
  2026-07); repo này đã đi theo fork `sk3llo/ffmpeg_kit_flutter` (tên pub là
  `ffmpeg_kit_flutter_new`). Thêm gói cũ ⇒ trùng native library + `pub get` hỏng.
- **Không** đổi sang `ffmpeg_kit_flutter_new_audio` ngay: bản `audio` vẫn có
  `libmp3lame` nhưng **mất video codec** ⇒ chức năng "cắt đoạn video" không chạy.
  Đo dung lượng ở P4 rồi mới quyết (ADR mới nếu tách).
- Nếu cần API `ffprobe`/`MediaInformation`: fork đã có sẵn
  `ffprobe_kit.dart` / `media_information.dart` ⇒ chỉ dùng, không viết lại.

### D2 — Một lớp `media_tools` mới, tách 4 tầng, logic THUẦN ở tầng đáy

Bộ dựng lệnh trả `List<String>` (không phải chuỗi) và là hàm thuần. Hệ quả:
(a) hết lỗi escaping tên file có `'`/`"` — lỗi có thật trong `quotePath()`;
(b) CI `app_analyze.yml` test được từng lệnh mà không cần thiết bị;
(c) desktop/mobile dùng **cùng** một bộ lệnh.

### D3 — Vòng đời tác vụ hạng nhất: huỷ · tiến trình · dung lượng · dọn dẹp

- Mobile: `FFmpegKit.executeWithArgumentsAsync` + giữ `FFmpegSession` ⇒ `cancel()`;
  kết thúc gọi `FFmpegKitConfig.clearSessions()`.
- Desktop: `Process.start` + `-progress pipe:2` ⇒ tiến trình + `kill()`.
- Trước khi chạy: `probeFreeSpaceMB(thư mục đích)` (đã có ở
  `packages/in4up_stt/lib/utils/free_space.dart`) so với ước lượng × 1.5.
- Thêm `HeavyTaskKind.mediaExport` để `HeavyTaskWarningBanner` cảnh báo khi export
  chạy song song Whisper/dịch offline.
- **Không bao giờ** đọc cả file vào RAM.

### D4 — Export là "nguồn học tập", không phải file rời

Mọi kết quả đi qua: `AudioImportService.ensurePersistent` (path bền vững) →
`SourceArtifactStore.rememberLrc` (LRC đã **dịch mốc** bằng hàm thuần) →
`RecentAudioService.addOrUpdate` → (tuỳ chọn) `SoundlistProvider`.
Nhờ vậy clip xuất ra **mở lại đúng vị trí, còn karaoke, lặp A–B được** —
đây là điểm khác biệt so với app chuyển đổi thông thường.

### D5 — UI theo ngữ cảnh, một widget dùng chung

Sáu lối vào (tab Nghe A–B, menu file tab Nghe, Âm mục/chương, Video, YouTube,
Web Reader) đều mở **cùng** `MediaExportSheet`; tham số quyết định phạm vi và
tên gợi ý. Không làm tab "Media" riêng, không làm trang chủ "Converter".

### D6 — Nói thật về nền tảng

Windows/Linux **cần** `ffmpeg` bên ngoài; repo hiện **không** kèm `ffmpeg.exe`.
UI phải hiện trạng thái + nút "Chọn ffmpeg.exe", không được crash và không được
giả vờ "đã xong". Web ẩn toàn bộ. iOS được kiểm lần đầu ở P2/P3.

### D7 — `-c copy` không phải mặc định

Cắt/nối dùng `-c copy` **chỉ khi** đã kiểm tương thích codec/sample-rate/channels
và chấp nhận dung sai frame; đoạn A–B để **học phát âm** thì re-encode để đúng ms.
Đây là chỗ câu trả lời Gemini sai ("hoạt động hoàn hảo với cả mp3, m4a, wav").

## Hệ quả

**Tích cực:** 0 MB tăng dung lượng; 1 lớp test được; 6 bề mặt dùng chung; clip
xuất giữ karaoke; cả luồng STT hiện tại được hưởng lợi từ P0 (huỷ được, hết
`Future.delayed` giả lập).

**Tiêu cực / phải trả giá:** P0 chạm đường STT đang chạy ⇒ rủi ro hồi quy, cần
PR riêng + QA máy; trạng thái "có/không FFmpeg" khác nhau theo nền tảng phải nói
rõ trong UI; ~28 chuỗi i18n mới; Windows thiếu exe là khiếm khuyết có sẵn, không
phải do ADR này.

**Không đụng:** `lib/ffi/**` (UltraTimeStretch), 3 skill SM-2, schema
`Evidence`/`PdfFileIdentity`, `AudioSource` enum (không migration).

## Phương án đã cân nhắc và loại

| Phương án | Lý do loại |
|---|---|
| Thêm `ffmpeg_kit_flutter_full` (Gemini) | Gói của arThenica đã archive; trùng native lib với fork đang dùng |
| Chuyển ngay sang `ffmpeg_kit_flutter_new_audio` | Mất video codec ⇒ hỏng "cắt đoạn video"; cần đo dung lượng trước |
| Dùng lại `AudioConverter` cho export | Ép 16 kHz mono PCM ⇒ chất lượng không dùng được cho bản chia sẻ |
| Viết native Kotlin/Swift riêng | Trùng lặp với FFmpegKit đang có; 4 nền tảng × 2 ngôn ngữ |
| Làm server/API chuyển đổi | Trái nguyên tắc offline-first (ADR-0008 chỉ cho AI/TTS qua API) |
| Trang "Converter" riêng ở Home | Loãng app; người dùng đã có app chuyển đổi ngoài; giá trị In4Up nằm ở vòng lặp học |
