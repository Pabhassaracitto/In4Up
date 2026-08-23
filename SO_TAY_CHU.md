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

**2026-08-22:** lệnh Vá 1 đã chạy trên worktree leader (Git Bash) nhưng **chưa commit/push** — `origin/251e` và BETA vẫn file khóa cũ. Phải `git status` trên leader: nếu 4 file STT staged/modified thì commit ngay, rồi làm Vá 2 + sổ tay.

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

- [ ] Leader: commit + push Vá 1 (STT) nếu `git status` còn 4 file. Rồi Vá 2 + `SO_TAY_CHU.md`.  
- [ ] Kéo 2 file governance từ BETA `9b4fb41` về 251e (`AGENTS.md`, `docs/GOVERNANCE.md` mục 2a — sandbox fetch thiếu `arena/*`).  
- [ ] BETA chỉ FF/merge từ 251e sau khi leader đã có 9 file + sổ tay. Không checkout 580 thẳng vào BETA.  
- [ ] Đổi base PR Soundlist #7 `main` → `251e`.  
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

---

## Nhật ký

### 2026-08-22 | trợ lý 580 | lập sổ tay

- Chốt 3 làn: main ổn định, 251e DEV leader, beta chỉ build từ 251e. 630 đóng băng. 580 = khay vá.
- Hai vá chờ checkout vào 251e: `928525a` (STT tải khi bấm), `e4b51ff` (chấm viết 2 tầng + reload GGUF).
- Version: C sửa / B mốc đã cầm máy / A gãy HANDOFF. APK: `a.b.c+N-kênh-hash7`.
- Cái chung việc = KANBAN+PLAN trên 251e, không phải main. Handoff đóng. Sổ tay này = chỉ dẫn chủ.
- File tạo trên `arena/01a01580-in4up`. Chủ đưa lên 251e bằng:  
  `git checkout origin/arena/01a01580-in4up -- SO_TAY_CHU.md`
