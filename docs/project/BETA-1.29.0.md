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
| L1 | Live cabin | [199](https://linear.app/in4up/issue/PSRC-199) sửa/xoá nội dung · [200](https://linear.app/in4up/issue/PSRC-200) chọn chủ→đích khi chuyển sang tài liệu đọc · [201](https://linear.app/in4up/issue/PSRC-201) tuỳ chọn đồng bộ phiên sang Đọc/Nghe/Hiểu (cả phiên đã lưu) · [223](https://linear.app/in4up/issue/PSRC-223) cabin offline Sherpa dừng sau dòng đầu | `lib/features/cabin/**` (`live_cabin_screen`, `cabin_session_store`, `stts_cabin_service`, `cabin_read_bridge`) · `lib/screens/listen_mode/**` (audio phiên) · `lib/screens/read_mode/**` + `lib/screens/text_library/**` (đích) | — | ✅ land `96cf043a` `f3f65d89` `23c096e9` `6fcc7936` `70ca3a4a` |
| L2 | Âm thanh & video | [202](https://linear.app/in4up/issue/PSRC-202) audio tách từ video không tự mở rồi bị "dish" · [203](https://linear.app/in4up/issue/PSRC-203) chia sẻ sau xuất A–B không phản hồi (kiểm cả tab Video) · [205](https://linear.app/in4up/issue/PSRC-205) tạo lời file dài + m4a · [219](https://linear.app/in4up/issue/PSRC-219) Linux "could not play this track" · [220](https://linear.app/in4up/issue/PSRC-220) Linux `.mp4` ở tab View | `lib/features/video/**` · `lib/features/media_tools/**` (`media_export_service`) · `lib/screens/listen_mode/**` (player, tạo lời) · `linux/**` | — | ✅ land `bc8392ac`→`558e1587` (6 commit) |
| L3 | Tab Đọc & PDF/OCR | [206](https://linear.app/in4up/issue/PSRC-206) quét thư mục nhiều tài liệu ⇒ treo/lag · [207](https://linear.app/in4up/issue/PSRC-207) `.docx` không mở · [208](https://linear.app/in4up/issue/PSRC-208) chế độ TT chỉ ra chữ trang 2 · [209](https://linear.app/in4up/issue/PSRC-209) tinh chỉnh AI sau OCR báo sai cấu hình · [210](https://linear.app/in4up/issue/PSRC-210) OCR từ TT quét vùng trống | `lib/screens/read_mode/**` · `lib/screens/text_library/**` · `lib/services/text_source_loader.dart` · `lib/features/pdf_reader/**` · `lib/features/ocr/**` | — | ✅ land `8ae45100`→`bd8e788f` (7 commit) |
| L4 | Bong bóng dịch | [211](https://linear.app/in4up/issue/PSRC-211) bỏ sót khối, border dư dưới, bản dịch sai chỗ | `lib/features/screen_translate/**` · `android/app/src/main/kotlin/com/in4up/screentranslate/**` (`TranslationOverlayView`, `ScreenTranslateService`) | — | ✅ land `5ed57656` + `6d596c6d` (vòng 2: chip thu gọn, pending 32, insets) |
| L5 | Web & YouTube trên Linux | [212](https://linear.app/in4up/issue/PSRC-212) biểu tượng Web ⇒ màn hình đen · [213](https://linear.app/in4up/issue/PSRC-213) chọn kết quả YouTube ⇒ màn hình đen | `lib/features/web_reader/**` · `lib/features/youtube/**` · `linux/**` | — | ✅ land `0bfadd3a` `d74c1cfb` |
| L6 | VieNeu / Vieu-TTS | [214](https://linear.app/in4up/issue/PSRC-214) import phía trên không nhận model · [215](https://linear.app/in4up/issue/PSRC-215) import Q8_0 "thành công" nhưng thiếu engine · [216](https://linear.app/in4up/issue/PSRC-216) không khởi tạo engine · [217](https://linear.app/in4up/issue/PSRC-217) import giọng lỗi · [218](https://linear.app/in4up/issue/PSRC-218) tạo giọng từ mẫu thu lỗi | `packages/in4up_stt/lib/tts/vieneu_tts_core.dart` (+ worker isolate) · `lib/features/tts/engines/vieneu_tts_engine.dart` · `lib/screens/settings/**` (TTS) · `native/tts_vieneu/**` + CMake | — | ✅ land `a518b5b4` `ecea19b5` `ab827a20` `b6ef3853` `312ad17e` |
| L7 | Tệp, nơi lưu & "Mở bằng" | [204](https://linear.app/in4up/issue/PSRC-204) **đã chốt mô hình** (ADR-0029): mặc định `Download/In4Up` + đổi từng lần xuất · [222](https://linear.app/in4up/issue/PSRC-222) mở `.txt/.pdf/.docx/.md/.mp3/.m4a/.mp4` bằng In4Up | `android/app/src/main/AndroidManifest.xml` · `ios/Runner/Info.plist` · `lib/services/**` (nhận tệp) · `lib/features/media_tools/services/media_export_service.dart` (nơi lưu) · `lib/screens/text_library/**` · `linux/**` + `windows/**` (liên kết tệp) | — | ✅ land `0c19c57c` `7bc0d645` |
| L8 | Giọng đọc hệ thống Android | [221](https://linear.app/in4up/issue/PSRC-221) In4Up thành TTS engine của hệ thống (như Sherpa APK), lấy Piper làm cơ sở | `android/app/src/main/kotlin/**` (service TTS mới + engine XML + manifest) · `lib/screens/settings/**` (công tắc/hướng dẫn) | — | ✅ land `d3819528` `fe0832ac` |
| L9 | Shadowing & UI tab Nói/Hiểu | [224](https://linear.app/in4up/issue/PSRC-224) rà và bỏ mục Shadow ở "tạo lời" tab Nghe nếu vô dụng · [225](https://linear.app/in4up/issue/PSRC-225) thu gọn nội dung tab Nói, ưu tiên Shadowing · [226](https://linear.app/in4up/issue/PSRC-226) "Nghe mẫu" trôi quá dòng đã chọn · [227](https://linear.app/in4up/issue/PSRC-227) chấm điểm sai (tab Nói + tab Hiểu) · [228](https://linear.app/in4up/issue/PSRC-228) tab Hiểu thiếu gợi ý + đọc hết nội dung | `lib/features/shadowing/**` · `lib/screens/listen_mode/speak_mode_screen.dart` · `lib/screens/understand_mode/**` · `lib/screens/listen_mode/**` (mục Shadow) | — | ✅ land `0f8fbcc7` `12e71c42` `7bd01805` `e7e1c7d5` + PSRC-224 `18fe1711` |

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

### 2.4 Trạng thái land thật (2026-11-14, hub) — đọc mục này, đừng tin Linear

**Tip beta:** `0f71657b`. **43+ commit, 0 merge commit** ⇒ lịch sử tuyến tính.
**11/11 lane đã land**, đủ **35/35 issue cổng** PSRC-199…233 (PSRC-224 land muộn, `18fe1711`).

| Lane | Commit trên beta | Issue |
|---|---|---|
| L1 | `96cf043a` `f3f65d89` `23c096e9` `6fcc7936` + docs `70ca3a4a` | 199, 223, 200, 201 |
| L2 | `bc8392ac` `10d58cd8` `629108bb` `a9fa7d42` `bb2ecbfb` + docs | 202, 203, 205, 219, 220 |
| L3 | `8ae45100` `2f26847f` `180b7cd7` `cc1a4274` `072b1fcd` `5fb4bf66` `bd8e788f` | 206–210, 230, 233 |
| L4 | `5ed57656` (vòng 1) `6d596c6d` (vòng 2) | 211 |
| L5 | `0bfadd3a` `d74c1cfb` | 212, 213 |
| L6 | `a518b5b4` `ecea19b5` `ab827a20` `b6ef3853` `312ad17e` | 214–218 |
| L7 | `0c19c57c` `7bc0d645` | 204, 222 |
| L8 | `d3819528` `fe0832ac` | 221 |
| L9 | `0f8fbcc7` `12e71c42` `7bd01805` `e7e1c7d5` + `18fe1711` | 226, 228, 227, 225, **224** |
| L10 | `75776b9b` `8e1c7679` `6fbd0ea1` + docs `332ee4a5` | 229, 231, 232 |
| L11 | `f97f849c` `b56ec259` `0f71657b` | PSRC-6, PSRC-14 + phân loại ≤196 (ngoài cổng) |

Hai việc hub sửa cùng đợt:

- **PSRC-224** (`18fe1711`): nút "Shadowing" ở phần tạo lời **không phải** Shadowing mà là mic
  trực tiếp (`startConversation`, chỗ duy nhất trong app gọi hàm này) ⇒ giữ chức năng, đổi nhãn
  thành "Mic trực tiếp"/"Dừng mic" + i18n 8 locale. Không xoá để khỏi mất chức năng thật.
- **deploy-web** (`16a93f9f`): step publish thêm `if: github.ref == 'refs/heads/main'`, và
  `concurrency.group` đổi thành `github-pages-${{ github.ref }}` ⇒ nhánh lane không còn publish
  đè site thật và không huỷ run của nhau.

**CI của tip (kiểm 2026-11-14):** run `43601469838` (App Analyze + Locale Test — wide oracle,
5 job: analyze-and-locale-test, knowledge-regressions, vocabulary-tools, web-build-validation) và
run `43601469820` (Listen queue regression tests) trên `16a93f9f` ⇒ **tất cả xanh**.
`16a93f9f` là commit đầu của lượt push cuối nên **mang theo cả `18fe1711`** (một lượt push chỉ
sinh run cho commit đầu); `dfe7006a` / `0f71657b` / `f97f849c` / `b56ec259` là commit **docs** nằm
ngoài `paths:` của `app_analyze.yml` / `listen_queue_tests.yml` nên **không sinh run** — đúng thiết
kế, không phải CI thiếu. `workflow_dispatch` trên nhánh này vẫn bị 403 với token sandbox ⇒ chỉ
theo dõi được run do push.

**deploy-web không chạy cho nhánh beta** — `on.push.branches` có `'!arena/60e35d65-in4up'`, nên
việc "site thật bị đè" chỉ có thể đến từ nhánh lane khác; commit `16a93f9f` đã chặn nốt đường đó
(publish chỉ từ `main`).

**Đừng tin Linear/doc cũ để biết trạng thái**: Linear còn nhiều issue ở Backlog dù code đã land.
Nguồn sự thật là `git log` trên nhánh này.

### 2.5 Build `1.29.0-Beta` lần 1 (2026-11-14) — 4/4 nền tảng đỏ, nguyên nhân và cách sửa

Owner chạy `workflow_dispatch` trên tip `d7255451` (run **43628417444**): Android, Windows, iOS, Linux
đều đỏ; analyze trên cùng commit (run **43627869866**) cũng đỏ. Bốn lỗi, ba trong đó là **hạ tầng/workflow**
chứ không phải code của lane.

| Nền tảng | Lỗi trong log | Gốc | Sửa |
|---|---|---|---|
| Linux | `Target "media_kit_video_plugin" links to: PkgConfig::mpv but the target was not found` (CMake configure) | `media_kit_libs_linux` chỉ tải mimalloc rồi bật `MEDIA_KIT_LIBS_AVAILABLE`; `media_kit_video/linux/CMakeLists.txt` gọi `pkg_check_modules(mpv IMPORTED_TARGET mpv)` **không** `REQUIRED` rồi vẫn `target_link_libraries(... PkgConfig::mpv)` ⇒ tìm hụt là chết | cài `libmpv-dev` + `libepoxy-dev` (build-time) trong `build_final_complete.yml` (`d3b7c86`) |
| Android | `ANDROID_NDK_HOME=...ndk/28.2.13676358` ≠ `ANDROID_NDK_ROOT=...ndk/27.3.13750724` → `No such file or directory` | bước build SEA-G2P hard-code NDK 28.2, nhưng bước `Install NDKs` nằm **sau** nó và runner chỉ có 27.3 | lấy NDK đang có thật, đặt cả 3 biến về cùng đường dẫn (`d3b7c86`) |
| Windows | `2 Error(s)` (không có dòng lỗi trong log) | cây PDFium lệch: lock nâng `pdfrx 2.4.8`/`pdfrx_engine 0.4.7` nhưng `pdfium_dart` bị ghim `0.1.2` + `pdfium_flutter` là path dep `0.1.9` ⇒ engine gọi `getPdfium(modulePath:)` không tồn tại | ghim `pdfrx: 2.2.24` + trả `pdfrx`/`pdfrx_engine` trong lock về `2.2.24`/`0.3.9` (`4db1a40`) |
| iOS | `** BUILD FAILED **` (chỉ thấy warning của whisper) | cùng cây PDFium lệch như Windows | như trên (`4db1a40`) |

Lỗi **thật sự chặn analyze** (và là bằng chứng của cả Windows/iOS) đọc được từ annotation:

```text
pdfrx_engine-0.4.7/lib/src/native/pdfium.dart:11:41: Error: No named parameter with the name 'modulePath'.
  _pdfium ??= pdfium_bindings.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
pdfium_dart-0.1.2/lib/src/pdfium_downloader.dart:28:32: Context: Found this candidate, but the arguments don't match.
```

**Luật rút ra:** muốn nâng `pdfrx` thì phải nâng `pdfium_dart` + `pdfium_flutter` cùng lúc — `dependency_overrides`
đang ghim chặt cây PDFium nên `^2.2.1` sẽ âm thầm sinh tổ hợp hỏng. `pdfrx` nay ghim **chính xác** `2.2.24`.

**Vì sao đọc được lỗi:** log Actions nằm ở `productionresultssa*.blob.core.windows.net` — sandbox agent bị
chặn egress (`gh run view --log` trả EOF). Kênh duy nhất là **annotation** của check-run. Vì vậy 3 job
Linux/Windows/iOS giờ `tee` log ra `/tmp/build_*.log` rồi khi đỏ chạy
`scripts/ci/emit_failure_annotation.py` (`d3b7c86`), và script được mở rộng để bắt `Error:`/`error C####`/
`error LNK####`/`error MSB####`/`** BUILD FAILED **`/`Failed to load` + 10 dòng sau dòng `loading `
(`2bcac0b`).

**Trạng thái xác nhận:**

- `app_analyze` trên `4db1a40` = run **43631309682** 🟢 4/4 job (đã hết lỗi biên dịch; 2 test
  `linux_shell_regression_test` / `linux_web_reader/linux_external_browser_test` nạp và chạy bình thường).
- **Build 4 nền tảng lần 2 trên `86f7e35` = run [43632940769](https://github.com/Pabhassaracitto/In4Up/actions/runs/43632940769) 🟢
  4/4 job** (Android · Windows · iOS · Linux). Asset trên prerelease `1.29.0-Beta` đều được cập nhật:
  `in4up-Android-arm64-v8a-1.29.0-Beta-86f7e.apk` (204 MB) · `in4up-iOS-1.29.0-Beta.ipa` (95 MB) ·
  `in4up-Windows-1.29.0-Beta.zip` (54 MB) · `in4up-Linux-1.29.0-Beta.tar.gz` (51 MB).
  Bước `Build SEA-G2P (C ABI) cho arm64-v8a` 🟢 ⇒ engine phoneme nay thật sự nằm trong APK.

**Còn nợ trước G4:** `pubspec.yaml` vẫn `1.28.0+28` ⇒ APK/IPA mang version nội bộ **1.28.0 (28)**, chỉ tên
file là 1.29.0-Beta. Phải bump `1.29.0+29` rồi build lại lần cuối trước khi tag chính thức.

### 2.6 PSRC-205 vòng 2 (2026-11-15) — file dài: "lắt nhắt, thiếu đầu câu, Hủy không dừng"

Owner nghiệm thu `1.29.0-Beta` (Linear PSRC-205): `.m4a` ~7 phút lặp `Đang chuẩn bị` → `Đang nhận diện
chunk 1/1` → …, mỗi lượt thêm **một dòng**, rất lâu, dòng **thiếu đầu câu**; bấm **Hủy không dừng**.
`.mp3` 17 phút y hệt. Cả hai đều > 5 phút ⇒ đi đường **VAD pipeline** (`transcript_route_policy`).

| # | Gốc | Chỗ mã | Sửa |
|---|---|---|---|
| 1 | **Băm nát câu** — ngưỡng lặng 100 ms là ngắt giữa hai TỪ; mỗi mảnh 0,5-2 s thành một lượt `transcribeFile` (một lần "Đang chuẩn bị…/chunk 1/1", một dòng LRC) | `SherpaVadService.minSilenceDurationMs = 100` | 100 → **500 ms** + bước **gộp cụm** mới `mergeSpeechSegments` (khoảng lặng ≤ 0,45 s ⇒ cùng cụm; chia **đều** ≤ 14 s để không sinh mẩu đuôi) |
| 2 | **Cắt cụt biên** — 30 ms không cứu phụ âm đầu; đường sherpa còn không pad gì | `speechPadMs = 30`, `_runSherpaVad` map thẳng `s.startTime/endTime` | 30 → **300 ms**, pad cho **cả** đường sherpa (clamp `[0, độ dài file]`) |
| 3 | **Hủy vô hiệu** — UI chỉ hủy facade, nhưng pipeline tự lặp và mỗi lượt `transcribeFile` gọi `resetForNewTranscription()` ⇒ xoá cờ hủy | `cancelLrcGeneration()` | hủy **cả** `_vadIntegration` (pipeline) + trong `resetLrcStateForAudioChange()` |
| 4 | UI lặp chuỗi vô nghĩa | facade không biết đang ở đoạn nào | `SttServiceFacade.progressContext` ⇒ "Đoạn 5/23 · Đang nhận diện…" |

Commit: `04cfdfc`. Guard test: `test/vad/psrc_205_segment_merger_test.dart` (13 ca, hàm thuần + hằng số VAD +
quét nguồn cho pipeline/mixin) — **đã chạy trong CI**: step mới
`PSRC-205 tests — gộp đoạn VAD cho file dài` 🟢 (run **43698277447**, job `analyze-and-locale-test`).

**Chưa kiểm máy thật:** chưa nghe lại đúng file `.m4a` 7 phút / `.mp3` 17 phút của owner; chưa đo mức giảm
thời gian (ước tính số lượt transcribe giảm 5-10×). Hủy giữa một đoạn đang chạy vẫn chờ đoạn đó xong trên
desktop (không hủy được Isolate FFI); mobile dừng ngay giữa các chunk.

### 2.7 PSRC-171 (2026-11-12) — import model xong vẫn "Không thể tạo giọng"

Owner báo: import `vieneu-v3-turbo-q8_0.gguf` (~188 MB) + khởi tạo engine xong nhưng **mọi lần tạo
giọng đều báo "Không thể tạo giọng"**; câu báo lại đổ lỗi cho "mô hình TTS và mẫu thu âm". Ba nguyên
nhân độc lập, cả ba đều nằm sau lớp Dart nên trước đây không nhìn thấy:

| # | Gốc | Bằng chứng | Sửa |
|---|---|---|---|
| 1 | **libaudiocpp.so không có model spec nào.** audio.cpp v0.9.4 (`717efc34`, tag `v0.9.4` → commit `f7ac446`) chỉ nhúng `model_specs/*.json` khi `AUDIOCPP_DEPLOYMENT_BUILD=ON` (mặc định **OFF**), nên `builtin_model_specs()` rỗng và `default_package_spec_path()` ném `model spec not found for family 'vietneu_tts'` (`src/framework/model_spec/package.cpp:490`) | `CMakeLists.txt` L64-67 (`AUDIOCPP_BUILTIN_MODEL_SPEC_ENTRIES` chỉ được thêm entry khi cờ đó bật). `AUDIOCPP_MODEL_SET` / `AUDIOCPP_MODELS` mà bản 1.28 truyền vào chỉ **chọn model nào được biên dịch** (L425-427, L2878+), KHÔNG cấp spec ⇒ không bù được bảng spec rỗng | Wrapper nhúng **đúng** spec của family (`model_specs/vieneu_v3_turbo.json`, 12 279 B) lúc configure; chỉ khi lần nạp đầu báo lỗi chứa `model spec` mới ghi spec ra `<thư mục model>/model_specs/` và nạp lại với `audiocpp_model_config.model_spec_override` |
| 2 | **"Tạo giọng" không mã hoá gì.** `vieneu_tts_clone_voice` cũ ghi `speaker.emb.txt` = **256 số 0** rồi trả THÀNH CÔNG; audio.cpp chỉ nhận **đúng 192** float trên dòng đầu ⇒ mọi lần đọc bằng giọng đó ném `must contain exactly 192 float values` | `vieneu_tts.cpp` (nhánh `embedding_dim = 256`, `emb_file << 0.0f`) | Native giải WAV mẫu (PCM 8/16/24/32 + float 32/64, mono/stereo, chunk `LIST`, WAVE_FORMAT_EXTENSIBLE), cắt 8 s (`_MAX_REF_SECONDS` của upstream), gọi `audiocpp_request_set_voice_audio` + `encode_reference_only=true`, đọc artifact `ACOUSTIC_TOKENS` và ghi **`cloned_voices/<id>/ref_codes.txt`**; xoá luôn `speaker.emb.txt` placeholder cũ trong thư mục giọng |
| 3 | **Thông báo sai nguyên nhân.** Nhánh `catch` của `_initOnce` để `_blockingReason = null` ⇒ UI rơi về câu "kiểm tra mô hình TTS và mẫu thu âm" | `vieneu_tts_engine.dart` | `classifyVieneuNativeLoadError()` phân loại lỗi native thành `modelSpecMissing` / `noPhonemeDictionary` / `voiceDataUnusable` / `engineLoadFailed`; mỗi lý do một câu riêng (8 locale, `tool/priority_native_pack.json`) |

Phụ: engine chỉ truyền `speaker_embedding_file` khi file **đúng 192 số** và khi giọng **không** có
`ref_codes.txt`; native cũng bỏ qua embedding khi đã có ref codes ⇒ file rác của bản 1.28 không còn
làm hỏng giọng.

Test máy bắt: `test/tts/psrc171_voice_creation_test.dart` (source-scan CMake/wrapper/Dart +
`isUsableVieneuSpeakerEmbedding` / `hasVieneuRefCodes` / `classifyVieneuNativeLoadError`).
Bộ giải WAV đã được kiểm bằng harness C++ riêng trên 10 tệp (PCM8/16/24/32, float32/64, stereo 48 kHz,
có chunk `LIST`, file cắt cụt, file không phải WAV).

**Giới hạn còn lại:** `libvieneu_tts` chỉ được build cho **Android arm64-v8a** (ADR-0028). Trên
**Linux/Windows desktop** engine vẫn chưa có trong bản cài ⇒ app báo đúng lý do
`noNativeLibrary` (không còn câu chung), nhưng muốn "tạo giọng" chạy trên Linux thì cần một dự án
build desktop cho audio.cpp — việc riêng, chưa làm ở đây.

### 2.8 PSRC-171b (2026-11-12) — "import giọng thành công mà giọng không hiện"

**Triệu chứng (owner, bản Beta cũ):** dùng bản sao gói VieNeu-TTS từ một mirror
Hugging Face (`.../turbo/gguf` + `voices/<tên người đọc>/`), khởi tạo engine
thành công, **import giọng báo thành công**, nhưng danh sách giọng vẫn chỉ có
"Minh Quang Pro", và không đọc được câu nào.

**Nguyên nhân.** Khâu nhận diện giọng chỉ dò **đúng 3 tên file** của gói gốc
(`ref_codes.txt`, `ref_codes.bin`, `speaker.emb.txt`). Mirror cộng đồng thường
đặt tên khác (`codes.txt`, `embedding.txt`, `ref_codes.csv`…) ⇒ thư mục bị coi
là "không có dữ liệu giọng" nên **không được liệt kê**, dù đã copy vào đúng
chỗ. Bản Beta cũ còn có thêm hai lỗi ở §2.7 (spec model + embedding 256 số 0)
nên kể cả giọng hiện ra cũng không đọc được.

audio.cpp **không quan tâm tên file**: `reference_codes_file` /
`speaker_embedding_file` nhận đường dẫn bất kỳ. Vậy chỗ sai nằm hoàn toàn ở
Dart.

**Sửa.**

| Thành phần | Thay đổi |
|---|---|
| `vieneu_tts_paths.dart` | `VieneuVoiceDataKind` + `classifyVieneuVoiceDataText()` — phân loại **theo nội dung**: dòng đầu đủ **192 float** ⇒ embedding; toàn số nguyên ⇒ ref codes; còn lại ⇒ không rõ |
| `vieneu_model_files.dart` | `resolveVieneuVoiceFiles()` — **tên chuẩn trước**, rồi mới "ngửi" nội dung các file text ≤ 8 MB (đọc ≤ 256 KB), bỏ qua `.wav/.png/.json/...`. `folderHasVieneuVoiceData()` nay dùng chính hàm này ⇒ **đường import và đường liệt kê dùng CÙNG một định nghĩa** |
| `vieneu_tts_engine.dart` | `_scanVoiceDirectory()` dùng resolver ⇒ giọng đặt tên file khác vẫn hiện; `_hasVoiceData`/`_hasUsableEmbedding` (bản sao thứ hai của cùng logic) bị xoá |
| Cài đặt | nút **"Không thấy giọng vừa import?"** (cả khi danh sách rỗng): hiện gốc thư mục, tên model, `sea_g2p.bin` có/thiếu, và **từng thư mục giọng** kèm `✅ dùng được` / `⚠️ rỗng` / `⚠️ không có file dữ liệu giọng` / `❌ file không đúng định dạng` + tên các file |

**Chưa làm (có chủ ý).**
* Thư mục chỉ có **mẫu WAV** (không có mã/embedding) chưa được tự mã hoá lúc
  dùng — cần thêm đường "encode lazy khi chọn giọng"; hiện bảng chẩn đoán nói
  rõ file nào đang bị bỏ qua thay vì im lặng.
* Định dạng `.npy` / `.pt` (nếu mirror nào dùng) **không** đọc được — phải là
  text như audio.cpp yêu cầu.

**Kiểm chứng:** `test/tts/psrc171b_voice_disk_discovery_test.dart` (14 ca: phân
loại nội dung, resolver với thư mục thật, 4 trạng thái chẩn đoán). Chưa kiểm
máy thật.

### 2.9 PSRC-171c (2026-11-12) — gói giọng của upstream (`<Tên>.pt` + `<Tên>.txt` + `<Tên>.wav`)

**Bằng chứng từ máy owner** (hộp thoại "Vì sao giọng không hiện?"):
`voices/` **0 thư mục**, `cloned_voices/123 — dùng được`, `sea_g2p.bin: có`.
Nghĩa là: engine nạp được model, **giọng clone do app tạo đọc được** (mã hoá ref
codes đã chạy), nhưng thư mục giọng của gói tải về **không được import**.

**Nguyên nhân.** Gói giọng của upstream (`src/vieneu/assets/samples/` trong
`pnnbao97/VieNeu-TTS`) gồm **ba** file: `<Tên>.pt` (mã + embedding), `<Tên>.txt`
(lời mẫu), `<Tên>.wav` (âm thanh). Không file nào tên `ref_codes.txt` /
`speaker.emb.txt` ⇒ §2.8 (nhận theo nội dung) vẫn không cứu được: `.pt` là
pickle của torch, `.txt` là lời nói, `.wav` là âm thanh. Thư mục bị coi là
"không có dữ liệu giọng" ⇒ import bỏ qua, `voices/` rỗng.

**Sửa.** Thêm đường thứ ba: **giọng đóng gói dạng mẫu âm thanh**.

| Thành phần | Thay đổi |
|---|---|
| `resolveVieneuVoiceFiles()` | trả thêm `samplePath` (file `.wav` > 1 KB) và `isVoice = usable \|\| samplePath != null`; `folderHasVieneuVoiceData()` dùng `isVoice` ⇒ **import copy được** thư mục giọng chỉ có mẫu |
| `VieneuVoiceFolderStatus.sampleOnly` | bảng chẩn đoán hiện `🎙️ <tên> — chỉ có mẫu WAV, mã hoá khi đọc lần đầu`; `voices/` rỗng có thêm dòng gợi ý |
| Engine | `_materializeSample()`: khi chọn giọng chưa có mã, copy mẫu vào `<thư mục giọng>/_encode_sample/` rồi gọi `_core.cloneVoice()` (chính đường `encode_reference_only` của PSRC-171) ⇒ sinh `<thư mục giọng>/ref_codes.txt`; lần sau dùng thẳng, không mã hoá lại. Lỗi mã hoá **không chặn** giọng khác |

**Vì sao không đọc `.pt`:** `.pt` là pickle + zip của torch, audio.cpp không có
đường đọc; trong khi `.wav` đi đúng đường native đã kiểm (giải WAV 9/10 định
dạng, `encode_reference_only`) nên kết quả giống hệt giọng do người dùng tạo.

**Chưa kiểm máy thật.** Cần owner cài APK mới, import lại thư mục `voices/`
của gói, rồi chọn giọng mới (lần đọc đầu chậm thêm ~1–3 s để mã hoá mẫu).

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

- 2026-11-12 | rebase lên 251e | agent `arena/60e35d65-in4up` | owner yêu cầu:
  *"hãy rebase từ 251e vì nó có commit mới"*. Nhánh beta **93 commit** được
  replay lên tip mới `arena/01a0251e-in4up` (`f46a54a`, hơn nền cũ 9 commit:
  DICT-SOURCE-001 / DICT-PACK-002 / DICT-LINK-002 + CI log từ điển). Xung đột
  chỉ ở 7 tệp nối đuôi: `KANBAN.md` (giữ **cả hai** card), `tool/priority_native_pack.json`
  (merge JSON 3 chiều theo từng khoá), `generated_priority_native_pack.dart`
  (sinh lại bằng `tool/generate_priority_native_pack.py`, không sửa tay),
  `app_analyze.yml` / `AGENTS.md` / `pubspec*` (auto-merge). Sau rebase: cây sạch,
  không còn dấu xung đột, pack JSON ≡ mã sinh ra, `251e` là tổ tiên.
  **CI: `app_analyze` [43754214001](https://github.com/Pabhassaracitto/In4Up/actions/runs/43754214001) 🟢,
  `listen_queue` 43754214010 🟢, `vieneu_engine_build`
  [43754214070](https://github.com/Pabhassaracitto/In4Up/actions/runs/43754214070) 🟢** (APK artifact từ HEAD `8d369ee`).
- 2026-11-12 | PSRC-171c | agent `arena/60e35d65-in4up` | hộp thoại chẩn đoán
  trên máy owner cho thấy `voices/` **rỗng** còn `cloned_voices/123` dùng được:
  gói giọng của upstream là `<Tên>.pt` + `<Tên>.txt` + `<Tên>.wav` nên cả nhận
  theo tên lẫn theo nội dung đều trượt. Nay thư mục chỉ có mẫu WAV vẫn là một
  giọng: import copy được, engine mã hoá mẫu **một lần** qua
  `encode_reference_only`` → `ref_codes.txt`, rồi đọc bình thường. Xem §2.9.
  Chưa kiểm máy thật.
- 2026-11-12 | PSRC-171b | agent `arena/60e35d65-in4up` | "import giọng báo
  thành công mà giọng không hiện" (owner, mirror Hugging Face): khâu nhận diện
  chỉ dò đúng 3 tên file của gói gốc ⇒ thư mục giọng đặt tên khác bị bỏ qua. Nay
  nhận diện **theo nội dung** (`resolveVieneuVoiceFiles`) dùng chung cho cả
  import và liệt kê, và Cài đặt có bảng chẩn đoán từng thư mục. Xem §2.8.
  Chưa kiểm máy thật.
- 2026-11-12 | PSRC-171 build xanh | agent `arena/60e35d65-in4up` | `vieneu_engine_build` run
  [43708199917](https://github.com/Pabhassaracitto/In4Up/actions/runs/43708199917) 🟢 (step 18 mới xác minh
  **trong APK**: `libvieneu_tts.so` chứa `"display_name": "VieNeu-TTS v3 Turbo"`; `libvieneu_tts.so` 1,0 MiB,
  `libaudiocpp.so` 4,9 MiB) + `app_analyze` run
  [43708199889](https://github.com/Pabhassaracitto/In4Up/actions/runs/43708199889) 🟢 4/4 job, commit `1e18992`.
  Run [43706402644](https://github.com/Pabhassaracitto/In4Up/actions/runs/43706402644) trước đó **đỏ** ở
  `:vieneu:buildCMakeDebug[arm64-v8a]` vì đã xoá `AUDIOCPP_MODEL_SET=custom` + `AUDIOCPP_MODELS` với giả
  định sai rằng chúng là no-op: hai option đó **chọn model nào được biên dịch** (`CMakeLists.txt` L425-427,
  L2878+) nên bỏ đi ⇒ `full` ⇒ `latentsync/video.cpp` (`posix_spawn_file_actions_*`, NDK không khai báo) vào
  build. Chúng **không** cấp model spec — §2.7 giữ nguyên. Chưa kiểm máy thật.
- 2026-11-12 | PSRC-171 | agent `arena/60e35d65-in4up` | nhúng model spec vào `libvieneu_tts`
  (audio.cpp v0.9.4 không nhúng spec ⇒ chưa từng nạp được model), viết lại `vieneu_tts_clone_voice`
  để mã hoá mẫu thu âm thành ref codes thật (`encode_reference_only`) thay cho embedding 256 số 0,
  và phân loại lỗi nạp model để UI hết báo sai. Xem §2.7. Chưa kiểm máy thật.


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
- 2026-11-14 | land L2 | agent `arena/60e35d65-in4up` | `arena/377f5fa5-in4up` rebase 6 commit →
  `558e1587` (PSRC-202/203/205/219/220). Hợp nhất xung đột với L7 trong `media_export_follow_up.dart`
  (giữ "Mở thư mục" của ADR-0029 + luồng kiểm file bị dời của L2). Chốt **không nhúng libmpv**: package
  `media_kit_libs_linux` trên Linux không bundle lib (set rỗng) ⇒ yêu cầu `libmpv2` từ hệ điều hành, kèm
  fallback "mở ngoài". Còn nợ G4: cập nhật `pubspec.lock` (chưa ai chạy được `flutter pub get` trong
  sandbox) + pin `media_kit_libs_linux`. Chưa kiểm Linux thật (G3). Chi tiết:
  `beta-1.29.0/L2-hub-nghiem-thu.md`.

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
- 2026-11-15 | PSRC-245/246/247/248/249 | agent `arena/60e35d65-in4up` | **vì sao bản
  beta vẫn "đọc bằng Piper/hệ thống"**: `_loadPersistedSettings` nối engine MỚI xuống
  CUỐI prefs ⇒ với người dùng nâng cấp, `vieneu_tts` nằm sau `offline_tts` (giọng máy,
  luôn phát được) và **không bao giờ được gọi**. Nay có hàm thuần
  `mergePersistedEngineOrder` (chèn theo ưu tiên mặc định, giữ thứ tự người dùng đã sắp,
  di trú một lần cho prefs đã lỡ lưu vieneu ở cuối) + 6 unit test; `synthesizeToFile`
  ("lưu âm thanh") cũng đi VieNeu trước Piper/Edge. Kèm 4 chỉnh UI theo yêu cầu owner:
  panel «Công cụ đọc» có chip **Về thư viện đọc** (3 tab Gần đây/Cloud/Thiết bị, nút quay
  lại) thay cho «Mở nguồn» trùng lối ở góc trái trên; **hoán đổi icon** robot ⇄ thư viện
  giữa AppBar shell và header Home; **bảng «Hướng dẫn đọc theo dòng» sửa lại cho khớp cử
  chỉ thật** sau PSRC-234 (chạm đúp = đọc + dịch cả dòng, giữ dòng = bảng hành động, không
  còn "chạm đúp để tra nghĩa"); danh sách mẫu WAV trong Voice Clone hiện tên + dung lượng
  + xoá từng mẫu. 15 chuỗi × 8 locale (pack 3.785 khoá). Còn mở: import TRỌN BỘ thư mục
  (PSRC-249-A) và đồng bộ giao diện "gương màu" — **chưa kiểm máy thật**.
