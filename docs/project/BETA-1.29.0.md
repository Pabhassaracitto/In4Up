# BETA-1.29.0 — Nhánh tổng hợp & kiểm thử trước khi vào 251e

> **Vai trò nhánh `arena/60e35d65-in4up`:** bàn tổng hợp (Beta hub) cho v1.29.0.
> 9 nhánh agent xử lý 9 nhóm lỗi audit v1.28.0 → **land vào đây** → kiểm thử chung →
> chỉ khi tất cả xanh mới đưa sang nhánh cha `arena/01a0251e-in4up` (251e) để phát hành.
>
> **Nguồn sự thật trạng thái toàn cục:** `docs/project/KANBAN.md` (card `BETA-1.29.0`).
> File này là **bảng điều phối chi tiết**: lane, thứ tự land, cổng kiểm, luật cho agent con.
>
> **Luật ghi:** append-only như `docs/GOVERNANCE.md` §3 — không xoá lane, không xoá
> dòng nhật ký; đổi trạng thái thì thêm dòng vào §8.

## 1. Mốc

| Mốc | Giá trị |
|---|---|
| Nhánh beta | `arena/60e35d65-in4up` |
| Nền (base) | `d23341a` — tip 251e ngay sau card `REL-1.28.0` |
| Nhánh cha (đích cuối) | `arena/01a0251e-in4up` (251e) |
| Bản phát hành gần nhất | **1.28.0** — tag trên `db51dd38`, build 4/4 🟢 run `43209683845` |
| `pubspec.yaml` hiện tại | `1.28.0+28` — **giữ nguyên** tới cổng **G4** |
| CI oracle | `app_analyze.yml` (chạy khi push `arena/**`) + `listen_queue_tests.yml` + `deploy-web.yml` |
| Sandbox agent | **không có Flutter/Dart SDK** ⇒ compile/test chạy qua CI; đọc `docs/skills/ci-red-debugging/SKILL.md` |

Không có nhánh con nào tồn tại ở thời điểm mở hub (2026-11-12). Bảng §2 là chỗ ghi
nhánh thật khi owner giao việc.

## 2. 9 lane — audit v1.28.0 (Linear, owner 2026-11-12)

Link issue dùng dạng rút gọn `https://linear.app/in4up/issue/PSRC-<số>`.

| L | Nhóm | Issue | Vùng code chính | Nhánh agent | Trạng thái |
|---|---|---|---|---|---|
| L1 | Live cabin | [199](https://linear.app/in4up/issue/PSRC-199) sửa/xoá nội dung · [200](https://linear.app/in4up/issue/PSRC-200) chọn chủ→đích khi chuyển sang tài liệu đọc · [201](https://linear.app/in4up/issue/PSRC-201) tuỳ chọn đồng bộ phiên sang Đọc/Nghe/Hiểu (cả phiên đã lưu) · [223](https://linear.app/in4up/issue/PSRC-223) cabin offline Sherpa dừng sau dòng đầu | `lib/features/cabin/**` (`live_cabin_screen`, `cabin_session_store`, `stts_cabin_service`, `cabin_read_bridge`) · `lib/screens/listen_mode/**` (audio phiên) · `lib/screens/read_mode/**` + `lib/screens/text_library/**` (đích) | — | ⬜ chưa nhận |
| L2 | Âm thanh & video | [202](https://linear.app/in4up/issue/PSRC-202) audio tách từ video không tự mở rồi bị "dish" · [203](https://linear.app/in4up/issue/PSRC-203) chia sẻ sau xuất A–B không phản hồi (kiểm cả tab Video) · [205](https://linear.app/in4up/issue/PSRC-205) tạo lời file dài + m4a · [219](https://linear.app/in4up/issue/PSRC-219) Linux "could not play this track" · [220](https://linear.app/in4up/issue/PSRC-220) Linux `.mp4` ở tab View | `lib/features/video/**` · `lib/features/media_tools/**` (`media_export_service`) · `lib/screens/listen_mode/**` (player, tạo lời) · `linux/**` | — | ⬜ chưa nhận |
| L3 | Tab Đọc & PDF/OCR | [206](https://linear.app/in4up/issue/PSRC-206) quét thư mục nhiều tài liệu ⇒ treo/lag · [207](https://linear.app/in4up/issue/PSRC-207) `.docx` không mở · [208](https://linear.app/in4up/issue/PSRC-208) chế độ TT chỉ ra chữ trang 2 · [209](https://linear.app/in4up/issue/PSRC-209) tinh chỉnh AI sau OCR báo sai cấu hình · [210](https://linear.app/in4up/issue/PSRC-210) OCR từ TT quét vùng trống | `lib/screens/read_mode/**` · `lib/screens/text_library/**` · `lib/services/text_source_loader.dart` · `lib/features/pdf_reader/**` · `lib/features/ocr/**` | — | ⬜ chưa nhận |
| L4 | Bong bóng dịch | [211](https://linear.app/in4up/issue/PSRC-211) bỏ sót khối, border dư dưới, bản dịch sai chỗ | `lib/features/screen_translate/**` · `android/app/src/main/kotlin/com/in4up/screentranslate/**` (`TranslationOverlayView`, `ScreenTranslateService`) | — | ⬜ chưa nhận |
| L5 | Web & YouTube trên Linux | [212](https://linear.app/in4up/issue/PSRC-212) biểu tượng Web ⇒ màn hình đen · [213](https://linear.app/in4up/issue/PSRC-213) chọn kết quả YouTube ⇒ màn hình đen | `lib/features/web_reader/**` · `lib/features/youtube/**` · `linux/**` | — | ⬜ chưa nhận |
| L6 | VieNeu / Vieu-TTS | [214](https://linear.app/in4up/issue/PSRC-214) import phía trên không nhận model · [215](https://linear.app/in4up/issue/PSRC-215) import Q8_0 "thành công" nhưng thiếu engine · [216](https://linear.app/in4up/issue/PSRC-216) không khởi tạo engine · [217](https://linear.app/in4up/issue/PSRC-217) import giọng lỗi · [218](https://linear.app/in4up/issue/PSRC-218) tạo giọng từ mẫu thu lỗi | `packages/in4up_stt/lib/tts/vieneu_tts_core.dart` (+ worker isolate) · `lib/features/tts/engines/vieneu_tts_engine.dart` · `lib/screens/settings/**` (TTS) · `native/tts_vieneu/**` + CMake | — | 🔨 doing — **owner chốt ship engine** (ADR-0028); hub đã pin submodule + workflow build |
| L7 | Tệp, nơi lưu & "Mở bằng" | [204](https://linear.app/in4up/issue/PSRC-204) **đã chốt mô hình** (ADR-0029): mặc định `Download/In4Up` + đổi từng lần xuất · [222](https://linear.app/in4up/issue/PSRC-222) mở `.txt/.pdf/.docx/.md/.mp3/.m4a/.mp4` bằng In4Up | `android/app/src/main/AndroidManifest.xml` · `ios/Runner/Info.plist` · `lib/services/**` (nhận tệp) · `lib/features/media_tools/services/media_export_service.dart` (nơi lưu) · `lib/screens/text_library/**` · `linux/**` + `windows/**` (liên kết tệp) | — | ⬜ chưa nhận — **hợp đồng đã có: ADR-0029** |
| L8 | Giọng đọc hệ thống Android | [221](https://linear.app/in4up/issue/PSRC-221) In4Up thành TTS engine của hệ thống (như Sherpa APK), lấy Piper làm cơ sở | `android/app/src/main/kotlin/**` (service TTS mới + engine XML + manifest) · `lib/screens/settings/**` (công tắc/hướng dẫn) | — | ⬜ chưa nhận |
| L9 | Shadowing & UI tab Nói/Hiểu | [224](https://linear.app/in4up/issue/PSRC-224) rà và bỏ mục Shadow ở "tạo lời" tab Nghe nếu vô dụng · [225](https://linear.app/in4up/issue/PSRC-225) thu gọn nội dung tab Nói, ưu tiên Shadowing · [226](https://linear.app/in4up/issue/PSRC-226) "Nghe mẫu" trôi quá dòng đã chọn · [227](https://linear.app/in4up/issue/PSRC-227) chấm điểm sai (tab Nói + tab Hiểu) · [228](https://linear.app/in4up/issue/PSRC-228) tab Hiểu thiếu gợi ý + đọc hết nội dung | `lib/features/shadowing/**` · `lib/screens/listen_mode/speak_mode_screen.dart` · `lib/screens/understand_mode/**` · `lib/screens/listen_mode/**` (mục Shadow) | — | ⬜ chưa nhận |

**Ngoài phạm vi sửa:** [PSRC-8](https://linear.app/in4up/issue/PSRC-8) đã **Done** — giữ làm mốc
hồi quy (Microsoft Edge đọc tốt ở 1.28.0, Sherpa phát được, nguồn Piper đầy đủ). Nếu lane
L6/L8 làm hỏng các đường đọc này thì đó là **regression của lane**, không phải việc mở lại PSRC-8.

### 2.1 Chồng lấn đã biết (đọc trước khi giao việc)

| Cặp | File/khu vực chạm chung | Hệ quả |
|---|---|---|
| L1 ↔ L2 | tab Nghe: nguồn audio phiên, player, "tạo lời" | L2 land trước L1 |
| L1 ↔ L3 | tab Đọc / thư viện tài liệu (đích khi chuyển cabin sang tài liệu) | L3 land trước L1 |
| L1 ↔ L9 | tab Nói / tab Hiểu (đích đồng bộ + bố cục Shadowing) | L9 land trước L1 |
| L2 ↔ L9 | "tạo lời" tab Nghe (mục Shadow) | L2 land trước L9 |
| L6 ↔ L8 | màn Cài đặt TTS, `TtsService`/engine registry | L6 land trước L8 |
| L7 ↔ L2 | nơi lưu tệp xuất media / nhận tệp | cùng đụng `media_export_service` ⇒ L7 land trước L2 nếu cả hai sửa hàm lưu |
| tất cả | `KANBAN.md`, `tool/priority_native_pack.json`, ARB `lib/l10n/app_*.arb`, `.github/workflows/app_analyze.yml` | **hub độc quyền sửa** (xem §3.3) |

### 2.2 L6 — quyết định "engine phải chạy thật" (owner 2026-11-12)

Owner: *"Tôi muốn VieNeu thực sự hoạt động."* → [ADR-0028](../adr/0028-vieneu-engine-ship-audio-cpp-va-sea-g2p.md).
Hub đã làm phần **hạ tầng** để lane L6 không còn bế tắc; phần còn lại thuộc lane.

| Mảnh | Trước | Nay (hub đã làm) |
|---|---|---|
| `third_party/audio.cpp` | khai trong `.gitmodules` nhưng **không có gitlink** ⇒ CI `pathspec did not match` (nuốt bằng `|| true`) | gitlink pin **v0.9.4** `717efc34`; API C của header đúng tag khớp mọi hàm wrapper dùng |
| SEA-G2P (bắt buộc: model nhận **phoneme**, không nhận chữ thô) | không có trong repo | gitlink `third_party/sea-g2p` pin **v0.10.0** `dae5ca83` + `cargo ndk` build `arm64-v8a` trong workflow |
| Âm thanh | wrapper copy thô `frames` mẫu trong khi VieNeu phát **stereo 48 kHz** ⇒ cụt nửa dữ liệu, phát 2× | wrapper **trộn kênh** về mono đúng hợp đồng FFI |
| Nạp SEA-G2P | chỉ tìm `.so` cạnh model (người dùng phải chép) | ưu tiên cạnh model nếu có, còn lại để audio.cpp `dlopen` **theo tên** từ `jniLibs`; truyền `g2p_dict_file` khi có `sea_g2p.bin` |
| Bằng chứng build | chỉ lộ ở bước release | workflow riêng `vieneu_engine_build.yml` + test hợp đồng 4 ca trong `app_analyze`; **run 43325244915 🟢** — APK arm64 có đủ 3 `.so`, job 17m05s |
| Nơi build CMake | engine nằm trong CMake của `:app` ⇒ **trùng target `ggml::ggml`** với llama.cpp (audio.cpp mang ggml 0.12.0 riêng) | **module Gradle `:vieneu`** (`android/vieneu/`) — CMake project riêng, chỉ build `audiocpp` + `vieneu_tts` (`posix_spawnp` của CLI cần API 28 > minSdk 24) |

**Còn lại cho lane L6** (đúng thứ tự):
1. ~~Chạy `vieneu_engine_build.yml` tới xanh; ghi thời gian build~~ ✅ 17m05s (43325244915,
   18m52s ở 43328297538) — engine ≈10 MiB chưa nén; **chênh lệch APK release** vẫn phải đo
   ở G4 (debug 261 MiB không đại diện).
2. ~~Đường tải/import **`sea_g2p.bin`** (≈60 MiB) trong app + checksum~~ ✅ đã có service + card UI + 13 chuỗi 8 locale + test (ADR-0028 §8).
3. PSRC-214…218: import ở **mọi** mục (kể cả mục phía trên), không báo "thành công" giả,
   khởi tạo engine / import giọng / tạo giọng có thông điệp đúng sự thật.
4. Máy thật: đọc ≥ 3 đoạn tiếng Việt; đo nạp/tổng hợp/RAM; gỡ model ⇒ rơi về engine kế, không crash.

### 2.3 Phiếu việc chi tiết trong `beta-1.29.0/` (2026-11-13)

Toàn bộ nội dung kỹ thuật của từng lane đã tách ra thư mục
[`docs/project/beta-1.29.0/`](beta-1.29.0/README.md), để chủ dự án chỉ cần **nhắn một câu**
cho mỗi agent thay vì dán lại ngữ cảnh:

| File | Nội dung |
|---|---|
| [`README.md`](beta-1.29.0/README.md) | luật chung: nhánh, **luật commit để rebase tuyến tính**, phạm vi file, DoD 6 điểm, CI |
| [`PROMPTS.md`](beta-1.29.0/PROMPTS.md) | câu nhắn mẫu cho từng lane (một câu/lane) + thứ tự land |
| `L1-…` … `L11-…` | phiếu từng lane: issue, hướng điều tra, file chạm, nghiệm thu, mẫu tiêu đề commit |

Thay đổi so với bảng §2 (bảng §2 vẫn là bản đồ gốc, **số hiệu L1–L9 không đổi**):

- **L10 mới** — PDF/Web reader (karaoke, tự cuộn, tốc độ): PSRC-229, 231, 232. Tách khỏi L3 vì L3 đã có 7 issue.
- **L11 mới** — chốt In Review (PSRC-6, PSRC-14) + phân loại backlog cũ ≤ PSRC-196. **Ngoài cổng beta.**
- Issue audit đợt 2 **PSRC-224…233** đã được gán: 224/225/226/227/228 → **L9**, 229 → **L10**, 230 → **L3**, 231/232 → **L10**, 233 → **L3**.
- Tổng trong cổng: **35 issue** (PSRC-199…233), mỗi issue đúng một lane; đợt 2 cũ (172, 174, 178, 179, 180, 193, 194, 195, 196) đã gán lane nhưng **không** thuộc cổng.

## 3. Hợp đồng cho agent con (copy nguyên khối này vào prompt)

```text
Bạn là Arena coding agent của In4Up, làm MỘT lane của Beta v1.29.0.

NHÁNH ĐÍCH: arena/60e35d65-in4up — đây là bàn tổng hợp Beta, KHÔNG phải main và
KHÔNG phải 251e. PR của bạn phải có base = arena/60e35d65-in4up.
Không push trực tiếp vào 251e (arena/01a0251e-in4up), không push vào main.

ĐỌC TRƯỚC: AGENTS.md · docs/GOVERNANCE.md · docs/project/BETA-1.29.0.md (lane của
bạn ở §2, chồng lấn ở §2.1) · card BETA-1.29.0 trong docs/project/KANBAN.md ·
file nguồn liên quan. Fetch origin và tạo nhánh từ tip MỚI NHẤT của
arena/60e35d65-in4up.

PHẠM VI: chỉ đúng các issue Linear của lane bạn (ghi số PSRC-… trong PR). Không
sửa lỗi lane khác cho "tiện tay". Không đụng UltraTimeStretch, lib/ffi/ và
native C++ ngoài phạm vi card; nếu buộc phải đụng thì DỪNG và báo owner.

BẰNG CHỨNG TRƯỚC KHI SỬA: ghi lại repro (thiết bị/nền tảng, build, thao tác,
log/ảnh). Với lỗi chỉ tái hiện trên máy thật (Android/Linux/Windows), ghi rõ
"chưa tái hiện trong sandbox" và mô tả cách kiểm trên máy — không đoán rồi tuyên bố xong.

CODE + TEST: fix tối thiểu, không đổi kiến trúc ngoài card. Thêm test bắt được
lỗi (ưu tiên logic thuần + test quét nguồn như các card trước). Nếu thêm test
mới, thêm MỘT step riêng vào .github/workflows/app_analyze.yml chạy đúng file
test của bạn, không `|| true` — hub sẽ resolve xung đột file này khi land.

i18n (AGENTS.md luật 5): mọi chữ UI mới phải có ARB hoặc uiText + English trong
tool/legacy_ui_english_overrides.json; key ARB mới phải dịch đủ hi/zh/zh_TW/si
ngay trong cùng PR. Nếu thêm entry vào tool/priority_native_pack.json thì chạy
python3 tool/generate_priority_native_pack.py (và --check phải OK). KHÔNG chạy
generate_arbs.py.

KHÔNG ĐƯỢC LÀM (để tránh 9-way conflict):
- Không sửa pubspec.yaml version (giữ 1.28.0+28; hub bump một lần ở cổng G4).
- Không sửa docs/project/KANBAN.md và docs/project/PLAN.md — hub ghi hộ card +
  lịch sử khi land (bạn ghi bằng chứng trong PR body, hub chép vào card).
- Không sửa docs/project/BETA-1.29.0.md; không tạo tag, không tạo release.

KIỂM TRƯỚC KHI PR: git diff --check · flutter analyze --no-fatal-infos
--no-fatal-warnings · test liên quan chạy xanh · CI của nhánh xanh (nếu sandbox
không có Flutter thì nêu rõ và để CI làm oracle).

PR: dùng .github/pull_request_template.md; tiêu đề "[BETA-1.29.0 · L<n>] <mô tả>";
body ghi số PSRC, commit map, lệnh test, CI run URL, AT trên máy đã tick/chưa,
rủi ro còn lại. Giữ commit logic riêng (test/repro · implementation · i18n/docs),
không squash.

BÁO CÁO CUỐI: file đã đổi · commit map · CI run · điều đã kiểm / chưa kiểm được ·
điểm cần owner quyết (nếu có).
```

### 3.1 Nhánh & PR

- Nhánh do Arena tạo (`arena/<session>-in4up`); **không đổi tên**, không tạo nhánh khác trong cùng session.
- PR **base = `arena/60e35d65-in4up`**, head = nhánh agent. Không mở PR vào `main`/251e.
- Nếu nhánh agent được tạo từ 251e: trước khi PR phải `git merge origin/arena/60e35d65-in4up` (hoặc rebase) vào nhánh mình và đẩy lại — hub không vá xung đột thay agent trừ khi owner yêu cầu.
- Không force-push vào beta; nhánh agent tự force-push phần của mình thì được (theo yêu cầu gom commit của owner, như các session trước).

### 3.2 Định nghĩa "lane xong" (agent tự khai)

1. Repro + fix + test bắt được lỗi (hoặc lý do không thể thêm test, được hub chấp nhận).
2. `flutter analyze` chỉ còn infos/warnings lịch sử, **0 error**.
3. Step test của lane xanh trong `app_analyze`; toàn bộ step cũ vẫn xanh.
4. Không đổi ngoài phạm vi; `git diff --name-only` khớp §2.
5. AT máy thật tick được, hoặc ghi rõ **"chờ nghiệm thu máy"** — không khai done giả.

### 3.3 Việc hub giữ độc quyền

`docs/project/KANBAN.md` · `docs/project/PLAN.md` · `docs/project/BETA-1.29.0.md` ·
`pubspec.yaml` (version) · `tool/priority_native_pack.json` + generated pack ·
`tool/legacy_ui_english_overrides.json` · `lib/l10n/app_*.arb` (gộp cuối) ·
`.github/workflows/*` (resolve) · tag/release.

Lý do: 9 nhánh cùng nối đuôi các file này ⇒ xung đột chắc chắn và dễ mất dòng lịch sử
(GOVERNANCE §3.5). Hub ghi **một** dòng lịch sử cho mỗi lần land, giữ nguyên văn bằng
chứng agent đưa trong PR.

## 4. Thứ tự land đề xuất

Nguyên tắc: **lane nào thay đổi màn hình mà lane khác tiêu thụ thì land trước**;
L1 (cabin) tiêu thụ cả ba tab nên land **cuối**, trừ khi owner yêu cầu ngược.

| Đợt | Lane | Vì sao |
|---|---|---|
| 1 | L6 VieNeu | cô lập nhất (`packages/in4up_stt` + engine); mở đường cho L8 |
| 1 | L4 bong bóng dịch | chỉ `screen_translate` + Kotlin overlay |
| 1 | L5 Web/YouTube Linux | chỉ `web_reader`/`youtube`/`linux` |
| 1 | L7 tệp & "Mở bằng" | manifest/Info.plist + nơi lưu; phải trước L2 |
| 2 | L8 TTS hệ thống Android | sau L6 (dùng chung `TtsService`/Cài đặt) |
| 3 | L3 Tab Đọc/PDF/OCR | phải trước L1 (đích tài liệu đọc) |
| 4 | L2 Âm thanh & video | phải trước L1 và L9 (tab Nghe) |
| 5 | L9 Shadowing & UI | phải trước L1 (tab Nói/Hiểu) |
| 6 | L1 Live cabin | tiêu thụ Đọc/Nghe/Hiểu + phiên |

Mỗi đợt: land → CI trên beta tip → ghi nhật ký → mới sang đợt kế. Không land hai
nhánh cùng lúc khi chưa biết CI của nhánh trước xanh.

## 5. Cổng kiểm

| Cổng | Ai | Nội dung | Điều kiện qua |
|---|---|---|---|
| **G0** | agent | tự kiểm theo §3.2, PR vào beta | CI nhánh + PR xanh, không đổi file ngoài lane |
| **G1** | hub | rà diff từng nhánh: phạm vi, version, KANBAN, i18n, test được wire | `git diff --check`; `python3 tool/generate_priority_native_pack.py --check`; test mới thật chạy; analyze 0 error |
| **G2** | hub | chéo lane: CI trên beta tip sau mỗi đợt + build web (`deploy-web`) + rà xung đột ngữ nghĩa ở file dùng chung; **lane L6 thêm `vieneu_engine_build`** (native arm64) | `app_analyze` 🟢, `listen_queue_tests` 🟢, `deploy-web` 🟢 (build, không cần publish), `vieneu_engine_build` 🟢 khi có thay đổi native |
| **G3** | owner | nghiệm thu máy thật theo cột "AT" từng lane (Android/iOS/Windows/Linux) | owner xác nhận trong chat/Linear |
| **G4** | hub | bump `1.29.0+29` **một lần**, tag beta, build 4 nền tảng, web | build 4/4 🟢; tag là **prerelease** |
| **G5** | hub + owner | đưa sang 251e bằng PR base 251e (merge thường); nếu 251e đã tiến hoá thì rebase beta lên tip mới trước | PR xanh, owner bấm merge |

**Không được** tag/build bản beta trước G4: `pubspec` còn `1.28.0+28` thì APK/IPA sẽ mang
version 1.28.0 trong khi tag là 1.29.0 — sai lệch không sửa được sau khi phát.

## 6. Phiên bản & tag

- Trong suốt thời gian land: **`version: 1.28.0+28`** (không đổi). Hub kiểm ở G1.
- G4: một commit duy nhất `chore(release): bump 1.28.0+28 → 1.29.0+29`.
- Tag beta: `1.29.0-beta.1`, `1.29.0-beta.2`, … (tăng dần mỗi lần build lại).
  `build_final_complete.yml` nhận tag bắt đầu bằng chữ số nên tag này kích hoạt đúng workflow.
- Tag phải là **prerelease** để không chiếm nhãn "Latest" của GitHub. `build_final_complete.yml`
  đã được sửa để tự đặt `prerelease` khi tên tag/version có chữ `beta` (4 bước release).
- Bản phát hành chính thức vẫn là `1.29.0` cắt từ 251e **sau** G5, theo đúng quy trình các
  bản 1.24–1.28 (card `REL-1.29.0` sẽ được tạo ở 251e, không phải ở đây).
- `versionCode` 28 → 29 ⇒ cài đè 1.28.0 được, dữ liệu giữ nguyên.

## 7. Checklist hub khi nhận một nhánh

1. `git fetch origin` rồi `git log --oneline HEAD..origin/<nhánh>` — đọc commit, không đọc mô tả PR.
2. `git diff --stat HEAD...origin/<nhánh>` — đối chiếu §2; file lạ ⇒ hỏi agent/owner trước khi land.
3. Kiểm version: `git show origin/<nhánh>:pubspec.yaml | head` (đúng `1.28.0+28`).
4. Kiểm KANBAN/PLAN không bị sửa trên nhánh con (nếu có ⇒ giữ phần beta, chép bằng chứng vào card hub).
5. Merge: `git merge --no-ff origin/<nhánh> -m "merge(beta): L<n> …"`, resolve xung đột theo
   GOVERNANCE §3.5 (giữ cả hai phía, phần beta đứng trước) — **không** rebase lịch sử đã đẩy.
6. Push beta → chờ `app_analyze` + `listen_queue_tests` trên tip mới; đỏ thì sửa tại beta
   hoặc trả lại agent, **không** land nhánh kế.
7. Cập nhật §2 (trạng thái lane) + §8 (nhật ký) + card `BETA-1.29.0` trong KANBAN trong **cùng commit**.
8. Ghi rõ điều chưa kiểm được (máy thật) — hub không được tuyên bố thay owner.

## 8. Nhật ký (append-only)

- 2026-11-12 | created | agent `arena/60e35d65-in4up` | owner giao nhánh làm Beta hub cho
  v1.29.0: 9 lane / 30 issue Linear ([PSRC-199…228](https://linear.app/in4up/project/i4u)),
  land vào đây để kiểm thử trước khi sang 251e. Chưa có nhánh con, chưa có code mới trên
  nhánh này; `pubspec` giữ `1.28.0+28`.
- 2026-11-12 | hub dựng xong | agent `arena/60e35d65-in4up` | 2 commit `74488d5` (tài liệu +
  script) và `e4f67c2` (workflow). **Baseline CI trên `e4f67c2`: `app_analyze` run
  [43296883675](https://github.com/Pabhassaracitto/In4Up/actions/runs/43296883675) 🟢 4/4 job**
  (analyze · knowledge-regressions · vocabulary-tools · web-build-validation) — mã y hệt
  251e nên đỏ ở đây là do lane, không do nền. `deploy-web` **không chạy** khi push (đúng
  luật loại trừ ở §5/G2). `pubspec` vẫn `1.28.0+28`; chưa có nhánh con.
- 2026-11-12 | L6 mở khoá kỹ thuật | agent `arena/60e35d65-in4up` | owner chốt *"VieNeu thực sự
  hoạt động"* ⇒ ADR-0028 + gitlink `third_party/audio.cpp` v0.9.4 + `third_party/sea-g2p`
  v0.10.0 + workflow `vieneu_engine_build.yml` + wrapper trộn stereo→mono / truyền SEA-G2P
  + 4 test hợp đồng. **Chưa có build NDK xanh** — đó là cổng của lane L6, không phải việc
  đã đóng.
- 2026-11-13 | phiếu việc tách rời | agent `arena/60e35d65-in4up` | toàn bộ nội dung kỹ thuật
  của lane chuyển vào `docs/project/beta-1.29.0/` (`README.md` + `PROMPTS.md` + 11 phiếu) để
  owner chỉ nhắn **một câu**/agent, không dán ngữ cảnh; thêm **L10** (PDF/Web reader 229/231/232)
  và **L11** (chốt PSRC-6/PSRC-14 + phân loại backlog cũ ≤ PSRC-196, ngoài cổng); gán
  PSRC-224…233; chốt luật một-issue-một-commit + chỉ rebase để land tuyến tính vào 251e.
  **Không đổi code.**
- 2026-11-14 | land 2 lane đầu | agent `arena/60e35d65-in4up` | beta tuyến tính: `3e3ca64` →
  **L8** `d3819528`+`fe0832ac` (PSRC-221 giọng đọc hệ thống Android) → **L4** `5ed57656`
  (PSRC-211). Hai nhánh L4 cùng làm một issue: nhận `arena/33cb5b7a-in4up` (có test đầu-cuối
  + chứng minh đỏ-trước-xanh-sau, gộp đoạn/dòng mềm trước khi dịch), giữ `arena/defa5264-in4up`
  làm tham chiếu cho vòng 2 (cutout/insets/xoay, `RegionSelectView` offset, lọc rác trước hạn
  mức). Chi tiết: `beta-1.29.0/L4-hub-tra-loi.md` §7. L8 mang trigger `android/app/src/main/kotlin/**`
  vào `vieneu_engine_build.yml` ⇒ từ nay sửa Kotlin có oracle biên dịch (không cần `workflow_dispatch`).
  Chưa nghiệm thu máy thật (G3).

## 9. Prompt riêng từng lane (dán **sau** khối §3)

Mỗi khối dưới đây chỉ thay phần "NHIỆM VỤ" của §3; các luật còn lại giữ nguyên.

### L1 — Live cabin (`[BETA-1.29.0 · L1]`)

```text
Nhiệm vụ: PSRC-199, PSRC-200, PSRC-201, PSRC-223.
- 199: cho người dùng SỬA và XOÁ nội dung Live cabin (lỗi thực tế: hay thiếu khúc ghi
  của câu đầu). Sửa được cả khi phiên đang chạy lẫn phiên đã lưu; sau khi sửa, bản lưu
  và bản xuất phải đổi theo — không để hai nguồn lệch nhau.
- 200: khi chuyển nội dung cabin sang TÀI LIỆU ĐỌC, cho chọn cặp ngôn ngữ nguồn → đích
  (owner ghi "chủ → đích"; nếu nghĩa khác thì hỏi owner trước khi code) với đích mặc
  định hợp lý, và cho phép chỉnh ngược lại sau khi đã chuyển.
- 201: tuỳ chọn ĐỒNG BỘ phiên sang các tab Đọc / Nghe / Hiểu — mặc định bật tất cả,
  người dùng bỏ tích từng mục. Áp dụng cả popup lưu cuối phiên VÀ phiên đã lưu trong
  thư mục Phiên; riêng tab Nghe phải có lựa chọn đồng bộ vì phiên có file âm thanh khớp chữ.
- 223: cabin OFFLINE (Sherpa) EN→VI chỉ nhận diện/dịch/đọc dòng đầu rồi dừng: đèn ghi âm
  Android vẫn sáng nhưng bộ đếm giây đứng, nói thêm không phản ứng. Chế độ online bình
  thường (Piper vẫn đọc) ⇒ khoanh vùng ở pipeline offline streaming, KHÔNG phải TTS.
Ưu tiên: 199/223 là lỗi chặn dùng; 200/201 là tính năng. Tách commit theo từng issue.
```

### L2 — Âm thanh & video (`[BETA-1.29.0 · L2]`)

```text
Nhiệm vụ: PSRC-202, PSRC-203, PSRC-205, PSRC-219, PSRC-220.
- 202: tách audio từ video (PLAN-048) rồi chọn "mở trong tab Nghe" ⇒ audio không tự mở
  và sau đó bị "dish". Kiểm cả luồng có/không có tiêu đề clip và sau khi khởi động lại.
- 203: sau khi xuất đoạn A–B, bấm CHIA SẺ không có phản ứng gì. Kiểm luôn tab Video.
  Không được im lặng: hoặc mở share sheet, hoặc báo lý do + đường thay thế (mở thư mục).
- 205: "Tạo lời" cho file dài báo "lỗi không xác định"; một số .m4a cũng lỗi (không phải
  tất cả). Mục tiêu: file dài (kể cả hàng tiếng) vẫn tạo lời được — chia đoạn/stream,
  báo tiến độ, không treo; nêu rõ giới hạn thật nếu có.
- 219: Linux vẫn "could not play this track" — tìm đúng tầng (plugin just_audio/backend
  Linux vs codec), đừng chỉ bọc try/catch.
- 220: Linux mở .mp4 ở tab View ⇒ "cannot open video: UnimplementedError int() has not
  been implemented". Xác định API nào bị thiếu trên Linux rồi chọn đường thay thế.
```

### L3 — Tab Đọc & PDF/OCR (`[BETA-1.29.0 · L3]`)

```text
Nhiệm vụ: PSRC-206, PSRC-207, PSRC-208, PSRC-209, PSRC-210.
- 206: quét thư mục có RẤT NHIỀU tài liệu ⇒ Android báo "In4Up không phản hồi"; mở lại
  thì hết, nhưng mở danh sách thư viện bị lag. Phải chuyển việc nặng ra khỏi UI thread
  (isolate/stream), có tiến độ và huỷ được.
- 207: một số .docx báo không mở được nội dung (dự án mở được .docx khác; .doc 97-2003
  KHÔNG cần hỗ trợ). Tìm đúng khác biệt định dạng (ví dụ .docx không có styles/khác
  content-type) và báo lỗi nêu được lý do thay vì "không mở được".
- 208: chế độ TT chỉ hiện chữ của trang thứ 2, các trang còn lại trống.
- 209: sau OCR, "tinh chỉnh bằng AI" báo "không thể tinh chỉnh ngay lúc này, kiểm tra
  cấu hình AI" dù AI đã cấu hình và chạy được ở chức năng khác.
- 210: từ chế độ TT, gợi ý quét OCR nhưng khi quét ngay tại đó lại quét chính vùng trống
  TT thay vì trang PDF thật; chọn icon PDF rồi OCR thì đúng. Sửa nguồn ảnh đưa vào OCR.
```

### L4 — Bong bóng dịch (`[BETA-1.29.0 · L4]`)

```text
Nhiệm vụ: PSRC-211 (Linear có ảnh chụp).
Bong bóng dịch bỏ sót nhiều khối không dịch; border còn thừa bên dưới; cần bo/nới để đủ
chỗ cho các khối dịch liền kề khi có; và một số bản dịch nằm sai chỗ.
Yêu cầu: đủ khối (không bỏ sót) · khung đủ chỗ, không cắt chữ (đã có sàn 10sp từ
XLAT-SCR-006 — không phá) · khối dịch neo đúng khối gốc khi cuộn/đổi tỉ lệ.
Đây là native overlay (Kotlin) + Dart layout: sửa cả hai phía, có test thuần cho phần
tính khung (screen_translate_overlay_layout / geometry).
```

### L5 — Web & YouTube trên Linux (`[BETA-1.29.0 · L5]`)

```text
Nhiệm vụ: PSRC-212, PSRC-213.
Linux: chọn biểu tượng Web ⇒ màn hình ĐEN; tìm bài YouTube xong chọn 1 bài ⇒ cũng ĐEN
như vậy. Hai lỗi có biểu hiện giống nhau nhưng CHƯA chắc cùng nguyên nhân — điều tra
tầng webview/texture trên Linux (plugin, GL, compositing), đừng chỉ vá UI.
Nếu Linux không có backend webview khả dụng: nói thẳng giới hạn và cho UI báo lý do
thay vì màn hình đen.
```

### L6 — VieNeu / Vieu-TTS (`[BETA-1.29.0 · L6]`)

```text
Nhiệm vụ: PSRC-214, PSRC-215, PSRC-216, PSRC-217, PSRC-218.
Chuỗi lỗi liên hoàn: import ở mục phía trên không nhận model · import Q8_0 (~170 MB)
được báo "thành công" nhưng kèm "bản cài chưa kèm engine VieNeu-TTS" · khởi tạo engine
báo "kiểm tra file gguf và thư viện native" · import giọng báo lỗi · tạo giọng từ mẫu
đã ghi âm báo "kiểm tra mô hình TTS và mẫu thu âm". Hiện chỉ có giọng Minh Quang Pro.
ĐỌC TRƯỚC card TTS-VIENEU-SHIP-001: `libvieneu_tts.so` không có trong bản cài vì gitlink
`third_party/audio.cpp` chưa từng được commit — đây là quyết định của OWNER (có ship
native + build NDK hay không). Nếu lane cần ship native để thật sự chạy được: DỪNG, báo
owner chọn, đừng tự ý commit submodule/NDK. Phần chắc chắn làm được ngay: import đúng
mọi mục (kể cả mục phía trên), thông điệp đúng sự thật, không cho "thành công" giả,
không crash, và nêu rõ engine nào đang thiếu.
```

### L7 — Tệp, nơi lưu & "Mở bằng" (`[BETA-1.29.0 · L7]`)

```text
Nhiệm vụ: PSRC-204 (**đã có quyết định — ADR-0029**, KHÔNG đánh giá lại), PSRC-222 (triển khai).
Làm đúng ADR-0029: mặc định `Download/In4Up` (+ iOS `Files → On My iPhone/In4Up`,
desktop `~/In4Up`), đổi cho từng lần xuất qua SAF, dữ liệu app (phiên cabin, model,
DB) **không** đưa ra thư mục công khai. Ba điểm còn treo ở ADR-0029 §6 hỏi hub
trước khi code phần tương ứng.
- 204: đánh giá cho người dùng chọn/đổi nơi lưu âm thanh–ghi âm (thư mục mang tên ứng
  dụng ở bộ nhớ trong). KHÔNG tự coi là đã chốt: trả lời được 3 câu — nền tảng nào làm
  được (Android SAF/scoped storage, iOS, desktop), quyền/hệ quả khi đổi nơi lưu sau khi
  đã có dữ liệu, và chi phí migration. Kết luận + đề xuất, chưa code feature lớn nếu owner
  chưa duyệt.
- 222: cho chọn "Mở bằng In4Up" từ ngoài app cho .txt/.pdf/.docx/.md/.mp3/.m4a/.mp4
  (và định dạng đã hỗ trợ khác): Android intent-filter + nhận Intent, iOS document types,
  desktop file association. Không nhân đôi logic mở tệp — dùng chung đường import sẵn có.
```

### L8 — Giọng đọc hệ thống Android (`[BETA-1.29.0 · L8]`)

```text
Nhiệm vụ: PSRC-221.
Đưa In4Up thành TTS ENGINE của hệ thống Android (như Sherpa APK đã làm), lấy Piper đang
chạy tốt làm cơ sở: service `TextToSpeechService` + engine metadata XML + manifest +
danh sách giọng/ngôn ngữ hệ thống hỏi được. Không được làm hỏng TTS trong app (Piper,
Edge, VieNeu đang chạy): engine hệ thống là tiến trình/đường riêng.
Phụ thuộc L6 về màn Cài đặt TTS — land sau L6. Nếu cần model/giọng ngoài phạm vi bản cài,
nêu rõ điều kiện và hỏi owner thay vì tự tải.
```

### L9 — Shadowing & UI tab Nói/Hiểu (`[BETA-1.29.0 · L9]`)

```text
Nhiệm vụ: PSRC-224, PSRC-225, PSRC-226, PSRC-227, PSRC-228.
- 224: tab Nghe → "tạo lời" có mục SHADOW; nếu ở đó không có chức năng thật thì LƯỢC BỎ
  (kiểm trước, đừng xoá mù).
- 225: tab Nói quá nhiều chữ, rối mắt ⇒ có chế độ bung/gộp; nếu có Shadowing Mode thì
  đưa lên đầu như phần trung tâm màn hình.
- 226: Shadowing tab Nói → "Gợi ý theo câu": chọn một dòng rồi "Nghe mẫu" thì audio đọc
  trôi QUÁ dòng đã chọn; phải khớp đúng câu.
- 227: chấm điểm SAI ở cả tab Nói và tab Hiểu — đọc sai/đọc vài từ vẫn điểm cao, báo
  "đúng hết". Đây là lỗi nghiêm trọng nhất của lane: ưu tiên làm rõ thang điểm và
  ngưỡng, có test thuần cho bộ chấm.
- 228: Shadowing tab Hiểu thiếu các dòng gợi ý và "nghe mẫu" đọc hết nội dung thay vì
  theo câu (giống 226).
Ưu tiên: 227 (điểm sai) → 226/228 (đọc trôi) → 224 → 225 (UI).
```

## 10. Đề xuất nơi lưu tệp (PSRC-204) — owner ĐÃ CHỐT 2026-11-12 → [ADR-0029](../adr/0029-noi-luu-tep-mac-dinh-va-doi-tung-lan.md)

> **Chốt:** owner chọn đúng mô hình dưới đây (2026-11-12). Quyết định chính thức +
> chi tiết kỹ thuật + 3 điểm còn phải chốt khi lane L7 bắt đầu: [ADR-0029](../adr/0029-noi-luu-tep-mac-dinh-va-doi-tung-lan.md).

Trả lời ngắn: **cả hai, nhưng phân tầng** — một **nơi lưu mặc định** đặt
một lần, và **quyền đổi cho từng lần xuất** khi người dùng muốn. Không chọn một trong hai.

### 10.1 Mô hình đề xuất

| Tầng | Nội dung | Vì sao |
|---|---|---|
| **Mặc định (không hỏi lại)** | Thư mục công khai mang tên app: Android `Download/In4Up/` · iOS `Files → On My iPhone/In4Up` · Windows/Linux `~/In4Up` | Người dùng mở Files/Downloads là thấy; không cần quyền rộng; không phải nhớ đường dẫn `Android/data/com.in4up/...` (đa số máy không vào được) |
| **Đổi cho riêng lần xuất** | Hộp thoại xuất ghi rõ *"Lưu vào: Download/In4Up"* + nút **Đổi…** (SAF `ACTION_OPEN_DOCUMENT_TREE`) + tick *"Luôn lưu vào thư mục này"* | Xuất hàng loạt/lặp lại thì không bị hỏi liên tục; ai muốn đưa vào thư mục riêng (Drive, thẻ nhớ) vẫn làm được |
| **Dữ liệu app tự quản** | Phiên cabin, model, DB, cache ⇒ **giữ trong thư mục riêng của app** | Không cho người dùng xoá nhầm; tránh app bị coi là "trình quản lý tệp" |

Nguyên tắc: **dữ liệu do người dùng tạo ra và muốn mang đi** (file xuất A–B, bản ghi âm đã
lưu, bản dịch) → thư mục công khai; **dữ liệu app cần để chạy** → thư mục riêng.

### 10.2 Vì sao không chọn "chỉ cố định" hoặc "chỉ hỏi từng file"

- **Chỉ cố định:** người dùng không tìm thấy tệp khi cần gửi đi; đổi ý phải vào Cài đặt.
- **Hỏi từng file:** xuất 10 đoạn A–B liên tiếp = 10 hộp thoại; đó là kiểu UX bị bỏ dùng.
- **Ghi thẳng vào bất kỳ đường dẫn nào** (kiểu desktop cũ) trên Android 11+ cần
  `MANAGE_EXTERNAL_STORAGE` ⇒ Play policy, dễ bị từ chối — không đi đường này.

### 10.3 Chi tiết theo nền tảng

| Nền tảng | API | Ghi chú |
|---|---|---|
| Android 10+ | `MediaStore.Downloads` (tạo thư mục con `In4Up/`) hoặc SAF `ACTION_CREATE_DOCUMENT` | Không cần quyền bộ nhớ; `IS_PENDING` khi đang ghi rồi publish |
| Android ≤ 9 | `WRITE_EXTERNAL_STORAGE` (đã khai trong manifest?) — chỉ đường dự phòng | Giữ tương thích, không mở rộng |
| iOS | App container `Documents/In4Up` + `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` | Hiện trong Files; "Đổi…" = `UIDocumentPickerViewController` |
| Windows / Linux | `path_provider` → `getDownloadsDirectory()` fallback `~/In4Up` | Desktop không cần hộp thoại xác nhận mỗi lần |

### 10.4 Migration & an toàn

1. **Không tự di chuyển** tệp cũ. Tệp đã xuất ở `Android/data/...` vẫn mở được (danh sách
   "Đã xuất" đọc theo đường dẫn đã lưu).
2. Cài đặt có nút **"Chuyển bản xuất cũ sang Download/In4Up"** (chỉ khi người dùng bấm,
   có xác nhận + báo số tệp/ dung lượng).
3. Tên tệp giữ theo `lib/features/media_tools/services/media_export_naming.dart` (đã có
   timestamp + nhãn nguồn) — không đổi quy ước.
4. Kiểm trùng tên: thêm ` (2)` thay vì ghi đè.
5. Nếu thư mục người dùng chọn bị xoá/mất quyền (SAF URI chết) ⇒ quay về mặc định + báo
   một lần, không lỗi im lặng.

### 10.5 Việc cần owner chốt trước khi lane L7 code

- Tên thư mục: **`In4Up`** (khớp tên app) hay `in4up` (chữ thường, tránh lệch trên Linux)?
  Đề xuất: **`In4Up`** cho Android/iOS/Windows, giữ đúng một tên.
- Có làm nút "Chuyển bản xuất cũ" ở bản 1.29 không, hay để 1.30?
- Bản ghi âm cabin (`.wav`) có xuất ra thư mục công khai ngay khi lưu phiên, hay chỉ khi
  người dùng bấm "Xuất"? Đề xuất: **chỉ khi bấm Xuất** — tránh thư mục công khai đầy tệp
  tạm.

## 11. Số đo engine VieNeu (cập nhật 2026-11-12)

| Chỉ số | Giá trị | Nguồn |
|---|---|---|
| Job `vieneu_engine_build` (checkout → APK, gồm cargo-ndk + compile ggml ×2) | **17m 05s** (18m 52s khi thêm bước đo) | run 43325244915 / 43328297538 |
| Artifact `vieneu-engine-arm64` (APK debug + log) | 259,7 MiB | `actions/artifacts` id 13993467652, 272.305.723 byte |
| `libaudiocpp.so` / `libsea_g2p_rs.so` / `libvieneu_tts.so` | **4,9 / 4,2 / 0,9 MiB** (≈10 MiB engine, chưa nén) | annotation "VieNeu engine measurements", run 43328297538 |
| Job lần đo (có thêm bước đo) | 18m 52s | run 43328297538 (23:22:26→23:41:18 UTC) |
| APK debug | chỉ để chứng minh engine có mặt; **số phát hành** lấy từ build release ở G4 |

Ghi chú: build **debug** phình to vì kèm symbol; đừng dùng số này để ước lượng APK phát
hành. Con số cần cho quyết định sản phẩm là *chênh lệch* APK release trước/sau khi có
`:vieneu`, đo ở G4.

- 2026-11-12 | L6 (tiếp) | agent `arena/60e35d65-in4up` | **đường tải/import `sea_g2p.bin`
  trong app** (owner chọn việc này): service tải + `.part` + sha256 + rename, nhập từ tệp,
  engine chặn trước khi nạp 170 MB, card UI + 13 chuỗi × 8 locale, test riêng. Sửa con số
  sai trước đó: từ điển **62.829.820 byte (~60 MiB)**, không phải 30 MB. CI: `app_analyze`
  **43360617301** 🟢 4/4 + `listen_queue_tests` **43360617254** 🟢 — **chưa chạy máy thật**.
- 2026-11-12 | PSRC-204 chốt | agent `arena/60e35d65-in4up` | owner duyệt mô hình nơi lưu
  ⇒ **ADR-0029** (mặc định công khai + đổi từng lần; dữ liệu app giữ riêng); lane L7 không
  phải đánh giá lại, chỉ thi công.
