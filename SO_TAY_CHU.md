# Sổ tay chủ — In4Up

> Chỗ ghi **cho bạn** (và trợ lý Arena khi bạn bảo ghi).  
> Không thay KANBAN / PLAN / HANDOFF. Ba file kia = việc dự án. File này = **chỉ dẫn vận hành của chủ**.

## Luật ghi chép (agent đọc trước khi sửa file này)

Khi chủ nói *«ghi chép»*, *«nhớ hộ»*, *«thêm vào sổ tay»*:

1. Chỉ **append**. Không xóa mục đã chốt. Không viết lại lịch sử.
2. Việc mới / quyết định mới → thêm mục dưới **Nhật ký** (ngày + 3–8 dòng, tiếng Việt, cụ thể: SHA, nhánh, file).
3. Quyết định thay thế cái cũ → gạch một dòng «cũ: … → nay: …» trong mục tương ứng, rồi ghi nhật ký.
4. Không nhét code dài, không nhét ARB, không nhét dump CI. Link + hash là đủ.
5. File nằm **gốc repo** (`SO_TAY_CHU.md`) vì `docs/` đang `.gitignore` — chủ không thấy file trong `docs/` trừ khi `git add -f`.
6. Đưa lên cái chung: path-checkout **một file này** vào leader 251e. Không merge cả nhánh trợ lý.

Đọc đầu phiên (cái chung):

```bash
git fetch origin
git show origin/arena/01a0251e-in4up:SO_TAY_CHU.md
```

---

## 1. Ba làn — đừng để Beta thành khay vá

| Làn | Nhánh | Việc được | Việc cấm |
|---|---|---|---|
| Ổn định | `main` | Tag `vA.B.C`, hotfix, release | Agent không push trực tiếp. Không force-push / squash-rewrite main |
| DEV / leader | `arena/01a0251e-in4up` | Nơi **duy nhất** chức năng mới đáp | Không dùng làm nhánh session của một agent |
| Beta | `arena/01a02a12-in4up` | Chỉ nhận **từ 251e** khi đã xanh + chủ smoke được. Build APK | Không hứng hàng từ 580, 18e, 2601… |

- **630** (`arena/019fe630-vipsound`) = leader cũ, **đóng băng** (hết lưu lượng / không trả lời). 251e = 630 + ~27 commit. Không PR vào 630.
- **580** (`arena/01a01580-in4up`) = khay vá của trợ lý này. **Không** phải Beta. Không merge cả 580 vào 251e/630.

```
Agent Arena (topic)  --path-checkout / PR nhỏ-->  251e (DEV)
                                                      |
                                      xanh + chủ cầm máy
                                                      ↓
                                                   beta  (build APK)
                                                      |
                                      ổn trên máy thật
                                                      ↓
                                                   main  (tag vA.B.C)
```

---

## 2. Đưa code: path-checkout, không merge mù

Nỗi lo đúng: merge khi lệch hàng trăm commit → không biết giữ gì → mất chức năng.

**Cấm** (với khay 580 và hầu hết `arena/*`):

- `git merge arena/01a01580-in4up` vào 251e/630/main  
- `git cherry-pick 928525a` / `e4b51ff` (parent 580, đích 251e → conflict giả)

**Làm:** lấy đúng blob file (rule 630 `8ae1022`, vẫn dùng cho 251e).

Git Bash (MINGW64) dùng `\` nối dòng. **PowerShell** không được — `\` bị Git hiểu là path. PowerShell: một dòng, hoặc backtick `` ` ``.

```bash
# đứng trên leader 251e
git fetch origin arena/01a01580-in4up

# Vá 1 — STT: tải khi bấm, không tự tải lúc mở app
git checkout 928525a -- \
  lib/screens/settings/stt_model_settings_screen.dart \
  packages/in4up_stt/lib/stt_model_manager.dart \
  packages/in4up_stt/lib/stt_service_facade.dart \
  packages/in4up_stt/lib/models/stt_model_info.dart

# Vá 2 — Viết: chấm 2 tầng + reload engine khi import .gguf
git checkout e4b51ff -- \
  lib/screens/read_mode/write_studio_screen.dart \
  packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart \
  packages/in4up_ai/lib/src/engine/ai_engine_mock.dart \
  packages/in4up_ai/lib/src/facade/ai_service_facade.dart \
  packages/in4up_ai/lib/src/models/ai_analysis.dart

# Sổ tay chủ
git checkout e0891de -- SO_TAY_CHU.md

git status
git diff --stat
git commit -m "sync(580): tai model khi bam + cham viet 2 tang + so tay chu"
git push origin arena/01a0251e-in4up
```

**2026-08-22:** cũ: Vá 1 chưa commit/push trên leader → nay: đã lên `251e` (`dfe81f7` / `6388114` / `6ef395c`). BETA còn chậm 4 commit — FF sau mục 9.

Khi conflict kiểu khác (hai nhánh cùng sửa 1 file sống):

| Muốn giữ | Lấy |
|---|---|
| VAD / Soundlist / tablet STT / governance | **251e** |
| Tải Whisper khi bấm / chấm viết 2 tầng / reload `.gguf` | **đúng 9 file trên** |

---

## 3. Ba file dự án (việc) — khác sổ tay này

| File | Việc | Ai viết | Nhịp |
|---|---|---|---|
| HANDOFF / blueprint | Hợp đồng: được / không | Chủ chốt. Agent **không sửa** bản đã đóng | Đổi = `HANDOFF_v3`, không ghi đè v2 |
| `docs/project/PLAN.md` | Milestone + ý chủ mới | Chủ đề. Agent chỉ **append** «Kế hoạch mới» | Chậm |
| `docs/project/KANBAN.md` | Việc, trạng thái, bằng chứng | Agent append lịch sử. Không xóa dòng | Mỗi khi xong việc |

Vòng: đầu phiên đọc **251e** (không đọc main làm bảng việc — main chậm ~557 commit). Làm trên nhánh topic. Đưa KANBAN/PLAN lên 251e bằng path-checkout 2 file. Conflict KANBAN: giữ **cả hai dòng lịch sử**; ô Trạng thái = dòng **mới hơn theo giờ**.

`docs/` đang gitignore → muốn chủ thấy: `git add -f` các file việc, hoặc giữ bản sống ở gốc repo. Đừng tin file chỉ nằm trong `docs/` chưa force-add.

Một **thủ thư** (chủ hoặc 1 session ngắn trên 251e), 1–2 lần/ngày: checkout KANBAN/PLAN từ nhánh đã xong. Đừng để 8 agent cùng sửa KANBAN trên 251e.

---

## 4. Version a.b.c và APK

Không chờ «làm hết plan». Không mỗi card KANBAN một version.

| Số | Khi nào |
|---|---|
| **C** `1.4.1` → `1.4.2` | Sửa hỏng, không đổi HANDOFF (crash, chấm viết hiện lại, cho bấm Tải về) |
| **B** `1.4.2` → `1.5.0` | Tính năng mới, user cũ vẫn dùng được. Một **mốc PLAN đã cầm máy** |
| **A** `1.5.0` → `2.0.0` | Gãy tương thích / đổi hiến pháp (schema không migrate, bỏ reopen nguồn, gộp 3 skill SM-2) |
| **+N** `1.5.0+12` | Mỗi APK đưa ra ngoài (kể cả beta). Tăng đều |

Milestone PLAN (M0/M1/M2) = chủ đề, **không** phải số version. M2 xong ≠ `2.0.0`.

Tên APK gọn:

```
In4Up-1.5.0+12-beta-fcaf125.apk
```

`tên-a.b.c+build-kênh-hash7`. Kênh: `dev` / `beta` / số tag.  
Trong app (Về ứng dụng): `1.5.0+12 · beta · fcaf125 · 2026-08-21`.

Một nguồn số: `pubspec.yaml` `version: A.B.C+N`. Android đang cứng `versionName 1.0.0` — lần release thật nhớ bỏ cứng, đọc pubspec.  
Tag annotated: `git tag -a v1.5.0 -m "…"`. Cấm tag bisect/test bằng `v1.4.0-*`.

Đồng hồ hiện lệch (`pubspec 1.4.1+3`, gradle `1.0.0`, tag `1.6.5` / `v1.4.0`). Lần phát thật tiếp theo: chọn **một** số (gợi ý `1.5.0` nếu đây là gói 251e sau VAD/Soundlist/chấm viết), ghi «đồng hồ mới từ đây». Tag cũ giữ, không xóa.

---

## 5. Sự thật kỹ thuật đã chốt (đừng chẩn đoán lại từ đầu)

### 5.1 Whisper / «Tải về» bị khóa

Trên 251e/630, Home → Quản lý Model AI chồng 3 khóa: không auto HTTP (đúng), nút Tải về chỉ dialog «chép file», Import chỉ `kDebugMode`.  
Lỗi gốc tablet: **tự** HTTP HuggingFace lúc mở app + Battery Saver → `HttpException` → đen màn.  
Cơ chế đúng: cửa tự động **cấm HTTP**; cửa user bấm **được tải** (HF rồi GitHub). Vá: `928525a`.

### 5.2 LRC / «Tạo lời thoại» tiếng Việt ra tiếng Anh

Không phải i18n chrome, không phải `tiny.en`.  
`generateLrcForCurrentAudio` hardcode `language: 'en'` trong `lib/providers/player/player_stt_mixin.dart` (VAD ~223, `transcribeAuto` ~267, `SttConfig` ~284). Whisper nhận `-l en` thì **ép decode English**.  
Hàm VAD default `language = 'vi'` nhưng caller đè `'en'`.  
Sửa thuộc **251e / Soundlist**, không lén trên 580 trừ khi chủ bảo.

### 5.3 Tab Viết — chấm 2 tầng «mất»

UI không bị xóa. Tầng 1 (Chấm nhanh) vẫn chạy. Tầng 2 không **hiện** vì `fromGemmaJson` để `inputText = ''` trong khi studio so khớp prompt.  
Import `.gguf` không dùng được: lúc mở app đã `initialize` mock, lần sau `if (_initialized) return`. Isolate cũ luôn mock generic.  
Vá: `e4b51ff`. `hasModel` chỉ true khi có GGUF thật.

### 5.4 Home I2U Chat

Mở được, round-trip **mock**. Không phải gia sư cho đến khi có model local + (sau này) grounding. `hasModel` từng nói dối (true cả mock).

### 5.5 In4Up không phải RAG

Local-first. Không embedding / vector DB (M3 out-of-scope). Hai công thức SM-2 còn sống (`WordEntry.SkillReviewData.review` vs `SM2Algorithm.calculate`) — đừng gộp 3 skill thành 1 điểm.

### 5.6 i18n chrome

Locale ≠ vi → chrome UI không còn tiếng Việt. Thiếu dịch → **English**, không bao giờ fallback `vi`.  
Không áp cho: văn bản user, lyric, vocab, output AI, STT, tiêu đề auto-TOC.

### 5.7 Vùng cấm (AGENTS.md)

1. Không đụng UltraTimeStretch C++ FFI / `lib/ffi/`.  
2. Không gộp 3 skill SM-2.  
3. Không làm mất reopen nguồn (PDF page/rect, Web url/scroll, audio timestamp).  
4. Đổi kiến trúc: ADR, không «hội đồng AI».

---

## 6. Việc chủ còn cầm (không giao agent «xong trên giấy»)

- [x] Leader: Vá STT + viết + sổ tay đã lên `251e` (`dfe81f7` / `6388114` / `6ef395c`).  
- [x] Governance mục 2a (sandbox fetch thiếu `arena/*`) đã trên `251e` `6ef395c`.  
- [ ] BETA chỉ FF/merge từ 251e sau khi đã nhận 02601 + 296a (mục 9). Không checkout 580 thẳng vào BETA.  
- [ ] Đổi base PR Soundlist #7 `main` → `251e`. **Đừng merge #7 vào main.**  
- [ ] LRC tiếng Việt: agent 251e/Soundlist sửa hardcode `'en'`.  
- [ ] Appendix B auto-TOC tiếng Việt: chủ cầm máy.  
- [ ] Đồng bộ `pubspec` + gradle version.  
- [ ] Một dòng đầu `AGENTS.md` 251e: leader = 251e, BETA = `01a02a12`, 630 archived.

Sandbox Arena thường **không có Flutter** — agent không được nhận đã `flutter analyze` / chạy app.

---

## 7. Câu chủ hay bảo trợ lý

| Chủ nói | Agent làm |
|---|---|
| Ghi chép / nhớ hộ | Append **Nhật ký** file này |
| Đưa vá lên 251e | In lệnh path-checkout, **không** merge |
| Tạo bản / version | Chỉ khi chủ bảo release; theo mục 4 |
| Thêm vào plan | Append PLAN «Kế hoạch mới», không sửa milestone đã đóng |
| Việc xong | Append KANBAN lịch sử + bằng chứng SHA/run |
| Ghi A. Repo / cái chung cái riêng | Đọc mục 8. **Không** tạo GitHub repo mới |

---

## 8. Cái chung / cái riêng — «A. Repo» không phải repo mới

Ai đó gọi **A. Repo** = **tầng A: thông tin chung sống trong git của chính dự án**.  
**Không** tạo GitHub repo thứ hai, **không** submodule, **không** «lấy repo về dự án».

| Tầng | Ở đâu | Đưa gì vào | Cấm |
|---|---|---|---|
| **A. Cái chung** | Repo **In4Up này**, sống trên **251e** | `SO_TAY_CHU.md`, `KANBAN.md`, `PLAN.md`, `AGENTS.md`, `GOVERNANCE.md`, ADR, code đã chốt | Secret, token, `google-services.json` thật, model `.gguf`, ghi chú đời tư |
| **B. Cái riêng** | Máy chủ / GitHub Secrets / folder ngoài git | Firebase secret, PAT, GGUF, nhật ký cá nhân | Commit vào In4Up |

Cách vận hành thật (không thêm hệ thống):

1. Việc dự án → card KANBAN + dòng PLAN trên **251e** (path-checkout 2 file, không merge cả nhánh).  
2. Chỉ dẫn cầm máy của chủ → **append** `SO_TAY_CHU.md` rồi checkout 1 file đó lên 251e.  
3. Luật kỹ thuật ít đổi → `AGENTS.md` / `GOVERNANCE.md`.  
4. Hợp đồng đã đóng → `HANDOFF_*` **không sửa**; bản mới = file mới.

**Một repo cho nhiều dự án?** Không nhét KANBAN In4Up vào Meetily / dự án khác. Mỗi repo sản phẩm một bộ A.  
Muốn «sổ tay đời sống» dùng chung nhiều dự án: folder trên máy hoặc **một private repo đứng riêng** (ví dụ `chu-ops`) — **không** kéo vào In4Up.

`docs/` đang `.gitignore` → chủ không thấy file trong `docs/` trừ khi `git add -f`. Sổ tay chủ để **gốc repo** vì lý do đó.

---

## 9. Đưa nhánh đã xong vào DEV (251e) — thứ tự

**Cấm:** `git merge` cả 580 / 18e / 296a / 02601 nếu chưa biết file nào chồng.  
**Làm:** path-checkout đúng list. PowerShell: một dòng hoặc backtick. Git Bash mới dùng `\`.

### Đã có trên 251e (`6ef395c`) — khỏi đưa lại

Knowledge `01a019bb`, Sherpa VAD+Piper, vá 580 (STT tải khi bấm + chấm viết 2 tầng + sổ tay), App Analyze xanh run `32584287028`.

### Lần 1 — AI Chat native `02601` (PR #8, đã nhắm 251e)

Hai file **không** lấy nguyên từ 02601 (sẽ **xóa** mock viết + `forceReload` 580):

- `packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart` → giữ 251e; isolate «báo sẵn sàng trước khi load GGUF» đã ghép trên 580 (sau commit sổ tay này).  
- `packages/in4up_ai/lib/src/facade/ai_service_facade.dart` → **giữ 251e**.

Git Bash, đứng trên worktree **leader 251e**:

```bash
git fetch origin arena/01a02601-in4up:refs/remotes/origin/arena/01a02601-in4up
git fetch origin arena/01a01580-in4up:refs/remotes/origin/arena/01a01580-in4up

git checkout origin/arena/01a02601-in4up -- \
  .gitmodules \
  android/app/build.gradle.kts \
  android/app/src/main/cpp/ai/CMakeLists.txt \
  packages/in4up_ai/native/in4up_ai_native.cpp \
  packages/in4up_ai/native/in4up_ai_native.h \
  packages/in4up_ai/native/README.md \
  packages/in4up_ai/lib/src/loader/ai_model_loader.dart \
  packages/in4up_ai/test/in4up_ai_test.dart \
  windows/CMakeLists.txt \
  windows/runner/CMakeLists.txt

git checkout origin/arena/01a01580-in4up -- \
  packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart

# Submodule llama.cpp (gitlink). Sau checkout:
git submodule update --init --depth 1 -- third_party/llama.cpp

git add -A
git status
git diff --stat
# Xem 2 file gemma + facade: facade không đổi; gemma chỉ thêm log isolate.
git commit -m "sync(02601): llama.cpp native AI chat; giu cham viet 2 tang"
git push origin arena/01a0251e-in4up
```

KANBAN/PLAN: **đừng** checkout cả file từ 02601 (đè card 251e). Thủ thư: copy tay card `AICHAT-01` + `PLAN-014` rồi append.

`lib/main.dart`: 251e đã `currentPlatform` / Android đọc `google-services.json` — **không** lấy `main.dart` 02601.

### Lần 2 — Sứ giả ngôn ngữ `296a` (CI xanh `32573825623`)

296a cắt từ `fcaf125` — **thiếu** vá 580. Checkout nhầm `write_studio` / `stt_*` / `in4up_ai` / `SO_TAY` = **xóa** chấm viết và sổ tay.

```bash
git fetch origin arena/01a0296a-in4up:refs/remotes/origin/arena/01a0296a-in4up
git checkout origin/arena/01a0296a-in4up -- \
  lib/core/language/language_roadmap.dart \
  lib/core/language/app_ui_translations.dart \
  lib/core/language/generated_ui_translations.dart \
  lib/l10n/app_hi.arb lib/l10n/app_si.arb lib/l10n/app_zh.arb lib/l10n/app_zh_TW.arb \
  lib/l10n/app_localizations_hi.dart \
  lib/l10n/app_localizations_si.dart \
  lib/l10n/app_localizations_zh.dart \
  generate_arbs.py \
  tool/lang_keep_english.json \
  tool/lang_rollout_floors.json \
  tool/lang_rollout_report.py \
  test/locale_chrome_no_vietnamese_test.dart
git commit -m "sync(296a): su gia ngon ngu wave 1 hi/zh/si"
git push origin arena/01a0251e-in4up
```

KANBAN: append card `LANG-630-01` tay. Không checkout cả `KANBAN.md` / `SO_TAY_CHU.md` từ 296a (296a **xóa** sổ tay).

### Chưa đưa

| Nhánh | Lý do |
|---|---|
| Soundlist `01a0018e` PR #7 | Base `main`, conflict, ~392 file. Đổi base → 251e rồi path-checkout từng cụm (auto-TOC / thư viện). |
| 580 cả nhánh | Khay vá. Chỉ còn gemma isolate ở Lần 1. |
| `02a4a` | Chưa tồn tại trên GitHub. |

### Sau khi 251e xanh + chủ cầm máy

```bash
# worktree BETA
git fetch origin arena/01a0251e-in4up:refs/remotes/origin/arena/01a0251e-in4up
git merge --ff-only origin/arena/01a0251e-in4up
git push origin arena/01a02a12-in4up
```

App Analyze 251e đã xanh. Full APK Android trên GitHub (tag `v*`) lần cuối vẫn đỏ google-services/`com.in4up.beta` — sửa `build.yml` `--flavor stable` (quyền workflows), không tắt flavor trong Gradle.

### Tên APK Flutter 3.44.1 (đừng đảo)

Source `packages/flutter_tools/lib/src/android/gradle.dart` hàm `_apkFilesFor`:

```
app$flavorString-$abi-$buildType.apk
→ app-stable-arm64-v8a-release.apk
```

**Đúng:** `app-<flavor>-<abi>-release.apk` và universal `app-stable-release.apk`.  
**Sai** (nhánh `02a4a` đảo): `app-arm64-v8a-stable-release.apk`.

`build_final_complete.yml` bước Rename **đã đúng** flavor-trước. Chỉ ra 1 APK universal vì bước Split có `||` — split đỏ thì im lặng build fat, không phải vì tên ABI-trước.

Patch `build.yml` (chủ dán, quyền `workflows`) — GitHub web editor:

```yaml
# Build Split + Build Universal: thêm --flavor stable
flutter build apk --release --flavor stable --split-per-abi ...
flutter build apk --release --flavor stable ...

# Rename All APKs — 4 dòng mv nguồn:
app-armeabi-v7a-release.apk  → app-stable-armeabi-v7a-release.apk
app-arm64-v8a-release.apk    → app-stable-arm64-v8a-release.apk
app-x86_64-release.apk       → app-stable-x86_64-release.apk
app-release.apk              → app-stable-release.apk
```

`02a4a` (PR #9 → **main**, 214 file): đã bỏ lách Gradle (đúng). Pin CMake 3.31.5 khi `CI=true` (`5995183`) hợp lý nhưng oracle `32586625020` Android vẫn đỏ Split APKs — cần log, đừng đoán. **Đừng merge PR #9 vào main.** Base đúng = 251e (như PR #8). CMake pin path-checkout 1 file `android/app/build.gradle.kts` sau Lần 1.

---

## Nhật ký

### 2026-08-22 | trợ lý 580 | A. Repo + thứ tự vào DEV

- «A. Repo» = tầng A trong **chính repo In4Up** (251e). Không tạo GitHub repo mới; không dùng một repo cho nhiều sản phẩm.
- 251e đã có Knowledge + Sherpa + vá 580. Việc tiếp: path-checkout 02601 (trừ gemma/facade) rồi 296a (chỉ file ngôn ngữ). Cấm merge 18e vào main.
- Ghép isolate 02601 (báo sẵn sàng trước load GGUF) vào gemma 251e — giữ mock viết 2 tầng.

### 2026-08-22 | trợ lý 580 | lập sổ tay

- Chốt 3 làn: main ổn định, 251e DEV leader, beta chỉ build từ 251e. 630 đóng băng. 580 = khay vá.
- Hai vá chờ checkout vào 251e: `928525a` (STT tải khi bấm), `e4b51ff` (chấm viết 2 tầng + reload GGUF).
- Version: C sửa / B mốc đã cầm máy / A gãy HANDOFF. APK: `a.b.c+N-kênh-hash7`.
- Cái chung việc = KANBAN+PLAN trên 251e, không phải main. Handoff đóng. Sổ tay này = chỉ dẫn chủ.
- File tạo trên `arena/01a01580-in4up`. Chủ đưa lên 251e bằng:  
  `git checkout origin/arena/01a01580-in4up -- SO_TAY_CHU.md`
