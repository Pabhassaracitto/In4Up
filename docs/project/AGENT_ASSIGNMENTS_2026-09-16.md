# Arena agent assignments — 2026-09-16

> Bản điều phối để copy vào prompt cho agent. Nguồn sự thật về trạng thái vẫn là
> `docs/project/KANBAN.md`; file này chỉ chia ownership, thứ tự và DoD để tránh
> hai agent sửa cùng một file.
>
> Phạm vi ưu tiên theo yêu cầu owner: **Sherpa/cabin, chat, Hy-MT**, sau đó
> đóng nhóm **BATCH OWNER 2026-09-15 — 9 lỗi sau build `1d58b78`**.

## 1. Baseline và luật chung

- Ngày điều phối: **2026-09-16**.
- Tip session hiện tại: `b58f33c` — chỉ dùng làm mốc; mỗi agent phải fetch tip
  mới nhất của nhánh đích trước khi code.
- Nhánh đích theo handoff trong KANBAN: `arena/01a0251e-in4up`.
- Nhánh session hiện tại của Arena: `arena/01a0a6b6-in4up`; không đổi tên, không
  tạo/push sang branch khác trong session này.
- CI oracle rộng: `.github/workflows/app_analyze.yml` — App Analyze + Locale Test,
  Flutter `3.44.1`; thay đổi `packages/**` phải thật sự trigger workflow.
- Đọc bắt buộc: `AGENTS.md`, `docs/GOVERNANCE.md`, card liên quan trong
  `docs/project/KANBAN.md`, và tài liệu `PLAN`/`Bangiao` được card trỏ tới.
- Không đụng `UltraTimeStretch`, `lib/ffi/` hoặc native C++ ngoài scope đã ghi.
- Không bịa URL/model. Không auto-download model. Không chạy
  `generate_arbs.py`. Chrome UI phải tuân rule #5.

### Luật commit / PR

1. Một agent chỉ nhận **một lane** dưới đây; không gom việc “tiện tay”.
2. PR branch phải bắt đầu từ tip mới nhất của nhánh đích. Nếu base đổi trong
   lúc làm, cập nhật trên branch agent và giải conflict tại đó; không force-push
   và không cherry-pick mù.
3. Giữ commit theo phần chức năng: `test/repro` (nếu có), `implementation`,
   `i18n/docs/checkpoint`. Mỗi commit phải ở trạng thái kiểm tra được; không
   để lại commit đỏ đã biết. Nếu test regression chỉ đỏ trước fix, đặt test +
   fix trong cùng một commit xanh.
4. Không commit `WIP`, `fixup!`, merge commit từ branch khác, file generated,
   `.dart_tool/`, `build/`, log, IDE settings hoặc format ngoài phạm vi.
5. Trước khi PR: `git diff --check`, `git diff --name-only` đối chiếu ownership
   matrix, test liên quan, analyze và CI xanh. Không đánh dấu `done` khi còn
   chờ nghiệm thu máy.
6. PR phải dùng `.github/pull_request_template.md`. Không squash nhiều commit
   logic thành một commit; nếu repository/owner yêu cầu squash thì dừng và báo
   owner, không tự squash.
7. Sau khi có bằng chứng, append lịch sử card trong KANBAN theo governance;
   không xóa hoặc viết lại lịch sử cũ.

## 2. Phân tải và thứ tự đề xuất

### Wave A — đóng 9 lỗi sau build `1d58b78`

| Lane | Card | Tải | Ownership chính | Phụ thuộc |
|---|---|---:|---|---|
| A1 | `PDF-JUMP-001` + `PDF-PAGE-001` | M | PDF screen/controller + test PDF | cùng `pdf_reader_screen.dart`, không tách hai agent |
| A2 | `WLIST-LANG-001` | S/M | selection save + language validation/i18n | không |
| A3 | `XLAT-MLKIT-001` | M | explicit source vs AUTO + ML Kit error | không |
| A4 | `READ-TOOLBAR-001` + `SHELL-GEAR-001` | M | visual/lifecycle chrome | cần xác nhận đúng gear khi nghiệm thu |
| A5 | `LISTEN-LRC-001` + `LISTEN-VIEW-001` | L | listen lifecycle, video texture, stale context | nên làm một agent vì trùng lifecycle; nhận thêm `LISTEN-LRC-LAYOUT-001` sau khi ổn |
| QA-P | phần Piper của batch 09-15 | S (audit) | verify fix đã có, chỉ mở code agent nếu AT còn đỏ | không trộn với catalog Piper |

`TTS-PIPER-002` đang bị dùng cho **hai ý khác nhau** trong KANBAN: (a) lỗi
status Piper của batch 09-15 và (b) catalog tải giọng theo PLAN-028. Trong prompt
phải ghi rõ `B0915-PIPER-STATUS` hoặc `PLAN028-PIPER-CATALOG`, không giao bare ID.

### Wave B — ưu tiên đúng trọng tâm owner

| Lane | Card | Tải | Ghi chú |
|---|---|---:|---|
| B1 | `HYMT-002` | M/L | queue, health/restart, chunk; không chỉ tăng timeout |
| B2 | `CABIN-ASR-002` + nghiệm thu `SHERPA-STREAM-001` | L | một owner cho mapping model/language và routing Online/Offline |
| B3 | `AI-CHAT-01` + audit `AI-CHAT-02`/`MODELS-002` | M/L | chỉ sửa gap còn mở; không đụng CMake llama.cpp |
| B4 | `HOME-QUICK-001` | M | nối STT thật và suggestion WordList, không giữ stub |
| B5 | `HOME-STUDIO-001` + `HOME-KG-001` | S/M | cùng navigation Home, tránh hai agent chạm `home_screen.dart` |
| B6 | `HOME-STREAK-001` | M | event thật + persist + thống kê; tách khỏi visual Home |
| B7 | `SHADOW-FILE-001` | L | persistent audio import + shadowing không bắt buộc AB |
| B8 | `XP-MODE-001` | S (design gate) | chỉ wireframe/route inventory trước; chưa code feature lớn khi chưa chốt UX |
| B9 | `LISTEN-LRC-LAYOUT-001` | S | giao cho A5 sau khi listen lifecycle xanh, không mở lane sửa cùng file sớm |

### Dependency graph

```text
A1 ───────────────┐
A2, A3, A4 ────────┼─> owner nghiệm thu BATCH-0915
A5 ───────────────┘       │
                          └─> B9 (LRC sát waveform)
SHERPA-STREAM-001 verify ───> B2 (CABIN-ASR-002)
B1 (HY-MT) ────────────────> translation offline acceptance
B3 (Chat) ────────────────> chat/model acceptance
B4/B5/B6 ────────────────> Home acceptance
```

Không cần chờ toàn bộ Wave A mới chạy B1/B2/B3; có thể chạy các lane không
đụng cùng file song song. Nhưng A5 và B9 phải tuần tự; SHERPA stream phải
được kiểm tra trước khi chốt cabin.

## 3. Prompt dùng chung cho mọi agent

Copy khối này trước prompt lane cụ thể:

```text
Bạn là Arena coding agent của In4Up. Chỉ nhận đúng lane được giao, không làm
việc ngoài scope và không sửa card khác cho “tiện tay”.

1. Đọc AGENTS.md, docs/GOVERNANCE.md, card trong docs/project/KANBAN.md và
   PLAN/Bangiao liên quan. Fetch origin, kiểm tra tip mới nhất của nhánh đích
   arena/01a0251e-in4up rồi tạo branch topic từ tip đó.
2. Ghi lại repro/bằng chứng trước fix. Nếu baseline đã đỏ, báo rõ lỗi nền và
   không đổ thêm thay đổi không liên quan.
3. Chỉ sửa file trong ownership của lane. Không đụng UltraTimeStretch,
   lib/ffi/, native C++ hoặc workflow để né lỗi nếu card không yêu cầu.
4. Chia commit theo phần logic (test/repro, implementation, i18n/docs). Không
   commit WIP/fixup/format toàn repo/generated files. Không để commit đỏ đã biết;
   test regression chỉ đỏ trước fix thì gộp test+fix trong cùng commit xanh.
5. Chạy test liên quan, flutter analyze với --no-fatal-infos --no-fatal-warnings,
   git diff --check. Push branch topic và tạo PR, giữ nguyên các commit logic,
   không squash.
6. PR bắt buộc dùng checklist trong .github/pull_request_template.md: card,
   commit map, CI run, log/screenshot, AT thiết bị, i18n và file scope.
7. Chỉ chuyển card sang done khi có CI xanh và AT đủ; nếu thiếu máy thì ghi
   “chờ nghiệm thu máy”, không khai báo hoàn tất giả.

Báo cáo cuối phải có: files đã đổi, commit map, lệnh test/analyze, CI run URL,
AT đã tick/chưa tick, rủi ro còn lại, và lý do nếu phải dừng.
```

## 4. Prompt lane Wave A — BATCH OWNER 2026-09-15

### A1 — PDF navigation

```text
Nhiệm vụ: PDF-JUMP-001 + PDF-PAGE-001.

Mục tiêu:
- Đóng dialog “Tới trang”/slider không còn assertion _dependents.isEmpty sau
  khi pop; không gọi jumpToPage trong lúc route dialog còn dispose.
- Mở/đóng WordList panel ở trang 50+ vẫn giữ đúng trang, không reload viewer
  về trang 1 hoặc nháy trang.

Ownership: lib/features/pdf_reader/pdf_reader_screen.dart,
lib/features/pdf_reader/pdf_reader_controller.dart và test PDF reader liên quan.
Ưu tiên giữ nguyên một PdfViewer sống bằng overlay/Positioned; nếu buộc phải
restore page thì bắt current page trước toggle và restore sau post-frame. Dialog
chỉ dùng dialogContext. Không đổi quy ước geometry/identity PDF.

DoD/AT:
- Điền số trang → Đi tới, Huỷ, mở/đóng 5 lần: không assertion.
- Ở trang 50+ mở/đóng panel 5 lần: giữ trang, không nháy trang 1.
- Có regression test cho controller/state hoặc widget seam phù hợp.
- Không làm mất selection, bookmark, annotation, reopen position.

Commit gợi ý:
1) test(pdf-reader): cover dialog pop and page preservation (nếu test đỏ trước
   fix thì gộp với fix); 2) fix(pdf-reader): defer navigation and keep viewer
   mounted; 3) docs/kanban: checkpoint bằng chứng.
```

### A2 — WordList custom language

```text
Nhiệm vụ: WLIST-LANG-001.

Thêm “＋ Thêm ngôn ngữ…” trong SelectionSaveSheet. Nhận code 2–4 ký tự,
normalize lowercase, trim và validate; chọn code mới phải lưu được vào WordList,
hiện chip ở lần mở sau và lọc được. Rà picker tương tự ở
lib/screens/read_mode/widgets/floating_text_actions.dart nhưng không nhân đôi
logic nếu không cần. Giữ dữ liệu/topic hiện có.

Ownership chính: lib/widgets/selection_save_sheet.dart,
lib/providers/vocabulary_provider.dart và test liên quan. UI mới phải dùng
ARB/uiText đúng rule #5; không hard-code Vietnamese cho locale khác.

AT: lưu `pi`, mở sheet lại thấy `pi`, lọc WordList theo `pi`; thử code rỗng,
quá dài, có space/ký tự sai phải báo lỗi hành động được.
Commit: test validation/persistence → fix picker/save → i18n + KANBAN checkpoint.
```

### A3 — ML Kit explicit source

```text
Nhiệm vụ: XLAT-MLKIT-001.

Khi tài liệu có source language explicit khác AUTO, không gọi
LanguageDetector cho từng dòng; dùng source đã chọn nhất quán. Chỉ AUTO mới
re-detect. Không tự đổi một tài liệu EN thành DE vì câu ngắn. Error ML Kit phải
nêu đúng source→target và phân biệt “auto-detect thiếu model” với “cặp explicit
thiếu model”; không retry âm thầm bằng ngôn ngữ khác khi user đã chọn explicit.

Ownership: lib/features/translation/text_provider_translation.dart,
lib/features/translation/engines/mlkit_engine.dart và test translation. Không
đụng engine khác ngoài seam cần thiết.

AT: offline ML Kit source EN→VI với câu ngắn vẫn không báo German; AUTO với văn
Đức vẫn giữ hành vi nhận diện và báo thiếu German đúng ngữ cảnh; test nguồn
explicit/auto riêng.
```

### A4 — visual chrome / orphaned Ink

```text
Nhiệm vụ: READ-TOOLBAR-001 + SHELL-GEAR-001.

Trước khi sửa, xác định đúng nút gear owner repro. Rà artifact khối đen/sọc
vàng-đen theo thứ tự ít rủi ro: bỏ ClipRect hoặc giảm AnimatedSlide offset về
1.0; chỉ thay InkWell bằng GestureDetector/custom highlight nếu log xác nhận
orphaned Ink. Không xoá Focus mode, không đổi hành vi long-press hợp lệ.

Ownership: read_mode_screen.dart/read_bottom_bar.dart và main_shell.dart /
translation_toolbar.dart ở phần gear. Không reformat file lớn.

AT thiết bị: cuộn Đọc 10 lần, Focus/Thoát Focus; long-press đúng gear 10 lần;
không khối đen, không sọc/assertion, nút vẫn hoạt động. Ghi thiết bị/GPU,
logcat hoặc video trong PR. Nếu chưa tái hiện được, chỉ thêm logging/test seam
và báo owner, không đoán sửa sâu.
```

### A5 — listen lifecycle

```text
Nhiệm vụ: LISTEN-LRC-001 + LISTEN-VIEW-001. Sau khi hai lỗi này xanh, nhận
thêm LISTEN-LRC-LAYOUT-001 trong một commit riêng nhỏ.

Mục tiêu:
- Mở audio có LRC sẵn không setState/notify trong build, không dùng stale
  context, không làm tab Hiểu red screen.
- Rời Listen → Xem video → quay lại Listen không còn màn hình đen/kẹt texture.
- Controller video pause/dispose đúng khi offstage và khởi tạo lại sạch khi
  onstage; lỗi init phải hiện thành UI lỗi, không đen im lặng.
- LRC panel ở B9 sát cạnh waveform, spacing 0 (hoặc tối đa 4px), không overflow.

Ownership: lib/screens/listen_mode/listen_mode_screen.dart,
lib/screens/main_shell.dart, lib/features/video/widgets/video_library_screen.dart,
player provider và các widget/test lifecycle liên quan. Các callback async phải
mounted/post-frame đúng chỗ; không sửa business translation ngoài scope.

AT: chọn 5 file có LRC, đổi Nghe/Xem 10 vòng, video chạy tối thiểu 5 giây rồi
quay lại; tab Hiểu vẫn mở; tạo lời AI thì panel chạm waveform, không khoảng
trắng/overflow. Ghi logcat nếu release khác debug.
```

### QA-P — Piper status, không nhầm với catalog

```text
Nhiệm vụ: B0915-PIPER-STATUS (không phải PLAN028-PIPER-CATALOG).

Audit code fix đang có của TTS-PIPER-001/status: tokens hợp lệ có thể nhỏ hơn
1KB, pre-flight phonemizer/model phải giải thích rõ và không crash native. Trên
máy có voice + espeak: chip xanh; thiếu phonemizer: chip đỏ/cam nhưng có hướng
dẫn; phát VI/Pali liên tiếp không crash. Nếu code đã đúng, không tạo PR rỗng:
chỉ báo cáo AT và đề xuất owner cập nhật bằng chứng. Chỉ commit khi có lỗi tái
hiện cụ thể. Catalog Piper theo PLAN-028 để lane khác sau batch.
```

## 5. Prompt lane Wave B — Sherpa, Hy-MT, chat

### B1 — Hy-MT timeout

```text
Nhiệm vụ: HYMT-002 — ưu tiên cao.

Đóng timeout Hy-MT theo lớp, không chỉ tăng 2 lên 4 phút:
1. Một request tại một thời điểm; request kế tiếp được queue hoặc trả trạng thái
   “đang bận” có cấu trúc, không treo thêm 2 phút.
2. Health/heartbeat trước request; isolate chết hoặc native load hỏng phải
   dispose, spawn lại và retry tối đa 1 lần với lỗi cuối rõ ràng.
3. Text dài được chunk theo ranh giới câu/cụm (mục tiêu khoảng ≤500 ký tự nếu
   phù hợp engine), ghép đúng thứ tự, không lặp/mất đoạn. Câu ngắn không bị
   timeout giả; không nuốt lỗi của chunk.
4. UI báo “Đang dịch bằng Hy-MT offline, có thể chậm” và kết thúc ở success
   hoặc error hữu hạn; không xoay vô hạn.

Ownership: lib/features/translation/engines/hymt_engine.dart, seam cần thiết ở
translation_service.dart/UI và test. Không đổi llama.cpp CMake/native backend
của Chat. Không load nhiều model song song gây OOM.

AT: câu EN→VI ngắn trên máy owner trả kết quả; 2000+ ký tự trả đủ theo thứ tự;
2 request liên tiếp không kẹt; mô phỏng isolate chết thì retry 1 lần rồi báo
lỗi. Ghi thời gian thực tế, không đặt DoD là “phải dưới N giây”.

Commit gợi ý: test chunk/queue seam → runtime recovery/timeout → UI message +
Kanban checkpoint. Mỗi commit phải xanh.
```

### B2 — Sherpa cabin / Zipformer

```text
Nhiệm vụ: CABIN-ASR-002 và nghiệm thu liên quan SHERPA-STREAM-001.

Đọc bắt buộc docs/Bangiao/bangiao_sherpa_wp4_live_stt.md và PLAN-023. Trước
khi sửa, xác nhận fix streaming đã có: model EN streaming chỉ vào
OnlineRecognizer; model offline VI vào OfflineRecognizer + VAD; không bao giờ
nạp streaming vào OfflineRecognizer (tránh SIGABRT Expected 39).

Sửa mapping/model selection:
- Không hardcode cabin mới luôn chọn EN khi máy chỉ import VI. Mặc định dùng
  language đã cài; nếu chưa có thì fallback mặc định VI có giải thích.
- Nếu user chọn EN nhưng chỉ có VI, không âm thầm nhận tiếng Anh bằng model VI:
  báo model thiếu + dẫn tới Quản lý Model AI hoặc hỏi xác nhận fallback.
- Import detection phải map đúng profile `asr-vi-30M-int8` /
  `asr-en-20M-streaming-int8`; dropdown đánh dấu profile chưa cài.
- Giữ không auto-download, không bịa profile ngôn ngữ.

Ownership: `lib/features/cabin/services/stts_cabin_service.dart`, cabin screen,
`packages/in4up_stt/lib/sherpa_model_manager.dart`,
`packages/in4up_stt/lib/stt_engine_sherpa.dart`, UI model settings và test
mapping/routing. Không sửa vùng FFI bảo vệ ngoài wrapper hiện có.

AT: máy chỉ có VI → Cabin Sherpa start + nhận tiếng Việt; chọn EN thiếu model →
message rõ; máy có EN streaming → live token-by-token không SIGABRT; file/LRC
không dùng nhầm streaming; VI simulated streaming vẫn chạy. CI phải trigger
cho packages/**.
```

### B3 — Chat runtime stabilization

```text
Nhiệm vụ: AI-CHAT-01; audit không hồi quy AI-CHAT-02 và MODELS-002.

Kiểm tra trước các fix đã ghi trong KANBAN (state processing/hasModel, queue,
watchdog, isolate exit, context bounded). Chỉ sửa gap còn tái hiện, không làm
lại phần đã có và không chạm CMake/llama.cpp native backend.

DoD:
- Model đã load: gửi tin không làm banner xanh nhảy thành “chưa nạp”.
- Request có timeout hữu hạn; isolate chết/OOM không làm spinner vô hạn; request
  sau vẫn hoạt động hoặc báo lỗi retry được.
- Hai tin liên tiếp được queue đúng, không trả “engine not ready” giả.
- Context chat có giới hạn và max tokens hợp lý, không gửi toàn lịch sử làm
  decode rỗng/cắt JSON.
- Import/status UX của MODELS-002 không bị regress.

Ownership: chat screen, facade/engine Dart và tests liên quan; tránh native CMake.
AT trên model nhỏ thật: import → gửi khi đang processing → banner giữ xanh;
gửi 2 tin; ép timeout/isolate restart → tin sau chạy được. Ghi memory/model size
và CI run.
```

## 6. Prompt lane Wave B — Home / audio / trải nghiệm

### B4 — Home quick input

```text
Nhiệm vụ: HOME-QUICK-001.

Thay hai stub “Nạp tri thức nhanh” và FAB microphone bằng flow thật dùng engine
STT hiện tại, ưu tiên Sherpa offline khi khả dụng: transcript realtime, dừng
sạch, lưu thành WordList hoặc ghi chú. Nút “Gợi ý” phải lấy một entry thật từ
WordList (ưu tiên đến kỳ FSRS), hiển thị word/IPA/meaning và TTS nếu có; không
random text/image giả.

Ownership: hebbian_input_card.dart, home_screen.dart/_SttDialog và seam provider
cần thiết. Tái sử dụng service có sẵn, không tạo STT singleton thứ hai hoặc
fire-and-forget mic. Test flow/state; i18n đầy đủ.

AT: nói một câu VI → transcript → lưu → thấy entry/note; Gợi ý khi WordList có
entry → hiện entry thật; danh sách rỗng → empty state có hướng dẫn.
```

### B5 — Studio + Knowledge Graph

```text
Nhiệm vụ: HOME-STUDIO-001 + HOME-KG-001.

Tách 7 card rõ: NGHE, NÓI, XEM, ĐỌC, VIẾT, HIỂU, NHỚ; route đúng sub-mode
(listen 0/1/2, read 0/1, understand, remember), responsive không overflow.
Nối nút “Xem Knowledge Graph” ở preview tới KnowledgeGraphScreen bằng cách
navigation đã dùng ở WordList.

Ownership: home_screen.dart, main_shell.dart ở callback/navigation và
knowledge_graph_preview.dart. Không chạm STT flow của B4 nếu không cần; nếu
base có thay đổi B4, rebase/resolve trên branch này, không lấy cả file cũ.

AT: 7/7 card mở đúng màn; XEM mở VideoLibrary; graph preview mở màn hình graph;
đổi locale không có chrome Vietnamese ngoài rule #5.
```

### B6 — real learning streak

```text
Nhiệm vụ: HOME-STREAK-001.

Định nghĩa và ghi event học thật theo ngày: đọc/tài liệu, lưu/import từ, LHB,
shadowing, dịch; không phụ thuộc effort slider đã bỏ. Persist gọn, idempotent,
không ghi duplicate mỗi rebuild. Card hiển thị số liệu hôm nay, streak và 7 ngày
(trong phạm vi phù hợp UI hiện tại); dùng nguồn provider thật, không hardcode.

Ownership: focus_streak_card.dart, focus_provider.dart và service/event model
mới nếu cần; test date boundary, restart, duplicate event. Không trộn route Studio.

AT: đọc + lưu từ hôm nay → số >0; mở lại app không nhân đôi; ngày không học
không tăng; học ngày kế tiếp tăng streak; timezone dùng nhất quán.
```

### B7 — persistent audio + shadowing

```text
Nhiệm vụ: SHADOW-FILE-001.

Sau file_picker, copy vào application documents persistent `audio_imports/`,
dedup an toàn và lưu path/identity bền vững; player, LRC, VAD, shadowing dùng
path persistent. Path cache cũ gặp ENOENT phải hiện hướng dẫn chọn lại, không
crash. Cho shadowing chạy toàn track khi chưa có AB; nếu có LRC thì gợi ý AB
theo câu, user vẫn sửa tay được.

Ownership: audio_library_drawer.dart, listen_library_screen.dart,
player_provider.dart, shadowing provider/widget và speak_mode_screen.dart.
Không tự xóa dữ liệu import cũ; migration/cleanup phải có xác nhận và test.

AT: chọn file → xóa cache/restart → phát vẫn được; shadowing không AB chạy cả
track; có LRC gợi ý từng câu; AB thủ công vẫn hoạt động.
```

### B8 — XP mode design gate

```text
Nhiệm vụ giai đoạn 1: XP-MODE-001, chỉ thiết kế trước khi code.

Lập wireframe ngắn và route inventory cho tab Trải nghiệm: 7 mode
NGHE/NÓI/XEM/ĐỌC/VIẾT/HIỂU/NHỚ; mỗi mode có mục tiêu + 3–5 bước dẫn đường; mục
Khám phá công cụ liệt kê tối thiểu 5 tool đang ẩn sau icon sấm sét (đặc biệt
Tipiṭaka), route mở ngay và trạng thái unavailable. Giữ grammarExperienceMode
cũ không phá.

Deliverable chỉ là một tài liệu/ảnh wireframe + danh sách file/route/i18n,
không triển khai đại trà. Xin owner chốt wireframe; sau đó mở PR implementation
riêng với card con và test navigation. Không để agent tự quyết UX lớn.
```

## 7. Mẫu báo cáo sau khi agent xong

```text
[AGENT DONE] <lane/card>

Base / branch:
Commits (giữ nguyên, không squash):
Files changed (đối chiếu ownership):
Repro trước fix:
Fix và giới hạn scope:
Tests + lệnh analyze:
CI App Analyze + Locale run:
CI module/package run (nếu có):
AT thiết bị: [ ] happy [ ] lỗi/lifecycle [ ] lặp lại
Screenshot/logcat/video:
I18n audit:
KANBAN history đã append:
Còn chờ owner:
Rủi ro / rollback:
```

Nếu không tái hiện được hoặc CI không chạy, agent phải trả về **BLOCKED + bằng
chứng**, không tự chuyển `done`, không tạo PR chứa thay đổi đoán mò.

## 8. Addendum sau audit Gemini / Video

- Audit Hy-MT chi tiết + prompt bổ sung: `docs/project/AUDIT-HYMT-GEMINI-2026-09-16.md`.
  Kết luận: Hy-MT inference đã ở isolate; timeout 15–18 giây không đúng source;
  `HYMT-002` vẫn cần queue/health/restart/chunk và bằng chứng CI/thiết bị.
- Prompt hoàn thiện tab phụ Video: `docs/Bangiao/PROMPT_AGENT_VIDEO.md`.
  Card chính `VID-001`; phải xử lý đồng thời lifecycle của `LISTEN-VIEW-001`,
  vì `IndexedStack` giữ child offstage và player controller không được phép
  để texture đen hoặc phát ngầm.
