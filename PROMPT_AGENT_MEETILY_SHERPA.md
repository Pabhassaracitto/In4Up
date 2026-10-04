# Prompt giao việc — Sherpa/Meetily: Stream dịch cabin + Sóng âm màu người nói + Ra lệnh bằng voice

> Giao cho: **agent Arena trên nhánh topic mới** (branch từ `origin/arena/01a0251e-in4up`)
> Thu hoạch + nghiệm thu: **agent `arena/01a0251e-in4up`** (nhánh leader 251e) — sau khi bạn báo SHA.
> Người duyệt cuối: owner.
> Ngày giao: 2026-08-25.

## 0. Bối cảnh

Ba mục dang dở từ các nhánh vipsound/sherpa trước đây (PLAN-008, PLAN-009 —
xem `docs/project/PLAN.md`), infrastructure đã có sẵn **nửa đường** trong
`packages/in4up_stt` + `lib/`. Task này là **nối nốt nửa còn lại** — không viết lại
từ đầu, không merge nhánh cũ.

Mỗi work package (WP) là **một milestone độc lập**: 1 phạm vi commit rõ, 1 bộ
AT riêng, harvest riêng. Làm xong WP nào báo SHA WP đó — không gộp.

**Thứ tự đề xuất: WP2 → WP3 → WP1** (WP2 ít rủi ro nhất; WP3 tái dùng mic/STT có
sẵn; WP1 nặng nhất vì phải tải model streaming).

## 1. Sự thật hiện trạng (đã đối chiếu trên tree 251e — đừng tin tưởng, grep lại)

### Đã CÓ (đừng làm lại)

| Hạng mục | File / API | Ghi chú |
|---|---|---|
| Interface STT + live stream | `packages/in4up_stt/lib/stt_engine.dart` | `startListening()`, `liveResultStream` (Stream<SttResult>), `stopListening()` — engine không hỗ trợ thì `Stream.empty()` |
| Sherpa STT engine (PoC đã merge) | `packages/in4up_stt/lib/stt_engine_sherpa.dart` | `SherpaSttEngine` — `OfflineRecognizer` + `OnlineRecognizer` (sherpa_onnx ^1.13.4), `SherpaModelPaths` (encoder/decoder/joiner/tokens) truyền qua `options['sherpaModels']` |
| Facade STT | `packages/in4up_stt/lib/stt_service_facade.dart` | `startListening()`, `partialResultStream`, `progressStream`, `transcribeAuto` (tự chọn model) |
| FFI init 1 lần | `packages/in4up_stt/lib/sherpa_bindings.dart` | `ensureSherpaBindings()` — **idempotent, gọi trước mọi API sherpa**; pointer giữ singleton, tránh xung đột FFI với whisper.cpp |
| VAD Silero | `vad/sherpa_vad_core.dart`, `lib/features/vad/...` | `SherpaVadService` singleton; model: `<documents>/sherpa_vad_models/silero_vad.onnx` (user tự push, không lên GitHub) |
| TTS Piper offline | `tts/sherpa_piper_tts_core.dart`, `lib/features/tts/engines/piper_tts_engine.dart` | `PiperTtsEngine.synthesize({text, voiceId...})` + `getAvailableVoices(language)`; model: `<documents>/sherpa_piper_models/` |
| Bản dịch | `lib/features/translation/translation_service.dart` | `TranslationService.translateText(...)` → `TranslationResult` (có cache `translation_cache.dart`) |
| Diarization Sprint 1 (heuristic) | `packages/in4up_stt/lib/diarization/diarization_service.dart` | `DiarizationService.diarize(SttResult)`; `HeuristicDiarizationService` (silence gap 1.6s + question pattern) — **chạy offline ngay, không cần model** |
| Speaker annotation + sidecar | `diarization/speaker_annotation.dart`, `diarization/speaker_sidecar.dart` | `SpeakerSidecar.save({lrcPath, speakerMap...})`, `loadSpeakerMap(lrcPath)` → `Map<String,int>` (joinKey/uid → speakerId), `getSidecarPath(lrcPath)` |
| Meetily Rust (Sprint 2) — **STUB** | `diarization/diarization_service.dart` (`MeetilyRustDiarizationService`), `meetily/meetily_adapter.dart` | `MeetilyRustDiarizationService(MeetilyBridge)` — bridge chưa có → tự fallback Heuristic. **Hợp đồng Rust Core nằm ở dự án Meetily bên ngoài — KHÔNG chờ nó; làm heuristic trước** |
| Waveform đa màu speaker | `lib/screens/listen_mode/widgets/rolling_waveform_painter.dart` + `rolling_waveform_view.dart` | `kSpeakerColors` (Map<int,Color>), tham số `speakerColorMap` + `data.segments` — **painter đã vẽ được, chỉ chờ được cấp dữ liệu** |
| LRC + transcript | `lib/services/sound_auto_toc_service.dart`, `providers/soundlist_provider.dart` | `transcriptFromLrcLines`, `SoundTranscript`, LRC lưu tại `documents/.in4up_lrc/` |
| Quyền mic | `AndroidManifest` `RECORD_AUDIO` | đã có |

### THIẾU (phạm vi task này)

1. **WP1**: không có `SherpaSttStreamingService` singleton (giữ `OnlineRecognizer`
   giữa các phiên), không có dịch vụ STS cabin (STT→translation→TTS stream),
   không có UI live caption, không có download model Zipformer streaming.
2. **WP2**: **không có code nào gọi `diarize()`**, không ai ghi/đọc sidecar trong
   luồng app, `RollingWaveformView` trong `listen_mode_screen.dart` +
   `understand_mode_screen.dart` được tạo **không** có `speakerColorMap` →
   sóng âm chưa bao giờ có màu.
3. **WP3**: không có gì (item mới).

## 2. Quy tắc làm việc (bắt buộc)

1. **Branch:** tạo nhánh topic từ `origin/arena/01a0251e-in4up` (fetch mới nhất
   TRƯỚC khi bắt đầu — tip có thể đã tiến). Commit nhỏ, **push ngay mỗi commit
   xanh được** (push = backup; sandbox có thể tái bản giữa phiên — bẫy 5.5 skill
   `docs/skills/ci-red-debugging/SKILL.md`).
2. **CI là oracle duy nhất** — log CI không đọc được từ môi trường agent
   (blob bị chặn). Khi đỏ: đọc SKILL.md, bisect theo đúng giao thức, mỗi vòng
   1 biến số, commit bisect phải tự compile được + chạm path trong
   `paths:` của workflow (chỉ chạm `packages/` là KHÔNG trigger app_analyze —
   bẫy 5.7). Bài học vừa rồi: 3 lỗi compile (nullable completer, `File.openRead()`
   trả `Stream` chứ không phải `RandomAccessFile`, trùng tên biến local) đều chỉ
   lộ qua oracle. **Kiểm tra API `dart:io`/`dart:async` đúng docs trước khi push.**
3. **Không** tạo/sửa file trong `.github/workflows/` (token không có quyền
   `workflows` — push chứa file đó bị reject cả commit).
4. `docs/` nằm trong `.gitignore` — file docs phải `git add -f`.
5. Không merge nhánh khác vào nhánh của bạn trong khi làm; không force-push
   nhánh 251e; không chạm `packages/vipsound_ai|vipsound_core` (đã exclude
   khỏi analyze nhưng code còn đó).
6. Giữ API hiện có tương thích (facade/painter/engine đã có caller trong app).
   Thêm thì thêm; đổi signature cũ thì phải sửa hết caller trong cùng commit.
7. Mỗi WP: code + test (nếu logic thuần) + 1 commit KANBAN cuối (card mới hoặc
   dòng lịch sử) — card ghi rõ: nguồn, nội dung, bằng chứng (run CI), trạng thái.

## 3. WP2 — Sóng âm màu theo người nói (distinguishing speakers by waveform color)

**Mục tiêu:** sau khi một file audio đã có LRC/transcript, waveform ở tab Nghe
(tab Hiểu tương tự) hiển thị **vùng màu theo người nói** (màu từ `kSpeakerColors`),
kèm legend nhỏ (Người 1 = màu A, Người 2 = màu B…).

**Bước làm:**
1. Trong luồng tạo LRC (sau `transcriptFromLrcLines`/lưu `SoundTranscript` — xem
   `providers/soundlist_provider.dart`) gọi `HeuristicDiarizationService().diarize(sttResult)`
   và `SpeakerSidecar.save(lrcPath: ...)` (sidecar nằm cạnh LRC,
   `getSidecarPath`). Diarize phải có `SttResult` với segments có `uid` +
   `joinKey` — đối chiếu `stt_result.dart`; nếu transcript LRC không có uid thì
   sinh uid chuẩn `startMs|textNorm` (xem comment trong `waveform_data.dart`).
2. Khi mở file audio (load LRC cache — luồng `peekCachedLrc`/autoLoad trong
   `listen_mode_screen.dart`): `SpeakerSidecar.loadSpeakerMap(lrcPath)` →
   giữ `Map<String,int>` trong provider có sẵn (WaveformProvider hoặc
   ListenState — chọn nơi ít đụng code nhất) → truyền vào
   `RollingWaveformView(speakerColorMap: ...)`.
3. `waveform_data.dart` đã có `segments` (null = file cũ chưa diarize —
   backward compatible, painter tự skip nếu `speakerColorMap.isEmpty`).
   Đảm bảo segments của file đã diarize được đưa vào `WaveformData.segments`.
4. Legend: widget nhỏ 1 dòng (chấm màu + "Người 1/2/3") đặt gần waveform
   (chỉ hiện khi có map).
5. **Không** implement Meetily Rust trong WP này — chỉ đảm bảo code gọi qua
   interface `DiarizationService` (đổi implementation sau này không sửa caller).

**AT WP2:**
- File LRC 2 người nói (tự tạo fixture: segments xen kẽ + khoảng lặng >1.6s)
  → sau mở file, waveform có ≥2 vùng màu khác nhau + legend 2 màu. (Test
  widget hoặc nghiệm thu thiết bị — ghi lại trong KANBAN.)
- File chưa diarize → sóng màu thường như hiện nay (không lỗi, không crash).
- CI App Analyze + Locale xanh.

## 4. WP3 — Ra lệnh bằng giọng nói (voice command qua STT streaming)

**Mục tiêu:** người dùng nói lệnh (tiếng Việt + English keywords) để điều khiển
app mà không chạm màn hình: phát / tạm dừng / tiếp theo / trước / tăng-giảm tốc
/ hiện-ẩn LRC / dịch… Tái dùng **hết** hạ tầng mic+STT có sẵn — không dựng
pipeline mic song song.

**Bước làm:**
1. `VoiceCommandService` (mới, `lib/features/voice_command/` hoặc đặt cạnh
   `providers/` — chọn 1 nơi, ghi trong KANBAN):
   - Dùng `SttServiceFacade.startListening()` + `partialResultStream`
     (engine sherpa online nếu model có; whisper live nếu có) — engine nào
     trả `Stream.empty()` thì service báo "không hỗ trợ" trung thực, không giả.
   - **Parser lệnh thuần** (pure function, tách riêng file để test được):
     normalize (bỏ dấu chọn lọc, lowercase) → khớp command. Grammar khởi điểm
     (mở rộng được, giữ trong 1 hằng số):
     `phát | chơi | play` → play · `tạm dừng | dừng | pause` → pause ·
     `tiếp theo | next` → next · `bài trước | trước | previous` → previous ·
     `nhanh hơn | tăng tốc | faster` → rate +0.25 · `chậm hơn | giảm tốc | slower` → rate −0.25 ·
     `hiện lời | ẩn lời | lyrics` → toggle LRC · `dịch | translate` → toggle dịch.
   - Chấm dứt phiên lệnh: im lặng ~1.5s hoặc tối đa ~6s.
   - Debounce: chỉ nhận lệnh khi phiên trước đã kết thúc; mỗi lệnh chỉ fire 1 lần
     (trả về command đầu tiên khớp trong phiên).
2. **Executor** tách riêng (map `VoiceCommand → Function(PlayerProvider, ...)`):
   gọi provider có sẵn (`PlayerProvider`, `UnderstandProvider`/`TextProvider`
   cho LRC/dịch) — KHÔNG gọi trực tiếp widget. Mỗi action 1 hàm nhỏ, test được.
3. UI tối giản: nút mic nhỏ ở góc (AppBar hoặc floating) + indicator đang nghe
   (spinner) + preview lệnh cuối ("Đã nhận: 'tạm dừng'"). Không làm screen mới.
4. Model: dùng model STT **đã có** (Whisper tiny/base hoặc sherpa online nếu
   user đã tải) — nếu chưa có model, nút mic hiện trạng thái "chưa có model STT"
   + dẫn tới Cài đặt → Quản lý Model (không tự auto-download — rule đã chốt
   trong repo).
5. **Test:** parser lệnh (pure) — table test đủ 8 lệnh trên + tiếng Việt có dấu
  + sai lệch nhẹ ("tam dung", "tai tiep").

**AT WP3:**
- Parser: test xanh, 100% lệnh mẫu + 3 dạng sai lệch.
- Thiết bị: bật mic → nói "tạm dừng" → player pause; "nhanh hơn" → tốc độ +0.25.
- Không model STT: UI báo trung thực (không crash, không im lặng).
- CI xanh.

## 5. WP1 — Stream dịch cabin (Live STT streaming + STS cabin)

**Mục tiêu (theo PLAN-008):** nói tiếng Anh vào mic → text tiếng Việt hiện ra
màn hình **theo thời gian thực** (bubble), tùy chọn phát tiếng dịch (TTS Piper).
Đây là bước "Zipformer streaming → STS cabin" trong lộ trình PLAN-008/009.

**Bước làm:**
1. **Model:** extend cơ chế model có sẵn (xem `SttModelManager` /
   `sherpa_model_manager.dart` để học pattern download+verify+path) thêm set
   model Zipformer streaming (sherpa onnx: encoder/decoder/joiner/tokens)
   download về `<documents>/sherpa_stt_models/` (verify size/header, không đóng
   gói vào APK). Model lấy từ đâu: owner sẽ chỉ nguồn (ghi trong KANBAN mục
   "chờ owner" nếu không có URL — **đừng bịa URL model**).
2. `SherpaSttStreamingService` (singleton, `packages/in4up_stt` hoặc
   `lib/features/` — đặt cạnh `SherpaVadService` cho đồng bộ):
   - `ensureSherpaBindings()` trước; giữ `OnlineRecognizer` (pointer C-struct)
     trong singleton — **không re-init mỗi phiên** (tránh xung đột FFI
     whisper.cpp — ghi chú sẵn trong `sherpa_bindings.dart`).
   - API: `start({language})` → `Stream<SttPartial>` (text từng phần + đoạn
     chốt), `stop()`, dispose sạch khi app background lâu.
   - Mic capture: tái dùng cách capture có sẵn (shadowing/live — grep
     `startListening` trong `stt_engine_sherpa.dart` + engine whisper) — 1 nguồn
     mic duy nhất trong app tại một thời điểm.
3. `SttsCabinService` (pipeline): mic → streaming STT (đoạn chốt mỗi ~1-3s) →
   `TranslationService.translateText` (từng đoạn, có cache) → emit
   `Stream<CabinCaption>` (gốc + dịch) → tùy chọn `PiperTtsEngine.synthesize`
   (chỉ khi user bật "phát âm dịch" — mặc định TẮT).
4. UI: `LiveCaptionBubble` (mới) kế thừa pattern bubble có sẵn trong repo
   (draggable, auto-hide ~4s, tap mute — grep `bubble` trong
   `lib/screens/` để lấy mẫu): 3 chế độ hiển thị **1 chữ hiện thời / 1 dòng
   hiện thời / full transcript** (user chọn trong bubble). Nút: tắt/bật,
   chế độ hiển thị, phát âm.
   - Vị trí: màn hình phù hợp (đề xuất: tab Nghe hoặc entry riêng ở Tools —
     chọn 1, ghi KANBAN).
   - Banner nhắc đeo tai nghe khi bật phát âm (widget `auto_hide_banner` có
     sẵn — grep `auto_hide` để lấy mẫu) — 3s rồi ẩn.
5. **Không** làm direct speech-to-speech model trong WP này (đề xuất "hay hơn"
   của PLAN-008 — để milestone sau).

**AT WP1:**
- Trên thiết bị (có model): nói EN → caption VI hiện trong ≤~2s, 1 dòng/dòng,
  full transcript cuộn; bật phát âm → nghe tiếng VI, banner tai nghe hiện.
- Chưa có model: UI dẫn tải model (không crash, không red screen).
- Tắt app/bật lại: service dispose sạch (không leak mic, không FFI double-init).
- CI xanh + KANBAN card SHERPA-003/004 (đặt tên số tiếp theo — xem KANBAN).

## 6. Báo cáo khi xong mỗi WP (định dạng bắt buộc)

```
WPx DONE
- Nhánh: <branch> · SHA: <sha-tip-WP> (.. <sha-base>)
- Commits: <danh sách sha + 1 dòng mỗi cái>
- CI: <run id xanh> (App Analyze + Locale)
- AT đạt: <điểm nào đạt / điểm nào chờ owner thiết bị>
- File mới/sửa: <tóm tắt>
- Điểm chờ owner: <model URL? nghiệm thu thiết bị? quyết định UI? >
```

Gửi vào chat owner → owner chuyển cho agent `arena/01a0251e-in4up` → agent đó
**thu hoạch** (cherry-pick có `-x`, đối chiếu blob từng file, fix nếu có compile
error — bài học: WP của nhánh trước 01a02a4a có 3 lỗi compile, nhánh 019ff2de
có 2 lỗi — **đỏ sẵn cũng phải báo trung thực trong báo cáo**) → **nghiệm thu**
(review code + CI + nghiệm thu thiết bị cùng owner) → KANBAN đóng card.

## 7. Bẫy đã trả giá thật (nhắc lại — chi tiết trong SKILL.md)

1. **paths-filter** (5.7): commit chỉ chạm `packages/` không trigger
   app_analyze → tưởng xanh, thực ra chưa chạy.
2. **API nhớ sai** (5.16 + 3 lỗi vừa rồi): `File.openRead()` trả `Stream`,
   `openWrite()` trả `IOSink` (không phải `RandomAccessFile` — cái đó là
   `File.open()`); nullable field đọc ra local rồi dùng không null-check;
   trùng tên local. **Verify API bằng docs/source trước khi push.**
3. **Sandbox tái bản** (5.5): file bị revert về commit nền giữa phiên →
   `cp` file đang sửa ra `/tmp` trước, fetch + `reset --hard origin/<branch>`
   để đồng bộ, cp ngược.
4. **Bisect tự vỡ** (5.8): file bisect cắt bằng script phải balance-check
   (nháy đơn + kép) trước khi push.
5. **Export-chain** (5.2/5.10): import trực tiếp + qua export cùng file, hoặc
   `show` tên không dùng thật → analyze/test đỏ khó hiểu.

## 8. Tài liệu tham khảo trong repo

- `docs/project/PLAN.md` — PLAN-008 (lộ trình VAD→streaming→TTS→STS), PLAN-009
  (tinh hoa Google cabin + Gemma Translator offline)
- `docs/project/KANBAN.md` — card SHERPA-001/002/003 (VAD, Piper TTS, VAD 30p)
- `docs/project/MODELS.md` — bảng model sherpa/piper + cách đặt model trên device
- `docs/skills/ci-red-debugging/SKILL.md` — debug CI đỏ không có log/SDK
- `lib/features/vad/README_VAD_TTS_STREAMING.md` — định hướng format model
- Branch tham khảo (chỉ fetch đọc, không merge): `origin/arena/019fe27a-vipsound`
  (PoC sherpa), `origin/arena/01a0018e-in4up` (audio library + auto TOC)
